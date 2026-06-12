-- PHASE 3 - EXPLORATORY DATA ANALYSIS
-- Task 1 - Orders over time (monthly volume, trend, seasonality, partial edge months)
-- Task 2 - Revenue over time + order value distribution (define revenue convention first)
-- Task 3 - Geography (orders/revenue by customer state, sellers by state)
-- Task 4 - Product categories (top by volume vs top by revenue)
-- Task 5 - Review score distribution
-- Task 6 - Buying behavior (payment types, installments, items per order)

-- Task 1 - Orders over time (monthly volume, trend, seasonality, partial edge months)
SELECT * FROM order_items LIMIT 5


SELECT  order_status , strftime('%Y-%m', purchased_at) AS purchased , COUNT(order_id)
FROM orders 
WHERE order_status = 'delivered'
GROUP BY purchased
ORDER BY purchased ASC

--TASK 1: ORDERS - delivered    2017-11    7289 at peak : Black Friday. The last Friday of November 

SELECT  strftime('%Y-%m', o.purchased_at) AS purchased ,SUM(oi.price + oi.freight_value) AS revenue 
FROM order_items AS oi
INNER JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY purchased
ORDER BY purchased ASC
-- average order value stayed stable over time, so growth came from more orders, not bigger orders. 



SELECT 
    MIN(t.order_total_value) AS min_revenue, 
    MAX(t.order_total_value) AS max_revenue, 
    AVG(t.order_total_value) AS avg_revenue
FROM (
    SELECT 
        oi.order_id, 
        SUM(oi.price + oi.freight_value) AS order_total_value
    FROM order_items oi 
    INNER JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
) AS t;

----MEDIAN : 

SELECT COUNT(*) 
FROM (
    SELECT oi.order_id
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
) AS t;
------------
SELECT t.order_total_value AS median_order_value
FROM (
    SELECT oi.order_id, SUM(oi.price + oi.freight_value) AS order_total_value
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
    ORDER BY order_total_value ASC
) AS t
LIMIT 1 OFFSET 48239;


-- TASK 2 - REVENUE
-- convention: revenue = SUM(price + freight_value) from order_items, delivered only
-- heavy right skew: tail of expensive orders pulls avg 50% above median
-- dashboard: report median as "typical order value"
-- max order value matches Phase 2 payment max (13,664) ,tables consistent


-- Task 3 - Geography (orders/revenue by customer state, sellers by state)


SELECT COUNT(DISTINCT c.customer_unique_id) AS number_of_customers  , c.state 
FROM customers c
INNER JOIN orders o 
ON c.customer_id = o.customer_id  
GROUP BY c.state
ORDER BY number_of_customers DESC
-- 40302 customer from SP / 12384	RJ / 11259	MG




SELECT  COUNT(DISTINCT s.seller_id) AS number_of_sellers , s.state
FROM sellers s 
INNER JOIN order_items oi 
ON s.seller_id = oi.seller_id
GROUP BY s.state
ORDER BY number_of_sellers DESC

-- 1849 seller from SP / 349	PR /  244	  MG



SELECT  COUNT(DISTINCT s.seller_id) AS number_of_sellers , s.state ,  SUM(oi.price + oi.freight_value) AS order_total_value
FROM sellers s 
INNER JOIN order_items oi 
ON s.seller_id = oi.seller_id
GROUP BY s.state
ORDER BY number_of_sellers DESC
-- 1849		SP	10235883.88
-- customers: SP 40,302 unique 
-- sellers: SP 1,849 of 3,095 
-- revenue by seller state: SP 10.2M
-- concentration ladder: customers < sellers < revenue
-- physical consequence: long shipping distances to north/northeast
-- feeds Phase 4: delivery time by state, freight by state, reviews by state
-- The farther a customer is from SP, the longer the delivery AND the higher the freight


-- Task 4 - Product categories (top by volume vs top by revenue)


SELECT p.category ,  COUNT(DISTINCT o.order_id) AS c_orders
FROM order_items o 
INNER JOIN products p 
ON o.product_id = p.product_id
WHERE p.category != 'unknown'
GROUP BY p.category
ORDER BY  c DESC
LIMIT 10 
-- bed_bath_table	9417
-- health_beauty	8836
-- sports_leisure	7720



