-- =====================================================================
-- MODEL ANSWER: Module 2 — STAGING to WAREHOUSE
-- All objects created in TASTYBYTES_CONSUMPTION.WAREHOUSE
-- =====================================================================

USE ROLE TB_DATA_ENGINEER;
USE WAREHOUSE TB_DE_WH;
USE SCHEMA TASTYBYTES_CONSUMPTION.WAREHOUSE;

-- =============================================================
-- Task 2.1: Create DIM_MENU dimension table (SCD Type 2)
-- Tracks changes to pricing and item attributes over time
-- =============================================================
CREATE OR REPLACE TABLE DIM_MENU (
    DIM_MENU_SK         NUMBER AUTOINCREMENT START 1 INCREMENT 1 COMMENT 'Surrogate key (auto-increment)',
    MENU_ITEM_ID        NUMBER        COMMENT 'Natural key — unique menu item identifier from source',
    MENU_ID             NUMBER        COMMENT 'Menu identifier',
    MENU_TYPE_ID        NUMBER        COMMENT 'Menu type/cuisine category identifier',
    MENU_TYPE           VARCHAR       COMMENT 'Cuisine type (e.g., BBQ, Tacos)',
    TRUCK_BRAND_NAME    VARCHAR       COMMENT 'Food truck brand',
    MENU_ITEM_NAME      VARCHAR       COMMENT 'Menu item display name (SCD2 tracked)',
    ITEM_CATEGORY       VARCHAR       COMMENT 'Item category (SCD2 tracked)',
    ITEM_SUBCATEGORY    VARCHAR       COMMENT 'Item subcategory (SCD2 tracked)',
    COST_OF_GOODS_USD   NUMBER(10,2)  COMMENT 'Cost of goods in USD (SCD2 tracked)',
    SALE_PRICE_USD      NUMBER(10,2)  COMMENT 'Sale price in USD (SCD2 tracked)',
    IS_DAIRY_FREE_FLAG  BOOLEAN       COMMENT 'TRUE if dairy-free',
    IS_GLUTEN_FREE_FLAG BOOLEAN       COMMENT 'TRUE if gluten-free',
    IS_HEALTHY_FLAG     BOOLEAN       COMMENT 'TRUE if classified as healthy',
    IS_NUT_FREE_FLAG    BOOLEAN       COMMENT 'TRUE if nut-free',
    INGREDIENTS         VARCHAR       COMMENT 'Comma-separated ingredient list',
    VALID_FROM          TIMESTAMP_NTZ COMMENT 'SCD2: start of validity period',
    VALID_TO            TIMESTAMP_NTZ COMMENT 'SCD2: end of validity (9999-12-31 for current)',
    IS_CURRENT          BOOLEAN       COMMENT 'SCD2: TRUE for the active record version',
    _DW_LOAD_TS         TIMESTAMP_NTZ COMMENT 'Data warehouse load timestamp',
    _DW_UPDATE_TS       TIMESTAMP_NTZ COMMENT 'Data warehouse last update timestamp'
) COMMENT = 'Menu item dimension (SCD Type 2). Tracks price and attribute changes over time.';

