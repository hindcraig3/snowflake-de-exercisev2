-- =====================================================================
-- MODEL ANSWER: Module 1 — RAW to STAGING
-- All objects created in TASTYBYTES_REFINED.STAGING
-- =====================================================================

USE ROLE TB_DATA_ENGINEER;
USE WAREHOUSE TB_DE_WH;
USE SCHEMA TASTYBYTES_REFINED.STAGING;

-- =============================================================
-- Task 1.2: Create STG_MENU staging table
-- Flattens JSON health metrics into individual columns
-- =============================================================
CREATE OR REPLACE TABLE STG_MENU (
    MENU_ID               NUMBER        COMMENT 'Unique identifier for the menu',
    MENU_TYPE_ID          NUMBER        COMMENT 'Foreign key to menu type/cuisine category',
    MENU_TYPE             VARCHAR       COMMENT 'Menu cuisine type (e.g., BBQ, Tacos, Ice Cream)',
    TRUCK_BRAND_NAME      VARCHAR       COMMENT 'Brand name of the food truck',
    MENU_ITEM_ID          NUMBER        COMMENT 'Unique identifier for the menu item',
    MENU_ITEM_NAME        VARCHAR       COMMENT 'Display name of the menu item',
    ITEM_CATEGORY         VARCHAR       COMMENT 'High-level item category (e.g., Main, Dessert, Beverage)',
    ITEM_SUBCATEGORY      VARCHAR       COMMENT 'Granular item subcategory',
    COST_OF_GOODS_USD     NUMBER(10,2)  COMMENT 'Cost of goods sold in USD',
    SALE_PRICE_USD        NUMBER(10,2)  COMMENT 'Customer-facing sale price in USD',
    IS_DAIRY_FREE_FLAG    BOOLEAN       COMMENT 'TRUE if the item is dairy-free',
    IS_GLUTEN_FREE_FLAG   BOOLEAN       COMMENT 'TRUE if the item is gluten-free',
    IS_HEALTHY_FLAG       BOOLEAN       COMMENT 'TRUE if the item is classified as healthy',
    IS_NUT_FREE_FLAG      BOOLEAN       COMMENT 'TRUE if the item is nut-free',
    INGREDIENTS           VARCHAR       COMMENT 'Comma-separated list of ingredients',
    _LOAD_TS              TIMESTAMP_NTZ COMMENT 'Timestamp when the row was loaded into staging',
    _SOURCE_TABLE         VARCHAR(100)  COMMENT 'Name of the RAW source table'
) COMMENT = 'Staged menu items with flattened health metrics. Source: TASTYBYTES_RAW.RAW.MENU';

-- =============================================================
-- Task 1.3: Create STG_ORDER_HEADER staging table
-- Fixes FLOAT→NUMBER, TEXT→TIMESTAMP, TEXT→NUMBER casts
-- =============================================================
CREATE OR REPLACE TABLE STG_ORDER_HEADER (
    ORDER_ID              NUMBER        COMMENT 'Unique identifier for the order',
    TRUCK_ID              NUMBER        COMMENT 'Foreign key to the truck that fulfilled the order',
    LOCATION_ID           NUMBER        COMMENT 'Foreign key to the selling location (cast from FLOAT)',
    CUSTOMER_ID           NUMBER        COMMENT 'Foreign key to the customer',
    DISCOUNT_ID           VARCHAR       COMMENT 'Discount code applied to the order',
    SHIFT_ID              NUMBER        COMMENT 'Identifier for the work shift',
    SHIFT_START_TIME      TIME          COMMENT 'Shift start time',
    SHIFT_END_TIME        TIME          COMMENT 'Shift end time',
    ORDER_CHANNEL         VARCHAR       COMMENT 'Channel used to place the order',
    ORDER_TS              TIMESTAMP_NTZ COMMENT 'Timestamp when the order was placed',
    SERVED_TS             TIMESTAMP_NTZ COMMENT 'Timestamp when the order was served (cast from TEXT)',
    ORDER_CURRENCY        VARCHAR       COMMENT 'ISO currency code for the order',
    ORDER_AMOUNT          NUMBER(10,2)  COMMENT 'Subtotal before tax and discounts',
    ORDER_TAX_AMOUNT      NUMBER(10,2)  COMMENT 'Tax amount (cast from TEXT)',
    ORDER_DISCOUNT_AMOUNT NUMBER(10,2)  COMMENT 'Discount amount (cast from TEXT)',
    ORDER_TOTAL           NUMBER(10,2)  COMMENT 'Final order total after tax and discounts',
    _LOAD_TS              TIMESTAMP_NTZ COMMENT 'Timestamp when the row was loaded into staging',
    _SOURCE_TABLE         VARCHAR(100)  COMMENT 'Name of the RAW source table'
) COMMENT = 'Staged order headers with corrected data types. Source: TASTYBYTES_RAW.RAW.ORDER_HEADER';

