# Module 2: STAGING to WAREHOUSE

## Objective

Create 2 dimension tables and 1 fact table in `TASTYBYTES_CONSUMPTION.WAREHOUSE`. Build MERGE-based stored procedures to load data from staging, and orchestrate them with a task graph. You will implement SCD Type 2 for `DIM_MENU` (tracking price history) and SCD Type 1 for `DIM_CUSTOMER` (overwrite on change).

---

## Standards and Conventions

### Naming
- **Dimension prefix:** `DIM_` (e.g., `DIM_MENU`)
- **Fact prefix:** `FACT_` (e.g., `FACT_ORDER_LINE`)
- **Procedure prefix:** `SP_LOAD_` (e.g., `SP_LOAD_DIM_MENU`)
- **Task prefix:** `TASK_LOAD_` (e.g., `TASK_LOAD_DIM_MENU`), root task: `TASK_WH_ROOT`

### Surrogate Keys
- Column naming: `{TABLE_NAME}_SK` (e.g., `DIM_MENU_SK`)
- Generated using: `AUTOINCREMENT START 1 INCREMENT 1`

### Metadata Columns
Every warehouse table must include:

| Column | Type | Value |
|--------|------|-------|
| `_DW_LOAD_TS` | TIMESTAMP_NTZ | `CURRENT_TIMESTAMP()` — when the row was first loaded |
| `_DW_UPDATE_TS` | TIMESTAMP_NTZ | `CURRENT_TIMESTAMP()` — when the row was last updated |

### SCD Type 2 Additional Columns (DIM_MENU only)

| Column | Type | Description |
|--------|------|-------------|
| `VALID_FROM` | TIMESTAMP_NTZ | Start of the record's validity period |
| `VALID_TO` | TIMESTAMP_NTZ | End of validity. `'9999-12-31'` for current records |
| `IS_CURRENT` | BOOLEAN | `TRUE` for the active version of the record |

### SCD Type 1 Additional Columns (DIM_CUSTOMER only)

| Column | Type | Description |
|--------|------|-------------|
| `IS_DELETED` | BOOLEAN | `TRUE` if the source record has been removed. Default `FALSE` |

### Role and Warehouse
```sql
USE ROLE TB_DATA_ENGINEER;
USE WAREHOUSE TB_DE_WH;
USE SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE;
```

---

## Concept: SCD Type 1 vs Type 2

Before you start building, understand these two patterns:

**SCD Type 1 (Overwrite):** When a source attribute changes, the dimension record is updated in place. There is no history of previous values. Use this when historical tracking is not needed (e.g., a customer changes their city — we only care about the current city).

