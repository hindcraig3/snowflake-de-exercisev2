# Checkpoint vs Exercise Consistency Report

## Summary

All three modules have checkpoint gaps. Module 2 is the most inconsistent: its checkpoint omits load procedures, the task graph, and masking validation — all of which are significant exercise deliverables. Module 1 omits grants and procedure comments. Module 3 is the tightest but still omits grants to TB_DATA_ENGINEER and column-level comments on the view.

---

## Module 1: RAW to STAGING

### Checkpoint Items (verbatim)

1. All 4 staging tables exist with correct column types
2. All tables have DATA_DOMAIN, DATA_CLASSIFICATION, and COST_CENTER tags
3. STG_CUSTOMER_LOYALTY PII columns are tagged and masked for TB_ANALYST
4. All tables have table-level and column-level COMMENTs
5. All 4 load procedures exist and execute successfully
6. Task graph runs end-to-end without errors
7. Row counts match expected values

### Coverage Mapping

| Checkpoint Item | Covering Task(s) | Notes |
|---|---|---|
| 1. Tables exist with correct types | Tasks 1.2–1.5 (DDL), Task 1.10 (validation of types) | Fully covered |
| 2. Governance tags on all tables | Task 1.6 (table-level tags) | Fully covered |
| 3. PII tagged and masked | Task 1.6 (PII tags + masking validation) | Fully covered |
| 4. Table and column COMMENTs | Tasks 1.2–1.5 (inline comments in DDL), Standards section | Fully covered |
| 5. Load procedures exist and execute | Task 1.8 (create procedures), Task 1.10 (execute via task graph) | Covered, but see MISSING below |
| 6. Task graph runs end-to-end | Tasks 1.9 (create), 1.10 (execute and monitor) | Fully covered |
| 7. Row counts match | Task 1.10 (validation queries), Tasks 1.2–1.5 (individual expected counts) | Fully covered |

### MISSING Checkpoint Items (exercise requires, checkpoint omits)

| Missing Item | Evidence | Confidence |
|---|---|---|
| **GRANTS to TB_DATA_ENGINEER** | Task 1.7 requires granting USAGE on schema and ALL on each table to TB_DATA_ENGINEER. Also explicitly states TB_ANALYST should NOT have access. Checkpoint does not mention grants at all. | High |
| **COMMENT clause on stored procedures** | Task 1.8 explicitly requires: "Comment: Add a comment that explains the purpose of the stored procedure" and shows `COMMENT = 'Loads data from RAW MENU table...'` in the pattern. Checkpoint item 5 says procedures "exist and execute successfully" but does not mention the COMMENT clause. | High |
| **Data type validation (no bad casts)** | Task 1.10 validation query 3 checks for unexpected NULLs introduced by type casting. Task 1.10 validation query 2 checks data types are correct. These are validation steps beyond row counts but the checkpoint only says "correct column types" (item 1) and "row counts" (item 7). The type validation is arguably covered by item 1, but the bad-cast NULL check is distinct from column types. | Medium |
| **JSON flattening verification** | Task 1.10 validation query 4 verifies JSON was flattened correctly (checking BOOLEAN flags and INGREDIENTS). Checkpoint does not specifically mention this. Could be argued as covered under "correct column types" but it's a distinct data-quality check. | Low |

### STALE Checkpoint Items (checkpoint mentions, exercise doesn't require)

None found.

---

## Module 2: STAGING to WAREHOUSE

### Checkpoint Items (verbatim)

1. DIM_MENU has 100 current records with correct SCD2 columns
2. DIM_CUSTOMER has 222,540 records with IS_DELETED = FALSE
3. FACT_ORDER_LINE row count matches STG_ORDER_DETAIL
4. No NULL surrogate keys in the fact table
5. All tables have governance tags and comments
6. PII columns on DIM_CUSTOMER are tagged and masked for TB_ANALYST
7. TB_ANALYST has SELECT on all warehouse tables
8. Revenue totals match between fact table and staging

### Coverage Mapping

