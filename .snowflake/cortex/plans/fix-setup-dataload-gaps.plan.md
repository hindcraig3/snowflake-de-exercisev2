---
name: "fix-setup-dataload-gaps"
created: "2026-09-20T22:54:21.629Z"
status: pending
---

# Plan: Fix Setup and Dataload Script Gaps

## Context

The gap analysis identified 13 issues; gap 9 (2022 data filtering) is excluded. The remaining 12 gaps are all addressed by modifying two files:

- setup/01\_setup.sql — databases, schemas, roles, warehouses, tags, masking policies, privileges, pre-populated table DDL
- setup/02\_dataload.sql — pre-populated table data loads

No exercise or model answer files change — the setup scripts are being brought into alignment with the design brief.

## Implementation Steps

### Task 1: Fix databases and schemas in 01\_setup.sql

**Add** `TASTYBYTES_GOVERNANCE` database and schema:

```sql
CREATE OR REPLACE DATABASE TASTYBYTES_GOVERNANCE;
CREATE OR REPLACE SCHEMA TASTYBYTES_GOVERNANCE.GOVERNANCE;
```

**Rename** `TASTYBYTES_CONSUMPTION.DW` to `TASTYBYTES_CONSUMPTION.WAREHOUSE`:

```sql
CREATE OR REPLACE SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE;
```

**Remove** unused schemas that don't appear in the design brief:

- `TASTYBYTES_REFINED.GOVERNANCE` (governance objects go in TASTYBYTES\_GOVERNANCE.GOVERNANCE)
- `TASTYBYTES_REFINED.PIPELINES` (procedures/tasks live in STAGING and WAREHOUSE schemas)
- `TASTYBYTES_CONSUMPTION.FUNCTIONS` (not used in the exercise)

**Update** all subsequent GRANT statements that reference the old schema names (DW, GOVERNANCE under REFINED, PIPELINES, FUNCTIONS) to use the new names.

Also update the validation check at the bottom of the file to expect the new schema names.

---

### Task 2: Add TB\_DATA\_ENGINEER and TB\_ANALYST roles in 01\_setup.sql

Add after the existing TB\_ADMIN role creation:

```sql
CREATE ROLE IF NOT EXISTS TB_DATA_ENGINEER COMMENT = 'Data engineer role for pipeline development';
CREATE ROLE IF NOT EXISTS TB_ANALYST COMMENT = 'Analyst role for reporting consumption';

-- Role hierarchy
GRANT ROLE TB_DATA_ENGINEER TO ROLE TB_ADMIN;
GRANT ROLE TB_ANALYST TO ROLE TB_ADMIN;
GRANT ROLE TB_ADMIN TO ROLE SYSADMIN;

-- Grant roles to current user
GRANT ROLE TB_ADMIN TO USER CURRENT_USER;  -- Note: uses SET variable pattern
GRANT ROLE TB_DATA_ENGINEER TO USER CURRENT_USER;
GRANT ROLE TB_ANALYST TO USER CURRENT_USER;
```

**TB\_DATA\_ENGINEER privileges:**

- USAGE on all 4 databases
- USAGE + CREATE TABLE + CREATE PROCEDURE + CREATE TASK on TASTYBYTES\_REFINED.STAGING
- USAGE + CREATE TABLE + CREATE PROCEDURE + CREATE TASK on TASTYBYTES\_CONSUMPTION.WAREHOUSE
- USAGE on TASTYBYTES\_CONSUMPTION.ANALYTICS (+ CREATE VIEW)
- USAGE on WAREHOUSE TB\_DE\_WH
- EXECUTE TASK ON ACCOUNT
- Future grants: ALL on future tables, procedures, tasks, views in the relevant schemas

**TB\_ANALYST privileges:**

