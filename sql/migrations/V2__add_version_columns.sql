-- V2: optimistic-locking version column (T-157, split from T-113; contract design rule 8, T-046).
-- Hibernate's `@Version Long` maps to BIGINT. Additive only: existing rows backfill to 0
-- through the DEFAULT, and the current domain image (ddl-auto=validate) tolerates the extra
-- column, so this must reach production before the image that maps it.
-- Skill catalog and person_skill are deliberately not versioned (contract rule 8).

ALTER TABLE person     ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE experience ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE education  ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE project    ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
