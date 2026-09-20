/***************************************************************************************************
  _______           _            ____          _             
 |__   __|         | |          |  _ \        | |            
    | |  __ _  ___ | |_  _   _  | |_) | _   _ | |_  ___  ___ 
    | | / _` |/ __|| __|| | | | |  _ < | | | || __|/ _ \/ __|
    | || (_| |\__ \| |_ | |_| | | |_) || |_| || |_|  __/\__ \
    |_| \__,_||___/ \__| \__, | |____/  \__, | \__|\___||___/
                          __/ |          __/ |               
                         |___/          |___/            
***************************************************************************************************/

USE ROLE ACCOUNTADMIN;

-- Set up cross region inference for AI calls.
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

USE ROLE sysadmin;
-- =============================
-- RESET (uncomment to tear down)
-- =============================
--  USE ROLE ACCOUNTADMIN;
--  DROP WAREHOUSE IF EXISTS tb_de_wh;
--  DROP WAREHOUSE IF EXISTS tb_analyst_wh;
--  DROP DATABASE IF EXISTS TASTYBYTES_RAW;
--  DROP DATABASE IF EXISTS TASTYBYTES_REFINED;
--  DROP DATABASE IF EXISTS TASTYBYTES_CONSUMPTION;
--  DROP DATABASE IF EXISTS TASTYBYTES_GOVERNANCE;
--  DROP ROLE IF EXISTS tb_admin;
--  DROP ROLE IF EXISTS tb_data_engineer;
--  DROP ROLE IF EXISTS tb_analyst;

/*--
 • database, schema and warehouse creation
--*/

-- training databases
CREATE OR REPLACE DATABASE TASTYBYTES_RAW;
CREATE OR REPLACE DATABASE TASTYBYTES_REFINED;
CREATE OR REPLACE DATABASE TASTYBYTES_CONSUMPTION;
CREATE OR REPLACE DATABASE TASTYBYTES_GOVERNANCE;

-- RAW landed source
CREATE OR REPLACE SCHEMA TASTYBYTES_RAW.RAW;

-- REFINED: staging layer
CREATE OR REPLACE SCHEMA TASTYBYTES_REFINED.STAGING;

-- CONSUMPTION: warehouse (dimensional model) and analytics (data products)
CREATE OR REPLACE SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE;
CREATE OR REPLACE SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS;

-- GOVERNANCE: tags, masking policies
CREATE OR REPLACE SCHEMA TASTYBYTES_GOVERNANCE.GOVERNANCE;

-- create warehouses
CREATE OR REPLACE WAREHOUSE tb_de_wh
    WAREHOUSE_SIZE = 'large' -- Large for initial data load - scaled down to XSmall at end of dataload script
    WAREHOUSE_TYPE = 'standard'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
COMMENT = 'Data engineering warehouse for TastyBytes pipeline development';

CREATE OR REPLACE WAREHOUSE tb_analyst_wh
    WAREHOUSE_SIZE = 'xsmall'
    WAREHOUSE_TYPE = 'standard'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
COMMENT = 'Analyst warehouse for reporting queries';


/*--
 • role creation
--*/
USE ROLE securityadmin;

CREATE ROLE IF NOT EXISTS tb_admin
    COMMENT = 'TastyBytes admin — owns governance objects, manages access';

CREATE ROLE IF NOT EXISTS tb_data_engineer
    COMMENT = 'TastyBytes data engineer — builds and runs pipelines';

CREATE ROLE IF NOT EXISTS tb_analyst
    COMMENT = 'TastyBytes analyst — consumes reporting views (PII masked)';

-- role hierarchy: tb_analyst -> tb_data_engineer -> tb_admin -> sysadmin
GRANT ROLE tb_analyst TO ROLE tb_data_engineer;
GRANT ROLE tb_data_engineer TO ROLE tb_admin;
GRANT ROLE tb_admin TO ROLE sysadmin;

-- grant roles to current user so they can USE ROLE
SET current_username = CURRENT_USER();
GRANT ROLE tb_admin TO USER IDENTIFIER($current_username);
GRANT ROLE tb_data_engineer TO USER IDENTIFIER($current_username);
GRANT ROLE tb_analyst TO USER IDENTIFIER($current_username);


