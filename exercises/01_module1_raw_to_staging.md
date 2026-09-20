# Module 1: RAW to STAGING

## Objective

Create 4 staging tables in `TASTYBYTES_REFINED.STAGING` and build a pipeline to load data from the RAW layer. You will fix data quality issues, flatten JSON, apply governance tags, create load procedures, and orchestrate them with a task graph.

---

## Standards and Conventions

Follow these standards for all objects you create in this module.

### Naming
- **Table prefix:** `STG_` (e.g., `STG_MENU`)
- **Procedure prefix:** `SP_LOAD_` (e.g., `SP_LOAD_STG_MENU`)
- **Task prefix:** `TASK_LOAD_` (e.g., `TASK_LOAD_STG_MENU`), root task: `TASK_STG_ROOT`
- **All names:** UPPERCASE with underscores

### Metadata Columns
Every staging table must include these columns at the end:

| Column | Type | Value |
|--------|------|-------|
| `_LOAD_TS` | TIMESTAMP_NTZ | `CURRENT_TIMESTAMP()` — when the row was loaded |
| `_SOURCE_TABLE` | VARCHAR(100) | Name of the RAW source table (e.g., `'MENU'`) |

### Data Quality Rules
- All `VARCHAR` columns: apply `TRIM()` to strip leading/trailing whitespace
- Preserve NULLs — do not replace them with default values unless explicitly stated
- Fix data type mismatches using `TRY_CAST()` or `CAST()` as appropriate

### Role and Warehouse
```sql
USE ROLE TB_DATA_ENGINEER;
USE WAREHOUSE TB_DE_WH;
USE SCHEMA TASTYBYTES_REFINED.STAGING;
```
For governance tasks (applying tags), switch to:
```sql
USE ROLE TB_ADMIN;
```

---

## Task 1.1: Explore RAW Tables

Before building anything, explore the source data to understand the structure and identify data quality issues.

**Instructions:**
1. Run `DESCRIBE TABLE` on each of these RAW tables:
   - `TASTYBYTES_RAW.RAW.MENU`
   - `TASTYBYTES_RAW.RAW.ORDER_HEADER`
   - `TASTYBYTES_RAW.RAW.ORDER_DETAIL`
   - `TASTYBYTES_RAW.RAW.CUSTOMER_LOYALTY`

2. Run sample queries (`SELECT * ... LIMIT 100`) to inspect the data

3. Identify the data quality issues. Look for:
   - Columns where the data type doesn't match the actual content (e.g., numbers stored as TEXT)
   - FLOAT columns that should be INTEGER/NUMBER
   - Timestamps stored as TEXT
   - Semi-structured data (VARIANT columns)

**Expected findings:**

| Table | Column | Issue |
|-------|--------|-------|
| ORDER_HEADER | LOCATION_ID | Stored as FLOAT, should be NUMBER |
| ORDER_HEADER | SERVED_TS | Stored as TEXT, should be TIMESTAMP_NTZ |
| ORDER_HEADER | ORDER_TAX_AMOUNT | Stored as TEXT, should be NUMBER |
| ORDER_HEADER | ORDER_DISCOUNT_AMOUNT | Stored as TEXT, should be NUMBER |
| ORDER_DETAIL | ORDER_ITEM_DISCOUNT_AMOUNT | Stored as TEXT, should be NUMBER |
| CUSTOMER_LOYALTY | CHILDREN_COUNT | Stored as TEXT, should be NUMBER |
| MENU | MENU_ITEM_HEALTH_METRICS_OBJ | VARIANT — JSON that needs to be flattened |

---

## Task 1.2: Create STG_MENU Table

Create a staging table for menu data that flattens the JSON health metrics into individual columns.