| Checkpoint Item | Covering Task(s) | Notes |
|---|---|---|
| 1. DIM_MENU 100 current records, SCD2 columns | Task 2.1 (DDL), Task 2.6 (load proc + validation) | Fully covered |
| 2. DIM_CUSTOMER 222,540 records | Task 2.2 (DDL), Task 2.7 (load proc + validation) | Fully covered |
| 3. FACT row count matches staging | Task 2.3 (DDL), Task 2.8 (load proc), Task 2.10 (validation) | Fully covered |
| 4. No NULL surrogate keys | Task 2.8 (surrogate key lookups are required in proc). **However, no explicit validation query is provided in the exercise to check for NULLs.** | Partially covered — checkpoint requires it but exercise provides no validation SQL |
| 5. Tags and comments | Tasks 2.1–2.3 (inline comments), Task 2.4 (tags) | Fully covered |
| 6. PII masked for TB_ANALYST | Task 2.4 (PII tags) | See MISSING below — no validation step |
| 7. TB_ANALYST has SELECT | Task 2.5 (grants) | Fully covered |
| 8. Revenue totals match | Task 2.10 (revenue sanity check query) | Fully covered |

### MISSING Checkpoint Items (exercise requires, checkpoint omits)

| Missing Item | Evidence | Confidence |
|---|---|---|
| **Load procedures exist and execute** | Tasks 2.6, 2.7, 2.8 each create a stored procedure (SP_LOAD_DIM_MENU, SP_LOAD_DIM_CUSTOMER, SP_LOAD_FACT_ORDER_LINE). These are core deliverables with detailed logic (SCD2 MERGE, SCD1 MERGE, multi-join fact load). The checkpoint has no item verifying that these procedures exist or function correctly. Module 1's checkpoint includes "All 4 load procedures exist and execute successfully" — Module 2's checkpoint does not. | High |
| **Task graph runs end-to-end** | Task 2.9 creates TASK_WH_ROOT with 3 child tasks including a multi-dependency (FACT depends on both DIMs). Task 2.10 executes and monitors it. The checkpoint has no item for the task graph. Module 1's checkpoint includes "Task graph runs end-to-end without errors" — Module 2's checkpoint does not. | High |
| **GRANTS to TB_DATA_ENGINEER** | Task 2.5 requires "full access to TB_DATA_ENGINEER". Checkpoint item 7 only mentions TB_ANALYST having SELECT. TB_DATA_ENGINEER grants are not checkpointed. | High |
| **Masking validation step** | Task 2.4 applies PII tags to DIM_CUSTOMER but, unlike Module 1's Task 1.6, provides no validation SQL (switching to TB_ANALYST to verify masking). Checkpoint item 6 says "masked for TB_ANALYST" but the exercise doesn't include the verification step. | Medium |
| **COGS calculation validation** | Task 2.8 provides a specific validation query to verify COGS_AMOUNT = COST_OF_GOODS_USD * QUANTITY. This is a non-trivial derived measure. Checkpoint does not mention it. | Medium |
| **COMMENT on stored procedures** | Module 2's Standards section mentions comments for "table, view and column" but does not mention procedures. However, the procedure pattern established in Module 1 (Task 1.8) includes COMMENT. Module 2's tasks 2.6–2.8 do not explicitly require COMMENT on procedures, creating an inconsistency with Module 1. | Low |

### STALE Checkpoint Items (checkpoint mentions, exercise doesn't require)

| Stale Item | Evidence | Confidence |
|---|---|---|
| **"No NULL surrogate keys in the fact table" (item 4)** | While this is a valid quality check, the exercise provides no validation query for it. Task 2.10's validation queries check row counts and revenue totals but not NULL surrogate keys. The checkpoint expects the learner to verify something the exercise never asks them to verify. Not truly "stale" (it's a valid check), but it's an **unguided checkpoint item** — the exercise should include a validation query. | Medium |

---

## Module 3: WAREHOUSE to DATA PRODUCT

### Checkpoint Items (verbatim)

1. RPT_MONTHLY_MENU_SALES view exists and returns data
2. The view has DATA_DOMAIN, DATA_CLASSIFICATION, and COST_CENTER tags
3. The view has a descriptive COMMENT
4. TB_ANALYST can query the view
5. Revenue totals tie back across all layers (staging, warehouse, reporting)
6. The business queries return sensible results (12 months, positive margins, multiple cities)

### Coverage Mapping

