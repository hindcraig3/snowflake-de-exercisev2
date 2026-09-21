# Environment Setup

Use this guide to create a Snowflake trial account and load the TastyBytes training environment.

You need:

- A valid email address (no credit card)
- This `setup` folder (`01_setup.sql` and `02_dataload.sql`)

After setup you will have:

| Database | Schemas | Used for |
|---|---|---|
| `TASTYBYTES_RAW` | `RAW` | Landed source tables (read-only) |
| `TASTYBYTES_REFINED` | `STAGING` | Staging tables |
| `TASTYBYTES_CONSUMPTION` | `WAREHOUSE`, `ANALYTICS` | Dimensional model, reporting views |
| `TASTYBYTES_GOVERNANCE` | `GOVERNANCE` | Tags and masking policies |

You will also have three roles (`TB_ADMIN`, `TB_DATA_ENGINEER`, `TB_ANALYST`) and two warehouses (`TB_DE_WH`, `TB_ANALYST_WH`).

---

## 1. Create a Snowflake trial account

1. Open [https://signup.snowflake.com/](https://signup.snowflake.com/).
2. Sign up with Google, or enter:
   - First name
   - Last name
   - Work email
   - Company name (use your organisation, or a placeholder such as `Training`)
   - Job title
3. Choose edition, cloud, and region. These cannot be changed later.
   - **Edition:** Enterprise (the default, and what this course expects)
   - **Cloud:** AWS, Azure, or GCP — any is fine
   - **Region:** pick one close to you
4. Accept the terms and select **Sign up**.
5. Open the activation email from Snowflake and follow the link.
6. Create your username and password, then select **Get Started**.
7. Sign in at [https://app.snowflake.com/](https://app.snowflake.com/). You land in Snowsight.

The trial lasts **30 days** or until the **$400** free credit balance is used, whichever comes first. No payment details are required.

If the activation email does not arrive, check spam. Corporate mail filters sometimes block Snowflake. Request a new activation email from the signup or login page.

---

## 2. Open your default workspace

Snowflake now uses **Workspaces** as the SQL editor. Each user gets a default workspace named **My Workspace**.

1. In Snowsight, open **Projects** » **Workspaces**.
2. If this is your first visit, Snowflake creates **My Workspace** automatically. Stay in that workspace.




---

## 3. Run `01_setup.sql`

This script creates four databases, four schemas, three roles (`TB_ADMIN`, `TB_DATA_ENGINEER`, `TB_ANALYST`), two warehouses (`TB_DE_WH`, `TB_ANALYST_WH`), governance tags, masking policies, stages, file formats, empty RAW tables, and pre-populated staging/warehouse table DDL.

1. In **My Workspace**, select **+** next to the workspace (or a folder) and choose **SQL File**.
2. Name the file `01_setup.sql`.
3. Confirm the context selector (top right of the editor) is set to:
   - **Role:** `ACCOUNTADMIN`
   - **Warehouse:** `COMPUTE_WH` (the trial default is fine for now)
3. Open `setup/01_setup.sql` from this course on your computer.
4. Copy the **entire** file and paste it into the new SQL file in Snowsight.
5. Confirm the role is still `ACCOUNTADMIN`.
6. Select **Run All** (or press **Cmd+Shift+Return** on Mac / **Ctrl+Shift+Enter** on Windows).

Wait until every statement finishes. This may take a few minutes

The last query is a setup check. You should see **PASS** for:

- 4 of 4 databases
- 1 of 1 RAW schemas
- 1 of 1 REFINED schemas
- 2 of 2 CONSUMPTION schemas
- 1 of 1 GOVERNANCE schemas
- 9 of 9 RAW tables
- 2 of 2 pre-populated staging tables
- 2 of 2 pre-populated warehouse tables
- 4 of 4 governance tags

If any row is **FAIL**, do not continue. Re-run the script as `ACCOUNTADMIN`, or ask a facilitator.

`CREATE OR REPLACE DATABASE` drops and recreates those databases. Only run this on a trial account you created for the course.

The setup script creates `TB_DE_WH` and `TB_ANALYST_WH`, and switches to `TB_ADMIN`. You still need `ACCOUNTADMIN` to start the script.

---

## 4. Run `02_dataload.sql`

This script copies TastyBytes data from the public Quickstarts S3 buckets, applies a few data-quality defects, and loads 4 pre-populated tables (`STG_COUNTRY`, `STG_LOCATION`, `DIM_LOCATION`, `DIM_DATE`) that you will use as reference examples and for dimension lookups.

1. In **My Workspace**, create another SQL file named `02_dataload.sql`.
2. Copy the **entire** contents of `setup/02_dataload.sql` into that file.
3. Leave the role as `ACCOUNTADMIN` (or switch to `TB_ADMIN` if you prefer — both work after setup).
4. Select **Run All**.

The copy into `ORDER_HEADER` and `ORDER_DETAIL` is large. Allow several minutes. Do not close the browser tab while it is running.

The last query lists row counts across all layers. Typical values:

| Layer | Table | Approximate rows |
|---|---|---|
| RAW | `ORDER_DETAIL` | ~673 million |
| RAW | `ORDER_HEADER` | ~248 million |
| RAW | `CUSTOMER_LOYALTY` | ~222 thousand |
| RAW | `LOCATION` | ~13 thousand |
| RAW | `TRUCK_REVIEWS` | ~1 thousand (trimmed, plus 15 workshop inserts) |
| RAW | `TRUCK` | 450 |
| RAW | `FRANCHISE` | 335 |
| RAW | `MENU` | 100 |
| RAW | `COUNTRY` | 30 |
| STAGING | `STG_COUNTRY` | 30 |
| STAGING | `STG_LOCATION` | ~13 thousand |
| WAREHOUSE | `DIM_DATE` | 2,557 |
| WAREHOUSE | `DIM_LOCATION` | ~13 thousand |

If a `COPY INTO` fails, run that statement again. Do not re-run the whole file unless the tables are empty, or you will duplicate the workshop inserts.

---

## 5. Confirm you are ready for Task 1

In a new SQL file, run:

```sql
USE ROLE TB_DATA_ENGINEER;
USE WAREHOUSE TB_DE_WH;

SHOW TABLES IN TASTYBYTES_RAW.RAW;
```

You should see the nine RAW tables. You can now start [Module 1: RAW to STAGING](../exercises/01_module1_raw_to_staging.md).

Do **not** create extra databases or schemas. Use the objects this setup created.

For the exercise modules, use `TB_DATA_ENGINEER` and `TB_DE_WH` as your default role and warehouse. Switch to `TB_ADMIN` when applying governance tags. Switch to `TB_ANALYST` when validating masking. Size the warehouse up to **LARGE** when building the fact table, then size it back down so the trial credits last.

---

## Troubleshooting

| Symptom | What to do |
|---|---|
| Activation email never arrives | Check spam; retry signup with the same email; ask IT to allow Snowflake mail |
| `Insufficient privileges` on `CREATE DATABASE` | Set the worksheet role to `ACCOUNTADMIN` and run again |
| Setup check shows FAIL | Re-run `01_setup.sql` as `ACCOUNTADMIN` from the top |
| Copy runs for a long time | Expected for the order tables. Wait for **Run All** to finish |
| Duplicate review rows after a second load | Those come from the workshop `INSERT`. Use a new trial account, or truncate `TRUCK_REVIEWS` and copy that table only |
| Warehouse will not start | Resume `TB_DE_WH` or `COMPUTE_WH` from the context selector |

To reset a trial environment and start again, uncomment the `DROP` statements at the top of `01_setup.sql`, run them as `ACCOUNTADMIN`, then run both scripts from the beginning.