**DDL Requirements:**

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| MENU_ID | NUMBER | MENU.MENU_ID | |
| MENU_TYPE_ID | NUMBER | MENU.MENU_TYPE_ID | |
| MENU_TYPE | VARCHAR | MENU.MENU_TYPE | TRIM |
| TRUCK_BRAND_NAME | VARCHAR | MENU.TRUCK_BRAND_NAME | TRIM |
| MENU_ITEM_ID | NUMBER | MENU.MENU_ITEM_ID | |
| MENU_ITEM_NAME | VARCHAR | MENU.MENU_ITEM_NAME | TRIM |
| ITEM_CATEGORY | VARCHAR | MENU.ITEM_CATEGORY | TRIM |
| ITEM_SUBCATEGORY | VARCHAR | MENU.ITEM_SUBCATEGORY | TRIM |
| COST_OF_GOODS_USD | NUMBER(10,2) | MENU.COST_OF_GOODS_USD | |
| SALE_PRICE_USD | NUMBER(10,2) | MENU.SALE_PRICE_USD | |
| IS_DAIRY_FREE_FLAG | BOOLEAN | JSON field | From `MENU_ITEM_HEALTH_METRICS_OBJ` |
| IS_GLUTEN_FREE_FLAG | BOOLEAN | JSON field | From `MENU_ITEM_HEALTH_METRICS_OBJ` |
| IS_HEALTHY_FLAG | BOOLEAN | JSON field | From `MENU_ITEM_HEALTH_METRICS_OBJ` |
| IS_NUT_FREE_FLAG | BOOLEAN | JSON field | From `MENU_ITEM_HEALTH_METRICS_OBJ` |
| INGREDIENTS | VARCHAR | JSON field | From `MENU_ITEM_HEALTH_METRICS_OBJ`, array joined as comma-separated string |
| _LOAD_TS | TIMESTAMP_NTZ | Metadata | `CURRENT_TIMESTAMP()` |
| _SOURCE_TABLE | VARCHAR(100) | Metadata | `'MENU'` |

**JSON Flattening Hint:**

The `MENU_ITEM_HEALTH_METRICS_OBJ` column contains this structure:
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

To extract fields, use Snowflake's semi-structured data syntax:
```sql
MENU_ITEM_HEALTH_METRICS_OBJ:menu_item_health_metrics[0].is_dairy_free_flag::VARCHAR
```

To convert `'Y'`/`'N'` to BOOLEAN:
```sql
IFF(value::VARCHAR = 'Y', TRUE, FALSE)
```

To convert the ingredients array to a comma-separated string:
```sql
ARRAY_TO_STRING(MENU_ITEM_HEALTH_METRICS_OBJ:menu_item_health_metrics[0].ingredients, ', ')
```

**Validation:**
```sql
SELECT COUNT(*) FROM TASTYBYTES_REFINED.STAGING.STG_MENU;
-- Expected: 100 rows
```

---

## Task 1.3: Create STG_ORDER_HEADER Table

Create a staging table for order headers, fixing all data type issues.

**DDL Requirements:**

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| ORDER_ID | NUMBER | ORDER_HEADER.ORDER_ID | |
| TRUCK_ID | NUMBER | ORDER_HEADER.TRUCK_ID | |
| LOCATION_ID | NUMBER | ORDER_HEADER.LOCATION_ID | **Cast from FLOAT to NUMBER** |
| CUSTOMER_ID | NUMBER | ORDER_HEADER.CUSTOMER_ID | |
| DISCOUNT_ID | VARCHAR | ORDER_HEADER.DISCOUNT_ID | TRIM |
| SHIFT_ID | NUMBER | ORDER_HEADER.SHIFT_ID | |
| SHIFT_START_TIME | TIME | ORDER_HEADER.SHIFT_START_TIME | |
| SHIFT_END_TIME | TIME | ORDER_HEADER.SHIFT_END_TIME | |
| ORDER_CHANNEL | VARCHAR | ORDER_HEADER.ORDER_CHANNEL | TRIM |
| ORDER_TS | TIMESTAMP_NTZ | ORDER_HEADER.ORDER_TS | |
| SERVED_TS | TIMESTAMP_NTZ | ORDER_HEADER.SERVED_TS | **Cast from TEXT to TIMESTAMP_NTZ** |
| ORDER_CURRENCY | VARCHAR | ORDER_HEADER.ORDER_CURRENCY | TRIM |
| ORDER_AMOUNT | NUMBER(10,2) | ORDER_HEADER.ORDER_AMOUNT | |
| ORDER_TAX_AMOUNT | NUMBER(10,2) | ORDER_HEADER.ORDER_TAX_AMOUNT | **Cast from TEXT to NUMBER** |
| ORDER_DISCOUNT_AMOUNT | NUMBER(10,2) | ORDER_HEADER.ORDER_DISCOUNT_AMOUNT | **Cast from TEXT to NUMBER** |
| ORDER_TOTAL | NUMBER(10,2) | ORDER_HEADER.ORDER_TOTAL | |
| _LOAD_TS | TIMESTAMP_NTZ | Metadata | |
| _SOURCE_TABLE | VARCHAR(100) | Metadata | `'ORDER_HEADER'` |