/*--
 • privilege grants
--*/
USE ROLE accountadmin;

GRANT IMPORTED PRIVILEGES ON DATABASE snowflake TO ROLE tb_admin;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE tb_admin;
GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE tb_admin;
GRANT APPLY TAG ON ACCOUNT TO ROLE tb_admin;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE tb_admin;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE tb_data_engineer;

USE ROLE securityadmin;

-- ===== TB_ADMIN grants =====
-- Database usage
GRANT USAGE ON DATABASE TASTYBYTES_RAW TO ROLE tb_admin;
GRANT USAGE ON DATABASE TASTYBYTES_REFINED TO ROLE tb_admin;
GRANT USAGE ON DATABASE TASTYBYTES_CONSUMPTION TO ROLE tb_admin;
GRANT USAGE ON DATABASE TASTYBYTES_GOVERNANCE TO ROLE tb_admin;

GRANT USAGE ON ALL SCHEMAS IN DATABASE TASTYBYTES_RAW TO ROLE tb_admin;
GRANT USAGE ON ALL SCHEMAS IN DATABASE TASTYBYTES_REFINED TO ROLE tb_admin;
GRANT USAGE ON ALL SCHEMAS IN DATABASE TASTYBYTES_CONSUMPTION TO ROLE tb_admin;
GRANT USAGE ON ALL SCHEMAS IN DATABASE TASTYBYTES_GOVERNANCE TO ROLE tb_admin;

-- Schema-level ALL for tb_admin
GRANT ALL ON SCHEMA TASTYBYTES_RAW.RAW TO ROLE tb_admin;
GRANT ALL ON SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_admin;
GRANT ALL ON SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_admin;
GRANT ALL ON SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS TO ROLE tb_admin;
GRANT ALL ON SCHEMA TASTYBYTES_GOVERNANCE.GOVERNANCE TO ROLE tb_admin;

-- Warehouse grants for tb_admin
GRANT OWNERSHIP ON WAREHOUSE tb_de_wh TO ROLE tb_admin COPY CURRENT GRANTS;
GRANT ALL ON WAREHOUSE tb_de_wh TO ROLE tb_admin;
GRANT OWNERSHIP ON WAREHOUSE tb_analyst_wh TO ROLE tb_admin COPY CURRENT GRANTS;
GRANT ALL ON WAREHOUSE tb_analyst_wh TO ROLE tb_admin;

-- Future grants for tb_admin
GRANT ALL ON FUTURE TABLES IN SCHEMA TASTYBYTES_RAW.RAW TO ROLE tb_admin;
GRANT ALL ON FUTURE TABLES IN SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_admin;
GRANT ALL ON FUTURE VIEWS IN SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_admin;
GRANT ALL ON FUTURE PROCEDURES IN SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_admin;
GRANT ALL ON FUTURE TASKS IN SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_admin;
GRANT ALL ON FUTURE TABLES IN SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_admin;
GRANT ALL ON FUTURE VIEWS IN SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_admin;
GRANT ALL ON FUTURE PROCEDURES IN SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_admin;
GRANT ALL ON FUTURE TASKS IN SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_admin;
GRANT ALL ON FUTURE TABLES IN SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS TO ROLE tb_admin;
GRANT ALL ON FUTURE VIEWS IN SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS TO ROLE tb_admin;

-- ===== TB_DATA_ENGINEER grants =====
-- Database usage
GRANT USAGE ON DATABASE TASTYBYTES_RAW TO ROLE tb_data_engineer;
GRANT USAGE ON DATABASE TASTYBYTES_REFINED TO ROLE tb_data_engineer;
GRANT USAGE ON DATABASE TASTYBYTES_CONSUMPTION TO ROLE tb_data_engineer;
GRANT USAGE ON DATABASE TASTYBYTES_GOVERNANCE TO ROLE tb_data_engineer;

