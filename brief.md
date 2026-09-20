# Data engineering learning Exercise brief

The prupsoe of this breif is to provide an outline for a training exercise for data engineers that enables them to build and end to end data pipeline in Snowflkae usign Snowflake native features and functions. 



## 1. Training Exercise Objectives

Allow learners to build an  end to end  Snowflake data pipeline to get data from the raw data layer through to a reporting view that can be consumed by a dashboard. 

## 2. Target Audience

Leaners will have a basic knowledge of Snowflake but will have data engineering experience. 

## 3. Business Scenario for the exercise 

	Business needs insight into monthly sales volume, revenue, and margin of menu items and menu item categories. 

## 4. Data Architecture

The data platform is Snowflake.  This is the data architecture to follow:

RAW (database/schema: TASTYBYTES_RAW.RAW)
* Source tables already landed (read-only)
STAGE (database/schema: TASTYBYTES_REFINED.STAGING)
* Cleaned, typed staging tables 
* Column masking applied on PII using tags
* Enterprise tags and COMMENTs on every staging table (and PII columns)
DIMENSIONAL MODEL (database/schema: TASTYBYTES_CONSUMPTION.WAREHOUSE)
* Use a standard dimensional model with dimensions and facts. 
* Tags, COMMENTs, and masking re-applied on the warehouse tables
DATA PRODUCTS (database/schema: TASTYBYTES_CONSUMPTION.ANALYTICS)
* Contains views or tables for specific reporting needs. Built from dimensional model in TASTYBYTES_CONSUMPTION.WAREHOUSE
* Product-level COMMENTs and catalog tags
DATA GOVERNANCE ( database/schema: TASTYBYTES_GOVERNANCE.GOVERNANCE)
* Security and governance policies and objects will be defined here including enterprise tags, column masking policies

For the training exercise assume the following:
- All databases and schema will exist. Leaners will not need to create these objects.
- Roles will already exist. Leaners will not need to create them but will need to define GRANTS for roles to objects they create
- All Tags will already be created in the TASTYBYTES_GOVERNANCE.GOVERNANCE schema

You can access the RAW data in the following schema : tastybytes_analytics.RAW 

## 5. Pipeline flow

The following is the general data pipeline flow leaners should follow. 

1. RAW - Data will already exist in the TASTYBYTES_RAW.RAW schema. Leaners will not need to ingest or modify the TASTYBYTES_RAW.RAW tables. The TASTYBYTES_RAW.RAW schema will be the source for the staging tables. 

2. STAGING - Leaners will need to define staging tables for the objects that are in scope for the exercise. Key steps in this phase include
        Define DDL for the required staging tables including appropriate logic to handle nulls, known bad data, white space stripping etc. 
        Convert JSON to columns if relevant.
        Include relevant columns to track metadata such as oad timestamp, source table and other relevant metadata columns for staging table
        Apply the relevant enterprise tags to the tables they create
        Apply the relevant column masking policies to columns that require it.  
        Define SQL stored procedure to load each staging table.
        Define a Task graph to trigger the stored procures in the correct order to load data from RAW into STAGING tables
        

3. DIMENSIONAL MODEL - Leaners will need to define the dimension and fact tables that are in scope for the exercise. The source for dimensional model tables will be the   TASTYBYTES_REFINED.STAGING schema. 
        Define the DDL for the dimension and fact tables. 
        Include relevant columns to track metadata such as load timestamp, valid to/from , is deleted etc depending on the nature of the dimension or fact table ( e.g. SCD type 1 or 2) 
        Leverage. Surrogate key where appropriate
        Define SQL Stored  procedures to load data from staging tables into dimension and fact tables.  These should reflect the nature of the dimension and fact table ( e.g. SCD type 1 vs 2) 


4. DATA PRODUCT - Leaners will create 1 reporting view that will be used to provide data to a dashboard. The source of the data will be the dimensional model in the TASTYBYTES_CONSUMPTION.WAREHOUSE  schema. 

## Exercise Structure

The proposed training exercise structure will be:

Set Up -  The traingn exercise will be designed to run in a Snowflake Trial account so there will be pre-requisite steps that the learner will need to complete includingL
    - set up snwoflake trial account with their work email address
    - Run a set up script to create all the neccessary snowflake objects includign database, schema, roles, warehouses etc. 
    - Run a data load scipt that will load data into the RAW tables, and any staging , and warehouse tables that will be pre-populated. 

Module 1: RAW to STAGING - Create staging obejcts and pipline to load data from RAW to STAGING.
MOdule 2 : STAGING to WAREHOUSE - Create WAREHOUSE objects and pipeline to load data from STAGING into WAREHOUSE
MOdule 3: WAREHOUSE to DATA PRODUCT