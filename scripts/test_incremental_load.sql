-- =====================================================================
-- INCREMENTAL DATA TEST: Add new data to RAW, run pipeline, validate
-- Proves the pipeline works end-to-end for new data arriving in RAW.
-- =====================================================================

-- =====================================================================
-- STEP 1: Capture baseline counts before adding new data
-- =====================================================================
USE ROLE TB_DATA_ENGINEER;
USE WAREHOUSE TB_DE_WH;

-- Save these numbers to compare after the pipeline runs
SELECT 'BASELINE' AS PHASE,
       'STG_ORDER_HEADER' AS TABLE_NAME,
       COUNT(*) AS ROW_COUNT
FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER
UNION ALL
SELECT 'BASELINE', 'STG_ORDER_DETAIL', COUNT(*)
FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL
UNION ALL
SELECT 'BASELINE', 'FACT_ORDER_LINE', COUNT(*)
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE
UNION ALL
SELECT 'BASELINE', 'RPT_VIEW_MONTHS', COUNT(DISTINCT MONTH_START_DATE)
FROM TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES;

-- =====================================================================
-- STEP 2: Insert test data into RAW tables
-- Adds 5 orders with 10 line items for a NEW month (2023-01-15)
-- that does not exist in the current dataset (which ends Nov 2022).
-- =====================================================================

-- Insert 5 new order headers for January 2023
INSERT INTO TASTYBYTES_RAW.RAW.ORDER_HEADER (
    ORDER_ID, TRUCK_ID, LOCATION_ID, CUSTOMER_ID, DISCOUNT_ID,
    SHIFT_ID, SHIFT_START_TIME, SHIFT_END_TIME,
    ORDER_CHANNEL, ORDER_TS, SERVED_TS, ORDER_CURRENCY,
    ORDER_AMOUNT, ORDER_TAX_AMOUNT, ORDER_DISCOUNT_AMOUNT, ORDER_TOTAL
)
SELECT * FROM VALUES
  (500000001, 37, 2114.0, 109380, NULL, 1, '08:00:00'::TIME, '16:00:00'::TIME,
   'walk-up', '2023-01-15 12:30:00'::TIMESTAMP_NTZ, '2023-01-15 12:35:00', 'USD',
   13.50, '1.08', '0.00', 14.58),
  (500000002, 37, 2114.0, 175804, NULL, 1, '08:00:00'::TIME, '16:00:00'::TIME,
   'walk-up', '2023-01-15 13:00:00'::TIMESTAMP_NTZ, '2023-01-15 13:05:00', 'USD',
   12.00, '0.96', '0.00', 12.96),
  (500000003, 37, 1266.0, 97231, NULL, 2, '16:00:00'::TIME, '23:00:00'::TIME,
   'app', '2023-01-15 18:00:00'::TIMESTAMP_NTZ, '2023-01-15 18:10:00', 'USD',
   9.00, '0.72', '0.00', 9.72),
  (500000004, 37, 1266.0, 188225, NULL, 2, '16:00:00'::TIME, '23:00:00'::TIME,
   'app', '2023-01-15 19:00:00'::TIMESTAMP_NTZ, '2023-01-15 19:05:00', 'USD',
   7.00, '0.56', '0.00', 7.56),
  (500000005, 37, 2114.0, 109380, NULL, 1, '08:00:00'::TIME, '16:00:00'::TIME,
   'walk-up', '2023-01-15 14:00:00'::TIMESTAMP_NTZ, '2023-01-15 14:05:00', 'USD',
   6.00, '0.48', '0.00', 6.48);