**Hint:** Use `TRY_CAST()` when converting TEXT to NUMBER or TIMESTAMP to gracefully handle malformed values (returns NULL instead of erroring).

**Validation:**
```sql
-- Row count
SELECT COUNT(*) FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER;

-- Verify LOCATION_ID is now NUMBER (no decimal places)
SELECT LOCATION_ID, TYPEOF(LOCATION_ID) FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER LIMIT 5;

-- Check no unexpected NULLs were introduced by type casting
SELECT COUNT(*) AS null_location_ids
FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER
WHERE LOCATION_ID IS NULL
  AND ORDER_ID IN (SELECT ORDER_ID FROM TASTYBYTES_RAW.RAW.ORDER_HEADER WHERE LOCATION_ID IS NOT NULL);
-- Expected: 0
```

---

## Task 1.4: Create STG_ORDER_DETAIL Table

Create a staging table for order line items.

**DDL Requirements:**

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| ORDER_DETAIL_ID | NUMBER | ORDER_DETAIL.ORDER_DETAIL_ID | |
| ORDER_ID | NUMBER | ORDER_DETAIL.ORDER_ID | |
| MENU_ITEM_ID | NUMBER | ORDER_DETAIL.MENU_ITEM_ID | |
| DISCOUNT_ID | VARCHAR | ORDER_DETAIL.DISCOUNT_ID | TRIM |
| LINE_NUMBER | NUMBER | ORDER_DETAIL.LINE_NUMBER | |
| QUANTITY | NUMBER | ORDER_DETAIL.QUANTITY | |
| UNIT_PRICE | NUMBER(10,2) | ORDER_DETAIL.UNIT_PRICE | |
| PRICE | NUMBER(10,2) | ORDER_DETAIL.PRICE | |
| ORDER_ITEM_DISCOUNT_AMOUNT | NUMBER(10,2) | ORDER_DETAIL.ORDER_ITEM_DISCOUNT_AMOUNT | **Cast from TEXT to NUMBER** |
| _LOAD_TS | TIMESTAMP_NTZ | Metadata | |
| _SOURCE_TABLE | VARCHAR(100) | Metadata | `'ORDER_DETAIL'` |

**Validation:**
```sql
SELECT COUNT(*) FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL;
```

---

## Task 1.5: Create STG_CUSTOMER_LOYALTY Table

Create a staging table for customer loyalty data. This table contains PII columns that will need masking in Task 1.6.

