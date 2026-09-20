# Data Engineering Training Exercise — Design Brief

## 1. Purpose

This design brief provides the detailed specification needed to build a hands-on Snowflake data engineering training exercise. It resolves all design decisions from the initial brief and provides the exercise designer with unambiguous inputs for creating setup scripts, exercise instructions, and model answers.

---

## 2. Training Exercise Objectives

Allow learners to build an end-to-end Snowflake data pipeline — from raw source tables through staging, dimensional model, and finally a reporting view — using Snowflake-native features including:

- DDL design with appropriate data types and constraints
- SQL stored procedures for data loading (TRUNCATE-reload and MERGE patterns)
- Task graphs for pipeline orchestration
- Enterprise tags and column-level masking policies for governance
- Table and column COMMENTs for catalog documentation

---

## 3. Target Audience

- **Experience level:** Data engineers with SQL and pipeline-building experience
- **Snowflake knowledge:** Basic — familiar with the UI and SQL worksheet, but not experienced with Snowflake-specific features (tasks, tags, masking policies, VARIANT data)
- **Account requirement:** Snowflake Enterprise Edition trial account (required for tag-based masking)

---

## 4. Business Scenario

> The business needs insight into **monthly sales volume, revenue, and margin of menu items and menu item categories**, broken down by location and time period.

**Key definitions:**
- **Sales volume** = total quantity of items sold
- **Revenue** = sum of line-item prices from ORDER_DETAIL.PRICE
- **COGS** = cost of goods, sourced from MENU.COST_OF_GOODS_USD multiplied by quantity
- **Margin** = Revenue − COGS (calculated at the order line item level, then aggregated)
- **Margin %** = (Margin / Revenue) × 100

---

## 5. Data Architecture

The data platform is Snowflake. All databases and schemas will be pre-created by the setup script. Learners do not create databases or schemas.

| Layer | Database.Schema | Purpose |
|-------|----------------|---------|
| **RAW** | `TASTYBYTES_RAW.RAW` | Source tables (read-only, pre-loaded) |
| **STAGING** | `TASTYBYTES_REFINED.STAGING` | Cleaned, typed staging tables with governance applied |
| **WAREHOUSE** | `TASTYBYTES_CONSUMPTION.WAREHOUSE` | Dimensional model (dimensions + facts) |
| **DATA PRODUCT** | `TASTYBYTES_CONSUMPTION.ANALYTICS` | Reporting views built from the warehouse layer |
| **GOVERNANCE** | `TASTYBYTES_GOVERNANCE.GOVERNANCE` | Tags, masking policies, and governance objects |

### 5.1 RAW Layer — Source Tables

The RAW layer contains 9 source tables. **The setup script will load 1 year of data (2022) into the transactional tables** to keep exercise runtimes manageable on trial-account XS warehouses.

| Table | Rows (approx, 2022 subset) | Description |
|-------|----------------------------|-------------|
| COUNTRY | 30 | Geographic reference: countries and cities |
| CUSTOMER_LOYALTY | 222,540 | Loyalty program members with demographics and PII |
| FRANCHISE | 335 | Franchise owner contact details |
| LOCATION | 13,093 | Physical food truck locations |
| MENU | 100 | Menu items with pricing, categories, and JSON health metrics |
| ORDER_HEADER | ~64M (2022) | Order transactions with truck, customer, location, and totals |
| ORDER_DETAIL | ~173M (2022) | Line items within orders: menu item, quantity, price |
| TRUCK | 450 | Food truck fleet details |
| TRUCK_REVIEWS | 1,016 | Customer reviews (multiple languages) |

### 5.2 Known Data Quality Issues in RAW

These are **intentional** — learners must discover and handle them during staging:

| Table | Column | Issue | Expected Handling |
|-------|--------|-------|-------------------|
| COUNTRY | CITY_POPULATION | TEXT instead of NUMBER | CAST to NUMBER, handle non-numeric values |
| CUSTOMER_LOYALTY | CHILDREN_COUNT | TEXT instead of NUMBER | CAST to NUMBER |
| ORDER_HEADER | LOCATION_ID | FLOAT instead of NUMBER | CAST to NUMBER for joins |
| ORDER_HEADER | SERVED_TS | TEXT instead of TIMESTAMP | CAST to TIMESTAMP_NTZ |
| ORDER_HEADER | ORDER_TAX_AMOUNT | TEXT instead of NUMBER | CAST to NUMBER |
| ORDER_HEADER | ORDER_DISCOUNT_AMOUNT | TEXT instead of NUMBER | CAST to NUMBER |
| ORDER_DETAIL | ORDER_ITEM_DISCOUNT_AMOUNT | TEXT instead of NUMBER | CAST to NUMBER |
| MENU | MENU_ITEM_HEALTH_METRICS_OBJ | VARIANT (JSON) | Flatten to columns (see §5.3) |