-- Insert 10 order detail line items (2 per order)
-- Uses menu items: Lemonade (10, $3.50), Sugar Cone (11, $6.00),
-- Waffle Cone (12, $6.00), Two Scoop Bowl (13, $7.00), Bottled Water (14, $2.00)
INSERT INTO TASTYBYTES_RAW.RAW.ORDER_DETAIL (
    ORDER_DETAIL_ID, ORDER_ID, MENU_ITEM_ID, DISCOUNT_ID,
    LINE_NUMBER, QUANTITY, UNIT_PRICE, PRICE, ORDER_ITEM_DISCOUNT_AMOUNT
)
SELECT * FROM VALUES
  (910000001, 500000001, 10, NULL, 1, 1, 3.50, 3.50, '0.00'),   -- Lemonade
  (910000002, 500000001, 13, NULL, 2, 1, 7.00, 7.00, '0.00'),   -- Two Scoop Bowl
  (910000003, 500000002, 11, NULL, 1, 2, 6.00, 12.00, '0.00'),  -- Sugar Cone x2
  (910000004, 500000002, 14, NULL, 2, 1, 2.00, 2.00, '0.00'),   -- Bottled Water
  (910000005, 500000003, 12, NULL, 1, 1, 6.00, 6.00, '0.00'),   -- Waffle Cone
  (910000006, 500000003, 10, NULL, 2, 1, 3.50, 3.50, '0.00'),   -- Lemonade
  (910000007, 500000004, 13, NULL, 1, 1, 7.00, 7.00, '0.00'),   -- Two Scoop Bowl
  (910000008, 500000004, 14, NULL, 2, 1, 2.00, 2.00, '0.00'),   -- Bottled Water
  (910000009, 500000005, 11, NULL, 1, 1, 6.00, 6.00, '0.00'),   -- Sugar Cone
  (910000010, 500000005, 10, NULL, 2, 1, 3.50, 3.50, '0.00');   -- Lemonade

-- Verify test data was inserted
SELECT 'TEST DATA INSERTED' AS STATUS,
       (SELECT COUNT(*) FROM TASTYBYTES_RAW.RAW.ORDER_HEADER WHERE ORDER_ID >= 500000001) AS NEW_ORDERS,
       (SELECT COUNT(*) FROM TASTYBYTES_RAW.RAW.ORDER_DETAIL WHERE ORDER_DETAIL_ID >= 910000001) AS NEW_DETAILS;

-- =====================================================================
-- STEP 3: Execute the staging pipeline
-- =====================================================================
EXECUTE TASK TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT;

-- Wait for completion (check after ~2 minutes for large tables)
-- Re-run this query until all tasks show SUCCEEDED
SELECT NAME, STATE, COMPLETED_TIME, ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  TASK_NAME => 'TASK_STG_ROOT',
  SCHEDULED_TIME_RANGE_START => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;

-- =====================================================================
-- STEP 4: Execute the warehouse pipeline
-- Run this AFTER all staging tasks have completed
-- =====================================================================
EXECUTE TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_WH_ROOT;

-- Wait for completion (the fact load takes longest)
SELECT NAME, STATE, COMPLETED_TIME, ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  TASK_NAME => 'TASK_WH_ROOT',
  SCHEDULED_TIME_RANGE_START => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;

-- =====================================================================
-- STEP 5: Validate data propagated through the pipeline
-- =====================================================================

-- 5a: Check test orders exist in staging
SELECT 'STAGING_CHECK' AS CHECK_NAME,
       IFF(COUNT(*) = 5, 'PASS', 'FAIL') AS STATUS,
       'New orders in STG_ORDER_HEADER: ' || COUNT(*) AS DETAIL
FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_HEADER
WHERE ORDER_ID >= 500000001;

-- 5b: Check test line items exist in staging
SELECT 'STAGING_DETAIL_CHECK' AS CHECK_NAME,
       IFF(COUNT(*) = 10, 'PASS', 'FAIL') AS STATUS,
       'New details in STG_ORDER_DETAIL: ' || COUNT(*) AS DETAIL
FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL
WHERE ORDER_DETAIL_ID >= 910000001;