-- Schema usage
GRANT USAGE ON SCHEMA TASTYBYTES_RAW.RAW TO ROLE tb_data_engineer;
GRANT USAGE ON SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_data_engineer;
GRANT USAGE ON SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_data_engineer;
GRANT USAGE ON SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS TO ROLE tb_data_engineer;
GRANT USAGE ON SCHEMA TASTYBYTES_GOVERNANCE.GOVERNANCE TO ROLE tb_data_engineer;

-- SELECT on RAW (read-only source)
GRANT SELECT ON ALL TABLES IN SCHEMA TASTYBYTES_RAW.RAW TO ROLE tb_data_engineer;
GRANT SELECT ON FUTURE TABLES IN SCHEMA TASTYBYTES_RAW.RAW TO ROLE tb_data_engineer;

-- CREATE privileges on staging and warehouse schemas
GRANT CREATE TABLE ON SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_data_engineer;
GRANT CREATE PROCEDURE ON SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_data_engineer;
GRANT CREATE TASK ON SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_data_engineer;
GRANT CREATE TABLE ON SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_data_engineer;
GRANT CREATE PROCEDURE ON SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_data_engineer;
GRANT CREATE TASK ON SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_data_engineer;
GRANT CREATE VIEW ON SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS TO ROLE tb_data_engineer;

-- Future grants so tb_data_engineer owns objects it creates
GRANT ALL ON FUTURE TABLES IN SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_data_engineer;
GRANT ALL ON FUTURE PROCEDURES IN SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_data_engineer;
GRANT ALL ON FUTURE TASKS IN SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_data_engineer;
GRANT ALL ON FUTURE TABLES IN SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_data_engineer;
GRANT ALL ON FUTURE PROCEDURES IN SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_data_engineer;
GRANT ALL ON FUTURE TASKS IN SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_data_engineer;
GRANT ALL ON FUTURE VIEWS IN SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS TO ROLE tb_data_engineer;

-- Warehouse usage
GRANT USAGE ON WAREHOUSE tb_de_wh TO ROLE tb_data_engineer;

-- ===== TB_ANALYST grants =====
-- Database and schema usage
GRANT USAGE ON DATABASE TASTYBYTES_CONSUMPTION TO ROLE tb_analyst;
GRANT USAGE ON DATABASE TASTYBYTES_REFINED TO ROLE tb_analyst;
GRANT USAGE ON SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_analyst;
GRANT USAGE ON SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS TO ROLE tb_analyst;
GRANT USAGE ON SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_analyst;

-- SELECT on warehouse and analytics (future grants)
GRANT SELECT ON FUTURE TABLES IN SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE TO ROLE tb_analyst;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS TO ROLE tb_analyst;
GRANT SELECT ON FUTURE TABLES IN SCHEMA TASTYBYTES_REFINED.STAGING TO ROLE tb_analyst;

-- Warehouse usage
GRANT USAGE ON WAREHOUSE tb_analyst_wh TO ROLE tb_analyst;


/*--
 • file format and stage creation
--*/
USE ROLE tb_admin;
USE WAREHOUSE tb_de_wh;

CREATE OR REPLACE FILE FORMAT TASTYBYTES_RAW.RAW.CSV_FF
type = 'csv';

CREATE OR REPLACE STAGE TASTYBYTES_RAW.RAW.S3LOAD_SALES
COMMENT = 'Quickstarts S3 Stage Connection'
DIRECTORY = (
    ENABLE = true
    AUTO_REFRESH = true
  )
url = 's3://sfquickstarts/frostbyte_tastybytes/'
file_format = TASTYBYTES_RAW.RAW.CSV_FF;

CREATE OR REPLACE STAGE TASTYBYTES_RAW.RAW.S3LOAD_REVIEWS
COMMENT = 'Quickstarts S3 Stage Connection'
DIRECTORY = (
    ENABLE = true
    AUTO_REFRESH = true
  )
url = 's3://sfquickstarts/tastybytes-voc/'
file_format = TASTYBYTES_RAW.RAW.CSV_FF;

CREATE OR REPLACE FILE FORMAT TASTYBYTES_RAW.RAW.JSON_IOT_FF
    TYPE = 'JSON'
    COMPRESSION = GZIP
    STRIP_OUTER_ARRAY = TRUE
    IGNORE_UTF8_ERRORS = TRUE
    COMMENT = 'JSON file format for IoT telemetry data ingestion';


