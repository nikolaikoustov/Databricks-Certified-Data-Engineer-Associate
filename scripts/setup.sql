-- Idempotent Unity Catalog grants for the pipeline execution service
-- principal (the bundle's `run_as` identity for a given target).
--
-- Rendered and executed by scripts/setup.sh, which substitutes the
-- {{CATALOG}}, {{SCHEMA}}, and {{RUN_AS_SP_ID}} placeholders below and runs
-- each statement via the Statement Execution API. Re-running is safe: GRANT
-- is additive and Unity Catalog de-duplicates privileges a principal already
-- holds.
--
-- Scope is deliberately minimal: enough to create/populate the schema's
-- volumes and tables and read them back, nothing catalog-admin or
-- account-admin. Backtick-quoted throughout since catalog/schema names may
-- contain hyphens (e.g. prod-workspace).

GRANT USE CATALOG ON CATALOG `{{CATALOG}}` TO `{{RUN_AS_SP_ID}}`;
GRANT CREATE SCHEMA ON CATALOG `{{CATALOG}}` TO `{{RUN_AS_SP_ID}}`;
GRANT USE SCHEMA ON SCHEMA `{{CATALOG}}`.`{{SCHEMA}}` TO `{{RUN_AS_SP_ID}}`;
GRANT CREATE TABLE ON SCHEMA `{{CATALOG}}`.`{{SCHEMA}}` TO `{{RUN_AS_SP_ID}}`;
GRANT CREATE VOLUME ON SCHEMA `{{CATALOG}}`.`{{SCHEMA}}` TO `{{RUN_AS_SP_ID}}`;
GRANT MODIFY ON SCHEMA `{{CATALOG}}`.`{{SCHEMA}}` TO `{{RUN_AS_SP_ID}}`;
GRANT SELECT ON SCHEMA `{{CATALOG}}`.`{{SCHEMA}}` TO `{{RUN_AS_SP_ID}}`;
-- READ/WRITE VOLUME are separate from SELECT/MODIFY: SELECT/MODIFY govern
-- table access, but "4.3 - Land New Data Task" reads and writes raw files
-- directly inside the volume (dbutils.fs.ls/cp, json.`path` queries), which
-- needs the volume file-I/O privileges specifically. Without these, file
-- reads fail with INSUFFICIENT_PERMISSIONS: "does not have permission
-- SELECT on any file" even though the schema-level SELECT grant above is
-- in place.
GRANT READ VOLUME ON SCHEMA `{{CATALOG}}`.`{{SCHEMA}}` TO `{{RUN_AS_SP_ID}}`;
GRANT WRITE VOLUME ON SCHEMA `{{CATALOG}}`.`{{SCHEMA}}` TO `{{RUN_AS_SP_ID}}`;
-- The DLT pipeline notebooks use legacy `CREATE OR REFRESH LIVE TABLE` /
-- `STREAMING LIVE TABLE` syntax, which Lakeflow executes as materialized
-- views / streaming tables respectively — separate object types from plain
-- tables, each gated by their own CREATE privilege distinct from CREATE
-- TABLE above.
GRANT CREATE MATERIALIZED VIEW ON SCHEMA `{{CATALOG}}`.`{{SCHEMA}}` TO `{{RUN_AS_SP_ID}}`;
GRANT CREATE STREAMING TABLE ON SCHEMA `{{CATALOG}}`.`{{SCHEMA}}` TO `{{RUN_AS_SP_ID}}`;
