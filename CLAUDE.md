# CLAUDE.md — cv-database

Data layer for cv-project: MySQL 8 schema managed exclusively through **Flyway 10 versioned migrations**. Every other repo's persistence depends on what this repo says the schema is. Cross-repo context: meta repo CLAUDE.md one directory up.

## Commands

```bash
docker compose up -d        # MySQL 8 on :3306 (db cv, user/pass cv/cv, root/root)
./scripts/migrate.sh        # apply migrations + dev seeds via dockerized Flyway
./scripts/reset.sh          # nuke volume, restart MySQL, re-migrate
docker compose down -v      # full teardown including data
```

CI: `Jenkinsfile` — applies all migrations against a throwaway MySQL container; broken SQL fails the build.

## Rules (breaking these breaks every downstream repo)

1. **Never edit an applied migration.** New change = new `sql/migrations/V{n}__description.sql`. Flyway checksums will reject edited history.
2. **Schema changes land here first.** `cv-domain-service` runs `ddl-auto: validate`; its entities must match these columns. Coordinate: migration PR merges before (or together with) the entity PR.
3. **Dev seed data goes only in `sql/dev-seeds/afterMigrate__seed_dev.sql`** — a Flyway callback that runs after *every* migrate, so every statement must be idempotent (`INSERT IGNORE`, natural-key lookups). Versioned migrations must never contain demo data (they'd reach production).
4. The `dev-seeds` location is listed only in the local `flyway.conf`; production configs point at `sql/migrations` alone.

## Schema (V1)

`person` (unique email) ← `experience` / `education` / `project` (FK cascade delete) · `skill` (unique name) ·  `person_skill` (composite PK person+skill, `proficiency` enum BEGINNER/INTERMEDIATE/ADVANCED/EXPERT).

## Critical gotcha

Flyway 10 bundles the **MariaDB** driver: every MySQL 8 JDBC URL needs `?allowPublicKeyRetrieval=true` (already in `flyway.conf`, the Jenkinsfile, and the meta repo's dev compose). Without it, migrate doesn't fail — it **hangs retrying** with an RSA-public-key warning.

## Git workflow

`master` is protected — feature branch (`feat/…`) → push → PR via `gh`. A schema PR's description must name the downstream repos it affects.
