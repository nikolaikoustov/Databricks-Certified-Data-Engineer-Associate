-- Databricks notebook source
-- MAGIC %run ../Includes/Copy-Datasets

-- COMMAND ----------

DESCRIBE TABLE customers_details

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Dynamic views

-- COMMAND ----------

CREATE OR REPLACE VIEW customers_vw AS
  SELECT
    customer_id,
    CASE 
      WHEN is_account_group_member('admins_demo') THEN email
      ELSE 'REDACTED'
    END AS email,
    gender,
    CASE 
      WHEN is_account_group_member('admins_demo') THEN first_name
      ELSE 'REDACTED'
    END AS first_name,
    CASE 
      WHEN is_account_group_member('admins_demo') THEN last_name
      ELSE 'REDACTED'
    END AS last_name,
    CASE 
      WHEN is_account_group_member('admins_demo') THEN street
      ELSE 'REDACTED'
    END AS street,
    city,
    country
  FROM customers_details

-- COMMAND ----------

SELECT * FROM customers_vw

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Data redaction and filtering
-- MAGIC As your account is not in the user group mentioned in the query, you will only see refacted data for France. 

-- COMMAND ----------

CREATE OR REPLACE VIEW customers_fr_vw AS
SELECT * FROM customers_vw
WHERE 
  CASE 
    WHEN is_account_group_member('admins_demo') THEN TRUE
    ELSE country = "France"
  END

-- COMMAND ----------

SELECT * FROM customers_fr_vw

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### User Group Management
-- MAGIC User groups can be managed at Account (User management -> Groups tab -> Add group...) as well as Workspace (User icon -> Settings... -> Identity and Access -> Groups -> Manage...) level. While managed from a Workspace, if Unity catalog is used, the user group is forced to be created at the Account level so Account level users can be added to that group.
-- MAGIC
-- MAGIC **IMPORTANT!!!** For the Account level user group to be visible to queries at a specific Workspace level they MAY need to be manually propagated to the respective Workspace(s).
-- MAGIC Always check that the user groups you need have been propagated and are visible in the Groups section of the Workspace's Identity and Access section with the Source = Account.
-- MAGIC
-- MAGIC Once you add the user group 'admins_demo' and add your own user account to it, re-run the query in the cell above and compare the results - data should no longer be redacted and you should see records for all countries not just France.  
-- MAGIC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Table-level row filters and column masks

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2.1. Column masks

-- COMMAND ----------

CREATE OR REPLACE FUNCTION mask_email(email STRING)
RETURN CASE WHEN is_account_group_member('Test') THEN email
            ELSE '***@***.***'
       END;

-- COMMAND ----------

ALTER TABLE customers_details ALTER COLUMN email SET MASK mask_email;

-- COMMAND ----------

SELECT * FROM customers_details

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2.2 Row filters 

-- COMMAND ----------

CREATE OR REPLACE FUNCTION geo_filter(country STRING)
RETURN IF(is_account_group_member('Test'), true, country="France");

-- COMMAND ----------

ALTER TABLE customers_details SET ROW FILTER geo_filter ON (country);

-- COMMAND ----------

SELECT * FROM customers_details

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Next, add the user group 'Test' and add your own user account to it, re-run the query in the cell above and compare the results - data should no longer be redacted and you should see records for all countries not just France.  

-- COMMAND ----------

ALTER TABLE customers_details ALTER COLUMN email DROP MASK;
ALTER TABLE customers_details DROP ROW FILTER;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Attribute-Based Access Control (ABAC) policies

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Tag management
-- MAGIC To create Tags, 
-- MAGIC 1) While in a Workspace, navigate to Catalog -> Govern button -> Governed Tags...
-- MAGIC 2) Click Create Governed Tag button.
-- MAGIC 3) While in the form, 
-- MAGIC     - name the tag as 'pii' then 
-- MAGIC     - add below list of permitted values:
-- MAGIC         - email_address
-- MAGIC     - click Create
-- MAGIC 4) Click Create Governed Tag button again
-- MAGIC 5) While in the form, 
-- MAGIC     - name the tag as 'geo_restricted' then 
-- MAGIC     - click Create
-- MAGIC

-- COMMAND ----------

ALTER TABLE customers_details SET TAGS ('geo_restricted');

ALTER TABLE customers_details ALTER COLUMN country SET TAGS ('geo_restricted');

-- COMMAND ----------

ALTER TABLE customers_details ALTER COLUMN email SET TAGS ('pii' = 'email_address');

-- COMMAND ----------

CREATE OR REPLACE POLICY pii_email_masking_policy
ON SCHEMA workspace.aws_training_data
COLUMN MASK workspace.aws_training_data.mask_email
TO `account users` EXCEPT `admins_demo`
FOR TABLES
MATCH COLUMNS hasTagValue('pii','email_address') AS e
ON COLUMN e

-- COMMAND ----------

CREATE OR REPLACE POLICY geo_filtering_policy
ON SCHEMA workspace.aws_training_data
ROW FILTER workspace.aws_training_data.geo_filter
TO `account users` EXCEPT `admins_demo`
FOR TABLES
WHEN has_tag('geo_restricted')
MATCH COLUMNS has_tag('geo_restricted') AS g
USING COLUMNS (g)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Validating policies
-- MAGIC To validate that policies were setup correctly:
-- MAGIC 1. While in a Workspace, navigate to Catalog -> select desired catalog (e.g. workspace) -> select desired scheme (e.g. aws_training_data)
-- MAGIC 2. Click on Policies tab
-- MAGIC 3. You should see two policies created with the cells above
-- MAGIC
-- MAGIC

-- COMMAND ----------

SELECT * FROM workspace.aws_training_data.customers_details
