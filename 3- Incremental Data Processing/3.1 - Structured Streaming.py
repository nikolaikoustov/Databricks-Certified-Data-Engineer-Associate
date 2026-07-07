# Databricks notebook source
# MAGIC %md-sandbox
# MAGIC
# MAGIC <div  style="text-align: center; line-height: 0; padding-top: 9px;">
# MAGIC   <img src="https://raw.githubusercontent.com/derar-alhussein/Databricks-Certified-Data-Engineer-Associate/main/Includes/images/bookstore_schema.png" alt="Databricks Learning" style="width: 600">
# MAGIC </div>

# COMMAND ----------

# MAGIC %run "../Includes/Copy-Datasets"

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Reading Streaming data
# MAGIC We can setup a stream over a streaming source like Kafka topic or we can setup a stream on a Delta table as shown below. 

# COMMAND ----------

(spark.readStream
      .table("books")
      .createOrReplaceTempView("books_streaming_tmp_vw")
)

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Displaying Streaming Data

# COMMAND ----------

# Executing SQL directly againt a streaming view is not supported for the Serverless Engine. If you try to run the code
# below, you will get the following error
# [TEMP_CHECKPOINT_LOCATION_NOT_SUPPORTED] Implicit temporary streaming checkpoint locations are not supported in the current workspace, please specify a checkpoint location explicitly.

# %sql
# SELECT author,count(book_id) AS total_books
# FROM books_streaming_tmp_vw
# GROUP BY author

# COMMAND ----------

# The following code will work because we are using the PySpark API thus we can specify a checkpoint location on stream read/processing.
# Make sure to follow the rule: "One checkpoint per logical stream consumer" i.e. use a unique, deterministic checkpoint path for each logical stream
# e.g.
# 1) /Volumes/<catalog>/<schema>/<volume>/checkpoints/bookstore/books_bronze
# 2) /Volumes/<catalog>/<schema>/<volume>/checkpoints/bookstore/customers_bronze
# 3) /Volumes/<catalog>/<schema>/<volume>/checkpoints/bookstore/orders_silver
#
# Do NOT reuse the same checkpoint for different queries, different targets, or different stream logic.
# Checkpoints allow Spark to keep track of the last processed records in the stream. This allows to re-run the notebook regularly
# to consume newly added records / events to the stream since the last checkpoint / processing event  

books_streaming_df = spark.sql("SELECT * FROM books_streaming_tmp_vw")
display(books_streaming_df, checkpointLocation = f"{checkpoints_bookstore}/tmp/books_streaming")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Applying Transformations

# COMMAND ----------

author_counts_df = spark.sql("""SELECT author, count(book_id) AS total_books
                                  FROM books_streaming_tmp_vw
                                  GROUP BY author""")
display(author_counts_df, checkpointLocation = f"{checkpoints_bookstore}/tmp/author_counts")

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Unsupported Operations

# COMMAND ----------

# If you uncomment this code, execution will fail with the error "Sorting is not supported on streaming DataFrames/Datasets, unless it is on aggregated DataFrame/Dataset in Complete output mode". 
# This shows that sorting is not supported for streamed sources
#
# books_streaming_df = books_streaming_df.orderBy("author")

(books_streaming_df.writeStream
                .option("checkpointLocation", f"{checkpoints_bookstore}/sorted_books")
                # This option (to process everything that is available on the stream) is supported on Serverless engine
                .trigger(availableNow=True)
                # This option (of periodic processing of micro-batches) is not supported on Serverless engine
                # If you try to use it the cell execution will fail with
                # "[INFINITE_STREAMING_TRIGGER_NOT_SUPPORTED] Trigger type ProcessingTime is not supported for this cluster type." 
                # .trigger(processingTime="10 seconds")
                .format("console")
                .start()
)

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC ## Persisting Streaming Data

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE OR REPLACE TEMP VIEW author_counts_tmp_vw AS (
# MAGIC   SELECT author, count(book_id) AS total_books
# MAGIC   FROM books_streaming_tmp_vw
# MAGIC   GROUP BY author
# MAGIC )

# COMMAND ----------

# Trigger type ProcessingTime is not supported for Serverless compute.
# This is because we cannot have always-on periodic processing notebooks on Serverless.
# (See: https://docs.databricks.com/aws/en/compute/serverless/limitations#streaming-limitations)
# Recommended Solution: Use Delta Live Tables (DLT) pipelines (Lecture 31) with Continuous mode.
# Alternative Workaround: use trigger AvailableNow

#(spark.table("author_counts_tmp_vw")                               
#      .writeStream  
#      .trigger(processingTime='4 seconds')
#      .outputMode("complete")
#      .option("checkpointLocation", f"{checkpoints_bookstore}/author_counts")
#      .table("author_counts")
#)

(spark.table("author_counts_tmp_vw")                               
      .writeStream  
      .trigger(availableNow=True)
      .outputMode("complete")
      .option("checkpointLocation", f"{checkpoints_bookstore}/author_counts")
      .table("author_counts")
)

# COMMAND ----------

# MAGIC %sql DESCRIBE EXTENDED author_counts

# COMMAND ----------

# MAGIC %sql
# MAGIC -- we can query the target as it is of type Delta Table not a Streaming View
# MAGIC SELECT * FROM author_counts;

# COMMAND ----------

# MAGIC %md
# MAGIC ## Adding New Data

# COMMAND ----------

# MAGIC %sql
# MAGIC INSERT INTO books (book_id, title, author, category, price)
# MAGIC values ("B19", "Introduction to Modeling and Simulation", "Mark W. Spong", "Computer Science", 25),
# MAGIC         ("B20", "Robot Modeling and Control", "Mark W. Spong", "Computer Science", 30),
# MAGIC         ("B21", "Turing's Vision: The Birth of Computer Science", "Chris Bernhardt", "Computer Science", 35)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Streaming in Batch Mode 

# COMMAND ----------

(spark.table("author_counts_tmp_vw")                               
      .writeStream           
      .trigger(availableNow=True)
      .outputMode("complete")
      .option("checkpointLocation", f"{checkpoints_bookstore}/author_counts")
      .table("author_counts")
      .awaitTermination()
)

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT *
# MAGIC FROM author_counts

# COMMAND ----------

-- Run this cell then go back and re-run cells in section 'Streaming in Batch Mode'.
-- Then review the results in the author_counts table.
-- This demonstrates how our statistics table can be updated periodically as new data about the book sales arrives / becomes available.
-- Note that the statistics table is updated with the latest data as it arrives, but the table itself is not updated with the new data
-- This is because the table is not a streaming table, but a batch table.   
%sql
INSERT INTO books (book_id, title, author, category, price)
values ("B16", "Hands-On Deep Learning Algorithms with Python", "Sudharsan Ravichandiran", "Computer Science", 25),
        ("B17", "Neural Network Methods in Natural Language Processing", "Yoav Goldberg", "Computer Science", 30),
        ("B18", "Understanding digital signal processing", "Richard Lyons", "Computer Science", 35)