- USAGE on TASTYBYTES\_CONSUMPTION database
- USAGE on TASTYBYTES\_CONSUMPTION.WAREHOUSE and TASTYBYTES\_CONSUMPTION.ANALYTICS schemas
- SELECT on future tables in TASTYBYTES\_CONSUMPTION.WAREHOUSE
- SELECT on future views in TASTYBYTES\_CONSUMPTION.ANALYTICS
- USAGE on WAREHOUSE TB\_ANALYST\_WH
- USAGE on TASTYBYTES\_REFINED.STAGING (for masking validation exercise)
- SELECT on future tables in TASTYBYTES\_REFINED.STAGING (masked by policy)

---

### Task 3: Add TB\_ANALYST\_WH warehouse in 01\_setup.sql

```sql
CREATE OR REPLACE WAREHOUSE TB_ANALYST_WH
    WAREHOUSE_SIZE = 'xsmall'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
COMMENT = 'Analyst warehouse for reporting queries';
```

Grant usage to TB\_ANALYST. Grant ownership to TB\_ADMIN.

---

### Task 4: Add governance tags in 01\_setup.sql

Create the 4 tags in TASTYBYTES\_GOVERNANCE.GOVERNANCE after the database/schema creation:

```sql
USE ROLE TB_ADMIN;
USE SCHEMA TASTYBYTES_GOVERNANCE.GOVERNANCE;

CREATE OR REPLACE TAG TASTY_PII
    ALLOWED_VALUES 'NAME', 'PHONE_NUMBER', 'EMAIL', 'BIRTHDAY'
    COMMENT = 'PII classification tag. Triggers tag-based masking policies.';

CREATE OR REPLACE TAG DATA_DOMAIN
    ALLOWED_VALUES 'Sales', 'Customer', 'Product'
    COMMENT = 'Business domain classification for tables.';

CREATE OR REPLACE TAG DATA_CLASSIFICATION
    ALLOWED_VALUES 'Public', 'Internal', 'Restricted'
    COMMENT = 'Data sensitivity level.';

CREATE OR REPLACE TAG COST_CENTER
    COMMENT = 'Cost attribution tag (free-form).';
```

The setup needs to grant TB\_ADMIN ownership of the TASTYBYTES\_GOVERNANCE database and schema so these CREATE TAG statements work, and grant APPLY TAG ON ACCOUNT.

---

### Task 5: Add masking policies and tag-based policy assignment in 01\_setup.sql

Create the two masking policies in TASTYBYTES\_GOVERNANCE.GOVERNANCE:

```sql
CREATE OR REPLACE MASKING POLICY TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII_STRING_MASK
    AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN IS_ROLE_IN_SESSION('TB_ADMIN') OR IS_ROLE_IN_SESSION('TB_DATA_ENGINEER')
        THEN val
        ELSE '**MASKED**'
    END
    COMMENT = 'Masks VARCHAR PII columns for non-privileged roles';

CREATE OR REPLACE MASKING POLICY TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII_DATE_MASK
    AS (val DATE) RETURNS DATE ->
    CASE
        WHEN IS_ROLE_IN_SESSION('TB_ADMIN') OR IS_ROLE_IN_SESSION('TB_DATA_ENGINEER')
        THEN val
        ELSE '1900-01-01'::DATE
    END
    COMMENT = 'Masks DATE PII columns for non-privileged roles';
```

Then assign the masking policies to the TASTY\_PII tag values:

```sql
ALTER TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII
    SET MASKING POLICY TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII_STRING_MASK;
```

Note: Tag-based masking requires Enterprise edition. The string policy covers tag values NAME, PHONE\_NUMBER, EMAIL. The date policy covers BIRTHDAY. Since a tag can only have one masking policy per data type, this is set up as: string mask on the tag (covers all VARCHAR columns tagged with TASTY\_PII), and the date mask needs to be assigned separately for DATE columns. The approach will use:

```sql
ALTER TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII
    SET MASKING POLICY TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII_STRING_MASK;

ALTER TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII
    SET MASKING POLICY TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII_DATE_MASK;
```

