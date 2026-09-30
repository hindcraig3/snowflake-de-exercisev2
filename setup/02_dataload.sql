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
/*--
 RAW zone table load from local CSV files
 
 PREREQUISITES:
   1. Run 01_setup.sql first to create databases, schemas, tables, and roles.
   2. Upload all 9 CSV files from setup/data/ to the internal stage using Snowsight:
      a. In Snowsight, navigate to Data » Add Data » Load files into a Stage.
      b. Select database TASTYBYTES_RAW, schema RAW, and stage DATA_LOAD_STAGE.
      c. Upload all 9 CSV files from the setup/data/ folder.
   3. Then run this script to load the data into RAW tables.
--*/

USE ROLE TB_ADMIN;
USE WAREHOUSE tb_de_wh;

-- ============================================================================
-- LOAD RAW TABLES FROM INTERNAL STAGE
-- Data files include all modifications (whitespace in CUSTOMER_LOYALTY,
-- multilingual TRUCK_REVIEWS) already baked in — no post-load SQL needed.
-- ============================================================================

-- Country reference data
COPY INTO TASTYBYTES_RAW.RAW.COUNTRY
FROM @TASTYBYTES_RAW.RAW.DATA_LOAD_STAGE/
PATTERN = '.*country.*'
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = (''))
ON_ERROR = 'ABORT_STATEMENT';

-- Franchise reference data
COPY INTO TASTYBYTES_RAW.RAW.FRANCHISE
FROM @TASTYBYTES_RAW.RAW.DATA_LOAD_STAGE/
PATTERN = '.*franchise.*'
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = (''))
ON_ERROR = 'ABORT_STATEMENT';

-- Location reference data
COPY INTO TASTYBYTES_RAW.RAW.LOCATION
FROM @TASTYBYTES_RAW.RAW.DATA_LOAD_STAGE/
PATTERN = '.*location.*'
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = (''))
ON_ERROR = 'ABORT_STATEMENT';

-- Menu data (VARIANT column loaded as JSON string — Snowflake auto-parses to VARIANT)
COPY INTO TASTYBYTES_RAW.RAW.MENU
FROM @TASTYBYTES_RAW.RAW.DATA_LOAD_STAGE/
PATTERN = '.*menu.*'
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = (''))
ON_ERROR = 'ABORT_STATEMENT';

-- Truck fleet data
COPY INTO TASTYBYTES_RAW.RAW.TRUCK
FROM @TASTYBYTES_RAW.RAW.DATA_LOAD_STAGE/
PATTERN = '.*truck\.csv.*'
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = (''))
ON_ERROR = 'ABORT_STATEMENT';

-- Customer loyalty data (whitespace in city column is pre-applied)
COPY INTO TASTYBYTES_RAW.RAW.CUSTOMER_LOYALTY
FROM @TASTYBYTES_RAW.RAW.DATA_LOAD_STAGE/
PATTERN = '.*customer_loyalty.*'
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = (''))
ON_ERROR = 'ABORT_STATEMENT';

-- Order headers (subsampled: ~100K orders from 2022)
COPY INTO TASTYBYTES_RAW.RAW.ORDER_HEADER
FROM @TASTYBYTES_RAW.RAW.DATA_LOAD_STAGE/
PATTERN = '.*order_header.*'
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = (''))
ON_ERROR = 'ABORT_STATEMENT';

-- Order details (matching order IDs only)
COPY INTO TASTYBYTES_RAW.RAW.ORDER_DETAIL
FROM @TASTYBYTES_RAW.RAW.DATA_LOAD_STAGE/
PATTERN = '.*order_detail.*'
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = (''))
ON_ERROR = 'ABORT_STATEMENT';

-- Truck reviews (includes multilingual entries)
COPY INTO TASTYBYTES_RAW.RAW.TRUCK_REVIEWS
FROM @TASTYBYTES_RAW.RAW.DATA_LOAD_STAGE/
PATTERN = '.*truck_reviews.*'
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = (''))
ON_ERROR = 'ABORT_STATEMENT';

-- ============================================================================
-- VALIDATE
-- ============================================================================
SELECT 'RAW' AS layer, TABLE_NAME, ROW_COUNT
FROM TASTYBYTES_RAW.information_schema.tables
WHERE TABLE_SCHEMA = 'RAW' AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'STAGING', TABLE_NAME, ROW_COUNT
FROM TASTYBYTES_REFINED.information_schema.tables
WHERE TABLE_SCHEMA = 'STAGING' AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'WAREHOUSE', TABLE_NAME, ROW_COUNT
FROM TASTYBYTES_CONSUMPTION.information_schema.tables
WHERE TABLE_SCHEMA = 'WAREHOUSE' AND TABLE_TYPE = 'BASE TABLE'
ORDER BY 1, 2;