-- =============================================================
-- Task 1.4: Create STG_ORDER_DETAIL staging table
-- Fixes TEXT→NUMBER cast on discount amount
-- =============================================================
CREATE OR REPLACE TABLE STG_ORDER_DETAIL (
    ORDER_DETAIL_ID            NUMBER        COMMENT 'Unique identifier for the order line item',
    ORDER_ID                   NUMBER        COMMENT 'Foreign key to the parent order header',
    MENU_ITEM_ID               NUMBER        COMMENT 'Foreign key to the menu item ordered',
    DISCOUNT_ID                VARCHAR       COMMENT 'Discount applied to this line item',
    LINE_NUMBER                NUMBER        COMMENT 'Sequential line number within the order',
    QUANTITY                   NUMBER        COMMENT 'Quantity of the item ordered',
    UNIT_PRICE                 NUMBER(10,2)  COMMENT 'Price per unit in order currency',
    PRICE                      NUMBER(10,2)  COMMENT 'Total line price (quantity x unit price)',
    ORDER_ITEM_DISCOUNT_AMOUNT NUMBER(10,2)  COMMENT 'Discount amount for this line (cast from TEXT)',
    _LOAD_TS                   TIMESTAMP_NTZ COMMENT 'Timestamp when the row was loaded into staging',
    _SOURCE_TABLE              VARCHAR(100)  COMMENT 'Name of the RAW source table'
) COMMENT = 'Staged order line items with corrected data types. Source: TASTYBYTES_RAW.RAW.ORDER_DETAIL';

-- =============================================================
-- Task 1.5: Create STG_CUSTOMER_LOYALTY staging table
-- Fixes TEXT→NUMBER cast on CHILDREN_COUNT. Contains PII columns.
-- =============================================================
CREATE OR REPLACE TABLE STG_CUSTOMER_LOYALTY (
    CUSTOMER_ID        NUMBER        COMMENT 'Unique identifier for the loyalty member',
    FIRST_NAME         VARCHAR       COMMENT 'Customer first name (PII - masked for non-privileged roles)',
    LAST_NAME          VARCHAR       COMMENT 'Customer last name (PII - masked for non-privileged roles)',
    CITY               VARCHAR       COMMENT 'Customer city of residence',
    COUNTRY            VARCHAR       COMMENT 'Customer country of residence',
    POSTAL_CODE        VARCHAR       COMMENT 'Customer postal/ZIP code',
    PREFERRED_LANGUAGE VARCHAR       COMMENT 'Customer preferred language',
    GENDER             VARCHAR       COMMENT 'Customer gender',
    FAVOURITE_BRAND    VARCHAR       COMMENT 'Customer preferred food truck brand',
    MARITAL_STATUS     VARCHAR       COMMENT 'Marital status',
    CHILDREN_COUNT     NUMBER        COMMENT 'Number of children (cast from TEXT)',
    SIGN_UP_DATE       DATE          COMMENT 'Date the customer joined the loyalty program',
    BIRTHDAY_DATE      DATE          COMMENT 'Customer date of birth (PII - masked for non-privileged roles)',
    E_MAIL             VARCHAR       COMMENT 'Customer email address (PII - masked for non-privileged roles)',
    PHONE_NUMBER       VARCHAR       COMMENT 'Customer phone number (PII - masked for non-privileged roles)',
    _LOAD_TS           TIMESTAMP_NTZ COMMENT 'Timestamp when the row was loaded into staging',
    _SOURCE_TABLE      VARCHAR(100)  COMMENT 'Name of the RAW source table'
) COMMENT = 'Staged customer loyalty data with PII masking applied. Source: TASTYBYTES_RAW.RAW.CUSTOMER_LOYALTY';

