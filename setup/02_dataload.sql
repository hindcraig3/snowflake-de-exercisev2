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
 raw zone table load 
 NOTE: This may take 1-2 mins. 
 
--*/

-- TRUNCATE TABLE TASTYBYTES_RAW.RAW.COUNTRY;
-- TRUNCATE TABLE TASTYBYTES_RAW.RAW.FRANCHISE;
-- TRUNCATE TABLE TASTYBYTES_RAW.RAW.LOCATION;
-- TRUNCATE TABLE TASTYBYTES_RAW.RAW.MENU;
-- TRUNCATE TABLE TASTYBYTES_RAW.RAW.TRUCK;
-- TRUNCATE TABLE TASTYBYTES_RAW.RAW.CUSTOMER_LOYALTY;
-- TRUNCATE TABLE TASTYBYTES_RAW.RAW.ORDER_DETAIL;
-- TRUNCATE TABLE TASTYBYTES_RAW.RAW.TRUCK_REVIEWS;

USE ROLE TB_ADMIN;
ALTER WAREHOUSE tb_de_wh SET WAREHOUSE_SIZE = 'Large';
USE WAREHOUSE tb_de_wh;

-- country table load
COPY INTO TASTYBYTES_RAW.RAW.COUNTRY
FROM @TASTYBYTES_RAW.RAW.S3LOAD_SALES/raw_pos/country/;

-- franchise table load
COPY INTO TASTYBYTES_RAW.RAW.FRANCHISE
FROM @TASTYBYTES_RAW.RAW.S3LOAD_SALES/raw_pos/franchise/;

-- location table load
COPY INTO TASTYBYTES_RAW.RAW.LOCATION
FROM @TASTYBYTES_RAW.RAW.S3LOAD_SALES/raw_pos/location/;

-- menu table load
COPY INTO TASTYBYTES_RAW.RAW.MENU
FROM @TASTYBYTES_RAW.RAW.S3LOAD_SALES/raw_pos/menu/;

-- truck table load
COPY INTO TASTYBYTES_RAW.RAW.TRUCK
FROM @TASTYBYTES_RAW.RAW.S3LOAD_SALES/raw_pos/truck/;

-- customer_loyalty table load
COPY INTO TASTYBYTES_RAW.RAW.CUSTOMER_LOYALTY
FROM @TASTYBYTES_RAW.RAW.S3LOAD_SALES/raw_customer/customer_loyalty/;

-- order_header table load
COPY INTO TASTYBYTES_RAW.RAW.ORDER_HEADER
FROM @TASTYBYTES_RAW.RAW.S3LOAD_SALES/raw_pos/order_header/;

-- order_detail table load
COPY INTO TASTYBYTES_RAW.RAW.ORDER_DETAIL
FROM @TASTYBYTES_RAW.RAW.S3LOAD_SALES/raw_pos/order_detail/;

-- truck_reviews table load
COPY INTO TASTYBYTES_RAW.RAW.TRUCK_REVIEWS
FROM @TASTYBYTES_RAW.RAW.S3LOAD_REVIEWS/raw_support/truck_reviews/;

-- Reduce the size of the Truck review table
DELETE FROM TASTYBYTES_RAW.RAW.TRUCK_REVIEWS
WHERE review_id < (124594-1000);

-- ============================================================================
-- PRE-WORKSHOP DATA MODIFICATIONS
-- Run this script ONCE before the workshop to prepare the RAW data.
-- ============================================================================

USE DATABASE TASTYBYTES_RAW;
USE SCHEMA RAW;


UPDATE CUSTOMER_LOYALTY SET city = '  ' || city WHERE MOD(customer_id, 20) = 0;
UPDATE CUSTOMER_LOYALTY SET city = city || '  ' WHERE MOD(customer_id, 20) = 1;
UPDATE CUSTOMER_LOYALTY SET city = UPPER(city) WHERE MOD(customer_id, 20) = 2;
UPDATE CUSTOMER_LOYALTY SET city = LOWER(city) WHERE MOD(customer_id, 20) = 3;


