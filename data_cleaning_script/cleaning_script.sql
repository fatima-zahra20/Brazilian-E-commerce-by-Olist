
-- STANDARD PROFILING CHECKLIST (run on every table)


-- 1. ROW COUNT
--    SELECT COUNT(*) FROM table_name;

-- 2. SCHEMA CHECK
--    PRAGMA table_info(table_name);

-- 3. NULL CHECK (per column)
--    SELECT COUNT(*) - COUNT(column_name) AS nulls FROM table_name;

-- 4. DUPLICATES
--    SELECT col1, col2, COUNT(*) c
--    FROM table_name
--    GROUP BY col1, col2
--    HAVING c > 1;

-- 5. VALUE RANGE / VALIDITY
--    SELECT COUNT(*) FROM table WHERE numeric_col < 0;
--    SELECT COUNT(*) FROM table WHERE score NOT BETWEEN 1 AND 5;

-- 6. DATE SANITY
--    SELECT COUNT(*) FROM table WHERE date_col > DATE('now');
--    SELECT COUNT(*) FROM table WHERE end_date < start_date;

-- 7. INCONSISTENT FORMATTING
--    SELECT DISTINCT city FROM table ORDER BY city;  -- spot casing issues
--    SELECT COUNT(*) FROM table WHERE TRIM(col) != col; -- leading/trailing spaces

-- 8. ORPHAN RECORDS (relational integrity)
--    SELECT COUNT(*) FROM table_a a
--    LEFT JOIN table_b b ON a.fk = b.pk
--    WHERE b.pk IS NULL;

-- 9. CARDINALITY CHECK (understand categorical columns)
--    SELECT column_name, COUNT(*) FROM table GROUP BY column_name ORDER BY 2 DESC;

-- 10. TYPOS IN CATEGORIES
--    SELECT DISTINCT status_col FROM table ORDER BY 1;

-- ============================================================
-- OLIST CLEANING SCRIPT
-- ============================================================
PRAGMA table_info(olist_customers_dataset) --all good 
PRAGMA table_info(olist_geolocation_dataset) --all good 
PRAGMA table_info(olist_order_items_dataset) --all good 
PRAGMA table_info(olist_order_payments_dataset) --all good 
PRAGMA table_info(olist_order_reviews_dataset) --all good 
PRAGMA table_info(olist_orders_dataset) --all good 
PRAGMA table_info(olist_products_dataset) --all good
PRAGMA table_info(olist_sellers_dataset) --all good 
PRAGMA table_info(product_category_name_translation) --all good 

-- ------------------------------------------------------------
-- 1. CUSTOMERS
-- ------------------------------------------------------------
DROP TABLE IF EXISTS customers;

CREATE TABLE customers AS
SELECT
    customer_id,
    customer_unique_id,
    CAST(customer_zip_code_prefix AS TEXT)  AS zip_code,
    TRIM(LOWER(customer_city))              AS city,
    TRIM(UPPER(customer_state))             AS state
FROM olist_customers_dataset
WHERE customer_id IS NOT NULL
  AND customer_unique_id IS NOT NULL;


-- ------------------------------------------------------------
-- 2. SELLERS
-- ------------------------------------------------------------
DROP TABLE IF EXISTS sellers;

CREATE TABLE sellers AS
SELECT
    seller_id,
    CAST(seller_zip_code_prefix AS TEXT)    AS zip_code,
    TRIM(LOWER(seller_city))                AS city,
    TRIM(UPPER(seller_state))               AS state
FROM olist_sellers_dataset
WHERE seller_id IS NOT NULL;


-- ------------------------------------------------------------
-- 3. PRODUCTS (join English category names here)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS products;

CREATE TABLE products AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, 'unknown') AS category,
    p.product_name_lenght       AS name_length,
    p.product_description_lenght AS description_length,
    p.product_photos_qty        AS photos_qty,
    p.product_weight_g          AS weight_g,
    p.product_length_cm         AS length_cm,
    p.product_height_cm         AS height_cm,
    p.product_width_cm          AS width_cm
