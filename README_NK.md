# Overview
This file contains additional notes related to the changes made to the origimal notebooks for running on Databricks Trial version deployed on AWS.
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

# Deploying and running pipelines

## Deploying and running notebooks with DLT pipelines

The notebook `4- Production Pipelines/4.1 - Delta Live Tables.sql` contains Spark Declarative Pipeline (formerly DLT) definitions that cannot be executed as regular notebook cells. Instead, they must be deployed as a **Lakeflow Spark Declarative Pipeline** using the Databricks CLI and Declarative Automation Bundles.

### Pipeline definition

The pipeline infrastructure is defined as code in `databricks.yml` at the repository root. This file specifies:
- Pipeline name, catalog (`workspace`), and schema (`aws_training_data`)
- Configuration: `datasets_path` pointing to the UC Volume with source data
- Source notebook reference
- Deployment targets (`dev` and `prod`)

### Prerequisites

1. Install the Databricks CLI: https://docs.databricks.com/dev-tools/cli/install.html
2. Configure authentication: `databricks configure --token`
3. Ensure the source data exists in `/Volumes/workspace/aws_training_data/bookstore_dataset` (run the `Includes/Copy-Datasets` notebook first)

### Deploying and running

```bash
# Validate the bundle definition
databricks bundle validate --target dev

# Deploy — creates/updates the pipeline in your Databricks workspace
databricks bundle deploy --target dev

# Run — triggers a pipeline update (materializes all tables)
databricks bundle run --target dev bookstore_dlt

# For production deployment
databricks bundle deploy --target prod
databricks bundle run --target prod bookstore_dlt
```

### What happens on deploy

1. The CLI reads `databricks.yml` and creates a pipeline resource in the workspace
2. The pipeline is configured to use the notebook from this Git repository as its source
3. Running the pipeline executes the DLT definitions (streaming tables, materialized views, data quality constraints) using the pipeline runtime — not regular notebook compute

### Resources

- https://docs.databricks.com/dev-tools/bundles/index.html
- https://docs.databricks.com/delta-live-tables/index.html

## Local development setup for Databricks

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

Generate a personal access token in Databricks:
1. Click your user icon (top-right) → **Settings**
2. Go to **Developer** → **Access tokens**
3. Click **Generate new token**, set a description and expiry, then copy the token

Configure the CLI:

```bash
# Interactive setup (prompts for host and token)
databricks configure

# When prompted:
#   Host: https://dbc-9d50ffda-1704.cloud.databricks.com
#   Token: <paste your personal access token>

# Verify authentication works
databricks auth env --host https://dbc-9d50ffda-1704.cloud.databricks.com
databricks clusters list
```

This creates a configuration profile at `~/.databrickscfg`. You can also set environment variables:

```bash
export DATABRICKS_HOST=https://dbc-9d50ffda-1704.cloud.databricks.com
export DATABRICKS_TOKEN=<your-token>
```

### Cloning the repo and deploying the pipeline

```bash
# Clone the training repo
git clone <your-github-repo-url>
cd Databricks-Certified-Data-Engineer-Associate

# Switch to the working branch
git checkout serverless-mode_nk-changes-for-aws

# Validate, deploy, and run the pipeline
databricks bundle validate --target dev
databricks bundle deploy --target dev
databricks bundle run --target dev bookstore_dlt
```

### Resources

- https://docs.databricks.com/dev-tools/cli/install.html
- https://docs.databricks.com/dev-tools/cli/authentication.html
