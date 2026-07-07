# Overview
This file contains additional notes related to the changes made to the origimal notebooks for running on Databricks Trial version deployed on AWS.
This version of Databricks only supports Serverless engines.

# Resources
- https://docs.databricks.com/aws/en/compute/serverless/limitations
- https://docs.databricks.com/aws/en/sql/language-manual/functions/read_files

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
