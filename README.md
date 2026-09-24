# cv-database

Data layer for the Currículum Interactivo project: a MySQL schema managed with [Flyway](https://flywaydb.org/) migrations. Source of truth for `cv-domain-service`.

Part of the [cv-project](../README.md) multi-repo. Pipeline: Jenkins.

## Stack

- MySQL 8.4
- Flyway (versioned SQL migrations under `sql/migrations`)

## Schema

- `person` — the CV owner's profile
- `experience` — work history
- `education` — academic history
- `skill` / `person_skill` — skills with per-person proficiency
- `project` — portfolio projects

## Local development

```bash
docker compose up -d          # start MySQL on localhost:3306 (db: cv, user/pass: cv/cv)
./scripts/migrate.sh          # apply migrations with Flyway
./scripts/reset.sh            # drop and recreate the local database
```

## Adding a migration

Add a new `sql/migrations/V{n}__description.sql` file following Flyway's naming convention, then run `./scripts/migrate.sh`. Never edit an already-applied migration file.

## Dev seed data

`sql/dev-seeds/afterMigrate__seed_dev.sql` is a Flyway callback with idempotent demo inserts. It runs only because the local `flyway.conf` lists the `dev-seeds` location — production configs must list only `sql/migrations`.
