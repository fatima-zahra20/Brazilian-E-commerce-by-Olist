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

SELECT * FROM orders LIMIT 5 
SELECT * FROM customers LIMIT 5 
SELECT * FROM sellers LIMIT 5
SELECT * FROM order_items LIMIT 5 

SELECT COUNT(DISTINCT c.customer_unique_id) AS number_of_customers  , c.state 
FROM customers c
INNER JOIN orders o 
ON c.customer_id = o.customer_id  
GROUP BY c.state
ORDER BY number_of_customers DESC
-- 40302 customer from SP


SELECT  COUNT(DISTINCT s.seller_id) AS number_of_sellers , s.state
FROM sellers s 
INNER JOIN order_items oi 
ON s.seller_id = oi.seller_id
GROUP BY s.state
ORDER BY number_of_sellers DESC

-- 1849 seller from SP 

SELECT  COUNT(DISTINCT s.seller_id) AS number_of_sellers , s.state ,  SUM(oi.price + oi.freight_value) AS order_total_value
FROM sellers s 
INNER JOIN order_items oi 
ON s.seller_id = oi.seller_id
GROUP BY s.state
ORDER BY number_of_sellers DESC
-- 1849		SP	10235883.88
-- TASK 3 - GEOGRAPHY
-- customers: SP 40,302 unique 
-- sellers: SP 1,849 of 3,095 
-- revenue by seller state: SP 10.2M
-- concentration ladder: customers < sellers < revenue
-- physical consequence: long shipping distances to north/northeast
-- feeds Phase 4: delivery time by state, freight by state, reviews by state
-- The farther a customer is from SP, the longer the delivery AND the higher the freight