/*--
 • RAW zone table build
--*/

CREATE OR REPLACE TABLE TASTYBYTES_RAW.RAW.COUNTRY
(
    country_id NUMBER(18,0) COMMENT 'Unique identifier for the country',
    country VARCHAR(16777216) COMMENT 'Full country name',
    iso_currency VARCHAR(3) COMMENT 'ISO 4217 currency code (e.g. USD, EUR)',
    iso_country VARCHAR(2) COMMENT 'ISO 3166-1 alpha-2 country code (e.g. US, DE)',
    city_id NUMBER(19,0) COMMENT 'Unique identifier for the city',
    city VARCHAR(16777216) COMMENT 'City name',
    city_population VARCHAR(16777216) COMMENT 'Population of the city'
)
COMMENT = 'Geographic reference data linking countries and cities where food trucks operate';

CREATE OR REPLACE TABLE TASTYBYTES_RAW.RAW.FRANCHISE
(
    franchise_id NUMBER(38,0) COMMENT 'Unique identifier for the franchise owner',
    first_name VARCHAR(16777216) COMMENT 'Franchise owner first name',
    last_name VARCHAR(16777216) COMMENT 'Franchise owner last name',
    city VARCHAR(16777216) COMMENT 'City where the franchise is based',
    country VARCHAR(16777216) COMMENT 'Country where the franchise is based',
    e_mail VARCHAR(16777216) COMMENT 'Franchise owner email address',
    phone_number VARCHAR(16777216) COMMENT 'Franchise owner phone number'
)
COMMENT = 'Franchise owner contact and location details';

CREATE OR REPLACE TABLE TASTYBYTES_RAW.RAW.LOCATION
(
    location_id NUMBER(19,0) COMMENT 'Unique identifier for the selling location',
    placekey VARCHAR(16777216) COMMENT 'Universal place identifier (Placekey standard)',
    location VARCHAR(16777216) COMMENT 'Name or address of the location',
    city VARCHAR(16777216) COMMENT 'City of the location',
    region VARCHAR(16777216) COMMENT 'State, province, or region',
    iso_country_code VARCHAR(16777216) COMMENT 'ISO country code for the location',
    country VARCHAR(16777216) COMMENT 'Full country name'
)
COMMENT = 'Physical locations where food trucks serve customers';

CREATE OR REPLACE TABLE TASTYBYTES_RAW.RAW.MENU
(
    menu_id NUMBER(19,0) COMMENT 'Unique identifier for the menu',
    menu_type_id NUMBER(38,0) COMMENT 'Foreign key to the menu type/cuisine category',
    menu_type VARCHAR(16777216) COMMENT 'Menu cuisine type (e.g. BBQ, Tacos, Ice Cream)',
    truck_brand_name VARCHAR(16777216) COMMENT 'Brand name of the food truck',
    menu_item_id NUMBER(38,0) COMMENT 'Unique identifier for the menu item',
    menu_item_name VARCHAR(16777216) COMMENT 'Display name of the menu item',
    item_category VARCHAR(16777216) COMMENT 'High-level item category (e.g. Main, Dessert, Beverage)',
    item_subcategory VARCHAR(16777216) COMMENT 'Granular item subcategory',
    cost_of_goods_usd NUMBER(38,4) COMMENT 'Cost of goods sold in USD',
    sale_price_usd NUMBER(38,4) COMMENT 'Customer-facing sale price in USD',
    menu_item_health_metrics_obj VARIANT COMMENT 'Semi-structured health/nutrition metrics (calories, allergens, etc.)'
)
COMMENT = 'Menu items with pricing, categorization, and health metrics per truck brand';