-- =============================================================
-- Task 2.2: Create DIM_CUSTOMER dimension table (SCD Type 1)
-- Overwrite on change with soft-delete support
-- =============================================================
CREATE OR REPLACE TABLE DIM_CUSTOMER (
    DIM_CUSTOMER_SK    NUMBER AUTOINCREMENT START 1 INCREMENT 1 COMMENT 'Surrogate key (auto-increment)',
    CUSTOMER_ID        NUMBER        COMMENT 'Natural key — unique customer identifier from source',
    FIRST_NAME         VARCHAR       COMMENT 'Customer first name (PII)',
    LAST_NAME          VARCHAR       COMMENT 'Customer last name (PII)',
    CITY               VARCHAR       COMMENT 'City of residence',
    COUNTRY            VARCHAR       COMMENT 'Country of residence',
    POSTAL_CODE        VARCHAR       COMMENT 'Postal/ZIP code',
    PREFERRED_LANGUAGE VARCHAR       COMMENT 'Preferred language',
    GENDER             VARCHAR       COMMENT 'Gender',
    FAVOURITE_BRAND    VARCHAR       COMMENT 'Preferred food truck brand',
    MARITAL_STATUS     VARCHAR       COMMENT 'Marital status',
    CHILDREN_COUNT     NUMBER        COMMENT 'Number of children',
    SIGN_UP_DATE       DATE          COMMENT 'Loyalty program sign-up date',
    BIRTHDAY_DATE      DATE          COMMENT 'Date of birth (PII)',
    E_MAIL             VARCHAR       COMMENT 'Email address (PII)',
    PHONE_NUMBER       VARCHAR       COMMENT 'Phone number (PII)',
    IS_DELETED         BOOLEAN DEFAULT FALSE COMMENT 'Soft-delete flag — TRUE if removed from source',
    _DW_LOAD_TS        TIMESTAMP_NTZ COMMENT 'Data warehouse load timestamp',
    _DW_UPDATE_TS      TIMESTAMP_NTZ COMMENT 'Data warehouse last update timestamp'
) COMMENT = 'Customer dimension (SCD Type 1). Overwrites on change with soft-delete support.';

-- =============================================================
-- Task 2.3: Create FACT_ORDER_LINE fact table
-- Grain: one row per order line item with surrogate keys to dimensions
-- =============================================================
CREATE OR REPLACE TABLE FACT_ORDER_LINE (
    ORDER_DETAIL_ID     NUMBER        COMMENT 'Natural key — unique order line identifier',
    ORDER_ID            NUMBER        COMMENT 'Degenerate dimension — parent order identifier',
    DIM_MENU_SK         NUMBER        COMMENT 'Surrogate key to DIM_MENU',
    DIM_CUSTOMER_SK     NUMBER        COMMENT 'Surrogate key to DIM_CUSTOMER',
    DIM_LOCATION_SK     NUMBER        COMMENT 'Surrogate key to DIM_LOCATION',
    DIM_DATE_SK         NUMBER        COMMENT 'Surrogate key to DIM_DATE',
    TRUCK_ID            NUMBER        COMMENT 'Degenerate dimension — truck identifier',
    DISCOUNT_ID         VARCHAR       COMMENT 'Degenerate dimension — discount code',
    ORDER_CHANNEL       VARCHAR       COMMENT 'Order channel (e.g., walk-up, app)',
    LINE_NUMBER         NUMBER        COMMENT 'Line number within the order',
    QUANTITY            NUMBER        COMMENT 'Quantity ordered',
    UNIT_PRICE          NUMBER(10,2)  COMMENT 'Price per unit',
    LINE_PRICE          NUMBER(10,2)  COMMENT 'Total line price (quantity x unit price)',
    COGS_AMOUNT         NUMBER(10,2)  COMMENT 'Cost of goods (COST_OF_GOODS_USD x quantity, frozen at load)',
    DISCOUNT_AMOUNT     NUMBER(10,2)  COMMENT 'Line item discount amount',
    ORDER_AMOUNT        NUMBER(10,2)  COMMENT 'Order subtotal before tax and discounts',
    ORDER_TAX_AMOUNT    NUMBER(10,2)  COMMENT 'Order tax amount',
    ORDER_TOTAL         NUMBER(10,2)  COMMENT 'Order total after tax and discounts',
    _DW_LOAD_TS         TIMESTAMP_NTZ COMMENT 'Data warehouse load timestamp',
    _DW_UPDATE_TS       TIMESTAMP_NTZ COMMENT 'Data warehouse last update timestamp'
) COMMENT = 'Order line item fact table. Grain: one row per order detail. Links to menu, customer, location, and date dimensions.';

-- =============================================================
-- Task 2.4: Apply governance tags (table-level)
-- Requires TB_ADMIN role
-- =============================================================
USE ROLE TB_ADMIN;

