# Module 3: WAREHOUSE to DATA PRODUCT

## Objective

Create a reporting view in `TASTYBYTES_CONSUMPTION.ANALYTICS` that answers the business question: **monthly sales volume, revenue, and margin of menu items and menu item categories, broken down by location and time period.**

---

## Standards and Conventions

### Naming
- **View prefix:** `RPT_` for reporting objects
- **Schema:** `TASTYBYTES_CONSUMPTION.ANALYTICS`

### Role and Warehouse
```sql
USE ROLE TB_DATA_ENGINEER;
USE WAREHOUSE TB_DE_WH;
USE SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS;
```

---

## Task 3.1: Create RPT_MONTHLY_MENU_SALES View

Create a view that aggregates fact data at the monthly/menu-item/city grain.

**View name:** `TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES`

**Grain:** One row per calendar month, per menu item, per city

**Column Specification:**

| Column | Source | Description |
|--------|--------|-------------|
| YEAR | DIM_DATE | Calendar year (e.g., 2022) |
| QUARTER | DIM_DATE | Calendar quarter (e.g., Q1, Q2) |
| MONTH_NAME | DIM_DATE | Month name (e.g., January) |
| MONTH_START_DATE | DIM_DATE | First day of the month |
| CITY | DIM_LOCATION | City name |
| COUNTRY | DIM_LOCATION | Country name |
| MENU_ITEM_NAME | DIM_MENU | Menu item display name |
| ITEM_CATEGORY | DIM_MENU | High-level category (Main, Dessert, Beverage) |
| ITEM_SUBCATEGORY | DIM_MENU | Granular subcategory |
| TRUCK_BRAND_NAME | DIM_MENU | Food truck brand |
| TOTAL_QUANTITY_SOLD | FACT_ORDER_LINE | `SUM(QUANTITY)` |
| TOTAL_REVENUE | FACT_ORDER_LINE | `SUM(LINE_PRICE)` |
| TOTAL_COGS | FACT_ORDER_LINE | `SUM(COGS_AMOUNT)` |
| TOTAL_MARGIN | Calculated | `TOTAL_REVENUE - TOTAL_COGS` |
| MARGIN_PCT | Calculated | `(TOTAL_MARGIN / NULLIF(TOTAL_REVENUE, 0)) * 100` |

**Source Tables:**
- `TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE` (fact)
- `TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_MENU` (joined on `DIM_MENU_SK`)
- `TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_DATE` (joined on `DIM_DATE_SK`)
- `TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_LOCATION` (joined on `DIM_LOCATION_SK`)

**Important:** Since `DIM_MENU` is SCD Type 2, the fact table already has the correct `DIM_MENU_SK` frozen at load time. Join directly on the surrogate key — do not filter by `IS_CURRENT`.

**GROUP BY:** All non-aggregated columns (year, quarter, month_name, month_start_date, city, country, menu_item_name, item_category, item_subcategory, truck_brand_name).

**Hint:** Check the pre-created `DIM_DATE` and `DIM_LOCATION` column names before writing the joins:
```sql
DESCRIBE TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_DATE;
DESCRIBE TABLE TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_LOCATION;
```

---

## Task 3.2: Apply Governance Tags and Comments

Switch to `TB_ADMIN`:

```sql
USE ROLE TB_ADMIN;
```

### Tags

| Tag | Value |
|-----|-------|
| DATA_DOMAIN | `'Sales'` |
| DATA_CLASSIFICATION | `'Internal'` |
| COST_CENTER | `'TASTYBYTES'` |

```sql
ALTER VIEW TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES
  SET TAG TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_DOMAIN = 'Sales',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.DATA_CLASSIFICATION = 'Internal',
          TASTYBYTES_GOVERNANCE.GOVERNANCE.COST_CENTER = 'TASTYBYTES';
```

### Comment

```sql
COMMENT ON VIEW TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES IS
  'Monthly sales volume, revenue, and margin by menu item, category, and location. Grain: one row per month/menu item/city.';
```

---

## Task 3.3: Define GRANTS

Grant read access to `TB_ANALYST`:

```sql
USE ROLE TB_ADMIN;

GRANT USAGE ON SCHEMA TASTYBYTES_CONSUMPTION.ANALYTICS TO ROLE TB_ANALYST;
GRANT SELECT ON VIEW TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES TO ROLE TB_ANALYST;

-- Also grant to TB_DATA_ENGINEER
GRANT ALL ON VIEW TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES TO ROLE TB_DATA_ENGINEER;
```

---

## Task 3.4: Validate with Business Queries

Switch to `TB_ANALYST` role and run these queries to verify the reporting view works correctly.

```sql
USE ROLE TB_ANALYST;
USE WAREHOUSE TB_ANALYST_WH;
```

### Query 1: Monthly Revenue Trend for 2022

```sql
SELECT YEAR, MONTH_NAME, MONTH_START_DATE, 
       SUM(TOTAL_REVENUE) AS revenue,
       SUM(TOTAL_MARGIN) AS margin
FROM TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES
WHERE YEAR = 2022
GROUP BY YEAR, MONTH_NAME, MONTH_START_DATE
ORDER BY MONTH_START_DATE;
-- Expected: 12 rows, one per month
```

### Query 2: Top 10 Menu Items by Margin %

```sql
SELECT MENU_ITEM_NAME, ITEM_CATEGORY, TRUCK_BRAND_NAME,
       SUM(TOTAL_QUANTITY_SOLD) AS qty,
       SUM(TOTAL_REVENUE) AS revenue,
       SUM(TOTAL_MARGIN) AS margin,
       ROUND((SUM(TOTAL_MARGIN) / NULLIF(SUM(TOTAL_REVENUE), 0)) * 100, 2) AS margin_pct
FROM TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES
GROUP BY MENU_ITEM_NAME, ITEM_CATEGORY, TRUCK_BRAND_NAME
ORDER BY margin_pct DESC
LIMIT 10;
```

### Query 3: Revenue by Category and City

```sql
SELECT CITY, COUNTRY, ITEM_CATEGORY,
       SUM(TOTAL_REVENUE) AS revenue
FROM TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES
WHERE YEAR = 2022
GROUP BY CITY, COUNTRY, ITEM_CATEGORY
ORDER BY revenue DESC
LIMIT 20;
```

### Revenue Tie-Back

Verify the view's total revenue matches the fact table:

```sql
USE ROLE TB_DATA_ENGINEER;

SELECT 'REPORTING_VIEW' AS source, SUM(TOTAL_REVENUE) AS total_revenue
FROM TASTYBYTES_CONSUMPTION.ANALYTICS.RPT_MONTHLY_MENU_SALES
UNION ALL
SELECT 'FACT_TABLE', SUM(LINE_PRICE)
FROM TASTYBYTES_CONSUMPTION.WAREHOUSE.FACT_ORDER_LINE
UNION ALL
SELECT 'STAGING', SUM(PRICE)
FROM TASTYBYTES_REFINED.STAGING.STG_ORDER_DETAIL;
-- All three values should match
```

---

## Checkpoint — Exercise Complete

You have now built a complete end-to-end data pipeline. Verify:

- [ ] RPT_MONTHLY_MENU_SALES view exists and returns data
- [ ] The view has DATA_DOMAIN, DATA_CLASSIFICATION, and COST_CENTER tags
- [ ] The view has a descriptive COMMENT
- [ ] TB_ANALYST can query the view
- [ ] Revenue totals tie back across all layers (staging, warehouse, reporting)
- [ ] The business queries return sensible results (12 months, positive margins, multiple cities)
