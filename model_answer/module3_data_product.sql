-- =====================================================================
-- MODEL ANSWER: Module 3 — WAREHOUSE to DATA PRODUCT
-- Reporting view in TASTYBYTES_CONSUMPTION.ANALYTICS
-- =====================================================================

USE ROLE TB_DATA_ENGINEER;
USE WAREHOUSE TB_DE_WH;
USE SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS;

-- =============================================================
-- Task 3.1: Create RPT_MONTHLY_MENU_SALES reporting view
-- Monthly sales volume, revenue, and margin by menu item and location.
-- Grain: one row per calendar month, per menu item, per city.
-- =============================================================
CREATE OR REPLACE VIEW RPT_MONTHLY_MENU_SALES AS
SELECT
    dd.YEAR,
    dd.QUARTER,
    dd.MONTH_NAME,
    dd.MONTH_START_DATE,
    dl.CITY,
    dl.COUNTRY,
    dm.MENU_ITEM_NAME,
    dm.ITEM_CATEGORY,
    dm.ITEM_SUBCATEGORY,
    dm.TRUCK_BRAND_NAME,
    SUM(f.QUANTITY)                                                         AS TOTAL_QUANTITY_SOLD,
    SUM(f.LINE_PRICE)                                                      AS TOTAL_REVENUE,
    SUM(f.COGS_AMOUNT)                                                     AS TOTAL_COGS,
    SUM(f.LINE_PRICE) - SUM(f.COGS_AMOUNT)                                AS TOTAL_MARGIN,
    ROUND((SUM(f.LINE_PRICE) - SUM(f.COGS_AMOUNT))
          / NULLIF(SUM(f.LINE_PRICE), 0) * 100, 2)                        AS MARGIN_PCT
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE f
JOIN TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU dm
  ON f.DIM_MENU_SK = dm.DIM_MENU_SK
JOIN TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_DATE dd
  ON f.DIM_DATE_SK = dd.DIM_DATE_SK
JOIN TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_LOCATION dl
  ON f.DIM_LOCATION_SK = dl.DIM_LOCATION_SK
GROUP BY
    dd.YEAR,
    dd.QUARTER,
    dd.MONTH_NAME,
    dd.MONTH_START_DATE,
    dl.CITY,
    dl.COUNTRY,
    dm.MENU_ITEM_NAME,
    dm.ITEM_CATEGORY,
    dm.ITEM_SUBCATEGORY,
    dm.TRUCK_BRAND_NAME;

-- =============================================================
-- Task 3.2: Apply governance tags and comment
-- =============================================================
USE ROLE TB_ADMIN;

ALTER VIEW TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES
  SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_DOMAIN = 'Sales',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_CLASSIFICATION = 'Internal',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.COST_CENTER = 'TASTYBYTES';

COMMENT ON VIEW TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES IS
  'Monthly sales volume, revenue, and margin by menu item, category, and location. Grain: one row per month/menu item/city.';

-- =============================================================
-- Task 3.3: Grant access
-- =============================================================
GRANT USAGE ON SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS TO ROLE TB_ANALYST;
GRANT SELECT ON VIEW TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES TO ROLE TB_ANALYST;
GRANT ALL ON VIEW TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES TO ROLE TB_DATA_ENGINEER;
