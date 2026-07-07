# Databricks notebook source
# DBTITLE 1,Set catalog and schema context
# MAGIC %sql
# MAGIC dbutils.widgets.text("catalog", "workspace")
# MAGIC dbutils.widgets.text("schema", "aws_training_data")
# MAGIC
# MAGIC spark.sql(f"USE CATALOG {dbutils.widgets.get('catalog')}")
# MAGIC spark.sql(f"USE SCHEMA {dbutils.widgets.get('schema')}")

# COMMAND ----------

#files = dbutils.fs.ls("dbfs:/mnt/demo/dlt/demo_bookstore")
#display(files)

# COMMAND ----------

#files = dbutils.fs.ls("dbfs:/mnt/demo/dlt/demo_bookstore/system/events")
#display(files)

# COMMAND ----------

# MAGIC %sql
# MAGIC --SELECT * FROM delta.`dbfs:/mnt/demo/dlt/demo_bookstore/system/events`

# COMMAND ----------

#files = dbutils.fs.ls("dbfs:/mnt/demo/dlt/demo_bookstore/tables")
#display(files)

# COMMAND ----------

# DBTITLE 1,Cell 5
# MAGIC %sql
# MAGIC SELECT * FROM cn_daily_customer_books

# COMMAND ----------

# DBTITLE 1,Cell 6
# MAGIC %sql
# MAGIC SELECT * FROM fr_daily_customer_books