| Checkpoint Item | Covering Task(s) | Notes |
|---|---|---|
| 1. View exists and returns data | Task 3.1 (create view) | Fully covered |
| 2. Tags applied | Task 3.2 (3 governance tags) | Fully covered |
| 3. Descriptive COMMENT | Task 3.1/3.2 (Standards say COMMENT required; Task 3.2 syntax shows COMMENT ON VIEW) | Fully covered at view level |
| 4. TB_ANALYST can query | Task 3.3 (grants), Task 3.4 (validation as TB_ANALYST) | Fully covered |
| 5. Revenue tie-back | Task 3.4 (Revenue Tie-Back query across 3 layers) | Fully covered |
| 6. Business queries return sensible results | Task 3.4 (3 business queries with expected-result hints) | Fully covered |

### MISSING Checkpoint Items (exercise requires, checkpoint omits)

| Missing Item | Evidence | Confidence |
|---|---|---|
| **GRANTS to TB_DATA_ENGINEER** | Task 3.3 explicitly grants `ALL ON VIEW ... TO ROLE TB_DATA_ENGINEER`. Checkpoint item 4 only verifies TB_ANALYST access. | High |
| **USAGE grant on ANALYTICS schema** | Task 3.3 includes `GRANT USAGE ON SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS TO ROLE TB_ANALYST`. This is a prerequisite for TB_ANALYST access but not separately checkpointed. Arguably covered by "TB_ANALYST can query the view" since that would fail without the schema grant. | Low |
| **Column-level COMMENTs on the view** | The Standards section states "Every table, view and column must have a COMMENT inline in the CREATE TABLE / CREATE VIEW statement (Tasks 3.1)." This implies column comments are required. However, the checkpoint only says "a descriptive COMMENT" (singular, view-level). Column comments on views require `COMMENT ON COLUMN` syntax (not inline). The Standards section's "(Tasks 3.1)" reference is misleading since Task 3.1 doesn't mention column comments. | Medium |

### STALE Checkpoint Items (checkpoint mentions, exercise doesn't require)

None found.

---

## Cross-Module Consistency Issues

| Issue | Evidence | Confidence |
|---|---|---|
| **GRANTS never checkpointed consistently** | Module 1 checkpoint omits grants entirely. Module 2 checkpoints TB_ANALYST SELECT but not TB_DATA_ENGINEER grants. Module 3 checkpoints TB_ANALYST access but not TB_DATA_ENGINEER. All three modules have explicit GRANT tasks (1.7, 2.5, 3.3) that are partially or fully omitted from checklists. | High |
| **Procedure/task-graph checkpoint inconsistency between Modules 1 and 2** | Module 1 checkpoint includes "All 4 load procedures exist and execute successfully" and "Task graph runs end-to-end without errors." Module 2 has equivalent tasks (2.6–2.9) but its checkpoint omits both. This is the most significant structural inconsistency. | High |
| **Masking validation inconsistency between Modules 1 and 2** | Module 1 Task 1.6 includes explicit masking validation SQL (switch to TB_ANALYST, query PII columns, verify masked values). Module 2 Task 2.4 applies the same PII tags to DIM_CUSTOMER but includes no masking validation step. Both checkpoints mention masking, but only Module 1's exercise provides the verification procedure. | Medium |
| **Stored procedure COMMENT requirement inconsistency** | Module 1 Task 1.8 explicitly requires COMMENT on procedures. Module 2 Tasks 2.6–2.8 do not mention it. The Standards sections differ: Module 1 mentions "table, view and coloumn [sic]" and then Task 1.8 adds the procedure requirement. Module 2 Standards mention "table, view and column" with no procedure mention. | Medium |

---

## Recommendation

1. **Module 2 checkpoint needs two items added**: "All 3 load procedures exist and execute successfully" and "Task graph runs end-to-end without errors" — these are major deliverables with no checkpoint coverage.
2. **Add a GRANTS checkpoint item to all three modules**, or at minimum Modules 1 and 3 (Module 2 already has the TB_ANALYST item).
3. **Add a stored-procedure COMMENT checkpoint item to Module 1** (item 5 should say "exist with COMMENT and execute successfully"), and decide whether Module 2 procedures also require COMMENT — if so, add it to both Standards and checkpoint.
4. **Add masking validation SQL to Module 2 Task 2.4** to match the pattern established in Module 1 Task 1.6.
5. **Add a NULL surrogate key validation query to Module 2 Task 2.10** since checkpoint item 4 expects learners to verify this but provides no guidance.
6. **Clarify column-level comments on views in Module 3** — either require them explicitly with syntax guidance, or narrow the Standards statement to exclude view columns.
