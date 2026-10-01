# Model Answer Overview

This directory contains the complete model answer for the TastyBytes Data Engineering Training Exercise. The answer is split into three SQL files, one per module.

## File Structure

| File | Module | Contents |
|------|--------|----------|
| `module1_staging.sql` | RAW to STAGING | 4 staging table DDLs, governance tags/comments, grants, 4 load procedures, task graph |
| `module2_warehouse.sql` | STAGING to WAREHOUSE | 2 dimension DDLs, 1 fact DDL, governance tags/comments, grants, 3 MERGE procedures, task graph |
| `module3_data_product.sql` | WAREHOUSE to DATA PRODUCT | 1 reporting view, governance tags/comments, grants |

## Design Rationale

### TRUNCATE-Reload for Staging

The staging layer uses TRUNCATE followed by INSERT for each load. This pattern was chosen because:

- **Idempotent** — re-running the procedure always produces the same result regardless of how many times it runs
- **Simple** — no need for change detection at the staging layer; just reload the full dataset
- **Appropriate for batch** — in a batch pipeline where the full source is available, there's no benefit to incremental staging loads
- **Safe** — if the INSERT fails, the table is empty rather than partially loaded (an improvement on DELETE which can leave partial data)

See `module1_staging.sql` for the implementation of all 4 staging procedures.

### SCD Type 2 for DIM_MENU

DIM_MENU uses SCD Type 2 to track historical changes in pricing and item attributes. This was chosen because:

- **Price changes affect margin analysis** — if a menu item's price changes mid-year, historical orders should reflect the price at the time of sale, not the current price
- **COGS frozen at fact load time** — the COGS_AMOUNT in FACT_ORDER_LINE is calculated using the current DIM_MENU price when the fact row is loaded, so historical accuracy depends on the dimension being correctly versioned
- **Tracked columns** are: MENU_ITEM_NAME, ITEM_CATEGORY, ITEM_SUBCATEGORY, COST_OF_GOODS_USD, SALE_PRICE_USD

The SCD2 MERGE uses a two-step approach (see `module2_warehouse.sql`, SP_LOAD_DIM_MENU):
1. First MERGE: close records where tracked attributes have changed (set IS_CURRENT = FALSE, set VALID_TO)
2. Then INSERT: add new current versions for changed records and brand-new items

This two-step approach is simpler to understand than a single-statement multi-table MERGE and avoids the non-deterministic behavior that can occur with MERGE when multiple source rows match a single target row.

### SCD Type 1 for DIM_CUSTOMER

DIM_CUSTOMER uses SCD Type 1 (overwrite) because:

- The business scenario does not require historical customer attribute analysis
- Customer data changes (address updates, name corrections) are corrections, not analytically significant changes
- Simplicity — SCD1 with MERGE is a single statement

A soft-delete flag (IS_DELETED) handles customers removed from the source system. See `module2_warehouse.sql`, SP_LOAD_DIM_CUSTOMER.

### AUTOINCREMENT for Surrogate Keys

Surrogate keys use AUTOINCREMENT rather than SEQUENCE because:

- **Simpler DDL** — no separate SEQUENCE object to manage
- **Automatic** — values are assigned on INSERT without explicit calls
- **Sufficient for this exercise** — there is no multi-table insert scenario requiring a shared sequence

### MERGE for Facts

FACT_ORDER_LINE uses MERGE on the natural key (ORDER_DETAIL_ID) rather than INSERT because:

- **Idempotent re-runs** — if the procedure runs twice, existing rows are updated rather than duplicated
- **Handles corrections** — if a staging record is corrected and the pipeline re-runs, the fact table reflects the correction
- **Standard pattern** — consistent with how most production fact loads are built

### COGS Calculation at Load Time

COGS_AMOUNT is calculated as `DIM_MENU.COST_OF_GOODS_USD * QUANTITY` during the fact load, not in the reporting view. This freezes the COGS at the point of sale:

- If the menu COGS changes later (SCD2 creates a new version), existing fact rows retain the COGS that was in effect when they were loaded
- The reporting view simply sums the pre-calculated COGS_AMOUNT without needing to re-derive it

### Reporting View Joins on Surrogate Keys

RPT_MONTHLY_MENU_SALES joins FACT_ORDER_LINE to dimensions using surrogate keys (DIM_MENU_SK, DIM_DATE_SK, DIM_LOCATION_SK). It does NOT filter by IS_CURRENT on DIM_MENU in the view because:

- The fact table already captured the correct DIM_MENU_SK at load time
- Each fact row points to the specific version of the menu item that was in effect when that order was processed
- Filtering by IS_CURRENT would incorrectly apply current prices to historical orders

See `module3_data_product.sql` for the view definition.

## Execution Order

Run the SQL files in order. Each file starts with the appropriate `USE ROLE` and `USE SCHEMA` statements.

1. Run `module1_staging.sql` — creates staging tables, applies governance, creates and executes the staging task graph
2. Wait for the staging task graph to complete (monitor via TASK_HISTORY)
3. Run `module2_warehouse.sql` — creates warehouse tables, applies governance, creates and executes the warehouse task graph
4. Wait for the warehouse task graph to complete
5. Run `module3_data_product.sql` — creates the reporting view, applies governance, grants access

After execution, use the validation script at `../scripts/validate_exercise.sql` to verify all objects were created correctly.