-- =============================================================
-- Task 1.6: Apply governance tags (table-level)
-- Requires TB_ADMIN role
-- =============================================================
USE ROLE TB_ADMIN;

ALTER TABLE TASTYBYTES_REFINED.STAGING.STG_MENU
  SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_DOMAIN = 'Product',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_CLASSIFICATION = 'Internal',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.COST_CENTER = 'TASTYBYTES';

ALTER TABLE TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER
  SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_DOMAIN = 'Sales',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_CLASSIFICATION = 'Internal',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.COST_CENTER = 'TASTYBYTES';

ALTER TABLE TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL
  SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_DOMAIN = 'Sales',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_CLASSIFICATION = 'Internal',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.COST_CENTER = 'TASTYBYTES';

ALTER TABLE TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY
  SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_DOMAIN = 'Customer',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_CLASSIFICATION = 'Restricted',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.COST_CENTER = 'TASTYBYTES';

-- =============================================================
-- Task 1.6: Apply PII column tags on STG_CUSTOMER_LOYALTY
-- These trigger the pre-created tag-based masking policies
-- =============================================================
ALTER TABLE TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY
  ALTER COLUMN FIRST_NAME SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII = 'NAME';

ALTER TABLE TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY
  ALTER COLUMN LAST_NAME SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII = 'NAME';

ALTER TABLE TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY
  ALTER COLUMN E_MAIL SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII = 'EMAIL';

ALTER TABLE TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY
  ALTER COLUMN PHONE_NUMBER SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII = 'PHONE_NUMBER';

ALTER TABLE TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY
  ALTER COLUMN BIRTHDAY_DATE SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII = 'BIRTHDAY';

-- =============================================================
-- Task 1.7: Grant access to TB_DATA_ENGINEER
-- =============================================================
GRANT ALL ON TABLE TASTYBYTES_REFINED.STAGING.STG_MENU TO ROLE TB_DATA_ENGINEER;
GRANT ALL ON TABLE TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER TO ROLE TB_DATA_ENGINEER;
GRANT ALL ON TABLE TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL TO ROLE TB_DATA_ENGINEER;
GRANT ALL ON TABLE TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY TO ROLE TB_DATA_ENGINEER;

-- =============================================================
-- Task 1.8: Create load procedure — SP_LOAD_STG_MENU
-- TRUNCATE-reload pattern with JSON flattening
-- =============================================================
USE ROLE TB_DATA_ENGINEER;

CREATE OR REPLACE PROCEDURE TASTYBYTES_REFINED.STAGING.SP_LOAD_STG_MENU()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
BEGIN
  TRUNCATE TABLE TASTYBYTES_REFINED.STAGING.STG_MENU;

  INSERT INTO TASTYBYTES_REFINED.STAGING.STG_MENU (
    MENU_ID, MENU_TYPE_ID, MENU_TYPE, TRUCK_BRAND_NAME,
    MENU_ITEM_ID, MENU_ITEM_NAME, ITEM_CATEGORY, ITEM_SUBCATEGORY,
    COST_OF_GOODS_USD, SALE_PRICE_USD,
    IS_DAIRY_FREE_FLAG, IS_GLUTEN_FREE_FLAG, IS_HEALTHY_FLAG, IS_NUT_FREE_FLAG,
    INGREDIENTS,
    _LOAD_TS, _SOURCE_TABLE
  )
  SELECT
    MENU_ID,
    MENU_TYPE_ID,
    TRIM(MENU_TYPE),
    TRIM(TRUCK_BRAND_NAME),
    MENU_ITEM_ID,
    TRIM(MENU_ITEM_NAME),
    TRIM(ITEM_CATEGORY),
    TRIM(ITEM_SUBCATEGORY),
    COST_OF_GOODS_USD,
    SALE_PRICE_USD,
    IFF(MENU_ITEM_HEALTH_METRICS_OBJ:menu_item_health_metrics[0].is_dairy_free_flag::VARCHAR = 'Y', TRUE, FALSE),
    IFF(MENU_ITEM_HEALTH_METRICS_OBJ:menu_item_health_metrics[0].is_gluten_free_flag::VARCHAR = 'Y', TRUE, FALSE),
    IFF(MENU_ITEM_HEALTH_METRICS_OBJ:menu_item_health_metrics[0].is_healthy_flag::VARCHAR = 'Y', TRUE, FALSE),
    IFF(MENU_ITEM_HEALTH_METRICS_OBJ:menu_item_health_metrics[0].is_nut_free_flag::VARCHAR = 'Y', TRUE, FALSE),
    ARRAY_TO_STRING(MENU_ITEM_HEALTH_METRICS_OBJ:menu_item_health_metrics[0].ingredients, ', '),
    CURRENT_TIMESTAMP(),
    'MENU'
  FROM TASTYBYTES_RAW.RAW.MENU;

  RETURN 'SP_LOAD_STG_MENU completed. Rows loaded: ' || SQLROWCOUNT;
