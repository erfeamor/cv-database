-- Flyway afterMigrate callback: runs after every successful migrate, so all
-- statements must be idempotent. Only included via the dev-seeds location in
-- the local flyway.conf — production configs must not add this location.

INSERT IGNORE INTO person (full_name, headline, email, location, summary) VALUES
  ('Jane Doe', 'Full-Stack Engineer', 'jane.doe@example.com', 'Remote', 'Demo seed record for local development.');

INSERT IGNORE INTO skill (name, category) VALUES
  ('Java', 'Backend'),
  ('Spring Boot', 'Backend'),
  ('Node.js', 'Backend'),
  ('React', 'Frontend'),
  ('Terraform', 'Infra');

INSERT IGNORE INTO person_skill (person_id, skill_id, proficiency)
SELECT p.id, s.id, 'ADVANCED'
FROM person p, skill s
WHERE p.email = 'jane.doe@example.com';

-- ---------------------------------------------------------------------------
-- experience / education / project
--
-- These three tables have ONLY an autoincrement `id` PK plus an FK to person
-- (verified against V1__init_schema.sql) — no unique constraint anywhere. So
-- `INSERT IGNORE` has nothing to collide with and would append a fresh copy of
-- every row on every migrate, while the migrate still exits 0. Each insert
-- below is therefore guarded by `NOT EXISTS` on a natural key, and resolves
-- person_id by email in the same statement (never a literal id — ids are not
-- stable across a reset.sh volume wipe).
--
-- Natural keys: experience = company + role + start_date
--               education  = institution + degree + start_date
--               project    = name + start_date
-- ---------------------------------------------------------------------------

-- experience: three roles, exactly one current (end_date NULL), and that one
-- has the latest start_date. experience.start_date is NOT NULL, so plain `=`
-- is correct in the guard.

INSERT INTO experience (person_id, company, role, location, start_date, end_date, description)
SELECT p.id, 'Northwind Analytics', 'Junior Software Engineer', 'Madrid, Spain',
       '2016-09-05', '2019-05-31',
       'First engineering role. Maintained a Java 8 reporting backend and its MySQL schema, and wrote the batch jobs that fed the analytics dashboards.'
FROM person p
WHERE p.email = 'jane.doe@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM experience e
    WHERE e.person_id = p.id
      AND e.company = 'Northwind Analytics'
      AND e.role = 'Junior Software Engineer'
      AND e.start_date = '2016-09-05'
  );

INSERT INTO experience (person_id, company, role, location, start_date, end_date, description)
SELECT p.id, 'Globex Systems', 'Software Engineer', 'Barcelona, Spain',
       '2019-06-17', '2022-02-28',
       'Built and shipped REST services on Spring Boot backed by MySQL, plus the React admin screens on top of them. Introduced Flyway to a schema that had been hand-migrated until then.'
FROM person p
WHERE p.email = 'jane.doe@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM experience e
    WHERE e.person_id = p.id
      AND e.company = 'Globex Systems'
      AND e.role = 'Software Engineer'
      AND e.start_date = '2019-06-17'
  );

INSERT INTO experience (person_id, company, role, location, start_date, end_date, description)
SELECT p.id, 'Acme Corp', 'Senior Full-Stack Engineer', 'Remote',
       '2022-03-14', NULL,
       'Current role. Owns a Spring Boot domain service and the Node BFF in front of it, from the MySQL schema through to the public Next.js site. Runs the multi-repo CI and the Terraform that deploys it.'
FROM person p
WHERE p.email = 'jane.doe@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM experience e
    WHERE e.person_id = p.id
      AND e.company = 'Acme Corp'
      AND e.role = 'Senior Full-Stack Engineer'
      AND e.start_date = '2022-03-14'
  );

-- education: education.start_date is NOT NULL, so plain `=` is correct here too.

INSERT INTO education (person_id, institution, degree, field_of_study, start_date, end_date)
SELECT p.id, 'Universidad Politecnica de Madrid', 'BSc Computer Engineering',
       'Software Engineering', '2012-09-10', '2016-06-24'
FROM person p
WHERE p.email = 'jane.doe@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM education ed
    WHERE ed.person_id = p.id
      AND ed.institution = 'Universidad Politecnica de Madrid'
      AND ed.degree = 'BSc Computer Engineering'
      AND ed.start_date = '2012-09-10'
  );

INSERT INTO education (person_id, institution, degree, field_of_study, start_date, end_date)
SELECT p.id, 'Universitat Oberta de Catalunya', 'MSc Distributed Systems',
       'Cloud Architecture', '2018-09-17', '2020-07-10'
FROM person p
WHERE p.email = 'jane.doe@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM education ed
    WHERE ed.person_id = p.id
      AND ed.institution = 'Universitat Oberta de Catalunya'
      AND ed.degree = 'MSc Distributed Systems'
      AND ed.start_date = '2018-09-17'
  );

-- project: UNLIKE experience and education, project.start_date is NULLABLE, and
-- one seed row below is deliberately undated (it exercises the contract's
-- "undated projects sort last" ordering rule end to end).
--
-- ==> The guard therefore compares start_date with the NULL-SAFE equality
--     operator `<=>`, NOT with `=`. In MySQL, `pr.start_date = NULL` is never
--     true and neither is `pr.start_date = '2024-02-05'` when the stored value
--     is NULL, so a plain `=` guard would find nothing for the undated row,
--     pass, and re-insert it on EVERY migrate — the exact duplicate-row bug
--     this whole file is written to avoid, and one that is invisible because
--     the migrate still exits 0. `<=>` returns TRUE for NULL <=> NULL.
--     Applied to all project rows for consistency, not just the undated one.
--     If you add a project row here, keep `<=>`.

INSERT INTO project (person_id, name, description, repo_url, start_date, end_date)
SELECT p.id, 'Curriculum Interactivo',
       'Interactive CV platform built as seven independent repos: MySQL and Flyway, a Spring Boot domain API, a Node BFF, a React admin UI and two public front ends, each with its own CI and deploy pipeline.',
       'https://github.com/erfeamor/curriculum', '2024-02-05', NULL
FROM person p
WHERE p.email = 'jane.doe@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM project pr
    WHERE pr.person_id = p.id
      AND pr.name = 'Curriculum Interactivo'
      AND pr.start_date <=> '2024-02-05'
  );

INSERT INTO project (person_id, name, description, repo_url, start_date, end_date)
SELECT p.id, 'Ledger CLI',
       'Small double-entry bookkeeping tool in Java, with a plain-text ledger format and a reporting command that renders monthly balances in the terminal.',
       'https://github.com/erfeamor/ledger-cli', '2021-11-08', '2022-06-30'
FROM person p
WHERE p.email = 'jane.doe@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM project pr
    WHERE pr.person_id = p.id
      AND pr.name = 'Ledger CLI'
      AND pr.start_date <=> '2021-11-08'
  );

-- Deliberately undated (start_date NULL): the row that exercises both the
-- "undated last" ordering rule and the null-safe guard above.
INSERT INTO project (person_id, name, description, repo_url, start_date, end_date)
SELECT p.id, 'Dotfiles',
       'Long-running personal toolchain setup — shell, editor and container config, kept in one repo and bootstrapped by a single install script. No meaningful start date; it predates the habit of recording one.',
       'https://github.com/erfeamor/dotfiles', NULL, NULL
FROM person p
WHERE p.email = 'jane.doe@example.com'
  AND NOT EXISTS (
    SELECT 1 FROM project pr
    WHERE pr.person_id = p.id
      AND pr.name = 'Dotfiles'
      AND pr.start_date <=> NULL
  );