ALTER TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU
  SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_DOMAIN = 'Product',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_CLASSIFICATION = 'Internal',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.COST_CENTER = 'TASTYBYTES';

ALTER TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER
  SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_DOMAIN = 'Customer',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_CLASSIFICATION = 'Restricted',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.COST_CENTER = 'TASTYBYTES';

ALTER TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE
  SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_DOMAIN = 'Sales',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_CLASSIFICATION = 'Internal',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.COST_CENTER = 'TASTYBYTES';

-- PII tags on DIM_CUSTOMER
ALTER TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER
  ALTER COLUMN FIRST_NAME SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII = 'NAME';
ALTER TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER
  ALTER COLUMN LAST_NAME SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII = 'NAME';
ALTER TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER
  ALTER COLUMN E_MAIL SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII = 'EMAIL';
ALTER TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER
  ALTER COLUMN PHONE_NUMBER SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII = 'PHONE_NUMBER';
ALTER TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER
  ALTER COLUMN BIRTHDAY_DATE SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.TASTY_PII = 'BIRTHDAY';

-- =============================================================
-- Task 2.5: Grant access
-- =============================================================
GRANT ALL ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU TO ROLE TB_DATA_ENGINEER;
GRANT ALL ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER TO ROLE TB_DATA_ENGINEER;
GRANT ALL ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE TO ROLE TB_DATA_ENGINEER;

GRANT SELECT ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU TO ROLE TB_ANALYST;
GRANT SELECT ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER TO ROLE TB_ANALYST;
GRANT SELECT ON TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE TO ROLE TB_ANALYST;

-- =============================================================
-- Task 2.6: Create DIM_MENU load procedure (SCD Type 2 MERGE)
-- Step 1: Close changed records. Step 2: Insert new versions + new items.
-- =============================================================
USE ROLE TB_DATA_ENGINEER;

CREATE OR REPLACE PROCEDURE TASTYBYTES_CONSUMPTION.WAREHOUSE.SP_LOAD_DIM_MENU()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
BEGIN
  -- Step 1: Close existing records where tracked attributes have changed
  MERGE INTO TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU AS tgt
  USING TASTYBYTES_REFINED.STAGING.STG_MENU AS src
    ON tgt.MENU_ITEM_ID = src.MENU_ITEM_ID
   AND tgt.IS_CURRENT = TRUE
  WHEN MATCHED AND (
       tgt.MENU_ITEM_NAME    != src.MENU_ITEM_NAME
    OR tgt.ITEM_CATEGORY     != src.ITEM_CATEGORY
    OR tgt.ITEM_SUBCATEGORY  != src.ITEM_SUBCATEGORY
    OR tgt.COST_OF_GOODS_USD != src.COST_OF_GOODS_USD
    OR tgt.SALE_PRICE_USD    != src.SALE_PRICE_USD
  ) THEN UPDATE SET
    tgt.VALID_TO      = CURRENT_TIMESTAMP(),
    tgt.IS_CURRENT    = FALSE,
    tgt._DW_UPDATE_TS = CURRENT_TIMESTAMP();

  -- Step 2: Insert new versions for changed records and brand-new items
  INSERT INTO TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU (
    MENU_ITEM_ID, MENU_ID, MENU_TYPE_ID, MENU_TYPE, TRUCK_BRAND_NAME,
    MENU_ITEM_NAME, ITEM_CATEGORY, ITEM_SUBCATEGORY,
    COST_OF_GOODS_USD, SALE_PRICE_USD,
    IS_DAIRY_FREE_FLAG, IS_GLUTEN_FREE_FLAG, IS_HEALTHY_FLAG, IS_NUT_FREE_FLAG,
    INGREDIENTS,
    VALID_FROM, VALID_TO, IS_CURRENT,
    _DW_LOAD_TS, _DW_UPDATE_TS
  )
  SELECT
    src.MENU_ITEM_ID, src.MENU_ID, src.MENU_TYPE_ID, src.MENU_TYPE, src.TRUCK_BRAND_NAME,
    src.MENU_ITEM_NAME, src.ITEM_CATEGORY, src.ITEM_SUBCATEGORY,
    src.COST_OF_GOODS_USD, src.SALE_PRICE_USD,
    src.IS_DAIRY_FREE_FLAG, src.IS_GLUTEN_FREE_FLAG, src.IS_HEALTHY_FLAG, src.IS_NUT_FREE_FLAG,
    src.INGREDIENTS,
    CURRENT_TIMESTAMP(),
    '9999-12-31'::TIMESTAMP_NTZ,
    TRUE,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
  FROM TASTYBYTES_REFINED.STAGING.STG_MENU src
  WHERE NOT EXISTS (
    SELECT 1 FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU tgt
    WHERE tgt.MENU_ITEM_ID = src.MENU_ITEM_ID
      AND tgt.IS_CURRENT = TRUE
  );

  RETURN 'SP_LOAD_DIM_MENU completed.';