SELECT p.category , SUM(o.price + o.freight_value) AS revenue , COUNT(DISTINCT o.order_id) AS c_orders
FROM order_items o 
INNER JOIN products  p 
ON o.product_id = p.product_id
WHERE p.category != 'unknown'
GROUP BY p.category
ORDER BY  revenue  DESC
-- health_beauty	1441248.07	8836
-- watches_gifts	1305541.61	5624
-- bed_bath_table	1241681.72	9417

-- by orders:  bed_bath_table 9,417 / health_beauty 8,836 / sports_leisure 7,720
-- by revenue: health_beauty 1.44M / watches_gifts 1.31M / bed_bath_table 1.24M
-- revenue per order: watches_gifts 232 / health_beauty 163 / bed_bath 132
-- rankings disagree -> "top category" requires specifying the metric
-- health_beauty strong on both axes = flagship category
-- categories already translated to English upstream, no translation join needed
-- 'unknown' (610 flagged products) excluded, per Phase 2

-- Task 5 - Review score distribution


SELECT COUNT(DISTINCT review_id) AS c_reviews , review_score , ROUND(COUNT(DISTINCT review_id) * 100.0 / (SELECT COUNT(DISTINCT review_id) FROM reviews), 2) AS percentage 
FROM reviews
GROUP BY review_score
ORDER BY c_reviews DESC
-- 56910	5	57.83
-- 19007	4	19.31
-- TASK 5 - REVIEWS
-- distribution: 5: 57.8% / 4: 19.3% / 1: 11.5% / 3: 8.2% / 2: 3.2%
-- backwards-J shape: poles speak, middle is silent (megaphone pattern)
-- avg (~4.1) misleading on bimodal data -> dashboard uses % pos / % neg
-- 1-star population (11,282) = Phase 4 target: link to late deliveries
-- caveat: reviews self-selected, not a census of satisfaction

-- Task 6 - Buying behavior (payment types, installments, items per order)

WITH items_per_order AS (
    SELECT order_id, COUNT(order_item_id) AS count_items
    FROM order_items
    GROUP BY order_id
)
SELECT
    CASE WHEN count_items = 1 THEN 'single item' ELSE 'multi item' END AS bucket,
    COUNT(*) AS orders,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM items_per_order), 2) AS pct
FROM items_per_order
GROUP BY bucket;

-- multi item	9803	9.94
-- single item	88863	90.06



SELECT  payment_type, COUNT(DISTINCT order_id) c_orders , ROUND(COUNT(DISTINCT order_id) * 100.0 / (SELECT COUNT(DISTINCT order_id) FROM payments ), 2) AS percentage 
FROM payments 
GROUP BY payment_type 
ORDER BY c_orders DESC 
-- credit_card	76505	76.94
-- boleto		19784	 19.9
-- voucher		 3866	 3.89
-- debit_card	 1528	 1.54
-- not_defined	    3	  0.0




SELECT 
	payment_type,
    COUNT(DISTINCT order_id) c_orders,
	ROUND(COUNT(DISTINCT order_id) * 100.0 / (SELECT COUNT(DISTINCT order_id) FROM payments ), 2) AS percentage,
    CASE 
        WHEN payment_installments <=  1 THEN 'upfront'
        WHEN payment_installments BETWEEN 2 AND 5 THEN 'Mid-Range'
        WHEN payment_installments > 5 THEN 'Long'
        ELSE 'Unknown'
    END AS bucket_label
FROM payments p
GROUP BY bucket_label  , payment_type
ORDER BY payment_installments ASC

-- TASK 6 - BUYING BEHAVIOR
-- payment type mix: credit_card 76.94 pct, boleto 19.9 pct, voucher 3.89 pct, debit 1.54 pct, not_defined 3 orders (flagged, check values)
-- installments: upfront 49.34 pct, mid-range (2-5) 35.32 pct, long (6+) 16.17 pct
-- cross finding: ALL financed orders are credit_card, no other method can split
-- within credit_card users: about 1/3 pay upfront, 2/3 finance
-- story: half of order volume is financed, exclusively via credit cards,
--        meaning revenue depends on Brazilian consumer credit appetite
-- bucket percentages sum slightly over 100 due to multi-payment-type orders (known, Phase 2)
-- items per order: max 21 (Phase 1 note corrected from 20)
-- single-item order share: 90 pct single item per order 