**SCD Type 2 (History Tracking):** When a tracked attribute changes, the current record is "closed" (VALID_TO set to the current timestamp, IS_CURRENT set to FALSE) and a new record is inserted with the updated values. This preserves the full history. Use this when you need to analyze data using the attribute values that were in effect at the time of a transaction (e.g., a menu item's price at the time it was sold).

---

## Task 2.1: Create DIM_MENU Table (SCD Type 2)

Create a dimension table for menu items that tracks changes over time.

**DDL Requirements:**

| Column | Type | Notes |
|--------|------|-------|
| DIM_MENU_SK | NUMBER AUTOINCREMENT | Surrogate key |
| MENU_ITEM_ID | NUMBER | Natural key (business key from source) |
| MENU_ID | NUMBER | |
| MENU_TYPE_ID | NUMBER | |
| MENU_TYPE | VARCHAR | |
| TRUCK_BRAND_NAME | VARCHAR | |
| MENU_ITEM_NAME | VARCHAR | **Tracked for SCD2** |
| ITEM_CATEGORY | VARCHAR | **Tracked for SCD2** |
| ITEM_SUBCATEGORY | VARCHAR | **Tracked for SCD2** |
| COST_OF_GOODS_USD | NUMBER(10,2) | **Tracked for SCD2** |
| SALE_PRICE_USD | NUMBER(10,2) | **Tracked for SCD2** |
| IS_DAIRY_FREE_FLAG | BOOLEAN | |
| IS_GLUTEN_FREE_FLAG | BOOLEAN | |
| IS_HEALTHY_FLAG | BOOLEAN | |
| IS_NUT_FREE_FLAG | BOOLEAN | |
| INGREDIENTS | VARCHAR | |
| VALID_FROM | TIMESTAMP_NTZ | SCD2: start of validity |
| VALID_TO | TIMESTAMP_NTZ | SCD2: end of validity (`'9999-12-31'` for current) |
| IS_CURRENT | BOOLEAN | SCD2: `TRUE` for active record |
| _DW_LOAD_TS | TIMESTAMP_NTZ | Metadata |
| _DW_UPDATE_TS | TIMESTAMP_NTZ | Metadata |

**Tracked columns** — these are the columns that trigger a new SCD2 version when they change:
`MENU_ITEM_NAME`, `ITEM_CATEGORY`, `ITEM_SUBCATEGORY`, `COST_OF_GOODS_USD`, `SALE_PRICE_USD`

**Validation:**
```sql
-- After initial load, expect 100 current records
SELECT COUNT(*) AS current_records
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU
WHERE IS_CURRENT = TRUE;
-- Expected: 100
```

---

## Task 2.2: Create DIM_CUSTOMER Table (SCD Type 1)

Create a dimension table for customers using the overwrite pattern.

**DDL Requirements:**

| Column | Type | Notes |
|--------|------|-------|
| DIM_CUSTOMER_SK | NUMBER AUTOINCREMENT | Surrogate key |
| CUSTOMER_ID | NUMBER | Natural key |
| FIRST_NAME | VARCHAR | **PII** |
| LAST_NAME | VARCHAR | **PII** |
| CITY | VARCHAR | |
| COUNTRY | VARCHAR | |
| POSTAL_CODE | VARCHAR | |
| PREFERRED_LANGUAGE | VARCHAR | |
| GENDER | VARCHAR | |
| FAVOURITE_BRAND | VARCHAR | |
| MARITAL_STATUS | VARCHAR | |
| CHILDREN_COUNT | NUMBER | |
| SIGN_UP_DATE | DATE | |
| BIRTHDAY_DATE | DATE | **PII** |
| E_MAIL | VARCHAR | **PII** |
| PHONE_NUMBER | VARCHAR | **PII** |
| IS_DELETED | BOOLEAN | Default FALSE. Set TRUE if removed from source. |
| _DW_LOAD_TS | TIMESTAMP_NTZ | Metadata |
| _DW_UPDATE_TS | TIMESTAMP_NTZ | Metadata |

**Validation:**
```sql
SELECT COUNT(*) FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER;
-- Expected: 222,540 rows
```

---

## Task 2.3: Create FACT_ORDER_LINE Table

Create a fact table at the order line item grain. Each row represents one line item from an order, linked to all relevant dimensions via surrogate keys.

**DDL Requirements:**

| Column | Type | Notes |
|--------|------|-------|
| ORDER_DETAIL_ID | NUMBER | Natural key (degenerate dimension) |
| ORDER_ID | NUMBER | Degenerate dimension |
| DIM_MENU_SK | NUMBER | FK to DIM_MENU (looked up at load time) |
| DIM_CUSTOMER_SK | NUMBER | FK to DIM_CUSTOMER |
| DIM_LOCATION_SK | NUMBER | FK to DIM_LOCATION (pre-created) |
| DIM_DATE_SK | NUMBER | FK to DIM_DATE (pre-created) |
| TRUCK_ID | NUMBER | Degenerate dimension |
| DISCOUNT_ID | VARCHAR | Degenerate dimension |
| ORDER_CHANNEL | VARCHAR | |
| LINE_NUMBER | NUMBER | |
| QUANTITY | NUMBER | Measure |
| UNIT_PRICE | NUMBER(10,2) | Measure |
| LINE_PRICE | NUMBER(10,2) | Measure (from ORDER_DETAIL.PRICE) |
| COGS_AMOUNT | NUMBER(10,2) | Measure: `DIM_MENU.COST_OF_GOODS_USD * QUANTITY` |
| DISCOUNT_AMOUNT | NUMBER(10,2) | Measure (from ORDER_DETAIL.ORDER_ITEM_DISCOUNT_AMOUNT) |
| ORDER_AMOUNT | NUMBER(10,2) | From ORDER_HEADER |
| ORDER_TAX_AMOUNT | NUMBER(10,2) | From ORDER_HEADER |
| ORDER_TOTAL | NUMBER(10,2) | From ORDER_HEADER |
| _DW_LOAD_TS | TIMESTAMP_NTZ | Metadata |
| _DW_UPDATE_TS | TIMESTAMP_NTZ | Metadata |

**Important Notes:**
- `DIM_MENU_SK`: Look up the **current** menu dimension record (`IS_CURRENT = TRUE`) matching on `MENU_ITEM_ID`
- `DIM_CUSTOMER_SK`: Look up from DIM_CUSTOMER matching on `CUSTOMER_ID`
- `DIM_LOCATION_SK`: Look up from the pre-created `DIM_LOCATION` matching on the `LOCATION_ID` from `STG_ORDER_HEADER`
- `DIM_DATE_SK`: Look up from the pre-created `DIM_DATE` matching on `ORDER_TS::DATE` from `STG_ORDER_HEADER`
- `COGS_AMOUNT`: Calculated at load time as `DIM_MENU.COST_OF_GOODS_USD * STG_ORDER_DETAIL.QUANTITY`

**Hint:** The fact load procedure will need to join multiple tables:
```
STG_ORDER_DETAIL
  JOIN STG_ORDER_HEADER ON ORDER_ID
  JOIN DIM_MENU ON MENU_ITEM_ID (WHERE IS_CURRENT = TRUE)
  JOIN DIM_CUSTOMER ON CUSTOMER_ID
  JOIN DIM_LOCATION ON LOCATION_ID
  JOIN DIM_DATE ON ORDER_TS::DATE = DATE_VALUE (or equivalent)
```

**Validation:**
```sql
-- Row count should match STG_ORDER_DETAIL
SELECT COUNT(*) FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE;

-- No NULL surrogate keys
SELECT
  COUNT_IF(DIM_MENU_SK IS NULL) AS null_menu_sk,
  COUNT_IF(DIM_CUSTOMER_SK IS NULL) AS null_customer_sk,
  COUNT_IF(DIM_LOCATION_SK IS NULL) AS null_location_sk,
  COUNT_IF(DIM_DATE_SK IS NULL) AS null_date_sk
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE;
-- Expected: all 0
```

---

## Task 2.4: Apply Governance Tags and Comments

Switch to `TB_ADMIN` and apply tags to all 3 warehouse tables.

### Table-Level Tags

| Table | DATA_DOMAIN | DATA_CLASSIFICATION | COST_CENTER |
|-------|-------------|--------------------| ------------|
| DIM_MENU | `'Product'` | `'Internal'` | `'TASTYBYTES'` |
| DIM_CUSTOMER | `'Customer'` | `'Restricted'` | `'TASTYBYTES'` |
| FACT_ORDER_LINE | `'Sales'` | `'Internal'` | `'TASTYBYTES'` |

### PII Column Tags (DIM_CUSTOMER only)

Apply the same `TASTY_PII` tags as in Module 1:

| Column | Tag Value |
|--------|-----------|
| FIRST_NAME | `'NAME'` |
| LAST_NAME | `'NAME'` |
| E_MAIL | `'EMAIL'` |
| PHONE_NUMBER | `'PHONE_NUMBER'` |
| BIRTHDAY_DATE | `'BIRTHDAY'` |

### Comments

Add table-level and column-level COMMENTs **inline in the CREATE TABLE statements** (Tasks 2.1-2.3). Use the same syntax as Module 1:

```sql
CREATE OR REPLACE TABLE DIM_MENU (
    DIM_MENU_SK NUMBER AUTOINCREMENT START 1 INCREMENT 1 COMMENT 'Surrogate key (auto-increment)',
    MENU_ITEM_ID NUMBER COMMENT 'Natural key - unique menu item identifier from source',
    -- ... remaining columns with COMMENT ...
) COMMENT = 'Menu item dimension (SCD Type 2). Tracks price and attribute changes over time.';
```

---

## Task 2.5: Define GRANTS

Grant access to both `TB_DATA_ENGINEER` and `TB_ANALYST`:

```sql
-- TB_DATA_ENGINEER: full access
GRANT ALL ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU TO ROLE TB_DATA_ENGINEER;
GRANT ALL ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER TO ROLE TB_DATA_ENGINEER;
GRANT ALL ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE TO ROLE TB_DATA_ENGINEER;

-- TB_ANALYST: read-only
GRANT SELECT ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU TO ROLE TB_ANALYST;
GRANT SELECT ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER TO ROLE TB_ANALYST;
GRANT SELECT ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE TO ROLE TB_ANALYST;
```

---

## Task 2.6: Create DIM_MENU Load Procedure (SCD Type 2 MERGE)

Create a stored procedure that implements SCD Type 2 logic using MERGE.

**Procedure name:** `SP_LOAD_DIM_MENU`

**Logic:**
1. **Match** source records (from `STG_MENU`) to existing current records (from `DIM_MENU WHERE IS_CURRENT = TRUE`) on the natural key (`MENU_ITEM_ID`)
2. **When matched AND a tracked column has changed:**
   - Update the existing record: set `VALID_TO = CURRENT_TIMESTAMP()`, `IS_CURRENT = FALSE`, `_DW_UPDATE_TS = CURRENT_TIMESTAMP()`
3. **After the MERGE**, insert new current records for all changed rows:
   - `VALID_FROM = CURRENT_TIMESTAMP()`, `VALID_TO = '9999-12-31'`, `IS_CURRENT = TRUE`
4. **When not matched** (new menu items):
   - Insert with `VALID_FROM = CURRENT_TIMESTAMP()`, `VALID_TO = '9999-12-31'`, `IS_CURRENT = TRUE`

**Tracked columns** (detect changes on these):
- `MENU_ITEM_NAME`
- `ITEM_CATEGORY`
- `ITEM_SUBCATEGORY`
- `COST_OF_GOODS_USD`
- `SALE_PRICE_USD`

**Hint:** SCD Type 2 with MERGE can be complex. One approach is:
1. First MERGE to close changed records (UPDATE IS_CURRENT = FALSE)
2. Then INSERT new versions for those changed records
3. Also INSERT brand-new records that didn't exist before

Alternatively, use a single MERGE with a multi-table INSERT pattern. Choose whichever approach you're most comfortable with.

**Validation:**
```sql
-- After initial load: all records should be current
SELECT IS_CURRENT, COUNT(*) FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU GROUP BY IS_CURRENT;
-- Expected: TRUE = 100

-- VALID_TO should be '9999-12-31' for all current records
SELECT COUNT(*) FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU
WHERE IS_CURRENT = TRUE AND VALID_TO != '9999-12-31';
-- Expected: 0
```

---

## Task 2.7: Create DIM_CUSTOMER Load Procedure (SCD Type 1 MERGE)

Create a stored procedure that implements SCD Type 1 logic.

**Procedure name:** `SP_LOAD_DIM_CUSTOMER`

**Logic:**
1. **MERGE** source records (from `STG_CUSTOMER_LOYALTY`) with target (`DIM_CUSTOMER`) on `CUSTOMER_ID`
2. **When matched AND any column has changed:** UPDATE all columns, set `_DW_UPDATE_TS = CURRENT_TIMESTAMP()`
3. **When not matched:** INSERT the new record with `IS_DELETED = FALSE`
4. **Soft-delete:** After the MERGE, update `IS_DELETED = TRUE` for any `DIM_CUSTOMER` records whose `CUSTOMER_ID` no longer exists in `STG_CUSTOMER_LOYALTY`

**Validation:**
```sql
SELECT COUNT(*) FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER;
-- Expected: 222,540

SELECT COUNT(*) FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER WHERE IS_DELETED = TRUE;
-- Expected: 0 (initial load — no deletes yet)
```

---

## Task 2.8: Create FACT_ORDER_LINE Load Procedure

Create a stored procedure that loads the fact table using MERGE.

**Procedure name:** `SP_LOAD_FACT_ORDER_LINE`

**Logic:**
1. **MERGE** on `ORDER_DETAIL_ID` (natural key)
2. **When not matched:** INSERT with surrogate key lookups from all 4 dimensions
3. **When matched:** UPDATE measures if they have changed (handles corrections)

**Surrogate key lookups:**
- `DIM_MENU_SK` from `DIM_MENU WHERE MENU_ITEM_ID = STG_ORDER_DETAIL.MENU_ITEM_ID AND IS_CURRENT = TRUE`
- `DIM_CUSTOMER_SK` from `DIM_CUSTOMER WHERE CUSTOMER_ID = STG_ORDER_HEADER.CUSTOMER_ID AND IS_DELETED = FALSE`
- `DIM_LOCATION_SK` from `DIM_LOCATION WHERE LOCATION_ID = STG_ORDER_HEADER.LOCATION_ID`
- `DIM_DATE_SK` from `DIM_DATE WHERE DATE_VALUE = STG_ORDER_HEADER.ORDER_TS::DATE` (check the actual column name in the pre-created DIM_DATE)

**COGS Calculation:**
```sql
DIM_MENU.COST_OF_GOODS_USD * STG_ORDER_DETAIL.QUANTITY AS COGS_AMOUNT
```

**Note:** Review the pre-created `DIM_LOCATION` and `DIM_DATE` tables to understand their key column names:
```sql
DESCRIBE TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_LOCATION;
DESCRIBE TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_DATE;
```

**Validation:**
```sql
-- Row count
SELECT COUNT(*) FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE;

-- Verify COGS calculation
SELECT
  f.ORDER_DETAIL_ID,
  f.QUANTITY,
  f.COGS_AMOUNT,
  m.COST_OF_GOODS_USD,
  m.COST_OF_GOODS_USD * f.QUANTITY AS expected_cogs
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE f
JOIN TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU m ON f.DIM_MENU_SK = m.DIM_MENU_SK
LIMIT 10;
-- COGS_AMOUNT should match expected_cogs
```

---

## Task 2.9: Create Task Graph

Create a task graph for the warehouse load procedures.

**Task Graph Structure:**
```
TASK_WH_ROOT (root — manual trigger)
  ├── TASK_LOAD_DIM_MENU (runs after root)
  ├── TASK_LOAD_DIM_CUSTOMER (runs after root)
  └── TASK_LOAD_FACT_ORDER_LINE (runs after DIM_MENU AND DIM_CUSTOMER)
```

**Important:** `TASK_LOAD_FACT_ORDER_LINE` must depend on BOTH dimension tasks completing, because the fact load needs to look up surrogate keys from the dimension tables.

**Syntax for multi-dependency:**
```sql
CREATE OR REPLACE TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_FACT_ORDER_LINE
  WAREHOUSE = TB_DE_WH
  AFTER TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_DIM_MENU,
        TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_DIM_CUSTOMER
AS
  CALL TASTYBYTES_CONSUMPTION.WAREHOUSE.SP_LOAD_FACT_ORDER_LINE();
```

Resume all tasks (children first, then root):
```sql
ALTER TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_DIM_MENU RESUME;
ALTER TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_DIM_CUSTOMER RESUME;
ALTER TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_FACT_ORDER_LINE RESUME;
ALTER TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_WH_ROOT RESUME;
```

---

## Task 2.10: Execute and Validate

Execute the warehouse task graph and validate results.

**Execute:**
```sql
EXECUTE TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_WH_ROOT;
```

**Note:** The fact table load will take some time due to the large number of rows and multi-table joins. Monitor progress using task history.

**Validation queries:**
```sql
-- 1. Dimension row counts
SELECT 'DIM_MENU' AS table_name, COUNT(*) AS rows FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU WHERE IS_CURRENT = TRUE
UNION ALL
SELECT 'DIM_CUSTOMER', COUNT(*) FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER WHERE IS_DELETED = FALSE
UNION ALL
SELECT 'FACT_ORDER_LINE', COUNT(*) FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE;

-- 2. No NULL surrogate keys in fact table
SELECT
  COUNT_IF(DIM_MENU_SK IS NULL) AS null_menu,
  COUNT_IF(DIM_CUSTOMER_SK IS NULL) AS null_customer,
  COUNT_IF(DIM_LOCATION_SK IS NULL) AS null_location,
  COUNT_IF(DIM_DATE_SK IS NULL) AS null_date
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE;

-- 3. Revenue sanity check
SELECT SUM(LINE_PRICE) AS total_revenue
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE;
-- Should match: SELECT SUM(PRICE) FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL;
```

---

## Checkpoint

Before moving to Module 3, verify:

- [ ] DIM_MENU has 100 current records with correct SCD2 columns
- [ ] DIM_CUSTOMER has 222,540 records with IS_DELETED = FALSE
- [ ] FACT_ORDER_LINE row count matches STG_ORDER_DETAIL
- [ ] No NULL surrogate keys in the fact table
- [ ] All tables have governance tags and comments
- [ ] PII columns on DIM_CUSTOMER are tagged and masked for TB_ANALYST
- [ ] TB_ANALYST has SELECT on all warehouse tables
- [ ] Revenue totals match between fact table and staging
