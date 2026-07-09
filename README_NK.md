# Overview
This file contains additional notes related to the changes made to the original notebooks for running on Databricks Trial version deployed on AWS.
This version of Databricks only supports Serverless engines.
It also contains additional resources as well as steps to create and deploy pipelines with databricks CLI.

# Resources
- https://docs.databricks.com/aws/en/getting-started/high-level-architecture
- https://docs.databricks.com/aws/en/compute/serverless/
- https://docs.databricks.com/aws/en/compute/serverless/limitations
- https://docs.databricks.com/aws/en/data-engineering/procedural-vs-declarative
- https://docs.databricks.com/aws/en/ldp/concepts/
- https://docs.databricks.com/aws/en/ldp/developer/python-ref
- https://docs.databricks.com/aws/en/ldp/best-practices
- https://docs.databricks.com/aws/en/jobs/
- https://docs.databricks.com/aws/en/sql/language-manual/functions/read_files
- https://docs.databricks.com/aws/en/pyspark/reference/
- https://docs.databricks.com/aws/en/ingestion/cloud-object-storage/
- https://docs.databricks.com/aws/en/dev-tools/bundles/ci-cd-bundles
- https://docs.databricks.com/aws/en/dev-tools/ci-cd/github-actions
- https://github.com/databricks/setup-cli

# Deploying and running pipelines and jobs

## Prerequisites

1. Install the Databricks CLI: https://docs.databricks.com/dev-tools/cli/install.html
2. Configure authentication: `databricks configure --token`
3. Ensure the source data exists in `/Volumes/workspace/aws_training_data/bookstore_dataset` (run the `Includes/Copy-Datasets` notebook first)

## Deploying and running notebooks with DLT pipelines

The notebook `4- Production Pipelines/4.1 - Delta Live Tables.sql` contains Spark Declarative Pipeline (formerly DLT) definitions that cannot be executed as regular notebook cells. Instead, they must be deployed as a **Lakeflow Spark Declarative Pipeline** using the Databricks CLI and Declarative Automation Bundles.

### Pipeline definition