Snowflake allows multiple masking policies on a tag if they cover different data types.

---

### Task 6: Add APPLY TAG and EXECUTE TASK privileges in 01\_setup.sql

```sql
USE ROLE ACCOUNTADMIN;
GRANT APPLY TAG ON ACCOUNT TO ROLE TB_ADMIN;
GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE TB_ADMIN;  -- already exists, keep it
GRANT EXECUTE TASK ON ACCOUNT TO ROLE TB_DATA_ENGINEER;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE TB_ADMIN;
```

---

### Task 7: Add pre-populated staging tables (DDL) in 01\_setup.sql

Add DDL for STG\_LOCATION and STG\_COUNTRY at the end of setup, after tags/policies:

```sql
-- STG_COUNTRY: cleaned country reference
CREATE OR REPLACE TABLE TASTYBYTES_REFINED.STAGING.STG_COUNTRY (
    COUNTRY_ID      NUMBER COMMENT 'Unique identifier for the country',
    COUNTRY         VARCHAR COMMENT 'Full country name',
    ISO_CURRENCY    VARCHAR COMMENT 'ISO 4217 currency code',
    ISO_COUNTRY     VARCHAR COMMENT 'ISO 3166-1 alpha-2 country code',
    CITY_ID         NUMBER COMMENT 'Unique identifier for the city',
    CITY            VARCHAR COMMENT 'City name',
    CITY_POPULATION NUMBER COMMENT 'Population of the city (cast from TEXT)',
    _LOAD_TS        TIMESTAMP_NTZ COMMENT 'Load timestamp',
    _SOURCE_TABLE   VARCHAR(100) COMMENT 'Source table name'
) COMMENT = 'Cleaned country reference data. Source: TASTYBYTES_RAW.RAW.COUNTRY';

-- STG_LOCATION: cleaned location reference
CREATE OR REPLACE TABLE TASTYBYTES_REFINED.STAGING.STG_LOCATION (
    LOCATION_ID      NUMBER COMMENT 'Unique identifier for the location',
    PLACEKEY         VARCHAR COMMENT 'Universal place identifier',
    LOCATION         VARCHAR COMMENT 'Location name or address',
    CITY             VARCHAR COMMENT 'City name',
    REGION           VARCHAR COMMENT 'State, province, or region',
    ISO_COUNTRY_CODE VARCHAR COMMENT 'ISO country code',
    COUNTRY          VARCHAR COMMENT 'Full country name',
    _LOAD_TS         TIMESTAMP_NTZ COMMENT 'Load timestamp',
    _SOURCE_TABLE    VARCHAR(100) COMMENT 'Source table name'
) COMMENT = 'Cleaned location data. Source: TASTYBYTES_RAW.RAW.LOCATION';
```

---

### Task 8: Add pre-populated warehouse tables (DDL) in 01\_setup.sql