FROM olist_products_dataset p
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_id IS NOT NULL;


-- ------------------------------------------------------------
-- 4. ORDERS
-- ------------------------------------------------------------
DROP TABLE IF EXISTS orders;

CREATE TABLE orders AS
SELECT
    order_id,
    customer_id,
    TRIM(LOWER(order_status))                       AS order_status,
    DATETIME(order_purchase_timestamp)              AS purchased_at,
    DATETIME(order_approved_at)                     AS approved_at,
    DATETIME(order_delivered_carrier_date)          AS shipped_at,
    DATETIME(order_delivered_customer_date)         AS delivered_at,
    DATETIME(order_estimated_delivery_date)         AS estimated_delivery
FROM olist_orders_dataset
WHERE order_id IS NOT NULL
  AND customer_id IS NOT NULL;


-- ------------------------------------------------------------
-- 5. ORDER ITEMS
-- ------------------------------------------------------------
DROP TABLE IF EXISTS order_items;

CREATE TABLE order_items AS
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    DATETIME(shipping_limit_date)   AS shipping_limit,
    ROUND(price, 2)                 AS price,
    ROUND(freight_value, 2)         AS freight_value
FROM olist_order_items_dataset
WHERE order_id IS NOT NULL
  AND price >= 0
  AND freight_value >= 0;


-- ------------------------------------------------------------
-- 6. PAYMENTS
-- ------------------------------------------------------------
DROP TABLE IF EXISTS payments;

CREATE TABLE payments AS
SELECT
    order_id,
    payment_sequential,
    TRIM(LOWER(payment_type))       AS payment_type,
    payment_installments,
    ROUND(payment_value, 2)         AS payment_value
FROM olist_order_payments_dataset
WHERE order_id IS NOT NULL
  AND payment_value >= 0;


-- ------------------------------------------------------------
-- 7. REVIEWS
-- ------------------------------------------------------------
DROP TABLE IF EXISTS reviews;

CREATE TABLE reviews AS
SELECT
    review_id,
    order_id,
    review_score,
    NULLIF(TRIM(review_comment_title), '')      AS comment_title,
    NULLIF(TRIM(review_comment_message), '')    AS comment_message,
    DATETIME(review_creation_date)              AS created_at,
    DATETIME(review_answer_timestamp)           AS answered_at
FROM olist_order_reviews_dataset
WHERE order_id IS NOT NULL
  AND review_score BETWEEN 1 AND 5;


-- ------------------------------------------------------------
-- 8. GEOLOCATION (has known duplicates — deduplicate by avg)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS geolocation;

CREATE TABLE geolocation AS
SELECT
    CAST(geolocation_zip_code_prefix AS TEXT)   AS zip_code,
    ROUND(AVG(geolocation_lat), 6)              AS lat,
    ROUND(AVG(geolocation_lng), 6)              AS lng,
    TRIM(LOWER(geolocation_city))               AS city,
    TRIM(UPPER(geolocation_state))              AS state
FROM olist_geolocation_dataset
GROUP BY geolocation_zip_code_prefix;


-- ============================================================
-- VERIFY ALL CLEAN TABLES
-- ============================================================
SELECT 'customers'   , COUNT(*) FROM customers
UNION ALL
SELECT 'sellers'     , COUNT(*) FROM sellers
UNION ALL
SELECT 'products'    , COUNT(*) FROM products
UNION ALL
SELECT 'orders'      , COUNT(*) FROM orders
UNION ALL
SELECT 'order_items' , COUNT(*) FROM order_items
UNION ALL
SELECT 'payments'    , COUNT(*) FROM payments
UNION ALL
SELECT 'reviews'     , COUNT(*) FROM reviews
UNION ALL
SELECT 'geolocation' , COUNT(*) FROM geolocation;