-- 5c: Check test rows exist in fact table with correct surrogate keys
SELECT 'FACT_CHECK' AS CHECK_NAME,
       IFF(COUNT(*) = 10, 'PASS', 'FAIL') AS STATUS,
       'New rows in FACT_ORDER_LINE: ' || COUNT(*) AS DETAIL
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE
WHERE ORDER_ID >= 500000001;

-- 5d: Verify surrogate keys are populated on new fact rows
SELECT 'FACT_SK_CHECK' AS CHECK_NAME,
       IFF(
         COUNT_IF(DIM_MENU_SK IS NULL) = 0
         AND COUNT_IF(DIM_CUSTOMER_SK IS NULL) = 0
         AND COUNT_IF(DIM_LOCATION_SK IS NULL) = 0
         AND COUNT_IF(DIM_DATE_SK IS NULL) = 0,
         'PASS', 'FAIL'
       ) AS STATUS,
       'NULL SKs — Menu:' || COUNT_IF(DIM_MENU_SK IS NULL)
       || ' Cust:' || COUNT_IF(DIM_CUSTOMER_SK IS NULL)
       || ' Loc:' || COUNT_IF(DIM_LOCATION_SK IS NULL)
       || ' Date:' || COUNT_IF(DIM_DATE_SK IS NULL) AS DETAIL
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE
WHERE ORDER_ID >= 500000001;

-- 5e: Verify COGS was calculated correctly on new rows
SELECT 'COGS_CHECK' AS CHECK_NAME,
       IFF(COUNT_IF(ABS(f.COGS_AMOUNT - (dm.COST_OF_GOODS_USD * f.QUANTITY)) > 0.01) = 0,
           'PASS', 'FAIL') AS STATUS,
       'Rows with incorrect COGS: ' || COUNT_IF(ABS(f.COGS_AMOUNT - (dm.COST_OF_GOODS_USD * f.QUANTITY)) > 0.01) AS DETAIL
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE f
JOIN TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU dm ON f.DIM_MENU_SK = dm.DIM_MENU_SK
WHERE f.ORDER_ID >= 500000001;

-- 5f: Check January 2023 appears in the reporting view
SELECT 'RPT_VIEW_CHECK' AS CHECK_NAME,
       IFF(COUNT(*) > 0, 'PASS', 'FAIL') AS STATUS,
       'January 2023 rows in view: ' || COUNT(*) AS DETAIL
FROM TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES
WHERE YEAR = 2023 AND MONTH_NAME = 'January';

-- 5g: Verify revenue in the view matches inserted test data
-- Total test revenue: 3.50 + 7.00 + 12.00 + 2.00 + 6.00 + 3.50 + 7.00 + 2.00 + 6.00 + 3.50 = 52.50
SELECT 'REVENUE_CHECK' AS CHECK_NAME,
       IFF(ABS(total_rev - 52.50) < 0.01, 'PASS', 'FAIL') AS STATUS,
       'Jan 2023 view revenue: ' || total_rev || ' (expected: 52.50)' AS DETAIL
FROM (
  SELECT SUM(TOTAL_REVENUE) AS total_rev
  FROM TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES
  WHERE YEAR = 2023 AND MONTH_NAME = 'January'
);

-- =====================================================================
-- STEP 6 (OPTIONAL): Cleanup test data
-- Remove the test rows from RAW and re-run the pipeline
-- =====================================================================

-- Uncomment to run cleanup:
-- DELETE FROM TASTYBYTES_RAW.RAW.ORDER_DETAIL WHERE ORDER_DETAIL_ID >= 910000001;
-- DELETE FROM TASTYBYTES_RAW.RAW.ORDER_HEADER WHERE ORDER_ID >= 500000001;
-- EXECUTE TASK TASTYBYTES_REFINED.STAGING.TASK_STG_ROOT;
-- -- Wait for staging to complete, then:
-- EXECUTE TASK TASTYBYTES_CONSUMPTION.WAREHOUSE.TASK_WH_ROOT;