CREATE OR REPLACE TABLE TASTYBYTES_RAW.RAW.TRUCK
(
    truck_id NUMBER(38,0) COMMENT 'Unique identifier for the truck',
    menu_type_id NUMBER(38,0) COMMENT 'Foreign key to the menu type/cuisine served',
    primary_city VARCHAR(16777216) COMMENT 'Primary operating city',
    region VARCHAR(16777216) COMMENT 'Operating region or state',
    iso_region VARCHAR(16777216) COMMENT 'ISO region code',
    country VARCHAR(16777216) COMMENT 'Operating country',
    iso_country_code VARCHAR(16777216) COMMENT 'ISO country code',
    franchise_flag NUMBER(38,0) COMMENT '1 if franchise-operated, 0 if company-owned',
    year NUMBER(38,0) COMMENT 'Vehicle manufacture year',
    make VARCHAR(16777216) COMMENT 'Vehicle manufacturer (e.g. Ford, Toyota)',
    model VARCHAR(16777216) COMMENT 'Vehicle model name',
    ev_flag NUMBER(38,0) COMMENT '1 if electric vehicle, 0 otherwise',
    franchise_id NUMBER(38,0) COMMENT 'Foreign key to franchise owner (NULL if company-owned)',
    truck_opening_date DATE COMMENT 'Date the truck began operations'
)
COMMENT = 'Food truck fleet details including vehicle info, location, and franchise assignment';

CREATE OR REPLACE TABLE TASTYBYTES_RAW.RAW.ORDER_HEADER
(
    order_id NUMBER(38,0) COMMENT 'Unique identifier for the order',
    truck_id NUMBER(38,0) COMMENT 'Foreign key to the truck that fulfilled the order',
    location_id FLOAT COMMENT 'Foreign key to the selling location',
    customer_id NUMBER(38,0) COMMENT 'Foreign key to the customer',
    discount_id VARCHAR(16777216) COMMENT 'Discount code or identifier applied to the order',
    shift_id NUMBER(38,0) COMMENT 'Identifier for the work shift',
    shift_start_time TIME(9) COMMENT 'Shift start time',
    shift_end_time TIME(9) COMMENT 'Shift end time',
    order_channel VARCHAR(16777216) COMMENT 'Channel used to place the order (e.g. walk-up, app)',
    order_ts TIMESTAMP_NTZ(9) COMMENT 'Timestamp when the order was placed',
    served_ts VARCHAR(16777216) COMMENT 'Timestamp when the order was served',
    order_currency VARCHAR(3) COMMENT 'ISO currency code for the order',
    order_amount NUMBER(38,4) COMMENT 'Subtotal amount before tax and discounts',
    order_tax_amount VARCHAR(16777216) COMMENT 'Tax amount applied to the order',
    order_discount_amount VARCHAR(16777216) COMMENT 'Discount amount applied to the order',
    order_total NUMBER(38,4) COMMENT 'Final order total after tax and discounts'
)
COMMENT = 'Sales transaction headers with truck, customer, timing, and monetary totals';

CREATE OR REPLACE TABLE TASTYBYTES_RAW.RAW.ORDER_DETAIL
(
    order_detail_id NUMBER(38,0) COMMENT 'Unique identifier for the order line item',
    order_id NUMBER(38,0) COMMENT 'Foreign key to the parent order header',
    menu_item_id NUMBER(38,0) COMMENT 'Foreign key to the menu item ordered',
    discount_id VARCHAR(16777216) COMMENT 'Discount applied to this line item',
    line_number NUMBER(38,0) COMMENT 'Sequential line number within the order',
    quantity NUMBER(5,0) COMMENT 'Quantity of the item ordered',
    unit_price NUMBER(38,4) COMMENT 'Price per unit in order currency',
    price NUMBER(38,4) COMMENT 'Total line price (quantity x unit_price)',
    order_item_discount_amount VARCHAR(16777216) COMMENT 'Discount amount for this line item'
)
COMMENT = 'Individual line items within each order linking to menu items and pricing';

