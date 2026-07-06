-- Databricks notebook source
-- MAGIC %md-sandbox
-- MAGIC
-- MAGIC <div  style="text-align: center; line-height: 0; padding-top: 9px;">
-- MAGIC   <img src="https://raw.githubusercontent.com/derar-alhussein/Databricks-Certified-Data-Engineer-Associate/main/Includes/images/bookstore_schema.png" alt="Databricks Learning" style="width: 600">
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %run ../Includes/Copy-Datasets

-- COMMAND ----------

-- MAGIC %python
-- MAGIC dbutils.widgets.text("dataset_bookstore", dataset_bookstore)

-- COMMAND ----------

CREATE TABLE orders AS
SELECT * FROM parquet.`${dataset_bookstore}/orders`

-- COMMAND ----------

SELECT * FROM orders

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Overwriting Tables

-- COMMAND ----------

-- Helps to have atomicity as read transactions can still access old version of it 
CREATE OR REPLACE TABLE orders AS
SELECT * FROM parquet.`${dataset_bookstore}/orders`

-- COMMAND ----------

DESCRIBE HISTORY orders

-- COMMAND ----------

-- alternative syntax, but requires table to exist
-- also preserves schema of the table 
INSERT OVERWRITE orders
SELECT * FROM parquet.`${dataset_bookstore}/orders`

-- COMMAND ----------

DESCRIBE HISTORY orders

-- COMMAND ----------

-- shows that the INSERT OVERWRITE command preserves the existing schema of the table
INSERT OVERWRITE orders
SELECT *, current_timestamp() FROM parquet.`${dataset_bookstore}/orders`

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Appending Data

-- COMMAND ----------

-- this statement appends new records into the table
INSERT INTO orders
SELECT * FROM parquet.`${dataset_bookstore}/orders-new`

-- COMMAND ----------

SELECT count(*) FROM orders

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Merging Data

-- COMMAND ----------

-- to update existing records (as opposed to creating duplicates) and add new records use a temp view
CREATE OR REPLACE TEMP VIEW customers_updates AS 
SELECT * FROM json.`${dataset_bookstore}/customers-json-new`;
-- ... and MERGE INTO statement
MERGE INTO customers c
USING customers_updates u
ON c.customer_id = u.customer_id
WHEN MATCHED AND c.email IS NULL AND u.email IS NOT NULL THEN
  UPDATE SET email = u.email, updated = u.updated
WHEN NOT MATCHED THEN INSERT *

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW books_updates AS
SELECT * FROM read_files(
    '${dataset_bookstore}/books-csv-new',
    format => 'csv',
    header => 'true',
    delimiter => ';');

SELECT * FROM books_updates

-- COMMAND ----------

-- we can see that MERGE operation works with source and target being of different type  (JSON, CSV vs Parquet) 
-- the operation is idempotent and can be run multiple times
MERGE INTO books b
USING books_updates u
ON b.book_id = u.book_id AND b.title = u.title
WHEN NOT MATCHED AND u.category = 'Computer Science' THEN 
  INSERT *

-- COMMAND ----------

DESCRIBE HISTORY orders
