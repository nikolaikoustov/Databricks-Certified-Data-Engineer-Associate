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