**DDL Requirements:**

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| CUSTOMER_ID | NUMBER | CUSTOMER_LOYALTY.CUSTOMER_ID | |
| FIRST_NAME | VARCHAR | CUSTOMER_LOYALTY.FIRST_NAME | TRIM — **PII** |
| LAST_NAME | VARCHAR | CUSTOMER_LOYALTY.LAST_NAME | TRIM — **PII** |
| CITY | VARCHAR | CUSTOMER_LOYALTY.CITY | TRIM |
| COUNTRY | VARCHAR | CUSTOMER_LOYALTY.COUNTRY | TRIM |
| POSTAL_CODE | VARCHAR | CUSTOMER_LOYALTY.POSTAL_CODE | TRIM |
| PREFERRED_LANGUAGE | VARCHAR | CUSTOMER_LOYALTY.PREFERRED_LANGUAGE | TRIM |
| GENDER | VARCHAR | CUSTOMER_LOYALTY.GENDER | TRIM |
| FAVOURITE_BRAND | VARCHAR | CUSTOMER_LOYALTY.FAVOURITE_BRAND | TRIM |
| MARITAL_STATUS | VARCHAR | CUSTOMER_LOYALTY.MARITAL_STATUS | TRIM |
| CHILDREN_COUNT | NUMBER | CUSTOMER_LOYALTY.CHILDREN_COUNT | **Cast from TEXT to NUMBER** |
| SIGN_UP_DATE | DATE | CUSTOMER_LOYALTY.SIGN_UP_DATE | |
| BIRTHDAY_DATE | DATE | CUSTOMER_LOYALTY.BIRTHDAY_DATE | **PII** |
| E_MAIL | VARCHAR | CUSTOMER_LOYALTY.E_MAIL | TRIM — **PII** |
| PHONE_NUMBER | VARCHAR | CUSTOMER_LOYALTY.PHONE_NUMBER | TRIM — **PII** |
| _LOAD_TS | TIMESTAMP_NTZ | Metadata | |
| _SOURCE_TABLE | VARCHAR(100) | Metadata | `'CUSTOMER_LOYALTY'` |

**Validation:**
```sql
SELECT COUNT(*) FROM TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY;
-- Expected: 222,540 rows
```

---

## Task 1.6: Apply Governance Tags and Comments

Apply enterprise tags and comments to all 4 staging tables. You will need to switch to the `TB_ADMIN` role for this task.

```sql
USE ROLE TB_ADMIN;
```

### Table-Level Tags

Apply these tags to each staging table:

| Table | DATA_DOMAIN | DATA_CLASSIFICATION | COST_CENTER |
|-------|-------------|--------------------| ------------|
| STG_MENU | `'Product'` | `'Internal'` | `'TASTYBYTES'` |
| STG_ORDER_HEADER | `'Sales'` | `'Internal'` | `'TASTYBYTES'` |
| STG_ORDER_DETAIL | `'Sales'` | `'Internal'` | `'TASTYBYTES'` |
| STG_CUSTOMER_LOYALTY | `'Customer'` | `'Restricted'` | `'TASTYBYTES'` |

**Syntax:**
```sql
ALTER TABLE TASTYBYTES_REFINED.STAGING.STG_MENU
  SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_DOMAIN = 'Product',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_CLASSIFICATION = 'Internal',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.COST_CENTER = 'TASTYBYTES';
```

### PII Column Tags (STG_CUSTOMER_LOYALTY only)

Apply the `TASTY_PII` tag to these columns. This automatically activates the pre-created tag-based masking policies.

| Column | Tag Value |
|--------|-----------|
| FIRST_NAME | `'NAME'` |
| LAST_NAME | `'NAME'` |
| E_MAIL | `'EMAIL'` |
| PHONE_NUMBER | `'PHONE_NUMBER'` |
| BIRTHDAY_DATE | `'BIRTHDAY'` |

**Syntax:**
```sql
ALTER TABLE TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY
  ALTER COLUMN FIRST_NAME SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII = 'NAME';
```

### Table and Column Comments

Add a `COMMENT` to every table and every column **inline in the CREATE TABLE statement** (Tasks 1.2-1.5). Table comments should describe the table's purpose. Column comments should describe the column's content.

