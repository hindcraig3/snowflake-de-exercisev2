# TastyBytes Data Engineering Exercise

## Purpose

This hands-on exercise walks you through building a complete data pipeline in Snowflake. Starting from raw source data, you will create staging tables, a dimensional model, and a reporting view — using only Snowflake-native features.

By the end of this exercise you will have practical experience with:

- **DDL design** — creating tables with appropriate data types, handling data quality issues in source data
- **Semi-structured data** — flattening JSON (VARIANT) columns into relational columns
- **SQL stored procedures** — writing reusable load procedures using TRUNCATE-reload and MERGE patterns
- **Task graphs** — orchestrating pipeline execution with Snowflake Tasks and dependencies
- **Data governance** — applying enterprise tags, column-level masking policies, and catalog documentation (COMMENTs)
- **RBAC** — granting role-based access to the objects you create
- **Dimensional modelling** — building SCD Type 1 and Type 2 dimensions and a fact table
- **Reporting views** — creating a data product that answers a specific business question

---

## How to Complete This Exercise

Work through these steps in order:

### 1. Set Up Your Environment

Follow the instructions in [setup/setup.md](setup/setup.md) to create a Snowflake trial account, run the setup script, and load the source data.

### 2. Review the Background

Read [exercises/00_background.md](exercises/00_background.md) to understand the business scenario, data architecture, RBAC model, and what you will build across the three modules.

### 3. Build: Module 1 — RAW to STAGING

Complete [exercises/01_module1_raw_to_staging.md](exercises/01_module1_raw_to_staging.md). You will create 4 staging tables, apply governance tags and masking, write load procedures, and orchestrate them with a task graph.

### 4. Build: Module 2 — STAGING to WAREHOUSE

Complete [exercises/02_module2_staging_to_warehouse.md](exercises/02_module2_staging_to_warehouse.md). You will create dimension tables (SCD Type 1 and 2), a fact table, write MERGE-based load procedures, and build a second task graph.

### 5. Build: Module 3 — WAREHOUSE to DATA PRODUCT

Complete [exercises/03_module3_warehouse_to_product.md](exercises/03_module3_warehouse_to_product.md). You will create a reporting view that answers the business question and validate it with sample queries.

### 6. Validate Your Work

Run the validation script to check all objects were created correctly. See [scripts/validate_exercise_instructions.md](scripts/validate_exercise_instructions.md) for instructions.

### 7. Test the End-to-End Pipeline

Insert new test data into RAW and run the full pipeline to prove data flows through to the reporting view. See [scripts/test_incremental_load_instructions.md](scripts/test_incremental_load_instructions.md) for instructions.

---

## Model Answer

A complete model answer is available in the [model_answer/](model_answer/) directory. It contains one SQL file per module and an overview document explaining the design rationale. If you get stuck on a task, refer to the relevant model answer file — but try to build it yourself first.