CREATE OR REPLACE TABLE TASTYBYTES_RAW.RAW.CUSTOMER_LOYALTY
(
    customer_id NUMBER(38,0) COMMENT 'Unique identifier for the loyalty member',
    first_name VARCHAR(16777216) COMMENT 'Customer first name',
    last_name VARCHAR(16777216) COMMENT 'Customer last name',
    city VARCHAR(16777216) COMMENT 'Customer city of residence',
    country VARCHAR(16777216) COMMENT 'Customer country of residence',
    postal_code VARCHAR(16777216) COMMENT 'Customer postal/ZIP code',
    preferred_language VARCHAR(16777216) COMMENT 'Customer preferred language',
    gender VARCHAR(16777216) COMMENT 'Customer gender',
    favourite_brand VARCHAR(16777216) COMMENT 'Customers preferred food truck brand',
    marital_status VARCHAR(16777216) COMMENT 'Marital status',
    children_count VARCHAR(16777216) COMMENT 'Number of children',
    sign_up_date DATE COMMENT 'Date the customer joined the loyalty program',
    birthday_date DATE COMMENT 'Customer date of birth',
    e_mail VARCHAR(16777216) COMMENT 'Customer email address',
    phone_number VARCHAR(16777216) COMMENT 'Customer phone number'
)
COMMENT = 'Loyalty program members with demographics, preferences, and contact info';

CREATE OR REPLACE TABLE TASTYBYTES_RAW.RAW.TRUCK_REVIEWS
(
    order_id NUMBER(38,0) COMMENT 'Foreign key to the order being reviewed',
    language VARCHAR(16777216) COMMENT 'Language the review was written in',
    source VARCHAR(16777216) COMMENT 'Platform or channel where the review was submitted',
    review VARCHAR(16777216) COMMENT 'Full text of the customer review',
    review_id NUMBER(18,0) COMMENT 'Unique identifier for the review'
)
COMMENT = 'Customer reviews submitted for food truck orders across multiple languages';


/*--
 • governance objects: tags and masking policies
--*/
USE ROLE tb_admin;
USE SCHEMA TASTYBYTES_GOVERNANCE.GOVERNANCE;

-- Enterprise tags
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

-- Masking policies
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

-- Assign masking policies to the TASTY_PII tag (tag-based masking)
ALTER TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII
    SET MASKING POLICY TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII_STRING_MASK;

ALTER TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII
    SET MASKING POLICY TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII_DATE_MASK;


/*--
 • pre-populated staging tables (DDL only — data loaded by 02_dataload.sql)
--*/
USE ROLE tb_admin;

CREATE OR REPLACE TABLE TASTYBYTES_REFINED.STAGING.STG_COUNTRY (
    COUNTRY_ID      NUMBER        COMMENT 'Unique identifier for the country',
    COUNTRY         VARCHAR       COMMENT 'Full country name',
    ISO_CURRENCY    VARCHAR       COMMENT 'ISO 4217 currency code',
    ISO_COUNTRY     VARCHAR       COMMENT 'ISO 3166-1 alpha-2 country code',
    CITY_ID         NUMBER        COMMENT 'Unique identifier for the city',
    CITY            VARCHAR       COMMENT 'City name',
    CITY_POPULATION NUMBER        COMMENT 'Population of the city (cast from TEXT)',
    _LOAD_TS        TIMESTAMP_NTZ COMMENT 'Load timestamp',
    _SOURCE_TABLE   VARCHAR(100)  COMMENT 'Source table name'
) COMMENT = 'Pre-created: Cleaned country reference data. Source: TASTYBYTES_RAW.RAW.COUNTRY';

CREATE OR REPLACE TABLE TASTYBYTES_REFINED.STAGING.STG_LOCATION (
    LOCATION_ID      NUMBER        COMMENT 'Unique identifier for the location',
    PLACEKEY         VARCHAR       COMMENT 'Universal place identifier',
    LOCATION         VARCHAR       COMMENT 'Location name or address',
    CITY             VARCHAR       COMMENT 'City name',
    REGION           VARCHAR       COMMENT 'State, province, or region',
    ISO_COUNTRY_CODE VARCHAR       COMMENT 'ISO country code',
    COUNTRY          VARCHAR       COMMENT 'Full country name',
    _LOAD_TS         TIMESTAMP_NTZ COMMENT 'Load timestamp',
    _SOURCE_TABLE    VARCHAR(100)  COMMENT 'Source table name'
) COMMENT = 'Pre-created: Cleaned location data. Source: TASTYBYTES_RAW.RAW.LOCATION';


