# Incremental Data Test — Instructions

## Purpose

This script proves the pipeline works end-to-end by inserting new data into the RAW layer and verifying it propagates through staging, the warehouse, and into the reporting view.

The test inserts 5 new orders (with 10 line items) dated **January 15, 2023** — a date that does not exist in the original 2022 dataset. After running the pipeline, January 2023 should appear as a new month in the reporting view.

## Prerequisites

- All 3 modules must be completed (staging tables, warehouse tables, and reporting view exist)
- All task graphs must be in RESUMED state
- You must be connected as `TB_DATA_ENGINEER` using `TB_DE_WH`

## How to Run

The script has 6 steps. Run them sequentially — do not run the entire script at once, because you need to wait for task graphs to complete between steps.

### Step 1: Capture Baseline

Run the baseline query to record current row counts. Note these numbers for comparison later.

### Step 2: Insert Test Data

Run the INSERT statements to add 5 new orders and 10 line items into the RAW tables. The script uses ORDER_IDs starting at 500,000,001 and ORDER_DETAIL_IDs starting at 910,000,001 to avoid conflicts with existing data.

**Test data summary:**
- 5 orders, all on January 15, 2023
- 10 line items across those orders
- Menu items: Lemonade, Sugar Cone, Waffle Cone, Two Scoop Bowl, Bottled Water
- Total revenue: $52.50
- All orders from truck 37 at locations 1266 and 2114

### Step 3: Execute Staging Pipeline

Run `EXECUTE TASK` on the staging root task. Then monitor task history until all tasks show `SUCCEEDED`. This may take a few minutes since the staging procedures reload all data (TRUNCATE-reload pattern).

### Step 4: Execute Warehouse Pipeline

After staging completes, run `EXECUTE TASK` on the warehouse root task. Monitor until all tasks (especially FACT_ORDER_LINE) show `SUCCEEDED`. The fact load will be the longest-running task.

### Step 5: Validate

Run the validation queries. Each returns a CHECK_NAME, STATUS, and DETAIL:

| Check | What It Verifies |
|-------|-----------------|
| STAGING_CHECK | 5 new orders exist in STG_ORDER_HEADER |
| STAGING_DETAIL_CHECK | 10 new line items exist in STG_ORDER_DETAIL |
| FACT_CHECK | 10 new rows exist in FACT_ORDER_LINE |
| FACT_SK_CHECK | All surrogate keys are populated (no NULLs) |
| COGS_CHECK | COGS_AMOUNT = COST_OF_GOODS_USD * QUANTITY for new rows |
| RPT_VIEW_CHECK | January 2023 appears in the reporting view |
| REVENUE_CHECK | Total January 2023 revenue = $52.50 |

All checks should return `PASS`.

### Step 6: Cleanup (Optional)

If you want to remove the test data and return to the original state, uncomment and run the cleanup section. This deletes the test rows from RAW and re-runs both pipelines.

## Troubleshooting

| Issue | Likely Cause |
|-------|-------------|
| Staging check fails (0 new orders) | Task graph didn't complete — check TASK_HISTORY for errors |
| Fact check fails (0 new rows) | Warehouse task graph didn't run, or ran before staging completed |
| NULL surrogate keys | Dimension lookup failed — check JOIN conditions in SP_LOAD_FACT_ORDER_LINE. January 2023 must exist in DIM_DATE. |
| Revenue mismatch | Rounding issue or COGS calculation error in the fact load |
| January 2023 not in view | Fact rows loaded but DIM_DATE doesn't have January 2023 dates. Check DIM_DATE coverage. |