### 5.3 JSON Structure — MENU_ITEM_HEALTH_METRICS_OBJ

The VARIANT column contains this structure:

```json
{
  "menu_item_health_metrics": [
    {
      "ingredients": ["Lemons", "Sugar", "Water"],
      "is_dairy_free_flag": "Y",
      "is_gluten_free_flag": "Y",
      "is_healthy_flag": "N",
      "is_nut_free_flag": "Y"
    }
  ],
  "menu_item_id": 10
}
```

Learners should flatten this into individual columns in the MENU staging table:
- `IS_DAIRY_FREE_FLAG` (BOOLEAN)
- `IS_GLUTEN_FREE_FLAG` (BOOLEAN)
- `IS_HEALTHY_FLAG` (BOOLEAN)
- `IS_NUT_FREE_FLAG` (BOOLEAN)
- `INGREDIENTS` (ARRAY or VARCHAR — designer's choice)

---

## 6. Tables in Scope

### 6.1 Learner-Built Objects

Learners create and load these objects during the exercise:

**STAGING layer** (in `TASTYBYTES_REFINED.STAGING`):
| Staging Table | Source RAW Table | Key Activities |
|---------------|-----------------|----------------|
| STG_MENU | MENU | Flatten JSON, type conversion, add metadata columns |
| STG_ORDER_HEADER | ORDER_HEADER | Fix TEXT→NUMBER/TIMESTAMP casts, add metadata columns |
| STG_ORDER_DETAIL | ORDER_DETAIL | Fix TEXT→NUMBER cast, add metadata columns |
| STG_CUSTOMER_LOYALTY | CUSTOMER_LOYALTY | Fix TEXT→NUMBER cast, PII tagging and masking |

**WAREHOUSE layer** (in `TASTYBYTES_CONSUMPTION.WAREHOUSE`):
| Warehouse Table | Source Staging Table(s) | SCD Type | Notes |
|----------------|----------------------|----------|-------|
| DIM_MENU | STG_MENU | **SCD Type 2** | Track price changes over time. Includes surrogate key, valid_from, valid_to, is_current flag |
| DIM_CUSTOMER | STG_CUSTOMER_LOYALTY | SCD Type 1 | Overwrite on change. Surrogate key. |
| FACT_ORDER_LINE | STG_ORDER_HEADER + STG_ORDER_DETAIL + DIM_MENU + DIM_CUSTOMER + DIM_LOCATION + DIM_DATE | — | Grain: one row per order line item. Surrogate keys to all dimensions. |

**DATA PRODUCT layer** (in `TASTYBYTES_CONSUMPTION.ANALYTICS`):
| Object | Type | Description |
|--------|------|-------------|
| RPT_MONTHLY_MENU_SALES | VIEW | Monthly sales KPIs by menu item and location (see §8) |

### 6.2 Pre-Created Objects (Setup Script)

These objects exist before learners start. They are provided as reference examples and to keep the exercise focused.

**STAGING layer** (pre-populated with data):
| Table | Purpose |
|-------|---------|
| STG_LOCATION | Cleaned location reference data (from LOCATION + COUNTRY) |
| STG_COUNTRY | Cleaned country reference data |

**WAREHOUSE layer** (pre-populated with data):
| Table | Purpose |
|-------|---------|
| DIM_LOCATION | Location dimension built from STG_LOCATION + STG_COUNTRY |
| DIM_DATE | Standard date dimension covering 2019–2025 (generated, not from RAW) |

**Note:** Load procedures and tasks are NOT pre-created for the pre-populated tables. Only the DDL and data are provided. Learners can reference the DDL of pre-populated tables as examples.

---

## 7. Governance Specification

### 7.1 Enterprise Tags

Pre-created in `TASTYBYTES_GOVERNANCE.GOVERNANCE` by the setup script:

| Tag Name | Allowed Values | Apply To | Purpose |
|----------|---------------|----------|---------|
| TASTY_PII | NAME, PHONE_NUMBER, EMAIL, BIRTHDAY | Columns containing PII | Triggers tag-based masking policies |
| DATA_DOMAIN | Sales, Customer, Product | Tables | Business domain classification |
| DATA_CLASSIFICATION | Public, Internal, Restricted | Tables | Data sensitivity level |
| COST_CENTER | (free-form) | Tables | Cost attribution |

### 7.2 Masking Policies

Pre-created in `TASTYBYTES_GOVERNANCE.GOVERNANCE` by the setup script:

| Policy Name | Data Type | Behaviour | Triggered By |
|-------------|-----------|-----------|-------------|
| TASTY_PII_STRING_MASK | VARCHAR | Returns `'**MASKED**'` for non-privileged roles; full value for TB_ADMIN and TB_DATA_ENGINEER | Tag: TASTY_PII = 'NAME', 'PHONE_NUMBER', 'EMAIL' |
| TASTY_PII_DATE_MASK | DATE | Returns `'1900-01-01'` for non-privileged roles; full value for TB_ADMIN and TB_DATA_ENGINEER | Tag: TASTY_PII = 'BIRTHDAY' |

Masking is tag-based: learners apply the TASTY_PII tag to PII columns, and the masking policy is automatically enforced.

### 7.3 PII Columns to Tag

| Staging Table | Column | Tag Value |
|---------------|--------|-----------|
| STG_CUSTOMER_LOYALTY | FIRST_NAME | TASTY_PII = 'NAME' |
| STG_CUSTOMER_LOYALTY | LAST_NAME | TASTY_PII = 'NAME' |
| STG_CUSTOMER_LOYALTY | E_MAIL | TASTY_PII = 'EMAIL' |
| STG_CUSTOMER_LOYALTY | PHONE_NUMBER | TASTY_PII = 'PHONE_NUMBER' |
| STG_CUSTOMER_LOYALTY | BIRTHDAY_DATE | TASTY_PII = 'BIRTHDAY' |

### 7.4 Table-Level Tags and Comments

Every learner-created table must have:
1. A `DATA_DOMAIN` tag (e.g., STG_MENU → 'Product', STG_ORDER_HEADER → 'Sales', STG_CUSTOMER_LOYALTY → 'Customer')
2. A `DATA_CLASSIFICATION` tag (e.g., tables with PII → 'Restricted', others → 'Internal')
3. A `COST_CENTER` tag value of `'TASTYBYTES'`
4. A table-level COMMENT describing the table's purpose
5. Column-level COMMENTs on all columns

---

## 8. Reporting View Specification

**View name:** `TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES`

**Grain:** One row per calendar month, per menu item, per city

**Source tables:** FACT_ORDER_LINE joined to DIM_MENU, DIM_DATE, DIM_LOCATION

| Column | Source | Description |
|--------|--------|-------------|
| YEAR | DIM_DATE | Calendar year |
| QUARTER | DIM_DATE | Calendar quarter (Q1–Q4) |
| MONTH_NAME | DIM_DATE | Month name (January–December) |
| MONTH_START_DATE | DIM_DATE | First day of the month |
| CITY | DIM_LOCATION | City name |
| COUNTRY | DIM_LOCATION | Country name |
| MENU_ITEM_NAME | DIM_MENU | Menu item display name |
| ITEM_CATEGORY | DIM_MENU | High-level category (Main, Dessert, Beverage) |
| ITEM_SUBCATEGORY | DIM_MENU | Granular subcategory |
| TRUCK_BRAND_NAME | DIM_MENU | Food truck brand |
| TOTAL_QUANTITY_SOLD | FACT_ORDER_LINE | SUM(quantity) |
| TOTAL_REVENUE | FACT_ORDER_LINE | SUM(line_price) |
| TOTAL_COGS | FACT_ORDER_LINE | SUM(cogs_amount) — derived from DIM_MENU.COST_OF_GOODS_USD × quantity |
| TOTAL_MARGIN | Calculated | TOTAL_REVENUE − TOTAL_COGS |
| MARGIN_PCT | Calculated | (TOTAL_MARGIN / NULLIF(TOTAL_REVENUE, 0)) × 100 |

---

## 9. RBAC Model

### 9.1 Roles

Pre-created by the setup script:

| Role | Purpose | Key Privileges |
|------|---------|---------------|
| TB_ADMIN | Governance and administration | Owns TASTYBYTES_GOVERNANCE database. Can see unmasked PII. APPLY TAG, APPLY MASKING POLICY privileges. |
| TB_DATA_ENGINEER | Pipeline development and execution | CREATE TABLE, CREATE PROCEDURE, CREATE TASK, EXECUTE TASK on TASTYBYTES_REFINED and TASTYBYTES_CONSUMPTION. Can see unmasked PII. Owns warehouse usage. |
| TB_ANALYST | Consume reporting views | SELECT on TASTYBYTES_CONSUMPTION.ANALYTICS. PII is masked. |

### 9.2 Grants Learners Must Define

For every object learners create, they must grant appropriate access:

| Object Type | Grant To TB_DATA_ENGINEER | Grant To TB_ANALYST |
|-------------|--------------------------|---------------------|
| Staging tables | ALL (ownership) | — (no access) |
| Warehouse tables | ALL (ownership) | SELECT |
| Reporting views | ALL (ownership) | SELECT |
| Stored procedures | ALL (ownership) | — |
| Tasks | ALL (ownership) | — |

---

## 10. Pipeline Orchestration

### 10.1 Stored Procedure Patterns

**STAGING procedures** — TRUNCATE and reload:
```
TRUNCATE target staging table
INSERT INTO target
SELECT (with type casts, null handling, whitespace trimming, JSON flattening)
FROM RAW source
```

**WAREHOUSE procedures** — MERGE:
- **SCD Type 1 (DIM_CUSTOMER):** MERGE on natural key. UPDATE changed columns, INSERT new rows, soft-delete removed rows (IS_DELETED flag).
- **SCD Type 2 (DIM_MENU):** MERGE on natural key + IS_CURRENT. When a tracked attribute changes: close the current record (set VALID_TO, IS_CURRENT = FALSE), INSERT a new current record. INSERT brand-new items.
- **FACT_ORDER_LINE:** MERGE on natural key (ORDER_DETAIL_ID). INSERT new rows, handle late-arriving facts.

### 10.2 Task Graphs

**Module 1 — RAW to STAGING:**
A root task triggers the staging load procedures. Dependencies:
```
TASK_ROOT (schedule: manual / CRON for exercise)
  ├── TASK_LOAD_STG_MENU
  ├── TASK_LOAD_STG_ORDER_HEADER
  ├── TASK_LOAD_STG_ORDER_DETAIL (depends on TASK_LOAD_STG_ORDER_HEADER — same source)
  └── TASK_LOAD_STG_CUSTOMER_LOYALTY
```

**Module 2 — STAGING to WAREHOUSE:**
A separate task graph (or extension of Module 1) for the warehouse layer:
```
TASK_WH_ROOT (triggered after staging tasks complete, or separate schedule)
  ├── TASK_LOAD_DIM_MENU
  ├── TASK_LOAD_DIM_CUSTOMER
  └── TASK_LOAD_FACT_ORDER_LINE (depends on DIM_MENU and DIM_CUSTOMER completing)
```

### 10.3 Metadata Columns

Every staging table must include:

| Column | Type | Description |
|--------|------|-------------|
| _LOAD_TS | TIMESTAMP_NTZ | CURRENT_TIMESTAMP() at load time |
| _SOURCE_TABLE | VARCHAR | Name of the RAW source table |
| _LOAD_ID | VARCHAR | Unique identifier per load batch (optional: use task run ID or UUID) |

Every warehouse table must include:

| Column | Type | Description |
|--------|------|-------------|
| _DW_LOAD_TS | TIMESTAMP_NTZ | CURRENT_TIMESTAMP() at load time |
| _DW_UPDATE_TS | TIMESTAMP_NTZ | Last update timestamp |

SCD Type 2 tables (DIM_MENU) additionally include:

| Column | Type | Description |
|--------|------|-------------|
| VALID_FROM | TIMESTAMP_NTZ | Start of validity period |
| VALID_TO | TIMESTAMP_NTZ | End of validity period (NULL or '9999-12-31' for current) |
| IS_CURRENT | BOOLEAN | TRUE for the active record |

---

## 11. Exercise Structure

### 11.1 Setup Phase (Pre-Exercise)

Learners complete before starting modules:

1. **Create Snowflake trial account** — Enterprise Edition, using work email
2. **Run setup script** — Creates all databases, schemas, roles, warehouses, tags, masking policies, and pre-populated tables (STG_LOCATION, STG_COUNTRY, DIM_LOCATION, DIM_DATE)
3. **Run data load script** — Loads 2022 subset into RAW tables. Populates pre-created staging and warehouse tables.

### 11.2 Module 1: RAW to STAGING

**Objective:** Create staging tables and a pipeline to load data from RAW into STAGING.

**Learner tasks:**
1. Explore the RAW tables to understand structure, data types, and quality issues
2. Define DDL for 4 staging tables: STG_MENU, STG_ORDER_HEADER, STG_ORDER_DETAIL, STG_CUSTOMER_LOYALTY
   - Fix data type mismatches (TEXT → NUMBER, FLOAT → NUMBER, TEXT → TIMESTAMP)
   - Flatten VARIANT/JSON to columns (MENU health metrics)
   - Add metadata columns (_LOAD_TS, _SOURCE_TABLE)
   - Handle NULLs and whitespace (TRIM, COALESCE/NVL where appropriate)
3. Apply enterprise tags to each staging table (DATA_DOMAIN, DATA_CLASSIFICATION, COST_CENTER)
4. Apply TASTY_PII tags to PII columns on STG_CUSTOMER_LOYALTY
5. Add table and column COMMENTs
6. Define GRANTS to TB_DATA_ENGINEER
7. Create SQL stored procedures (one per staging table) using TRUNCATE-reload pattern
8. Create a Task graph to orchestrate the staging load procedures
9. Execute the task graph and validate data loaded correctly

### 11.3 Module 2: STAGING to WAREHOUSE

**Objective:** Create dimension and fact tables and load them from staging using MERGE procedures.

**Learner tasks:**
1. Define DDL for DIM_MENU (SCD Type 2), DIM_CUSTOMER (SCD Type 1), FACT_ORDER_LINE
   - Include surrogate keys (auto-increment or SEQUENCES)
   - Include metadata and SCD tracking columns
2. Apply enterprise tags and COMMENTs
3. Apply TASTY_PII tags to PII columns on DIM_CUSTOMER
4. Define GRANTS to TB_DATA_ENGINEER and TB_ANALYST (SELECT)
5. Create MERGE-based stored procedures:
   - DIM_MENU: SCD Type 2 MERGE (close expired records, insert new versions)
   - DIM_CUSTOMER: SCD Type 1 MERGE (update in place, insert new, soft-delete removed)
   - FACT_ORDER_LINE: MERGE on natural key with lookups to all dimension surrogate keys
6. Create a Task graph for the warehouse load procedures
7. Execute and validate dimension and fact data

### 11.4 Module 3: WAREHOUSE to DATA PRODUCT

**Objective:** Create a reporting view that answers the business question.

**Learner tasks:**
1. Create the `RPT_MONTHLY_MENU_SALES` view as specified in §8
2. Apply table-level tags and COMMENTs
3. Define GRANTS to TB_ANALYST (SELECT)
4. Validate the view returns expected results with sample queries:
   - Total revenue by month for 2022
   - Top 10 menu items by margin %
   - Revenue by item category and city

---

## 12. Validation Checkpoints

Each module should include validation queries learners run to confirm their work:

| Checkpoint | Module | Expected Result |
|------------|--------|-----------------|
| STG_MENU row count matches RAW.MENU | 1 | 100 rows |
| STG_ORDER_HEADER has no NULL LOCATION_IDs that were non-null in RAW | 1 | 0 unexpected NULLs |
| STG_CUSTOMER_LOYALTY PII columns are masked when queried as TB_ANALYST | 1 | All PII shows '**MASKED**' |
| DIM_MENU has IS_CURRENT = TRUE for exactly 100 rows (initial load) | 2 | 100 current rows |
| FACT_ORDER_LINE row count matches STG_ORDER_DETAIL | 2 | ~173M rows |
| FACT_ORDER_LINE has no NULL surrogate keys | 2 | 0 NULLs in SK columns |
| RPT_MONTHLY_MENU_SALES returns 12 months of data | 3 | 12 distinct months |
| Total revenue in the view ties back to SUM(PRICE) in STG_ORDER_DETAIL | 3 | Amounts match |

---

## 13. Warehouse Configuration

The setup script will create:

| Warehouse | Size | Purpose |
|-----------|------|---------|
| TB_DE_WH | X-SMALL | Used by TB_DATA_ENGINEER for pipeline execution and development |
| TB_ANALYST_WH | X-SMALL | Used by TB_ANALYST for querying reporting views |

Auto-suspend: 60 seconds. Auto-resume: enabled.

---

## 14. Assumptions and Constraints

1. All databases, schemas, roles, and warehouses are created by the setup script — learners do not create these
2. Tags and masking policies are created by the setup script — learners apply them, not create them
3. The RAW layer is read-only — learners never modify RAW tables
4. Data is static (one-time batch load) — no streaming or CDC in this exercise
5. All stored procedures use `LANGUAGE SQL` with `EXECUTE AS CALLER`
6. Trial account is Enterprise Edition (required for tag-based masking)
7. ORDER_HEADER and ORDER_DETAIL are filtered to 2022 data only in the RAW load
8. DIM_DATE is pre-generated covering 2019–2025 with standard calendar attributes (year, quarter, month, week, day, day_of_week, is_weekend, etc.)
