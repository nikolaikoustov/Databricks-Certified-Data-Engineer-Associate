-- Databricks notebook source
-- DBTITLE 1,Prerequisites
-- MAGIC %md
-- MAGIC ## Prerequisites
-- MAGIC
-- MAGIC This notebook demonstrates managed and external tables using Unity Catalog with an S3-based external location.
-- MAGIC
-- MAGIC **Required setup before running this notebook:**
-- MAGIC 1. **External Location**: `db_s3_external_databricks-s3-ingest-e6bf1` mapped to `s3://nk-databricks-training-july-2026/`
-- MAGIC 2. **S3 path for external tables**: `s3://nk-databricks-training-july-2026/training-notebooks/`
-- MAGIC 3. **Catalog**: `workspace` (using Unity Catalog instead of `hive_metastore`)
-- MAGIC 4. **Schema**: `aws_training_data` (created in the cell below)
-- MAGIC
-- MAGIC > **Note:** The original notebook used `hive_metastore` catalog with `dbfs:/mnt/...` mount paths.
-- MAGIC > This version uses Unity Catalog with an S3 external location, which is the recommended approach.

-- COMMAND ----------

-- DBTITLE 1,Create training schema
USE CATALOG workspace;
DROP SCHEMA IF EXISTS aws_training_data CASCADE;
CREATE SCHEMA aws_training_data
MANAGED LOCATION 's3://nk-databricks-training-july-2026/training-notebooks/schemas/aws_training_data';
DESCRIBE SCHEMA aws_training_data;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Managed Tables

-- COMMAND ----------

-- Original: USE CATALOG hive_metastore;
USE CATALOG workspace;
USE SCHEMA aws_training_data;

CREATE TABLE managed_default
  (width INT, length INT, height INT);

INSERT INTO managed_default
VALUES (3 INT, 2 INT, 1 INT)

-- COMMAND ----------

DESCRIBE EXTENDED managed_default

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Using **Data Engineering** -> **Data Injestion** -> **Create or modify table from file upload**, 
-- MAGIC load data from the **retail_sales.json** file

-- COMMAND ----------

-- Run this command AFTER importing retail_sales.json using the File import facility under Data Ingestion
-- The created table should be of type managed (as data is loaded relative to the schema location)
DESCRIBE TABLE EXTENDED retail_sales;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC
-- MAGIC ## External Tables

-- COMMAND ----------

-- Original LOCATION: 'dbfs:/mnt/demo/external_default'
CREATE TABLE external_default
  (width INT, length INT, height INT)
LOCATION 's3://nk-databricks-training-july-2026/training-notebooks/external_default';
  
INSERT INTO external_default
VALUES (3 INT, 2 INT, 1 INT)

-- COMMAND ----------

DESCRIBE EXTENDED external_default

-- COMMAND ----------

-- MAGIC %md
-- MAGIC
-- MAGIC ## Dropping Tables

-- COMMAND ----------

DROP TABLE managed_default

-- COMMAND ----------

-- Original: %fs ls 'dbfs:/user/hive/warehouse/managed_default'
-- After DROP TABLE, a managed table's data is deleted. This query should fail with TABLE_OR_VIEW_NOT_FOUND.
SELECT * FROM managed_default

-- COMMAND ----------

DROP TABLE external_default

-- COMMAND ----------

-- Original: %fs ls 'dbfs:/mnt/demo/external_default'
-- After DROP TABLE, an external table's data files are PRESERVED. Listing the S3 location proves it.
LIST 's3://nk-databricks-training-july-2026/training-notebooks/external_default'

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Creating Schemas

-- COMMAND ----------

CREATE SCHEMA new_default

-- COMMAND ----------

DESCRIBE DATABASE EXTENDED new_default

-- COMMAND ----------

USE new_default;

CREATE TABLE managed_new_default
  (width INT, length INT, height INT);
  
INSERT INTO managed_new_default
VALUES (3 INT, 2 INT, 1 INT);

-----------------------------------

-- Original LOCATION: 'dbfs:/mnt/demo/external_new_default'
CREATE TABLE external_new_default
  (width INT, length INT, height INT)
