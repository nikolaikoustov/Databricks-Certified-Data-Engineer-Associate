#!/usr/bin/env bash
set -euo pipefail

# Bootstraps the execution identity for a shared bundle target (dev or prod):
#
#   1. Creates (or reuses) a dedicated, minimally-privileged service
#      principal ("job-runner-<target>") that deployed jobs/pipelines will
#      run as.
#   2. Grants it just enough Unity Catalog access on that target's
#      catalog/schema (scripts/setup.sql).
#   3. Records its application ID into databricks.yml as that target's
#      `run_as` variable, so `databricks bundle deploy` picks it up with no
#      further action.
#
# This script only manages the job-runner (execution) service principal. It
# does not touch the CI/CD deploying service principal (e.g.
# github-actions-deploy) — granting that identity the "Service Principal
# User" role on job-runner-<target> (required for `run_as` to take effect)
# is a separate, manual, one-time step. See README_NK.md.
#
# Run this once per target, by an account/workspace admin, before the first
# deploy to that target. Safe to re-run — every step converges rather than
# duplicating or failing.
#
# Usage:
#   scripts/setup.sh <dev|prod> [--profile NAME] [--warehouse-id ID]
#
# Requires on PATH: databricks CLI (authenticated interactively as an
# admin), jq, and a Python 3 interpreter (as `python3` or `python`).

usage() {
  echo "Usage: $0 <dev|prod> [--profile NAME] [--warehouse-id ID]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
TARGET="$1"
shift
[[ "$TARGET" == "dev" || "$TARGET" == "prod" ]] || usage

PROFILE="DEFAULT"
WAREHOUSE_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --warehouse-id) WAREHOUSE_ID="$2"; shift 2 ;;
    *) usage ;;
  esac
done

for dep in databricks jq; do
  command -v "$dep" >/dev/null 2>&1 || { echo "Required tool not found on PATH: $dep" >&2; exit 1; }
done

PYTHON_BIN=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    PYTHON_BIN="$candidate"
    break
  fi
