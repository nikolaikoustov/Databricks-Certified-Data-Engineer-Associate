-- Databricks notebook source
-- MAGIC %md
-- MAGIC ## Creating Delta Lake Tables

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Note:** If your workspace does not support the `hive_metastore` catalog, switch to the **unity-catalog** branch in this Git Folder.

-- COMMAND ----------

-- NOTE: hive_metastore is not avaiable in Free edition or Trial version of Databricks
-- USE CATALOG hive_metastore

-- COMMAND ----------

CREATE TABLE employees
  (id INT, name STRING, salary DOUBLE);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC
-- MAGIC ## Catalog Explorer
-- MAGIC
-- MAGIC Check the created **employees** table in the **Catalog** explorer.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Inserting Data

-- COMMAND ----------

INSERT INTO employees
VALUES 
  (1, "Adam", 3500.0),
  (2, "Sarah", 4020.5);

INSERT INTO employees
VALUES
  (3, "John", 2999.3),
  (4, "Thomas", 4000.3);

INSERT INTO employees
VALUES
  (5, "Anna", 2500.0);

INSERT INTO employees
VALUES
  (6, "Kim", 6200.3)

-- COMMAND ----------

SELECT * FROM employees

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Exploring Table Metadata

-- COMMAND ----------

DESCRIBE DETAIL employees

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Exploring Table Directory

-- COMMAND ----------

-- NOTE: Direct file browsing via %fs is not available for managed tables on serverless compute
-- (Public DBFS root is disabled and the workspace catalog does not expose a file location)
-- For hive_metastore catalog, use: %fs ls 'dbfs:/user/hive/warehouse/employees'
-- Instead, we can see the underlying Parquet files using _metadata.file_path
SELECT _metadata.file_path AS file_name, * FROM employees

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Updating Table

-- COMMAND ----------

UPDATE employees 
SET salary = salary + 100
WHERE name LIKE "A%"

-- COMMAND ----------

SELECT * FROM employees

-- COMMAND ----------

-- NOTE: Direct file browsing via %fs is not available for managed tables on serverless compute
-- For hive_metastore catalog, use: %fs ls 'dbfs:/user/hive/warehouse/employees'
-- After the UPDATE, we can see new Parquet files were created
SELECT DISTINCT _metadata.file_path AS file_name FROM employees

-- COMMAND ----------

DESCRIBE DETAIL employees

-- COMMAND ----------

SELECT * FROM employees

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Exploring Table History

-- COMMAND ----------

DESCRIBE HISTORY employees

-- COMMAND ----------

-- NOTE: Direct browsing of _delta_log is not available for managed tables on serverless compute
-- For hive_metastore catalog, use: %fs ls 'dbfs:/user/hive/warehouse/employees/_delta_log'
-- DESCRIBE HISTORY shows the same transaction log information (one row per commit)
DESCRIBE HISTORY employees

-- COMMAND ----------

-- NOTE: Reading raw _delta_log JSON files is not available for managed tables on serverless compute
-- For hive_metastore catalog, use: %fs head 'dbfs:/user/hive/warehouse/employees/_delta_log/00000000000000000005.json'
-- Instead, we can inspect a specific commit version's details from the history
SELECT * FROM (DESCRIBE HISTORY employees) WHERE version = 5

-- COMMAND ----------


