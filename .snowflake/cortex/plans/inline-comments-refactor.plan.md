---
name: "inline-comments-refactor"
created: "2026-09-20T20:19:05.166Z"
status: pending
---

# Plan: Inline Comments in CREATE TABLE DDL

## Context

Currently, table and column comments are applied using separate `COMMENT ON TABLE` and `COMMENT ON COLUMN` statements AFTER the tables are created. The user wants these moved into inline `COMMENT` clauses within the `CREATE TABLE` DDL itself.

Snowflake supports this syntax:

```sql
CREATE OR REPLACE TABLE my_table (
    col1 NUMBER COMMENT 'Column description',
    col2 VARCHAR COMMENT 'Another description'
) COMMENT = 'Table-level description';
```

This affects 4 files across both modules:

- module1\_staging.sql — 4 CREATE TABLE + 67 COMMENT ON statements
- module2\_warehouse.sql — 3 CREATE TABLE + 63 COMMENT ON statements
- 01\_module1\_raw\_to\_staging.md — Task 1.6 comment instructions
- 02\_module2\_staging\_to\_warehouse.md — Task 2.4 comment instructions

## Implementation Steps

### Task 1: Refactor module1\_staging.sql

Replace the 4 CREATE TABLE statements (lines 14-99) with inline comments. Example for STG\_MENU:

```sql
CREATE OR REPLACE TABLE STG_MENU (
    MENU_ID               NUMBER        COMMENT 'Unique identifier for the menu',
    MENU_TYPE_ID          NUMBER        COMMENT 'Foreign key to menu type/cuisine category',
    ...
    _SOURCE_TABLE         VARCHAR(100)  COMMENT 'Name of the RAW source table'
) COMMENT = 'Staged menu items with flattened health metrics. Source: TASTYBYTES_RAW.RAW.MENU';
```

Then delete the entire COMMENT ON block (lines 146-226, 67 statements). Same treatment for all 4 tables.

### Task 2: Refactor module2\_warehouse.sql

Same approach for the 3 warehouse tables (DIM\_MENU, DIM\_CUSTOMER, FACT\_ORDER\_LINE). The comments on these tables are currently in a large block after the tag statements. Move them inline, delete the COMMENT ON block.

### Task 3: Update Module 1 instructions

In `01_module1_raw_to_staging.md`, Task 1.6 "Table and Column Comments" section (around line 298-307):

**Before:**

```
COMMENT ON TABLE ... IS '...';
COMMENT ON COLUMN ... IS '...';
```

**After:** Update instructions to say comments should be defined inline in the CREATE TABLE DDL. Update the syntax example. Add a note that Task 1.6 comment requirements should actually be addressed during Tasks 1.2-1.5 (when creating the tables), not as a separate step.

### Task 4: Update Module 2 instructions

Same change in `02_module2_staging_to_warehouse.md` Task 2.4 — update the comment instructions to reference inline syntax.

## Verification

- Confirm no `COMMENT ON TABLE` or `COMMENT ON COLUMN` statements remain in either SQL file
- Confirm all CREATE TABLE statements have `COMMENT = '...'` at the table level and `COMMENT '...'` on each column
- Confirm the instructions reference the inline syntax, not the old `COMMENT ON` approach
- Comment text (the actual descriptions) should be unchanged

## Critical Files

- model\_answer/module1\_staging.sql — 4 CREATE TABLE refactored, 67 COMMENT ON removed
- model\_answer/module2\_warehouse.sql — 3 CREATE TABLE refactored, 63 COMMENT ON removed
- exercises/01\_module1\_raw\_to\_staging.md — Task 1.6 syntax update
- exercises/02\_module2\_staging\_to\_warehouse.md — Task 2.4 syntax update