END;

-- =============================================================
-- Task 1.8: Create load procedure — SP_LOAD_STG_ORDER_HEADER
-- TRUNCATE-reload with type casting fixes
-- =============================================================
CREATE OR REPLACE PROCEDURE TASTYBYTES_REFINED.STAGING.SP_LOAD_STG_ORDER_HEADER()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
BEGIN
  TRUNCATE TABLE TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER;

  INSERT INTO TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER (
    ORDER_ID, TRUCK_ID, LOCATION_ID, CUSTOMER_ID, DISCOUNT_ID,
    SHIFT_ID, SHIFT_START_TIME, SHIFT_END_TIME,
    ORDER_CHANNEL, ORDER_TS, SERVED_TS, ORDER_CURRENCY,
    ORDER_AMOUNT, ORDER_TAX_AMOUNT, ORDER_DISCOUNT_AMOUNT, ORDER_TOTAL,
    _LOAD_TS, _SOURCE_TABLE
  )
  SELECT
    ORDER_ID,
    TRUCK_ID,
    LOCATION_ID::NUMBER,
    CUSTOMER_ID,
    TRIM(DISCOUNT_ID),
    SHIFT_ID,
    SHIFT_START_TIME,
    SHIFT_END_TIME,
    TRIM(ORDER_CHANNEL),
    ORDER_TS,
    TRY_CAST(SERVED_TS AS TIMESTAMP_NTZ),
    TRIM(ORDER_CURRENCY),
    ORDER_AMOUNT,
    TRY_CAST(ORDER_TAX_AMOUNT AS NUMBER(10,2)),
    TRY_CAST(ORDER_DISCOUNT_AMOUNT AS NUMBER(10,2)),
    ORDER_TOTAL,
    CURRENT_TIMESTAMP(),
    'ORDER_HEADER'
  FROM TASTYBYTES_RAW.RAW.ORDER_HEADER;

  RETURN 'SP_LOAD_STG_ORDER_HEADER completed. Rows loaded: ' || SQLROWCOUNT;
END;

-- =============================================================
-- Task 1.8: Create load procedure — SP_LOAD_STG_ORDER_DETAIL
-- TRUNCATE-reload with TEXT→NUMBER cast
-- =============================================================
CREATE OR REPLACE PROCEDURE TASTYBYTES_REFINED.STAGING.SP_LOAD_STG_ORDER_DETAIL()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
BEGIN
  TRUNCATE TABLE TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL;

  INSERT INTO TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL (
    ORDER_DETAIL_ID, ORDER_ID, MENU_ITEM_ID, DISCOUNT_ID,
    LINE_NUMBER, QUANTITY, UNIT_PRICE, PRICE, ORDER_ITEM_DISCOUNT_AMOUNT,
    _LOAD_TS, _SOURCE_TABLE
  )
  SELECT
    ORDER_DETAIL_ID,
    ORDER_ID,
    MENU_ITEM_ID,
    TRIM(DISCOUNT_ID),
    LINE_NUMBER,
    QUANTITY,
    UNIT_PRICE,
    PRICE,
    TRY_CAST(ORDER_ITEM_DISCOUNT_AMOUNT AS NUMBER(10,2)),
    CURRENT_TIMESTAMP(),
    'ORDER_DETAIL'
  FROM TASTYBYTES_RAW.RAW.ORDER_DETAIL;

  RETURN 'SP_LOAD_STG_ORDER_DETAIL completed. Rows loaded: ' || SQLROWCOUNT;