/*--
 • pre-populated warehouse tables (DDL only — data loaded by 02_dataload.sql)
--*/
CREATE OR REPLACE TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_LOCATION (
    DIM_LOCATION_SK  NUMBER AUTOINCREMENT START 1 INCREMENT 1 COMMENT 'Surrogate key',
    LOCATION_ID      NUMBER        COMMENT 'Natural key from source',
    PLACEKEY         VARCHAR       COMMENT 'Universal place identifier',
    LOCATION         VARCHAR       COMMENT 'Location name or address',
    CITY             VARCHAR       COMMENT 'City name',
    REGION           VARCHAR       COMMENT 'State, province, or region',
    ISO_COUNTRY_CODE VARCHAR       COMMENT 'ISO country code',
    COUNTRY          VARCHAR       COMMENT 'Full country name',
    ISO_CURRENCY     VARCHAR       COMMENT 'ISO currency code for the country',
    CITY_POPULATION  NUMBER        COMMENT 'City population',
    _DW_LOAD_TS      TIMESTAMP_NTZ COMMENT 'Warehouse load timestamp',
    _DW_UPDATE_TS    TIMESTAMP_NTZ COMMENT 'Warehouse update timestamp'
) COMMENT = 'Pre-created: Location dimension combining location and country attributes.';

CREATE OR REPLACE TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_DATE (
    DIM_DATE_SK      NUMBER AUTOINCREMENT START 1 INCREMENT 1 COMMENT 'Surrogate key',
    DATE             DATE          COMMENT 'Calendar date',
    YEAR             NUMBER        COMMENT 'Calendar year',
    QUARTER          VARCHAR       COMMENT 'Quarter label (Q1-Q4)',
    MONTH_NAME       VARCHAR       COMMENT 'Full month name',
    MONTH_START_DATE DATE          COMMENT 'First day of the month',
    MONTH_NUMBER     NUMBER        COMMENT 'Month number (1-12)',
    WEEK_OF_YEAR     NUMBER        COMMENT 'ISO week of year',
    DAY_OF_MONTH     NUMBER        COMMENT 'Day of month (1-31)',
    DAY_OF_WEEK      NUMBER        COMMENT 'Day of week (0=Mon, 6=Sun)',
    DAY_NAME         VARCHAR       COMMENT 'Day name (Monday-Sunday)',
    IS_WEEKEND       BOOLEAN       COMMENT 'TRUE if Saturday or Sunday',
    _DW_LOAD_TS      TIMESTAMP_NTZ COMMENT 'Warehouse load timestamp',
    _DW_UPDATE_TS    TIMESTAMP_NTZ COMMENT 'Warehouse update timestamp'
) COMMENT = 'Pre-created: Standard date dimension covering 2019-2025.';

-- Grant SELECT on pre-populated tables to tb_analyst
GRANT SELECT ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_LOCATION TO ROLE tb_analyst;
GRANT SELECT ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_DATE TO ROLE tb_analyst;
GRANT SELECT ON TABLE TASTYBYTES_REFINED.STAGING.STG_LOCATION TO ROLE tb_analyst;
GRANT SELECT ON TABLE TASTYBYTES_REFINED.STAGING.STG_COUNTRY TO ROLE tb_analyst;