END;

-- =============================================================
-- Task 2.7: Create DIM_CUSTOMER load procedure (SCD Type 1 MERGE)
-- Updates changed records, inserts new, soft-deletes removed
-- =============================================================
CREATE OR REPLACE PROCEDURE TASTYBYTES_CONSUMPTION.WAREHOUSE.SP_LOAD_DIM_CUSTOMER()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
BEGIN
  -- MERGE: update changed, insert new
  MERGE INTO TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER AS tgt
  USING TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY AS src
    ON tgt.CUSTOMER_ID = src.CUSTOMER_ID
  WHEN MATCHED AND (
       tgt.FIRST_NAME         != src.FIRST_NAME
    OR tgt.LAST_NAME          != src.LAST_NAME
    OR tgt.CITY               != src.CITY
    OR tgt.COUNTRY            != src.COUNTRY
    OR tgt.POSTAL_CODE        != src.POSTAL_CODE
    OR tgt.PREFERRED_LANGUAGE != src.PREFERRED_LANGUAGE
    OR tgt.GENDER             != src.GENDER
    OR tgt.FAVOURITE_BRAND    != src.FAVOURITE_BRAND
    OR tgt.MARITAL_STATUS     != src.MARITAL_STATUS
    OR NVL(tgt.CHILDREN_COUNT, -1) != NVL(src.CHILDREN_COUNT, -1)
    OR tgt.E_MAIL             != src.E_MAIL
    OR tgt.PHONE_NUMBER       != src.PHONE_NUMBER
  ) THEN UPDATE SET
    tgt.FIRST_NAME         = src.FIRST_NAME,
    tgt.LAST_NAME          = src.LAST_NAME,
    tgt.CITY               = src.CITY,
    tgt.COUNTRY            = src.COUNTRY,
    tgt.POSTAL_CODE        = src.POSTAL_CODE,
    tgt.PREFERRED_LANGUAGE = src.PREFERRED_LANGUAGE,
    tgt.GENDER             = src.GENDER,
    tgt.FAVOURITE_BRAND    = src.FAVOURITE_BRAND,
    tgt.MARITAL_STATUS     = src.MARITAL_STATUS,
    tgt.CHILDREN_COUNT     = src.CHILDREN_COUNT,
    tgt.SIGN_UP_DATE       = src.SIGN_UP_DATE,
    tgt.BIRTHDAY_DATE      = src.BIRTHDAY_DATE,
    tgt.E_MAIL             = src.E_MAIL,
    tgt.PHONE_NUMBER       = src.PHONE_NUMBER,
    tgt.IS_DELETED         = FALSE,
    tgt._DW_UPDATE_TS      = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT (
    CUSTOMER_ID, FIRST_NAME, LAST_NAME, CITY, COUNTRY, POSTAL_CODE,
    PREFERRED_LANGUAGE, GENDER, FAVOURITE_BRAND, MARITAL_STATUS,
    CHILDREN_COUNT, SIGN_UP_DATE, BIRTHDAY_DATE, E_MAIL, PHONE_NUMBER,
    IS_DELETED, _DW_LOAD_TS, _DW_UPDATE_TS
  ) VALUES (
    src.CUSTOMER_ID, src.FIRST_NAME, src.LAST_NAME, src.CITY, src.COUNTRY, src.POSTAL_CODE,
    src.PREFERRED_LANGUAGE, src.GENDER, src.FAVOURITE_BRAND, src.MARITAL_STATUS,
    src.CHILDREN_COUNT, src.SIGN_UP_DATE, src.BIRTHDAY_DATE, src.E_MAIL, src.PHONE_NUMBER,
    FALSE, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
  );

  -- Soft-delete: mark customers removed from source
  UPDATE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER
  SET IS_DELETED = TRUE, _DW_UPDATE_TS = CURRENT_TIMESTAMP()
  WHERE IS_DELETED = FALSE
    AND CUSTOMER_ID NOT IN (SELECT CUSTOMER_ID FROM TASTYBYTES_REFINED.STAGING.STG_CUSTOMER_LOYALTY);

  RETURN 'SP_LOAD_DIM_CUSTOMER completed.';