INSERT INTO TRUCK_REVIEWS (order_id, language, source, review, review_id)
VALUES
(40744, 'de', 'Google', 'Die Bratwurst vom Smoky BBQ Truck in Berlin war absolut fantastisch. Perfekt gegrillt und mit einer tollen Sauce serviert. Der Service war schnell und freundlich.', 900001),
(40745, 'de', 'Yelp', 'Der Mega Melt Truck in Berlin hat mich enttaeuscht. Das Grilled Cheese Sandwich war kalt und der Kaese kaum geschmolzen. Lange Wartezeit trotz weniger Kunden.', 900002),
(40746, 'de', 'Google', 'Kitakata Ramen Bar in Berlin - die beste Ramen die ich je gegessen habe! Der Tonkotsu war reichhaltig und die Nudeln perfekt. Komme definitiv wieder.', 900003),
(40747, 'ja', 'Google', 'ボストンのKitakata Ramen Barで食べたラーメンは最高でした。スープの味が深くて、麺のコシも完璧。また行きたいです。', 900004),
(40748, 'ja', 'Yelp', 'Plant Palaceのベジタリアンメニューは期待外れでした。味が薄くて量も少ない。価格に見合わないと思います。', 900005),
(40749, 'ko', 'Google', '서울의 Peking Truck에서 먹은 음식이 정말 맛있었습니다. 특히 볶음밥이 일품이었고, 서비스도 친절했습니다.', 900006),
(40750, 'ko', 'Yelp', 'Freezing Point 아이스크림이 너무 달았고, 종류도 적었습니다. 가격 대비 양이 부족합니다.', 900007),
(40751, 'hi', 'Google', 'दिल्ली में Nanis Kitchen का खाना बहुत स्वादिष्ट था। बटर चिकन और नान बिल्कुल घर जैसा स्वाद। सर्विस भी बहुत अच्छी थी।', 900008),
(40752, 'hi', 'Yelp', 'Tasty Tibs का इथियोपियन खाना ठीक था लेकिन कुछ खास नहीं। मसाले की कमी थी और सर्विस धीमी थी।', 900009),
(40753, 'sv', 'Google', 'Guac n Roll i Stockholm hade fantastiska tacos! Guacamolen var frasig och smakrik. Perfekt lunch pa sprangen.', 900010),
(40754, 'sv', 'Yelp', 'Cheeky Greek i Stockholm var en besvikelse. Gyrosen var torr och salladen inte frash. Behover forbattra kvaliteten.', 900011),
(40755, 'pl', 'Google', 'Amped Up Franks w Krakowie to najlepsze hot dogi jakie jadlem! Kielbasa swietnej jakosci, dodatki swietne. Polecam kazdemu!', 900012),
(40756, 'pl', 'Yelp', 'The Mac Shack w Krakowie - makaron byl rozgotowany i sos bez smaku. Dlugi czas oczekiwania. Nie wrocimy.', 900013),
(40757, 'ar', 'Google', 'تجربة رائعة مع شاحنة Better Off Bread. الساندويتشات طازجة ولذيذة والخدمة سريعة.', 900014),
(40758, 'pt', 'Google', 'Revenge of the Curds em Sao Paulo foi incrivel! A poutine era autentica e deliciosa. O molho estava perfeito e as batatas crocantes.', 900015);


-- ============================================================================
-- PRE-POPULATED STAGING TABLES
-- Load STG_COUNTRY and STG_LOCATION from RAW data
-- ============================================================================

-- STG_COUNTRY: cleaned country reference
INSERT INTO TASTYBYTES_REFINED.STAGING.STG_COUNTRY
SELECT
    COUNTRY_ID,
    TRIM(COUNTRY),
    TRIM(ISO_CURRENCY),
    TRIM(ISO_COUNTRY),
    CITY_ID,
    TRIM(CITY),
    TRY_CAST(CITY_POPULATION AS NUMBER),
    CURRENT_TIMESTAMP(),
    'COUNTRY'
FROM TASTYBYTES_RAW.RAW.COUNTRY;

-- STG_LOCATION: cleaned location reference
INSERT INTO TASTYBYTES_REFINED.STAGING.STG_LOCATION
SELECT
    LOCATION_ID,
    TRIM(PLACEKEY),
    TRIM(LOCATION),
    TRIM(CITY),
    TRIM(REGION),
    TRIM(ISO_COUNTRY_CODE),
    TRIM(COUNTRY),
    CURRENT_TIMESTAMP(),
    'LOCATION'
FROM TASTYBYTES_RAW.RAW.LOCATION;

-- ============================================================================
-- PRE-POPULATED WAREHOUSE TABLES
-- Load DIM_LOCATION and DIM_DATE
-- ============================================================================

-- DIM_LOCATION: join location with country for currency and population
INSERT INTO TASTYBYTES_CONSUMPTION.WAREHOUSE.DIM_LOCATION (
    LOCATION_ID, PLACEKEY, LOCATION, CITY, REGION, ISO_COUNTRY_CODE,
    COUNTRY, ISO_CURRENCY, CITY_POPULATION, _DW_LOAD_TS, _DW_UPDATE_TS)
SELECT
    l.LOCATION_ID,
    l.PLACEKEY,
    l.LOCATION,
    l.CITY,
    l.REGION,
    l.ISO_COUNTRY_CODE,
    l.COUNTRY,
    c.ISO_CURRENCY,
    c.CITY_POPULATION,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
FROM TASTYBYTES_REFINED.STAGING.STG_LOCATION l
LEFT JOIN (
    SELECT DISTINCT CITY, COUNTRY, ISO_CURRENCY, CITY_POPULATION
    FROM TASTYBYTES_REFINED.STAGING.STG_COUNTRY
) c ON l.CITY = c.CITY AND l.COUNTRY = c.COUNTRY;

-- DIM_DATE: generate date dimension from 2019-01-01 to 2025-12-31
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

ALTER WAREHOUSE tb_de_wh SET WAREHOUSE_SIZE = 'XSmall';

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