**Syntax:**
```sql
CREATE OR REPLACE TABLE STG_MENU (
    MENU_ITEM_ID NUMBER COMMENT 'Unique identifier for the menu item',
    MENU_ITEM_NAME VARCHAR COMMENT 'Display name of the menu item',
    -- ... remaining columns with COMMENT ...
    _LOAD_TS TIMESTAMP_NTZ COMMENT 'Timestamp when the row was loaded into staging'
) COMMENT = 'Staged menu items with flattened health metrics. Source: TASTYBYTES_RAW.RAW.MENU';
```

**Note:** Define comments when you create the table, not as separate `COMMENT ON` statements afterwards. The `COMMENT` keyword goes after the column type, and `COMMENT =` goes after the closing parenthesis for the table-level comment.

### Validate Masking

Switch to `TB_ANALYST` and verify PII is masked:
```sql
USE ROLE TB_ANALYST;
SELECT FIRST_NAME, LAST_NAME, E_MAIL, PHONE_NUMBER, BIRTHDAY_DATE
FROM TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY
LIMIT 5;
-- Expected: All values show '**MASKED**' or '1900-01-01'
```

Switch back when done:
```sql
USE ROLE TB_DATA_ENGINEER;
```

---

## Task 1.7: Define GRANTS

Grant appropriate access on all staging objects to `TB_DATA_ENGINEER`. Run these as `TB_ADMIN` or the role that owns the objects.

```sql
-- Grant usage on the schema (if not already granted by setup)
GRANT USAGE ON SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE TB_DATA_ENGINEER;

-- Grant ownership or all privileges on each staging table
GRANT ALL ON TABLE TASTYBYTES_REFINED.STAGING.STG_MENU TO ROLE TB_DATA_ENGINEER;
GRANT ALL ON TABLE TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER TO ROLE TB_DATA_ENGINEER;
GRANT ALL ON TABLE TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL TO ROLE TB_DATA_ENGINEER;
GRANT ALL ON TABLE TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY TO ROLE TB_DATA_ENGINEER;
```

**Note:** `TB_ANALYST` should NOT have access to staging tables. Do not grant any privileges to `TB_ANALYST` on this schema.

---

## Task 1.8: Create Load Procedures

Create one stored procedure per staging table using the TRUNCATE-reload pattern.

**Requirements:**
- Language: `LANGUAGE SQL`
- Execute as: `EXECUTE AS CALLER`
- Naming: `SP_LOAD_STG_MENU`, `SP_LOAD_STG_ORDER_HEADER`, `SP_LOAD_STG_ORDER_DETAIL`, `SP_LOAD_STG_CUSTOMER_LOYALTY`
- Schema: `TASTYBYTES_REFINED.STAGING`
- Return: A status message (VARCHAR) indicating success and row count

**Pattern:**
```sql
CREATE OR REPLACE PROCEDURE TASTYBYTES_REFINED.STAGING.SP_LOAD_STG_MENU()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
BEGIN
  TRUNCATE TABLE TASTYBYTES_REFINED.STAGING.STG_MENU;

  INSERT INTO TASTYBYTES_REFINED.STAGING.STG_MENU (
    -- column list
  )
  SELECT
    -- source columns with TRIM, CAST, JSON extraction, metadata
  FROM TASTYBYTES_RAW.RAW.MENU;

  RETURN 'SP_LOAD_STG_MENU completed. Rows loaded: ' || SQLROWCOUNT;
END;
```

**Important:** The INSERT...SELECT in each procedure must include all the data quality fixes (type casts, TRIM, JSON flattening) that you designed in Tasks 1.2–1.5.

**Validation:**
```sql
CALL TASTYBYTES_REFINED.STAGING.SP_LOAD_STG_MENU();
-- Expected: 'SP_LOAD_STG_MENU completed. Rows loaded: 100'
```

---

## Task 1.9: Create Task Graph

Create a task graph to orchestrate the staging load procedures.

**Task Graph Structure:**
```
TASK_STG_ROOT (root — scheduled or manual trigger)
  ├── TASK_LOAD_STG_MENU (runs after root)
  ├── TASK_LOAD_STG_ORDER_HEADER (runs after root)
  ├── TASK_LOAD_STG_ORDER_DETAIL (runs after TASK_LOAD_STG_ORDER_HEADER)
  └── TASK_LOAD_STG_CUSTOMER_LOYALTY (runs after root)
```

