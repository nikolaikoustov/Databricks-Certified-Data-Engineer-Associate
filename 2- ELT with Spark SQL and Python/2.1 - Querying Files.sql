-- Databricks notebook source
-- MAGIC %md-sandbox
-- MAGIC
-- MAGIC <div  style="text-align: center; line-height: 0; padding-top: 9px;">
-- MAGIC   <img src="https://raw.githubusercontent.com/derar-alhussein/Databricks-Certified-Data-Engineer-Associate/main/Includes/images/bookstore_schema.png" alt="Databricks Learning" style="width: 600">
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Querying JSON 

-- COMMAND ----------

-- MAGIC %run ../Includes/Copy-Datasets

-- COMMAND ----------

-- MAGIC %python
-- MAGIC # Configure the dataset path as a notebook parameter using Widgets, enabling its use in SQL queries through the ${dataset_bookstore} placeholder.
-- MAGIC dbutils.widgets.text("dataset_bookstore", dataset_bookstore)

-- COMMAND ----------

-- MAGIC %python
-- MAGIC files = dbutils.fs.ls(f"{dataset_bookstore}/customers-json")
-- MAGIC display(files)

-- COMMAND ----------

SELECT * FROM json.`${dataset_bookstore}/customers-json/export_001.json`

-- COMMAND ----------

SELECT * FROM json.`${dataset_bookstore}/customers-json/export_*.json`

-- COMMAND ----------

SELECT * FROM json.`${dataset_bookstore}/customers-json`

-- COMMAND ----------

SELECT count(*) FROM json.`${dataset_bookstore}/customers-json`

-- COMMAND ----------

 SELECT *,
    -- input_file_name() source_file
    _metadata.file_path  source_file
  FROM json.`${dataset_bookstore}/customers-json`;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Querying text Format

-- COMMAND ----------

SELECT * FROM text.`${dataset_bookstore}/customers-json`

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC ## Querying binaryFile Format

-- COMMAND ----------

SELECT * FROM binaryFile.`${dataset_bookstore}/customers-json`

-- COMMAND ----------

-- MAGIC %md
-- MAGIC
-- MAGIC ## Querying CSV 

-- COMMAND ----------

SELECT * FROM csv.`${dataset_bookstore}/books-csv`

-- COMMAND ----------

-- IMPORTANT: In newer runtime versions, you can use read_files() in CTAS statements to create delta tables. See the last two cells


--CREATE TABLE books_csv
--  (book_id STRING, title STRING, author STRING, category STRING, price DOUBLE)
--USING CSV
--OPTIONS (
--  header = "true",
--  delimiter = ";"
--)
--LOCATION "${dataset_bookstore}/books-csv"

-- COMMAND ----------

--SELECT * FROM books_csv

-- COMMAND ----------

-- MAGIC %md
-- MAGIC
-- MAGIC ## Limitations of Non-Delta Tables

-- COMMAND ----------

--DESCRIBE EXTENDED books_csv

-- COMMAND ----------

-- MAGIC %python
-- MAGIC files = dbutils.fs.ls(f"{dataset_bookstore}/books-csv")
-- MAGIC display(files)

-- COMMAND ----------

-- MAGIC %python
-- MAGIC #(spark.read
-- MAGIC #        .table("books_csv")
-- MAGIC #      .write
-- MAGIC #        .mode("append")
-- MAGIC #        .format("csv")
-- MAGIC #        .option('header', 'true')
-- MAGIC #        .option('delimiter', ';')
-- MAGIC #        .save(f"{dataset_bookstore}/books-csv"))

-- COMMAND ----------

-- MAGIC %python
-- MAGIC #files = dbutils.fs.ls(f"{dataset_bookstore}/books-csv")
-- MAGIC #display(files)

-- COMMAND ----------

--SELECT COUNT(*) FROM books_csv

-- COMMAND ----------

--REFRESH TABLE books_csv

-- COMMAND ----------

--SELECT COUNT(*) FROM books_csv

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## CTAS Statements

-- COMMAND ----------

-- we can read JSON files on a Volume with CTAS directly - even in serverless Databricks engine
DROP TABLE IF EXISTS customers;
CREATE TABLE customers AS
SELECT * FROM json.`${dataset_bookstore}/customers-json`;

DESCRIBE EXTENDED customers;

-- COMMAND ----------

CREATE TABLE books_unparsed AS
SELECT * FROM csv.`${dataset_bookstore}/books-csv`;

SELECT * FROM books_unparsed;

-- COMMAND ----------

-- we can read CSV files on a Volume with read_files() built-in function
DROP TABLE IF EXISTS books;
CREATE TABLE books AS
SELECT * FROM read_files(
    '${dataset_bookstore}/books-csv/export_*.csv',
    format => 'csv',
    header => 'true',
    delimiter => ';');

-- This syntax to create a CSV type View or Table is NOT supported on Serverless Databricks engine 
--CREATE TEMP VIEW books_tmp_vw
--   (book_id STRING, title STRING, author STRING, category STRING, price DOUBLE)
--USING CSV
--OPTIONS (
--  path = "${dataset_bookstore}/books-csv/export_*.csv",
--  header = "true",
--  delimiter = ";"
--);

--CREATE TABLE books AS
--  SELECT * FROM books_tmp_vw;
  
SELECT * FROM books

-- COMMAND ----------

-- Note that new tables in Databricks are created to use Parquet format by default and are Delta tables
-- so they are still backed by efficient mechanism for modification and querying 

-- The read_files function automatically tries to infer a unified schema from all the source files. 
-- If any value doesn’t match the expected schema, it's stored in an extra column called _rescued_data as a JSON string.
DESCRIBE EXTENDED books