END;

-- =============================================================
-- Task 2.8: Create FACT_ORDER_LINE load procedure
-- MERGE on natural key with surrogate key lookups from all dimensions.
-- COGS calculated as COST_OF_GOODS_USD * QUANTITY at load time.
-- =============================================================
CREATE OR REPLACE PROCEDURE TASTYBYTES_CONSUMPTION.WAREHOUSE.SP_LOAD_FACT_ORDER_LINE()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
BEGIN
  MERGE INTO TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE AS tgt
  USING (
    SELECT
      od.ORDER_DETAIL_ID,
      od.ORDER_ID,
      dm.DIM_MENU_SK,
      dc.DIM_CUSTOMER_SK,
      dl.DIM_LOCATION_SK,
      dd.DIM_DATE_SK,
      oh.TRUCK_ID,
      od.DISCOUNT_ID,
      oh.ORDER_CHANNEL,
      od.LINE_NUMBER,
      od.QUANTITY,
      od.UNIT_PRICE,
      od.PRICE          AS LINE_PRICE,
      dm.COST_OF_GOODS_USD * od.QUANTITY AS COGS_AMOUNT,
      od.ORDER_ITEM_DISCOUNT_AMOUNT AS DISCOUNT_AMOUNT,
      oh.ORDER_AMOUNT,
      oh.ORDER_TAX_AMOUNT,
      oh.ORDER_TOTAL
    FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL od
    JOIN TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER oh
      ON od.ORDER_ID = oh.ORDER_ID
    LEFT JOIN TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU dm
      ON od.MENU_ITEM_ID = dm.MENU_ITEM_ID AND dm.IS_CURRENT = TRUE
    LEFT JOIN TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_CUSTOMER dc
      ON oh.CUSTOMER_ID = dc.CUSTOMER_ID AND dc.IS_DELETED = FALSE
    LEFT JOIN TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_LOCATION dl
      ON oh.LOCATION_ID = dl.LOCATION_ID
    LEFT JOIN TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_DATE dd
      ON oh.ORDER_TS::DATE = dd.DATE
  ) AS src
    ON tgt.ORDER_DETAIL_ID = src.ORDER_DETAIL_ID
  WHEN MATCHED THEN UPDATE SET
    tgt.DIM_MENU_SK       = src.DIM_MENU_SK,
    tgt.DIM_CUSTOMER_SK   = src.DIM_CUSTOMER_SK,
    tgt.DIM_LOCATION_SK   = src.DIM_LOCATION_SK,
    tgt.DIM_DATE_SK       = src.DIM_DATE_SK,
    tgt.TRUCK_ID          = src.TRUCK_ID,
    tgt.DISCOUNT_ID       = src.DISCOUNT_ID,
    tgt.ORDER_CHANNEL     = src.ORDER_CHANNEL,
    tgt.LINE_NUMBER       = src.LINE_NUMBER,
    tgt.QUANTITY          = src.QUANTITY,
    tgt.UNIT_PRICE        = src.UNIT_PRICE,
    tgt.LINE_PRICE        = src.LINE_PRICE,
    tgt.COGS_AMOUNT       = src.COGS_AMOUNT,
    tgt.DISCOUNT_AMOUNT   = src.DISCOUNT_AMOUNT,
    tgt.ORDER_AMOUNT      = src.ORDER_AMOUNT,
    tgt.ORDER_TAX_AMOUNT  = src.ORDER_TAX_AMOUNT,
    tgt.ORDER_TOTAL       = src.ORDER_TOTAL,
    tgt._DW_UPDATE_TS     = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT (
    ORDER_DETAIL_ID, ORDER_ID,
    DIM_MENU_SK, DIM_CUSTOMER_SK, DIM_LOCATION_SK, DIM_DATE_SK,
    TRUCK_ID, DISCOUNT_ID, ORDER_CHANNEL, LINE_NUMBER,
    QUANTITY, UNIT_PRICE, LINE_PRICE, COGS_AMOUNT, DISCOUNT_AMOUNT,
    ORDER_AMOUNT, ORDER_TAX_AMOUNT, ORDER_TOTAL,
    _DW_LOAD_TS, _DW_UPDATE_TS
  ) VALUES (
    src.ORDER_DETAIL_ID, src.ORDER_ID,
    src.DIM_MENU_SK, src.DIM_CUSTOMER_SK, src.DIM_LOCATION_SK, src.DIM_DATE_SK,
    src.TRUCK_ID, src.DISCOUNT_ID, src.ORDER_CHANNEL, src.LINE_NUMBER,
    src.QUANTITY, src.UNIT_PRICE, src.LINE_PRICE, src.COGS_AMOUNT, src.DISCOUNT_AMOUNT,
    src.ORDER_AMOUNT, src.ORDER_TAX_AMOUNT, src.ORDER_TOTAL,
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
  );

  RETURN 'SP_LOAD_FACT_ORDER_LINE completed.';