**Requirements:**
- All tasks in schema `TASTYBYTES_REFINED.STAGING`
- Warehouse: `TB_DE_WH`
- Root task schedule: no automatic schedule (manual execution only for this exercise)
- `TASK_LOAD_STG_ORDER_DETAIL` depends on `TASK_LOAD_STG_ORDER_HEADER` completing first

**Syntax for root task:**
```sql
CREATE OR REPLACE TASK TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT
  WAREHOUSE = TB_DE_WH
  SCHEDULE = 'USING CRON 0 0 31 2 * UTC'  -- Never auto-runs (Feb 31 doesn't exist)
AS
  SELECT 1;  -- No-op root task
```

**Syntax for child task:**
```sql
CREATE OR REPLACE TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_MENU
  WAREHOUSE = TB_DE_WH
  AFTER TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT
AS
  CALL TASTYBYTES_REFINED.STAGING.SP_LOAD_STG_MENU();
```

**Resume all tasks** (tasks are created in suspended state):
```sql
ALTER TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_MENU RESUME;
ALTER TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_ORDER_HEADER RESUME;
ALTER TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_ORDER_DETAIL RESUME;
ALTER TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_CUSTOMER_LOYALTY RESUME;
ALTER TASK TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT RESUME;
```

**Important:** Resume child tasks BEFORE the root task.

---

## Task 1.10: Execute and Validate

Execute the task graph and verify all data loaded correctly.

**Execute:**
```sql
EXECUTE TASK TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT;
```

**Monitor progress:**
```sql
-- Check task run status (wait a minute for tasks to complete)
SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME, ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  TASK_NAME => 'TASK_STG_ROOT',
  SCHEDULED_TIME_RANGE_START => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;
```

**Validation queries:**

```sql
-- 1. Row counts
SELECT 'STG_MENU' AS table_name, COUNT(*) AS row_count FROM TASTYBYTES_REFINED.STAGING.STG_MENU
UNION ALL
SELECT 'STG_ORDER_HEADER', COUNT(*) FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER
UNION ALL
SELECT 'STG_ORDER_DETAIL', COUNT(*) FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL
UNION ALL
SELECT 'STG_CUSTOMER_LOYALTY', COUNT(*) FROM TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY;

-- 2. Verify data types are correct
SELECT COLUMN_NAME, DATA_TYPE
FROM TASTYBYTES_REFINED.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'STAGING' AND TABLE_NAME = 'STG_ORDER_HEADER'
ORDER BY ORDINAL_POSITION;

-- 3. Verify no unexpected NULLs from type casting
SELECT COUNT(*) AS bad_casts
FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER
WHERE SERVED_TS IS NULL
  AND ORDER_ID IN (
    SELECT ORDER_ID FROM TASTYBYTES_RAW.RAW.ORDER_HEADER WHERE SERVED_TS IS NOT NULL
  );
-- Expected: 0

-- 4. Verify JSON was flattened correctly
SELECT MENU_ITEM_NAME, IS_DAIRY_FREE_FLAG, IS_GLUTEN_FREE_FLAG, INGREDIENTS
FROM TASTYBYTES_REFINED.STAGING.STG_MENU
LIMIT 5;
```

---

## Checkpoint

Before moving to Module 2, verify:

- [ ] All 4 staging tables exist with correct column types
- [ ] All tables have DATA_DOMAIN, DATA_CLASSIFICATION, and COST_CENTER tags
- [ ] STG_CUSTOMER_LOYALTY PII columns are tagged and masked for TB_ANALYST
- [ ] All tables have table-level and column-level COMMENTs
- [ ] All 4 load procedures exist and execute successfully
- [ ] Task graph runs end-to-end without errors
- [ ] Row counts match expected values