/*--
 ============================================================================
 SET UP CHECK
 ============================================================================
--*/
USE ROLE tb_admin;
WITH database_check AS (
    SELECT
        1 AS sort_order,
        'DATABASES' AS object_type,
        COUNT(*)::VARCHAR || ' of 4 databases' AS object_name,
        CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL' END AS status
    FROM information_schema.databases
    WHERE database_name IN ('TASTYBYTES_RAW', 'TASTYBYTES_REFINED', 'TASTYBYTES_CONSUMPTION', 'TASTYBYTES_GOVERNANCE')
),
schema_check_raw AS (
    SELECT 2 AS sort_order, 'SCHEMAS (RAW)' AS object_type,
        COUNT(*)::VARCHAR || ' of 1 schemas' AS object_name,
        CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS status
    FROM TASTYBYTES_RAW.information_schema.schemata WHERE schema_name = 'RAW'
),
schema_check_refined AS (
    SELECT 3 AS sort_order, 'SCHEMAS (REFINED)' AS object_type,
        COUNT(*)::VARCHAR || ' of 1 schemas' AS object_name,
        CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS status
    FROM TASTYBYTES_REFINED.information_schema.schemata WHERE schema_name = 'STAGING'
),
schema_check_consumption AS (
    SELECT 4 AS sort_order, 'SCHEMAS (CONSUMPTION)' AS object_type,
        COUNT(*)::VARCHAR || ' of 2 schemas' AS object_name,
        CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END AS status
    FROM TASTYBYTES_CONSUMPTION.information_schema.schemata WHERE schema_name IN ('WAREHOUSE', 'ANALYTICS')
),
schema_check_governance AS (
    SELECT 5 AS sort_order, 'SCHEMAS (GOVERNANCE)' AS object_type,
        COUNT(*)::VARCHAR || ' of 1 schemas' AS object_name,
        CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS status
    FROM TASTYBYTES_GOVERNANCE.information_schema.schemata WHERE schema_name = 'GOVERNANCE'
),
table_check_raw AS (
    SELECT 6 AS sort_order, 'TABLES (RAW)' AS object_type,
        COUNT(*)::VARCHAR || ' of 9 tables' AS object_name,
        CASE WHEN COUNT(*) = 9 THEN 'PASS' ELSE 'FAIL' END AS status
    FROM TASTYBYTES_RAW.information_schema.tables
    WHERE table_schema = 'RAW' AND table_type = 'BASE TABLE'
      AND table_name IN ('COUNTRY','FRANCHISE','LOCATION','MENU','TRUCK','ORDER_HEADER','ORDER_DETAIL','CUSTOMER_LOYALTY','TRUCK_REVIEWS')
),
table_check_staging AS (
    SELECT 7 AS sort_order, 'TABLES (PRE-POP STAGING)' AS object_type,
        COUNT(*)::VARCHAR || ' of 2 tables' AS object_name,
        CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END AS status
    FROM TASTYBYTES_REFINED.information_schema.tables
    WHERE table_schema = 'STAGING' AND table_name IN ('STG_LOCATION', 'STG_COUNTRY')
),
table_check_warehouse AS (
    SELECT 8 AS sort_order, 'TABLES (PRE-POP WAREHOUSE)' AS object_type,
        COUNT(*)::VARCHAR || ' of 2 tables' AS object_name,
        CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END AS status
    FROM TASTYBYTES_CONSUMPTION.information_schema.tables
    WHERE table_schema = 'WAREHOUSE' AND table_name IN ('DIM_LOCATION', 'DIM_DATE')
),
role_check AS (
    SELECT 9 AS sort_order, 'ROLES' AS object_type,
        'tb_admin, tb_data_engineer, tb_analyst' AS object_name,
        'CHECK MANUALLY' AS status
),
tag_check AS (
    SELECT 10 AS sort_order, 'TAGS (GOVERNANCE)' AS object_type,
        COUNT(*)::VARCHAR || ' of 4 tags' AS object_name,
        CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL' END AS status
    FROM TASTYBYTES_GOVERNANCE.information_schema.tags
    WHERE tag_schema = 'GOVERNANCE'
),
warehouse_check AS (
    SELECT 11 AS sort_order, 'WAREHOUSES' AS object_type,
        'tb_de_wh, tb_analyst_wh' AS object_name,
        'CHECK MANUALLY' AS status
)
SELECT * FROM database_check UNION ALL
SELECT * FROM schema_check_raw UNION ALL
SELECT * FROM schema_check_refined UNION ALL
SELECT * FROM schema_check_consumption UNION ALL
SELECT * FROM schema_check_governance UNION ALL
SELECT * FROM table_check_raw UNION ALL
SELECT * FROM table_check_staging UNION ALL
SELECT * FROM table_check_warehouse UNION ALL
SELECT * FROM role_check UNION ALL
SELECT * FROM tag_check UNION ALL
SELECT * FROM warehouse_check
ORDER BY sort_order;
