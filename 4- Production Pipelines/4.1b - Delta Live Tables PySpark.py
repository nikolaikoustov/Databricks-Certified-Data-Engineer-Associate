# Databricks notebook source
# MAGIC %md
# MAGIC # Delta Live Tables - PySpark Syntax
# MAGIC This notebook demonstrates the same bookstore pipeline as `4.1 - Delta Live Tables.sql`
# MAGIC but using PySpark with `@dlt.table` decorators.

# COMMAND ----------

import dlt
from pyspark.sql.functions import col, count, date_trunc, from_unixtime, explode

# The datasets_path is provided via pipeline configuration
datasets_path = spark.conf.get("datasets_path")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Bronze Layer

# COMMAND ----------

@dlt.table(
    comment="The raw books orders, ingested from orders-raw (streaming)"
)
def orders_raw():
    return (
        spark.readStream.format("cloudFiles")
            .option("cloudFiles.format", "json")
            .option("cloudFiles.inferColumnTypes", "true")
            .load(f"{datasets_path}/orders-json-raw")
    )

# COMMAND ----------

@dlt.table(
    comment="The customers lookup table, ingested from customers-json"
)
def customers_pyspark():
    return spark.read.json(f"{datasets_path}/customers-json")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Silver Layer

# COMMAND ----------

@dlt.table(
    comment="The cleaned books orders with valid order_id"
)
@dlt.expect_or_drop("valid_order_number", "order_id IS NOT NULL")
def orders_cleaned():
    orders = dlt.read_stream("orders_raw")
    customers = dlt.read("customers_pyspark")

    return (
        orders.join(customers, orders.customer_id == customers.customer_id, "left")
            .select(
                orders.order_id,
                orders.quantity,
                orders.customer_id,
                col("profile:first_name").alias("f_name"),
                col("profile:last_name").alias("l_name"),
                from_unixtime(col("order_timestamp"), "yyyy-MM-dd HH:mm:ss").cast("timestamp").alias("order_timestamp"),
                orders.books,
                col("profile:address:country").alias("country")
            )
    )

# COMMAND ----------

# MAGIC %md
# MAGIC ## Gold Layer

# COMMAND ----------

@dlt.table(
    comment="Daily number of books per customer in China"
)
def cn_daily_customer_books():
    return (
        dlt.read("orders_cleaned")
            .filter(col("country") == "China")
            .groupBy("customer_id", "f_name", "l_name", date_trunc("DD", "order_timestamp").alias("order_date"))
            .agg(count("*").alias("books_counts"))
    )

# COMMAND ----------

@dlt.table(
    comment="Daily number of books per customer in France"
)
def fr_daily_customer_books():
    return (
        dlt.read("orders_cleaned")
            .filter(col("country") == "France")
            .groupBy("customer_id", "f_name", "l_name", date_trunc("DD", "order_timestamp").alias("order_date"))
            .agg(count("*").alias("books_counts"))
    )