done
[[ -n "$PYTHON_BIN" ]] || { echo "No Python 3 interpreter found on PATH (tried python3, python)" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_FILE="$REPO_ROOT/databricks.yml"
SQL_TEMPLATE="$REPO_ROOT/scripts/setup.sql"
RUN_AS_SP_NAME="job-runner-$TARGET"

echo "==> Target: $TARGET"

# --- 1. Resolve host/catalog/schema straight from the bundle (single source of truth) ---
BUNDLE_JSON="$(databricks bundle validate --target "$TARGET" --output json)"
HOST="$(echo "$BUNDLE_JSON" | jq -r '.workspace.host')"
CATALOG="$(echo "$BUNDLE_JSON" | jq -r '.variables.catalog.value')"
SCHEMA="$(echo "$BUNDLE_JSON" | jq -r '.variables.schema.value')"

[[ -n "$HOST" && "$HOST" != "null" ]] || { echo "Could not resolve workspace host for target '$TARGET'" >&2; exit 1; }
[[ -n "$CATALOG" && "$CATALOG" != "null" ]] || { echo "Could not resolve catalog for target '$TARGET'" >&2; exit 1; }
[[ -n "$SCHEMA" && "$SCHEMA" != "null" ]] || { echo "Could not resolve schema for target '$TARGET'" >&2; exit 1; }
echo "==> Host: $HOST | Catalog: $CATALOG | Schema: $SCHEMA"

# --- 2. Authenticate interactively as an admin ---
# PROFILE is shared across targets (dev/prod point at different hosts), so
# always (re-)login against this target's host rather than trusting
# whatever the DEFAULT profile last happened to be authenticated against.
echo "==> Launching browser login for $HOST"
databricks auth login --host "$HOST" --profile "$PROFILE"
WHOAMI="$(databricks current-user me --profile "$PROFILE" --output json | jq -r '.userName // .emails[0].value // "unknown"')"
echo "==> Authenticated as $WHOAMI"

# --- 3. Create (or reuse) the run-as service principal ---
sp_json="$(databricks service-principals list --profile "$PROFILE" --output json \
  | jq -c --arg name "$RUN_AS_SP_NAME" '[.[] | select(.displayName==$name)][0] // empty')"

if [[ -z "$sp_json" ]]; then
  echo "==> Creating service principal '$RUN_AS_SP_NAME'"
  sp_json="$(databricks service-principals create --profile "$PROFILE" \
    --json "$(jq -n --arg name "$RUN_AS_SP_NAME" '{displayName: $name, active: true}')" \
    --output json)"
else
  echo "==> Reusing existing service principal '$RUN_AS_SP_NAME'"
fi
RUN_AS_SP_APP_ID="$(echo "$sp_json" | jq -r '.applicationId')"
[[ -n "$RUN_AS_SP_APP_ID" && "$RUN_AS_SP_APP_ID" != "null" ]] || { echo "Failed to resolve run-as service principal" >&2; exit 1; }
echo "==> Run-as service principal application ID: $RUN_AS_SP_APP_ID"

# --- 4. Grant the run-as SP just enough Unity Catalog access (setup.sql) ---
if [[ -z "$WAREHOUSE_ID" ]]; then
  WAREHOUSE_ID="$(databricks warehouses list --profile "$PROFILE" --output json | jq -r '.[0].id // empty')"
fi
[[ -n "$WAREHOUSE_ID" ]] || { echo "No SQL warehouse found in workspace — pass --warehouse-id" >&2; exit 1; }
echo "==> Using SQL warehouse $WAREHOUSE_ID to apply grants"

run_sql_statement() {
  local statement="$1"
  local payload result status statement_id
  payload="$(jq -n --arg wid "$WAREHOUSE_ID" --arg stmt "$statement" \
    '{warehouse_id: $wid, statement: $stmt, wait_timeout: "30s"}')"
  result="$(databricks api post /api/2.0/sql/statements --profile "$PROFILE" --json "$payload")"
  status="$(echo "$result" | jq -r '.status.state')"
  statement_id="$(echo "$result" | jq -r '.statement_id')"
  while [[ "$status" == "PENDING" || "$status" == "RUNNING" ]]; do
    sleep 2
    result="$(databricks api get "/api/2.0/sql/statements/$statement_id" --profile "$PROFILE")"
    status="$(echo "$result" | jq -r '.status.state')"
  done
  if [[ "$status" != "SUCCEEDED" ]]; then
    echo "Statement failed ($status): $statement" >&2
    echo "$result" | jq -r '.status.error // empty' >&2
    exit 1
  fi
}

sql_rendered="$(sed \
  -e "s/{{CATALOG}}/$CATALOG/g" \
  -e "s/{{SCHEMA}}/$SCHEMA/g" \
  -e "s/{{RUN_AS_SP_ID}}/$RUN_AS_SP_APP_ID/g" \
  "$SQL_TEMPLATE" | grep -v '^--' | grep -v '^[[:space:]]*$' | sed 's/;[[:space:]]*$//')"

while IFS= read -r statement; do
  echo "    $statement;"
  run_sql_statement "$statement"
done <<< "$sql_rendered"

# --- 5. Record the run-as identity in databricks.yml for this target ---
echo "==> Writing run_as = $RUN_AS_SP_APP_ID into databricks.yml [$TARGET]"
"$PYTHON_BIN" "$REPO_ROOT/scripts/set_target_variable.py" "$BUNDLE_FILE" "$TARGET" run_as "$RUN_AS_SP_APP_ID"

echo "==> Done. Before deploying, make sure your CI/CD deploying service principal has been"
echo "    granted 'Use' permission on '$RUN_AS_SP_NAME' ($RUN_AS_SP_APP_ID) —"
echo "    see README_NK.md. Then 'databricks bundle deploy --target $TARGET' will deploy"
echo "    jobs/pipelines to run as $RUN_AS_SP_NAME."
