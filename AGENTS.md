# AGENTS.md — TastyBytes DE Exercise v2

## Project Structure

- `exercises/` — Sequential exercise modules (00-03), each building on the previous
- `model_answer/` — SQL model answers and design rationale for each module
- `scripts/` — Validation and incremental load test scripts
- `setup/` — Environment setup SQL and instructions

## Rules for Exercise Changes

When asked to modify any exercise file:

1. **Impact analysis first** — Before making any change, review all exercises (`exercises/00_background.md` through `exercises/03_module3_warehouse_to_product.md`) to identify upstream or downstream effects. Exercises are sequential and tightly coupled: a schema change in Module 1 cascades through Modules 2 and 3.

2. **Model answer review** — Check whether the corresponding model answer(s) in `model_answer/` need updating. This includes:
   - The SQL file(s) for the affected module(s) (`module1_staging.sql`, `module2_warehouse.sql`, `module3_data_product.sql`)
   - The design rationale in `model_answer/model_answer.md`
   - Downstream model answers if the change cascades

3. **Validation and test scripts** — Check whether `scripts/validate_exercise.sql` or `scripts/test_incremental_load.sql` need updating to reflect the change.

4. **Setup scripts** — If the change affects source data, schemas, or roles, check `setup/01_setup.sql` and `setup/02_dataload.sql`.

5. **Report all findings** — Before applying changes, report:
   - Which files are affected
   - What the upstream/downstream impacts are
   - A summary of all proposed changes across exercises, model answers, and scripts
