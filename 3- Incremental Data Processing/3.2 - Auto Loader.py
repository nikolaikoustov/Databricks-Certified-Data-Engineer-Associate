# Databricks notebook source
# MAGIC %md-sandbox
# MAGIC
# MAGIC <div  style="text-align: center; line-height: 0; padding-top: 9px;">
# MAGIC   <img src="https://raw.githubusercontent.com/derar-alhussein/Databricks-Certified-Data-Engineer-Associate/main/Includes/images/bookstore_schema.png" alt="Databricks Learning" style="width: 600">
# MAGIC </div>

# COMMAND ----------

# MAGIC %run ../Includes/Copy-Datasets

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Exploring The Source Directory

# COMMAND ----------

files = dbutils.fs.ls(f"{dataset_bookstore}/orders-raw")
display(files)

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Auto Loader

# COMMAND ----------

(spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "parquet")
        .option("cloudFiles.schemaLocation", f"{checkpoints_bookstore}/orders_loader_checkpoint")
        .load(f"{dataset_bookstore}/orders-raw")
      .writeStream
        .trigger(availableNow=True) # we use trigger AvailableNow as Trigger type ProcessingTime is not supported for Serverless compute.
        .option("checkpointLocation", f"{checkpoints_bookstore}/orders_loader_checkpoint")
        .table("orders_updates")
)

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT * FROM orders_updates

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT count(*) FROM orders_updates

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Landing New Files

# COMMAND ----------

load_new_data()

# COMMAND ----------

files = dbutils.fs.ls(f"{dataset_bookstore}/orders-raw")
display(files)

# COMMAND ----------

# MAGIC %md
# MAGIC # Re-running Auto Loader
# MAGIC When using serverless engine, we need to manually re-run the Auto Loader related cell to load data from the newly added files.
# MAGIC As we re-ran the Auto Loader usign the same checkpoint, it identified that we already processed one file in the source directory so it only worked on files added after the last checkpoint / we finished processing last time.
# MAGIC Once done, run the cells below to analyze the orders table.
# MAGIC

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT count(*) FROM orders_updates

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Exploring Table History

# COMMAND ----------

# MAGIC %sql
# MAGIC DESCRIBE HISTORY orders_updates

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Cleaning Up

# COMMAND ----------

# MAGIC %sql
# MAGIC -- This command deletes table from catalog but it preserves data in the underlying AWS S3 bucket and you need to delete it manually
# MAGIC DROP TABLE orders_updates

# COMMAND ----------

# This command deletes files in the checkpoint directory we used in this notebook
# As the checkpoint dirtectory is kept on a Volume backend by AWS S3 bucket, the files are actually deleted from AWS S3 bucket
dbutils.fs.rm(f"{checkpoints_bookstore}/orders_loader_checkpoint", True)
