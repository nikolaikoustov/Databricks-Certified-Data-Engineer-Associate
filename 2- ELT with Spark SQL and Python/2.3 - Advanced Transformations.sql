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

-- MAGIC %md
-- MAGIC
-- MAGIC ## Parsing JSON Data

-- COMMAND ----------

SELECT * FROM customers

-- COMMAND ----------

DESCRIBE customers

-- COMMAND ----------

-- Modern Spark SQL syntax to query JSON columns directly
SELECT customer_id, profile:first_name, profile:address:country 
FROM customers

-- COMMAND ----------

-- older Spark SQL syntax using get_json_object() funtion and JSONPath expressions 
SELECT customer_id, 
    get_json_object(profile, '$.first_name') AS first_name,
    get_json_object(profile, '$.address.country') AS country 
FROM customers

-- COMMAND ----------

-- NOTE The below query will NOT work without a JSON schema provided
--SELECT from_json(profile) AS profile_struct
--  FROM customers;

-- COMMAND ----------

SELECT profile 
FROM customers 
LIMIT 1

-- COMMAND ----------

-- using a sample JSON and scahme_of_json() we can construct a schema then pass it to from_json() function 
CREATE OR REPLACE TEMP VIEW parsed_customers AS
  SELECT customer_id, from_json(profile, schema_of_json('{"first_name":"Thomas","last_name":"Lane","gender":"Male","address":{"street":"06 Boulevard Victor Hugo","city":"Paris","country":"France"}}')) AS profile_struct
  FROM customers;
  
SELECT * FROM parsed_customers

-- COMMAND ----------

DESCRIBE parsed_customers

-- COMMAND ----------

-- now we can use struct syntax to reference attributes of it
SELECT customer_id, profile_struct.first_name, profile_struct.address.country
FROM parsed_customers

-- COMMAND ----------

-- Using .* syntax we can flatten the structure 
CREATE OR REPLACE TEMP VIEW customers_final AS
  SELECT customer_id, profile_struct.*
  FROM parsed_customers;
  
SELECT * FROM customers_final

-- COMMAND ----------

SELECT order_id, customer_id, books
FROM orders

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Explode Function

-- COMMAND ----------

-- What if a column is of type array ?
-- Use explode() function to split this into multiple rows - one per element of the array
SELECT order_id, customer_id, explode(books) AS book 
FROM orders

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Collecting Rows

-- COMMAND ----------

-- collect_set() function helps to collect unique values into a single column - doing reverse of explode() 
SELECT customer_id,
  collect_set(order_id) AS orders_set,
  collect_set(books.book_id) AS books_set
FROM orders
GROUP BY customer_id

-- COMMAND ----------

SELECT * FROM books

-- COMMAND ----------

-- MAGIC %md
-- MAGIC
-- MAGIC ##Flatten Arrays

-- COMMAND ----------

-- and combining both functions helps to produce a list of books per customer as an array of unique book ids
SELECT customer_id,
  collect_set(books.book_id) As before_flatten,
  array_distinct(flatten(collect_set(books.book_id))) AS after_flatten
FROM orders
GROUP BY customer_id

-- COMMAND ----------

-- MAGIC %md
-- MAGIC
-- MAGIC ##Join Operations

-- COMMAND ----------

-- JOINS allow us to enrich data in one table (orders) with describing columns in another table (books)
CREATE OR REPLACE VIEW orders_enriched AS
SELECT *
FROM (
  SELECT *, explode(books) AS book 
  FROM orders) o
INNER JOIN books b
ON o.book.book_id = b.book_id;

SELECT * FROM orders_enriched

-- COMMAND ----------

-- JOINS allow us to enrich data in one table (orders) with describing columns in another table (books)
CREATE OR REPLACE TEMP VIEW orders_enriched_v2 AS
SELECT o.customer_id, explode(books) as book, c.address.country
FROM orders o
INNER JOIN customers_final c
ON o.customer_id = c.customer_id;

SELECT * FROM orders_enriched_v2;

-- COMMAND ----------

-- To handle comparisons where NULL values should be treated as equal to other NULL values, 
-- Spark provides the null-safe equal operator, which is written as <=>. For example:

SELECT *
FROM orders o
INNER JOIN customers c
ON o.customer_id <=> c.customer_id;

-- Here, o.customer_id <=> c.customer_id returns true if both values are equal, or if both values are NULL. 
-- Otherwise, it returns false.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Set Operations

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW orders_updates
AS SELECT * FROM parquet.`${dataset_bookstore}/orders-new`;

SELECT * FROM orders 
UNION 
SELECT * FROM orders_updates 

-- COMMAND ----------

SELECT * FROM orders 
INTERSECT 
SELECT * FROM orders_updates 

-- COMMAND ----------

SELECT * FROM orders 
MINUS 
SELECT * FROM orders_updates 

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Reshaping Data with Pivot

-- COMMAND ----------

-- PIVOT operation on data sets allows to send input rows then apply an aggregation function to each group of rows.
-- the unique values of the column specified in the PIVOT clause are used as column names in the output.
-- the aggregation function is applied to each group of rows with the same value in the PIVOT column
CREATE OR REPLACE TABLE transactions AS

SELECT * FROM (
  SELECT
    customer_id,
    book.book_id AS book_id,
    book.quantity AS quantity
  FROM orders_enriched
) PIVOT (
  sum(quantity) FOR book_id in (
    'B01', 'B02', 'B03', 'B04', 'B05', 'B06',
    'B07', 'B08', 'B09', 'B10', 'B11', 'B12'
  )
);

SELECT * FROM transactions

-- COMMAND ----------

-- this query retrieves how many copies of each book were sold per in-scope country 
CREATE OR REPLACE TABLE transactions_by_country AS

SELECT * FROM (
  SELECT
    customer_id,
    country,
    book.book_id AS book_id,
    b.title AS title,
    b.author as author
  FROM orders_enriched_v2 o
  INNER JOIN books b
  ON o.book.book_id = b.book_id  
) PIVOT (
  -- we need to count customer_id as we want a count of each book sold per country NOT how many books each customer bought
  count(customer_id) AS total FOR country IN ('China', 'Canada', 'Mexico')
);

SELECT * FROM transactions_by_country

-- COMMAND ----------

-- This query validates the break-down by country about by providing the total sold for all in-scope countries 
SELECT book_id, title, author, count (*) as total FROM (
  SELECT
    customer_id,
    country,
    book.book_id AS book_id,
    b.title AS title,
    b.author as author
  FROM orders_enriched_v2 o
  INNER JOIN books b
  ON o.book.book_id = b.book_id
  WHERE country IN ('China', 'Canada', 'Mexico')
)
GROUP BY book_id, title, author;