The pipeline infrastructure is defined as code in `databricks.yml` at the repository root. This file specifies:
- Pipeline name, catalog, and schema — parameterized as bundle variables (`catalog` default `workspace`, `schema` default `aws_training_data`)
- Configuration: `datasets_path` variable pointing to the UC Volume with source data (default `/Volumes/workspace/aws_training_data/bookstore_dataset`)
- Source notebook reference
- Deployment targets — three environments, only one of which is meant for direct CLI use:
  - `personal` — your own free-edition sandbox, deploy directly from the CLI, default target
  - `dev` — shared dev workspace, deployed only via GitHub Actions
  - `prod` — production (aws-hosted), deployed only via GitHub Actions — see [CI/CD](#cicd-automated-deployment-via-github-actions) below

### Deploying and running

Using databricks CLI you can build then deploy Declarative Automation Bundles ('DABs').

1. Validate the code to make into a DAB:

```bash
# Validate the bundle definition
databricks bundle validate --target personal
```

2. Create a DAB then deploy to a target:
```bash
# Deploy — creates/updates the pipeline in your personal Databricks workspace
databricks bundle deploy --target personal
```
3. Run a pipeline:
```bash
# Run — triggers a pipeline update (materializes all tables)
databricks bundle run --target personal bookstore_dlt
```

`personal` is the `default: true` target, so plain `databricks bundle deploy` (no `--target`) resolves to it — that's intentional, so a bare command can never accidentally land on shared dev or prod.

### Overriding catalog/schema/dataset location per environment

`catalog`, `schema`, and `datasets_path` are bundle [variables](https://docs.databricks.com/dev-tools/bundles/variables.html) (declared at the top of `databricks.yml`), not hardcoded values. They can be overridden two ways:

```bash
# One-off override from the CLI
databricks bundle deploy --target personal --var="catalog=my_catalog" --var="schema=my_schema"
```

```yaml
# Persistent override for a specific target, in databricks.yml
targets:
  personal:
    variables:
      catalog: my_personal_catalog
```

All three targets currently use the same defaults (`workspace` / `aws_training_data`), since each points at a separate workspace with its own catalog namespace — override only if you need a target to diverge from that.

> **Note:** `dev` and `prod` are deployed exclusively through the GitHub Actions workflow (see [CI/CD](#cicd-automated-deployment-via-github-actions) below), never manually from the CLI. Don't configure a local profile or `DATABRICKS_TOKEN` for those workspaces — their credentials live only in GitHub Environment secrets used by CI. This keeps production additionally gated behind the required-reviewer approval on the `production` environment.

### What happens on deploy

1. The CLI reads `databricks.yml` and creates a pipeline resource in the workspace
2. The pipeline is configured to use the notebook from this Git repository as its source
3. Running the pipeline executes the DLT definitions (streaming tables, materialized views, data quality constraints) using the pipeline runtime — not regular notebook compute

### Resources

- https://docs.databricks.com/dev-tools/bundles/index.html
- https://docs.databricks.com/delta-live-tables/index.html

## Local setup for Databricks

### Provisioning Databricks workspace for personal target

Your `personal` target needs its own Databricks workspace. Databricks Free Edition provisions one for you at no cost and is sufficient for this repo (serverless-only, which is all this bundle uses):

1. Go to the [Databricks Free Edition sign-up page](https://login.databricks.com/?dbx_source=docs&intent=CE_SIGN_UP)
2. Sign up with an email address (or SSO provider) — Databricks automatically provisions a new, single-user workspace for you
3. Once provisioned, note your workspace URL from the browser address bar, e.g. `https://dbc-xxxxxxxx-xxxx.cloud.databricks.com/` — this is the `workspace.host` value to use for the `personal` target in `databricks.yml`
4. Confirm Unity Catalog is enabled (Free Edition workspaces come with it by default) and that a default catalog/schema exists — `Includes/Copy-Datasets` and the bundle's notebooks expect `workspace.aws_training_data`

Free Edition is quota-limited and serverless-only — see [limitations](https://www.databricks.com/aws/en/getting-started/free-edition-limitations) if you hit compute/storage caps. It replaced the old Community Edition, so ignore any Community Edition instructions you find elsewhere.

Once the workspace exists, continue with CLI install and authentication below, then set `workspace.host` for the `personal` target in `databricks.yml` to your new workspace's URL.

### Installing the Databricks CLI on Linux

```bash
# Option 1: Using curl (recommended)
curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh

# Option 2: Manual download
# Download the latest release for your architecture from:
# https://github.com/databricks/cli/releases
# For Intel/AMD 64-bit:
wget https://github.com/databricks/cli/releases/latest/download/databricks_cli_linux_amd64.zip
unzip databricks_cli_linux_amd64.zip
sudo mv databricks /usr/local/bin/

# Verify installation
databricks --version
```

### Authentication

Local CLI auth should only ever be configured against your **personal** workspace (e.g. `https://dbc-8247e575-4536.cloud.databricks.com/`) — never against the shared `dev` or `prod` hosts, whose credentials live solely in GitHub Environment secrets for CI.

Generate a personal access token in Databricks:
1. Click your user icon (top-right) → **Settings**
2. Go to **Developer** → **Access tokens**
3. Click **Generate new token**, set a description and expiry, then copy the token

Configure the CLI:

```bash
# Interactive setup (prompts for host and token)
databricks configure

# When prompted:
#   Host: <paste the URL of your Free edition's workspace e.g. https://dbc-8247e575-4536.cloud.databricks.com>
#   Token: <paste your personal access token>
```

This creates a configuration profile at `~/.databrickscfg`. You can also set environment variables if you prefer:

```bash
export DATABRICKS_HOST=<URL of your Free edition's workspace e.g. https://dbc-8247e575-4536.cloud.databricks.com>
export DATABRICKS_TOKEN=<your-token>
```

Verify authentication works:
```bash
databricks auth describe
databricks clusters list
```

### Cloning the repo and deploying the pipeline

```bash
# Clone the training repo
git clone <your-github-repo-url>
cd Databricks-Certified-Data-Engineer-Associate

# Switch to the working branch
git checkout serverless-mode_nk-changes-for-aws

# Validate, deploy, and run the pipeline against your personal workspace
databricks bundle validate --target personal
databricks bundle deploy --target personal
databricks bundle run --target personal bookstore_dlt
```

### Resources

- https://docs.databricks.com/dev-tools/cli/install.html
- https://docs.databricks.com/dev-tools/cli/authentication.html

## CI/CD: automated deployment via GitHub Actions

The workflow at `.github/workflows/databricks-deploy.yml` deploys the bundle automatically:

- Push/merge to the `nikolaikoustov/dev` branch → `databricks bundle deploy --target dev` against the **shared dev** workspace
- Push/merge to the `nikolaikoustov/prod` branch → `databricks bundle deploy --target prod` against the **production** workspace (`aws-hosted`)
- Both can also be triggered manually via **Actions → Deploy Databricks Bundle → Run workflow**, choosing the target
- Note: this repo does not currently have `nikolaikoustov/dev` or `nikolaikoustov/prod` branches — create them (e.g. `git checkout -b nikolaikoustov/prod && git push -u origin nikolaikoustov/prod`) before relying on the automatic trigger

### One-time setup required in Databricks

The deploying identity and the executing identity are deliberately separate principals (segregation of duties):

- **The deploying service principal** (e.g. `github-actions-deploy`) — only pushes bundle resources. It should hold **no direct Unity Catalog data grants**.
- **`job-runner-<target>`** — a dedicated, minimally-privileged service principal per target that the deployed jobs/pipelines actually *run as* (via the bundle's `run_as` mapping). This is the one with `USE CATALOG`/`USE SCHEMA`/`CREATE TABLE`/`CREATE VOLUME`/`MODIFY`/`SELECT` on that target's catalog/schema.

Do this once per shared workspace (`dev` and `prod` — not `personal`, which uses your own user PAT):

1. Run `scripts/setup.sh <dev|prod>` (see below) as an account/workspace admin against that workspace. It creates `job-runner-<target>`, grants it the data access it needs (`scripts/setup.sql`), and writes its application ID into `databricks.yml` as that target's `run_as` variable.
2. Grant your deploying service principal **Use** permission on `job-runner-<target>` (Settings → Identity and access → Service principals → `job-runner-<target>` → **Permissions** tab → add the deploying service principal with the "Use" permission). This is required for `run_as` to take effect — without it, `databricks bundle deploy` fails with a permissions error. `setup.sh` does not do this step for you.

Repeat for the other shared workspace. Commit the `databricks.yml` change `setup.sh` makes so CI/CD picks up the populated `run_as` value automatically — no GitHub-side changes needed.

#### `scripts/setup.sh`

```bash
# Run once per target, by an account/workspace admin, before the first deploy.
# Safe to re-run — every step is idempotent.
scripts/setup.sh dev
scripts/setup.sh prod
```

It authenticates interactively (browser OAuth against the `DEFAULT` CLI profile by default — pass `--profile NAME` to use a different one — re-logging in against the right host each run since `dev` and `prod` are different workspaces), reads the target's catalog/schema straight out of `databricks.yml` via `databricks bundle validate`, and requires the `databricks` CLI, `jq`, and a Python 3 interpreter on your PATH.

### One-time setup required for the deploying service principal

Do this once per shared workspace, for the service principal you'll use as `DATABRICKS_CLIENT_ID`/`DATABRICKS_CLIENT_SECRET` below:

1. Log into the workspace as an admin
2. **Settings** → **Identity and access** → **Service principals** → **Manage** → create a new service principal (e.g. `github-actions-deploy`)
3. On the new principal's entitlements, set **Workspace access** → **On** and **Admin access** → **Off** (least privilege — it only needs to be able to authenticate and deploy, not administer the workspace, and not touch the target data directly)
4. Open the service principal's own detail page → **Secrets** tab → **Generate secret** — this produces a **Client ID** and **Client Secret** (shown once — copy both immediately)
5. Grant it **Use** permission on `job-runner-<target>` (see previous section)

Repeat for the other shared workspace. Keep track of which Client ID/Secret pair belongs to `dev` vs `prod` — you'll paste them into the matching GitHub Environment next.

### One-time setup required in GitHub

1. **Create two Environments** (repo **Settings → Environments**):
   - `development`
   - `production` — add a **required reviewer** here so prod deploys pause for manual approval
2. **Add secrets to each Environment** (not repo-level secrets, so `dev` and `prod` can point at different workspaces and principals):
   - `DATABRICKS_HOST` — `https://dbc-9d50ffda-1704.cloud.databricks.com` for `development`, and `https://dbc-019e110a-3092.cloud.databricks.com/` (the `aws-hosted` production workspace) for `production`
   - `DATABRICKS_CLIENT_ID` — the service principal's Client ID from the Databricks-side setup above, for that workspace
   - `DATABRICKS_CLIENT_SECRET` — the matching Client Secret for that workspace

Databricks service principals authenticate via OAuth (client ID/secret), not classic personal access tokens — the CLI picks this up automatically from those three env vars, no `DATABRICKS_TOKEN` needed. Once both environments have all three secrets configured, pushes to `nikolaikoustov/dev`/`nikolaikoustov/prod` will validate and deploy the bundle automatically; production runs will wait for approval from a configured reviewer before deploying.