END;

-- =============================================================
-- Task 2.9: Create task graph — warehouse pipeline
-- DIM_MENU and DIM_CUSTOMER load in parallel; FACT depends on both.
-- =============================================================

-- Root task (never auto-runs)
CREATE OR REPLACE TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_WH_ROOT
  WAREHOUSE = TB_DE_WH
  SCHEDULE = 'USING CRON 0 0 31 2 * UTC'
AS
  SELECT 1;

-- Dimension tasks (parallel)
CREATE OR REPLACE TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_DIM_MENU
  WAREHOUSE = TB_DE_WH
  AFTER TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_WH_ROOT
AS
  CALL TASTYBYTES_CONSUMPTION.WAREHOUSE.SP_LOAD_DIM_MENU();

CREATE OR REPLACE TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_DIM_CUSTOMER
  WAREHOUSE = TB_DE_WH
  AFTER TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_WH_ROOT
AS
  CALL TASTYBYTES_CONSUMPTION.WAREHOUSE.SP_LOAD_DIM_CUSTOMER();

-- Fact task (depends on both dimensions)
CREATE OR REPLACE TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_FACT_ORDER_LINE
  WAREHOUSE = TB_DE_WH
  AFTER TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_DIM_MENU,
        TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_DIM_CUSTOMER
AS
  CALL TASTYBYTES_CONSUMPTION.WAREHOUSE.SP_LOAD_FACT_ORDER_LINE();

-- Resume tasks (children first, then root)
ALTER TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_DIM_MENU RESUME;
ALTER TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_DIM_CUSTOMER RESUME;
ALTER TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_LOAD_FACT_ORDER_LINE RESUME;
ALTER TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_WH_ROOT RESUME;

-- =============================================================
-- Task 2.10: Execute the task graph
-- =============================================================
EXECUTE TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_WH_ROOT;