END;

-- =============================================================
-- Task 1.8: Create load procedure — SP_LOAD_STG_CUSTOMER_LOYALTY
-- TRUNCATE-reload with TEXT→NUMBER cast
-- =============================================================
CREATE OR REPLACE PROCEDURE TASTYBYTES_REFINED.STAGING.SP_LOAD_STG_CUSTOMER_LOYALTY()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
BEGIN
  TRUNCATE TABLE TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY;

  INSERT INTO TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY (
    CUSTOMER_ID, FIRST_NAME, LAST_NAME, CITY, COUNTRY, POSTAL_CODE,
    PREFERRED_LANGUAGE, GENDER, FAVOURITE_BRAND, MARITAL_STATUS,
    CHILDREN_COUNT, SIGN_UP_DATE, BIRTHDAY_DATE, E_MAIL, PHONE_NUMBER,
    _LOAD_TS, _SOURCE_TABLE
  )
  SELECT
    CUSTOMER_ID,
    TRIM(FIRST_NAME),
    TRIM(LAST_NAME),
    TRIM(CITY),
    TRIM(COUNTRY),
    TRIM(POSTAL_CODE),
    TRIM(PREFERRED_LANGUAGE),
    TRIM(GENDER),
    TRIM(FAVOURITE_BRAND),
    TRIM(MARITAL_STATUS),
    TRY_CAST(CHILDREN_COUNT AS NUMBER),
    SIGN_UP_DATE,
    BIRTHDAY_DATE,
    TRIM(E_MAIL),
    TRIM(PHONE_NUMBER),
    CURRENT_TIMESTAMP(),
    'CUSTOMER_LOYALTY'
  FROM TASTYBYTES_RAW.RAW.CUSTOMER_LOYALTY;

  RETURN 'SP_LOAD_STG_CUSTOMER_LOYALTY completed. Rows loaded: ' || SQLROWCOUNT;
END;

-- =============================================================
-- Task 1.9: Create task graph — staging pipeline
-- Root task with 4 child tasks. ORDER_DETAIL depends on ORDER_HEADER.
-- =============================================================

-- Root task (never auto-runs — Feb 31 doesn't exist)
CREATE OR REPLACE TASK TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT
  WAREHOUSE = TB_DE_WH
  SCHEDULE = 'USING CRON 0 0 31 2 * UTC'
AS
  SELECT 1;

-- Child tasks
CREATE OR REPLACE TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_MENU
  WAREHOUSE = TB_DE_WH
  AFTER TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT
AS
  CALL TASTYBYTES_REFINED.STAGING.SP_LOAD_STG_MENU();

CREATE OR REPLACE TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_ORDER_HEADER
  WAREHOUSE = TB_DE_WH
  AFTER TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT
AS
  CALL TASTYBYTES_REFINED.STAGING.SP_LOAD_STG_ORDER_HEADER();

CREATE OR REPLACE TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_ORDER_DETAIL
  WAREHOUSE = TB_DE_WH
  AFTER TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_ORDER_HEADER
AS
  CALL TASTYBYTES_REFINED.STAGING.SP_LOAD_STG_ORDER_DETAIL();

CREATE OR REPLACE TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_CUSTOMER_LOYALTY
  WAREHOUSE = TB_DE_WH
  AFTER TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT
AS
  CALL TASTYBYTES_REFINED.STAGING.SP_LOAD_STG_CUSTOMER_LOYALTY();

-- Resume tasks (children first, then root)
ALTER TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_MENU RESUME;
ALTER TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_ORDER_HEADER RESUME;
ALTER TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_ORDER_DETAIL RESUME;
ALTER TASK TASTYBYTES_REFINED.STAGING.TASK_LOAD_STG_CUSTOMER_LOYALTY RESUME;
ALTER TASK TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT RESUME;

-- =============================================================
-- Task 1.10: Execute the task graph
-- =============================================================
EXECUTE TASK TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT;
