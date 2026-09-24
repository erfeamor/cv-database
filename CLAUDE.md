# CLAUDE.md — cv-database

Data layer for cv-project: MySQL 8.4 schema managed exclusively through **Flyway 13 versioned migrations**. Every other repo's persistence depends on what this repo says the schema is. Cross-repo context: meta repo CLAUDE.md one directory up.

## Commands

```bash
docker compose up -d        # MySQL 8.4 on :3306 (db cv, user/pass cv/cv, root/root)
./scripts/migrate.sh        # apply migrations + dev seeds via dockerized Flyway
./scripts/reset.sh          # nuke volume, restart MySQL, re-migrate
docker compose down -v      # full teardown including data
```

**Switching an existing local volume between MySQL versions — wipe it.** The image is pinned to
`mysql:8.4`, matching production (`cv-infra`) and the Jenkins migration gate. A `cv-mysql-data`
volume left over from the previous `8.0` pin holds an 8.0-formatted datadir. The supported
route when the pin moves in either direction is to throw the volume away:

```bash
docker compose down -v      # discard the old datadir
docker compose up -d        # the pinned server initialises a fresh one
./scripts/migrate.sh        # migrations + dev seeds regenerate
```

Nothing is lost: the volume only ever holds the migrations plus the `afterMigrate` dev-seed
callback, and `migrate.sh` re-applies both. `./scripts/reset.sh` already does all three steps.

Why wiping is the rule rather than a nicety — the two directions are **not** symmetric
(both verified on this stack, 2026-08-22):

- **8.0 → 8.4 succeeds silently.** The server performs an in-place upgrade on first start
  (`Data dictionary upgrading from version '80023' to '80300'`, `Server upgrade from '80046'
  to '80411' completed`) and comes up healthy. Convenient, but it is a one-way door: your
  volume is now 8.4-formatted.
- **8.4 → 8.0 fails hard and is not recoverable in place.** Checking out any branch still
  pinned at the old `8.0` image after 8.4 has touched the volume aborts startup with
  `[ERROR] [MY-014061] [InnoDB] Invalid MySQL server downgrade: Cannot downgrade from 80411
  to 80046. Downgrade is only permitted between patch releases.` The container exits 1, so it
  never reports `healthy` and `reset.sh`'s health poll **loops forever instead of erroring**.
  The fix is `docker compose down -v`.

CI: `Jenkinsfile` — applies all migrations against a throwaway MySQL 8.4 container (Flyway starts only once the container reports healthy, with a 120 s bound on that wait); broken SQL fails the build. The whole pipeline has a 10-minute timeout. The `Deploy` stage (gated on `master`) is a no-op placeholder.

## Rules (breaking these breaks every downstream repo)

1. **Never edit an applied migration.** New change = new `sql/migrations/V{n}__description.sql`. Flyway checksums will reject edited history.
2. **Schema changes land here first.** `cv-domain-service` runs `ddl-auto: validate`; its entities must match these columns. Coordinate: migration PR merges before (or together with) the entity PR.
3. **Dev seed data goes only in `sql/dev-seeds/afterMigrate__seed_dev.sql`** — a Flyway callback that runs after *every* migrate, so every statement must be idempotent (`INSERT IGNORE`, natural-key lookups). Versioned migrations must never contain demo data (they'd reach production).
4. The `dev-seeds` location is listed only in the local `flyway.conf`; production configs point at `sql/migrations` alone.

## Schema (V1)

`person` (unique email) ← `experience` / `education` / `project` (FK cascade delete) · `skill` (unique name) ·  `person_skill` (composite PK person+skill, `proficiency` enum BEGINNER/INTERMEDIATE/ADVANCED/EXPERT).

## Critical gotcha

Flyway bundles the **MariaDB** driver (both 10.22.0 and 13.7.0 ship only `mariadb-java-client-2.7.14`, verified 2026-09-23 in T-155): every MySQL 8 JDBC URL needs `?allowPublicKeyRetrieval=true` (already in `flyway.conf`, the Jenkinsfile, and the meta repo's dev compose). Without it, migrate doesn't fail — it **hangs retrying** with an RSA-public-key warning.

## Code review guidance

Priorities, ranked:

1. **Migration immutability.** Any edit to an already-applied `sql/migrations/V*.sql` file is a hard blocker — the fix is always a new `V{n+1}` file, never a rewrite. Flyway checksums make an edit fail loudly in CI, but flag it in review before that.
2. **Schema/entity coordination.** A migration adding/renaming a column with no companion PR (or note) in `cv-domain-service` is a gap — `ddl-auto: validate` means the entity must match exactly.
3. **Dev-seed hygiene.** Anything in `sql/dev-seeds/afterMigrate__seed_dev.sql` must be idempotent (`INSERT IGNORE` / natural-key lookups) and must never contain data that could reach a versioned migration.
4. Missing `allowPublicKeyRetrieval=true` on any new MySQL JDBC URL — it doesn't fail fast, it hangs.

Don't flag:
- The `dev-seeds` Flyway location existing only in the local `flyway.conf` (prod intentionally omits it).
- Self-hosted MySQL 8.4 on the domain-service EC2 instead of RDS — a deliberate cost/lifecycle decision (see cv-infra).

## Git workflow

`master` is protected — feature branch (`feat/…`) → push → PR via `gh`. A schema PR's description must name the downstream repos it affects.
