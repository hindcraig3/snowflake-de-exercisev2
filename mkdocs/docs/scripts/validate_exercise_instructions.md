# Validation Script — Instructions

## Purpose

The validation script checks that all exercise objects have been created correctly, data has been loaded, governance tags are applied, and masking is working. Run it after completing all 3 modules.

## How to Run

1. Open a Snowflake SQL worksheet
2. Copy and paste the contents of `validate_exercise.sql`
3. Run the entire script

**Important:** The script runs as `TB_DATA_ENGINEER`. The masking check at the end tests whether PII is visible to `TB_DATA_ENGINEER` (it should be, since that role is privileged). To verify masking works for `TB_ANALYST`, run this additional query separately:

```sql
USE ROLE TB_ANALYST;
USE WAREHOUSE TB_ANALYST_WH;

SELECT FIRST_NAME, LAST_NAME, E_MAIL, PHONE_NUMBER, BIRTHDAY_DATE
FROM TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY
LIMIT 5;
-- All PII columns should show '**MASKED**' or '1900-01-01'

SELECT FIRST_NAME, LAST_NAME, E_MAIL, PHONE_NUMBER, BIRTHDAY_DATE
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER
LIMIT 5;
-- Same masking should apply here
```

## Interpreting Results

The script returns a result set with three columns:

| Column | Description |
|--------|-------------|
| CHECK_NAME | Name of the check (e.g., `STAGING_TABLE_EXISTS: STG_MENU`) |
| STATUS | `PASS` or `FAIL` |
| DETAIL | Additional context (row counts, data types found, etc.) |

### Check Categories

| Prefix | What It Checks |
|--------|---------------|
| `STAGING_TABLE_EXISTS` | Staging tables exist in TASTYBYTES_REFINED.STAGING |
| `WAREHOUSE_TABLE_EXISTS` | Warehouse tables exist in TASTYBYTES_CONSUMPTION.WAREHOUSE |
| `VIEW_EXISTS` | Reporting view exists in TASTYBYTES_CONSUMPTION.ANALYTICS |
| `SCHEMA_CHECK` | Column data types, metadata columns, surrogate keys, SCD2 columns |
| `DATA_CHECK` | Row counts, NULL checks, revenue tie-back |
| `GOV_CHECK` | Table comments are set |
| `TAG_CHECK` | Enterprise tags (DATA_DOMAIN, TASTY_PII) are applied |
| `PROC_EXISTS` | Stored procedures exist |
| `MASKING_CHECK` | PII masking is working |

### What to Do If Checks Fail

- **Table/view not found:** Go back to the relevant module and create the missing object
- **Wrong data type:** Check your DDL — the column type cast may be incorrect
- **Missing metadata columns:** Add `_LOAD_TS` and `_SOURCE_TABLE` to staging tables, or `_DW_LOAD_TS` and `_DW_UPDATE_TS` to warehouse tables
- **Row count mismatch:** Re-run the load procedures or task graph
- **NULL surrogate keys:** Check the JOIN conditions in your fact load procedure
- **Revenue mismatch:** Verify the reporting view aggregation matches the fact table
- **Missing tags:** Switch to `TB_ADMIN` and apply the tags
- **Masking not working:** Verify the TASTY_PII tag is applied to the correct columns