LOCATION 's3://nk-databricks-training-july-2026/training-notebooks/external_new_default';
  
INSERT INTO external_new_default
VALUES (3 INT, 2 INT, 1 INT);

-- COMMAND ----------

DESCRIBE EXTENDED managed_new_default

-- COMMAND ----------

DESCRIBE EXTENDED external_new_default

-- COMMAND ----------

DROP TABLE managed_new_default;
DROP TABLE external_new_default;

-- COMMAND ----------

-- Original: %fs ls 'dbfs:/user/hive/warehouse/new_default.db/managed_new_default'
-- After DROP TABLE, a managed table's data is deleted. This query should fail with TABLE_OR_VIEW_NOT_FOUND.
SELECT * FROM new_default.managed_new_default

-- COMMAND ----------

-- Original: %fs ls 'dbfs:/mnt/demo/external_new_default'
-- After DROP TABLE, an external table's data files are PRESERVED. Listing the S3 location proves it.
LIST 's3://nk-databricks-training-july-2026/training-notebooks/external_new_default'

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Creating Schemas in Custom Location

-- COMMAND ----------

-- Original LOCATION: 'dbfs:/Shared/schemas/custom.db'
CREATE SCHEMA custom
MANAGED LOCATION 's3://nk-databricks-training-july-2026/training-notebooks/schemas/custom'

-- COMMAND ----------

-- After CREATE SCHEMA CMANAGED LOCATION, schema data does not yet exist.
LIST 's3://nk-databricks-training-july-2026/training-notebooks/schemas/custom'

-- COMMAND ----------

DESCRIBE DATABASE EXTENDED custom

-- COMMAND ----------

SHOW TABLES;

-- COMMAND ----------

USE custom;

CREATE TABLE managed_custom
  (width INT, length INT, height INT);
  
INSERT INTO managed_custom
VALUES (3 INT, 2 INT, 1 INT);

-----------------------------------

-- Original LOCATION: 'dbfs:/mnt/demo/external_custom'
CREATE TABLE external_custom
  (width INT, length INT, height INT)
LOCATION 's3://nk-databricks-training-july-2026/training-notebooks/external_custom';
  
INSERT INTO external_custom
VALUES (3 INT, 2 INT, 1 INT);

-- COMMAND ----------

DESCRIBE EXTENDED managed_custom

-- COMMAND ----------

-- After tables were created and populated, we can see external table data
LIST 's3://nk-databricks-training-july-2026/training-notebooks/schemas/custom'

-- COMMAND ----------

DESCRIBE EXTENDED external_custom

-- COMMAND ----------

-- After tables were created and populated, we can see external table data
LIST 's3://nk-databricks-training-july-2026/training-notebooks/external_custom'

-- COMMAND ----------

DROP TABLE managed_custom;
DROP TABLE external_custom;

-- COMMAND ----------

-- Original: %fs ls 'dbfs:/Shared/schemas/custom.db/managed_custom'
-- After DROP, managed table data at the custom schema location is deleted.
SELECT * FROM custom.managed_custom

-- COMMAND ----------

-- Original: %fs ls 'dbfs:/mnt/demo/external_custom'
-- After DROP, external table data files are PRESERVED at the S3 location.
LIST 's3://nk-databricks-training-july-2026/training-notebooks/external_custom'

-- COMMAND ----------

DROP SCHEMA custom;

-- COMMAND ----------

-- Original: %fs ls 'dbfs:/mnt/demo/external_custom'
-- After DROP SCHEMA, schema data are preserved at the S3 location.
LIST 's3://nk-databricks-training-july-2026/training-notebooks/schemas/'

-- COMMAND ----------

DROP SCHEMA IF EXISTS custom CASCADE;

-- COMMAND ----------

-- Original: %fs ls 'dbfs:/mnt/demo/external_custom'
-- After DROP SCHEMA CASCADE, table data are STILL preserved at the S3 location.
LIST 's3://nk-databricks-training-july-2026/training-notebooks/schemas/custom'
