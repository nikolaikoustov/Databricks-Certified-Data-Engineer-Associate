-- Databricks notebook source
-- MAGIC %md
-- MAGIC
-- MAGIC ## Delta Time Travel

-- COMMAND ----------

-- we cannot set catalog to hive_metastore as this type is not supported in Free edition
-- USE CATALOG hive_metastore

-- COMMAND ----------

DESCRIBE HISTORY employees

-- COMMAND ----------

SELECT * 
FROM employees VERSION AS OF 4

-- COMMAND ----------

SELECT * FROM employees@v4

-- COMMAND ----------

DELETE FROM employees

-- COMMAND ----------

SELECT * FROM employees

-- COMMAND ----------

RESTORE TABLE employees TO VERSION AS OF 6

-- COMMAND ----------

SELECT * FROM employees

-- COMMAND ----------

DESCRIBE HISTORY employees

-- COMMAND ----------

-- MAGIC %md
-- MAGIC
-- MAGIC ## OPTIMIZE Command

-- COMMAND ----------

DESCRIBE DETAIL employees

-- COMMAND ----------

OPTIMIZE employees
ZORDER BY id

-- COMMAND ----------

DESCRIBE DETAIL employees

-- COMMAND ----------

DESCRIBE HISTORY employees

-- COMMAND ----------

-- NOTE: Direct file browsing via %fs is not available for managed tables on serverless compute
-- For hive_metastore catalog, use: %fs ls 'dbfs:/user/hive/warehouse/employees'
-- After OPTIMIZE, we can see the compacted Parquet files
SELECT DISTINCT _metadata.file_path AS file_name FROM employees

-- COMMAND ----------

-- MAGIC %md
-- MAGIC
-- MAGIC ## VACUUM Command

-- COMMAND ----------

VACUUM employees

-- COMMAND ----------

-- NOTE: Direct file browsing via %fs is not available for managed tables on serverless compute
-- For hive_metastore catalog, use: %fs ls 'dbfs:/user/hive/warehouse/employees'
-- Before VACUUM, stale files are still present
SELECT DISTINCT _metadata.file_path AS file_name FROM employees

-- COMMAND ----------

VACUUM employees RETAIN 0 HOURS

-- COMMAND ----------

SET spark.databricks.delta.retentionDurationCheck.enabled = false;

-- COMMAND ----------

VACUUM employees RETAIN 1 HOURS

-- COMMAND ----------

-- NOTE: Direct file browsing via %fs is not available for managed tables on serverless compute
-- For hive_metastore catalog, use: %fs ls 'dbfs:/user/hive/warehouse/employees'
-- After VACUUM, only active files remain
SELECT DISTINCT _metadata.file_path AS file_name FROM employees

-- COMMAND ----------

SELECT * FROM employees@v1

-- COMMAND ----------

-- MAGIC %md
-- MAGIC
-- MAGIC ## Dropping Tables

-- COMMAND ----------

DROP TABLE employees

-- COMMAND ----------

SELECT * FROM employees

-- COMMAND ----------

-- NOTE: Direct file browsing via %fs is not available for managed tables on serverless compute
-- For hive_metastore catalog, use: %fs ls 'dbfs:/user/hive/warehouse/employees'
-- After DROP TABLE, the table and its files no longer exist
SELECT DISTINCT _metadata.file_path AS file_name FROM employees