```sql
-- DIM_LOCATION: location dimension joining location and country
CREATE OR REPLACE TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_LOCATION (
    DIM_LOCATION_SK  NUMBER AUTOINCREMENT START 1 INCREMENT 1 COMMENT 'Surrogate key',
    LOCATION_ID      NUMBER COMMENT 'Natural key from source',
    PLACEKEY         VARCHAR COMMENT 'Universal place identifier',
    LOCATION         VARCHAR COMMENT 'Location name or address',
    CITY             VARCHAR COMMENT 'City name',
    REGION           VARCHAR COMMENT 'State, province, or region',
    ISO_COUNTRY_CODE VARCHAR COMMENT 'ISO country code',
    COUNTRY          VARCHAR COMMENT 'Full country name',
    ISO_CURRENCY     VARCHAR COMMENT 'ISO currency code for the country',
    CITY_POPULATION  NUMBER COMMENT 'City population',
    _DW_LOAD_TS      TIMESTAMP_NTZ COMMENT 'Warehouse load timestamp',
    _DW_UPDATE_TS    TIMESTAMP_NTZ COMMENT 'Warehouse update timestamp'
) COMMENT = 'Location dimension combining location and country attributes.';

-- DIM_DATE: generated date dimension 2019-2025
CREATE OR REPLACE TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_DATE (
    DIM_DATE_SK      NUMBER AUTOINCREMENT START 1 INCREMENT 1 COMMENT 'Surrogate key',
    DATE             DATE COMMENT 'Calendar date',
    YEAR             NUMBER COMMENT 'Calendar year',
    QUARTER          VARCHAR COMMENT 'Quarter label (Q1-Q4)',
    MONTH_NAME       VARCHAR COMMENT 'Full month name',
    MONTH_START_DATE DATE COMMENT 'First day of the month',
    MONTH_NUMBER     NUMBER COMMENT 'Month number (1-12)',
    WEEK_OF_YEAR     NUMBER COMMENT 'ISO week of year',
    DAY_OF_MONTH     NUMBER COMMENT 'Day of month (1-31)',
    DAY_OF_WEEK      NUMBER COMMENT 'Day of week (0=Mon, 6=Sun)',
    DAY_NAME         VARCHAR COMMENT 'Day name (Monday-Sunday)',
    IS_WEEKEND       BOOLEAN COMMENT 'TRUE if Saturday or Sunday',
    _DW_LOAD_TS      TIMESTAMP_NTZ COMMENT 'Warehouse load timestamp',
    _DW_UPDATE_TS    TIMESTAMP_NTZ COMMENT 'Warehouse update timestamp'
) COMMENT = 'Standard date dimension covering 2019-2025.';
```

This defines the exact column names that the model answer SQL (module2\_warehouse.sql) references in its joins — particularly `DIM_LOCATION.LOCATION_ID`, `DIM_DATE.DATE`, and the surrogate keys.

---

### Task 9: Add pre-populated table data loads in 02\_dataload.sql

After the existing RAW data loads, add:

**STG\_COUNTRY load:**

```sql
INSERT INTO TASTYBYTES_REFINED.STAGING.STG_COUNTRY
SELECT COUNTRY_ID, TRIM(COUNTRY), TRIM(ISO_CURRENCY), TRIM(ISO_COUNTRY),
       CITY_ID, TRIM(CITY), TRY_CAST(CITY_POPULATION AS NUMBER),
       CURRENT_TIMESTAMP(), 'COUNTRY'
FROM TASTYBYTES_RAW.RAW.COUNTRY;
```

**STG\_LOCATION load:**

```sql
INSERT INTO TASTYBYTES_REFINED.STAGING.STG_LOCATION
SELECT LOCATION_ID, TRIM(PLACEKEY), TRIM(LOCATION), TRIM(CITY),
       TRIM(REGION), TRIM(ISO_COUNTRY_CODE), TRIM(COUNTRY),
       CURRENT_TIMESTAMP(), 'LOCATION'
FROM TASTYBYTES_RAW.RAW.LOCATION;
```

**DIM\_LOCATION load** (joining location with country for city population and currency):

```sql
INSERT INTO TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_LOCATION (
    LOCATION_ID, PLACEKEY, LOCATION, CITY, REGION, ISO_COUNTRY_CODE,
    COUNTRY, ISO_CURRENCY, CITY_POPULATION, _DW_LOAD_TS, _DW_UPDATE_TS)
SELECT l.LOCATION_ID, l.PLACEKEY, l.LOCATION, l.CITY, l.REGION,
       l.ISO_COUNTRY_CODE, l.COUNTRY, c.ISO_CURRENCY, c.CITY_POPULATION,
       CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
FROM TASTYBYTES_REFINED.STAGING.STG_LOCATION l
LEFT JOIN (SELECT DISTINCT CITY, COUNTRY, ISO_CURRENCY, CITY_POPULATION
           FROM TASTYBYTES_REFINED.STAGING.STG_COUNTRY) c
  ON l.CITY = c.CITY AND l.COUNTRY = c.COUNTRY;
```

**DIM\_DATE load** (generate dates from 2019-01-01 to 2025-12-31):

```sql
INSERT INTO TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_DATE (
    DATE, YEAR, QUARTER, MONTH_NAME, MONTH_START_DATE, MONTH_NUMBER,
    WEEK_OF_YEAR, DAY_OF_MONTH, DAY_OF_WEEK, DAY_NAME, IS_WEEKEND,
    _DW_LOAD_TS, _DW_UPDATE_TS)
SELECT
    d.DATE_VALUE,
    YEAR(d.DATE_VALUE),
    'Q' || QUARTER(d.DATE_VALUE),
    MONTHNAME(d.DATE_VALUE),
    DATE_TRUNC('MONTH', d.DATE_VALUE),
    MONTH(d.DATE_VALUE),
    WEEKOFYEAR(d.DATE_VALUE),
    DAY(d.DATE_VALUE),
    DAYOFWEEKISO(d.DATE_VALUE) - 1,
    DAYNAME(d.DATE_VALUE),
    DAYOFWEEKISO(d.DATE_VALUE) IN (6, 7),
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
FROM (
    SELECT DATEADD(DAY, SEQ4(), '2019-01-01'::DATE) AS DATE_VALUE
    FROM TABLE(GENERATOR(ROWCOUNT => 2557))
) d
WHERE d.DATE_VALUE <= '2025-12-31';
```

---

### Task 10: Remove unused schemas and update validation checks in 01\_setup.sql

Remove creation of and grants on:

- `TASTYBYTES_REFINED.GOVERNANCE`
- `TASTYBYTES_REFINED.PIPELINES`
- `TASTYBYTES_CONSUMPTION.FUNCTIONS`

Update the final validation query at the bottom of 01\_setup.sql to check for the correct schema names (WAREHOUSE instead of DW, add TASTYBYTES\_GOVERNANCE checks).

---

## Verification

After applying changes, run both scripts on a fresh trial account and verify:

1. `SHOW DATABASES` returns TASTYBYTES\_RAW, TASTYBYTES\_REFINED, TASTYBYTES\_CONSUMPTION, TASTYBYTES\_GOVERNANCE
2. `SHOW SCHEMAS IN DATABASE TASTYBYTES_CONSUMPTION` includes WAREHOUSE and ANALYTICS
3. `SHOW SCHEMAS IN DATABASE TASTYBYTES_GOVERNANCE` includes GOVERNANCE
4. `SHOW ROLES` includes TB\_ADMIN, TB\_DATA\_ENGINEER, TB\_ANALYST
5. `SHOW TAGS IN SCHEMA TASTYBYTES_GOVERNANCE.GOVERNANCE` returns 4 tags
6. `SHOW MASKING POLICIES IN SCHEMA TASTYBYTES_GOVERNANCE.GOVERNANCE` returns 2 policies
7. `SELECT COUNT(*) FROM TASTYBYTES_REFINED.STAGING.STG_LOCATION` returns 13,093
8. `SELECT COUNT(*) FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_DATE` returns 2,557 (7 years of dates)
9. `USE ROLE TB_DATA_ENGINEER; SELECT 1;` succeeds
10. `USE ROLE TB_ANALYST; SELECT 1;` succeeds
11. Run module1\_staging.sql model answer end-to-end as a smoke test

## Critical Files

- setup/01\_setup.sql — All structural changes: databases, schemas, roles, warehouses, tags, policies, privileges, pre-populated DDL
- setup/02\_dataload.sql — Pre-populated table data inserts (STG\_COUNTRY, STG\_LOCATION, DIM\_LOCATION, DIM\_DATE)
- design-brief.md — Source of truth for all object names, schemas, and specifications
- model\_answer/module2\_warehouse.sql — References DIM\_LOCATION and DIM\_DATE column names in SP\_LOAD\_FACT\_ORDER\_LINE joins
