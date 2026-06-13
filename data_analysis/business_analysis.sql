-- PHASE 4 - BUSINESS DEEP-DIVE
-- Task 1 - Delivery time + freight by customer state (distance hypothesis)
-- Task 2 - Late delivery rate by state and month (Black Friday stress test)
-- Task 3 - Review score vs delivery lateness (1-star autopsy)
-- Task 4 - Revenue concentration (top sellers, top categories share)
-- Task 5 - Repeat purchase rate (the retention reality)
-- Task 6 - Seller scorecard (revenue, speed, satisfaction per seller)



-- Distance Hypothesis 
SELECT 
	ROUND(AVG(julianday(delivered_at) - julianday(purchased_at)), 2) AS avg_delivery_days, c.state,
    COUNT(o.order_id) AS number_of_orders
FROM customers c
INNER JOIN orders o 
ON c.customer_id = o.customer_id  
WHERE o.order_status = 'delivered'  AND o.delivered_at IS NOT NULL AND julianday(o.shipped_at) <= julianday(o.delivered_at)
GROUP BY c.state
ORDER BY avg_delivery_days ASC;
-- freight_value
WITH freight_per_state AS (
    SELECT
        c.state,
        ROUND(AVG(oi.freight_value), 2) AS avg_freight,
        COUNT(*) AS items
    FROM customers c
    INNER JOIN orders o  ON c.customer_id = o.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.state
)
SELECT
    state,
    avg_freight,
    items,
    CASE
        WHEN avg_freight <= 20 THEN 'cheap'
        WHEN avg_freight <= 30 THEN 'mid'
        ELSE 'expensive'
    END AS freight_label
FROM freight_per_state
ORDER BY items DESC;


-- delivery time = delivered_at minus purchased_at, delivered orders only
-- exclusions applied: null delivery dates, 23 delivered-before-shipped orders
-- TIME: fastest SP 8.8 days (40,479 orders), slowest RR 29.4 / AP 27.2 / AM 26.4
-- FREIGHT: cheapest SP 15.15 avg, most expensive RR 42.98 / PB 42.72 / AC 40.07
-- freight query needs no julianday and no time-traveler exclusion: no dates involved
-- VERDICT: both hypotheses confirmed, time map = money map = distance map
-- remote north/northeast pays 3x freight and waits 3x longer than SP
-- caveat: small samples in remote states (RR 52 items), gradient consistent overall
-- dashboard implication: delivery performance map page, color by days or freight
-- business implication: Olist's worst customer experience is structural (geography),
--                       not operational, unless seller base decentralizes



-- Task 2 - Late delivery rate by state and month (Black Friday stress test)


SELECT 
	ROUND(AVG(julianday(delivered_at) - julianday(purchased_at)), 2) AS avg_delivery_days, c.state,
    COUNT(o.order_id) AS number_of_orders
	
FROM customers c
INNER JOIN orders o 
ON c.customer_id = o.customer_id  
WHERE o.order_status = 'delivered'  
AND o.delivered_at IS NOT NULL 
AND julianday(o.estimated_delivery) <= julianday(o.delivered_at)
AND julianday(o.shipped_at) <= julianday(o.delivered_at) 
GROUP BY c.state
ORDER BY avg_delivery_days DESC 

-- AP ranked the 1st of late deliveries up to 87 days , 47.45	days PA	with 117 order , while 22.37 days	for SP	with 2386 orders as the least rank of late deliveries 
SELECT
	ROUND(AVG(julianday(delivered_at) - julianday(purchased_at)), 2) AS avg_delivery_days, c.state,
    COUNT(o.order_id) AS number_of_orders,
	ROUND(SUM(CASE WHEN julianday(o.delivered_at) > julianday(o.estimated_delivery) THEN 1 ELSE 0 END) * 100.0 / COUNT(o.order_id), 2) AS late_rate_pct
FROM customers c
INNER JOIN orders o 
ON c.customer_id = o.customer_id  
WHERE o.order_status = 'delivered'  
AND o.delivered_at IS NOT NULL 
AND julianday(o.shipped_at) <= julianday(o.delivered_at) 
GROUP BY c.state
ORDER BY late_rate_pct DESC 
--24.54		AL		397		23.93 as the highest pct 

SELECT
	ROUND(AVG(julianday(delivered_at) - julianday(purchased_at)), 2) AS avg_delivery_days,
    COUNT(order_id) AS number_of_orders,
	ROUND(SUM(CASE WHEN julianday(delivered_at) > julianday(estimated_delivery) THEN 1 ELSE 0 END) * 100.0 / COUNT(order_id), 2) AS late_rate_pct
FROM orders 
WHERE order_status = 'delivered'  
AND delivered_at IS NOT NULL 
AND julianday(shipped_at) <= julianday(delivered_at) 
ORDER BY late_rate_pct DESC 


-- platform baseline late rate: 8.11% (96,446 delivered orders)



SELECT 
	strftime('%Y-%m', purchased_at) AS purchased ,
	ROUND(AVG(julianday(delivered_at) - julianday(purchased_at)), 2) AS avg_delivery_days,
    COUNT(o.order_id) AS number_of_orders,
	ROUND(SUM(CASE WHEN julianday(o.delivered_at) > julianday(o.estimated_delivery) THEN 1 ELSE 0 END) * 100.0 / COUNT(o.order_id), 2) AS late_rate_pct
FROM customers c
INNER JOIN orders o 
ON c.customer_id = o.customer_id  
WHERE o.order_status = 'delivered'  
AND o.delivered_at IS NOT NULL 
AND julianday(o.shipped_at) <= julianday(o.delivered_at) 
GROUP BY purchased
ORDER BY purchased ASC



-- TASK 2 - LATE DELIVERIES
-- platform baseline late rate: 24.54 AL	397		23.93 as the highest pct 
-- late by state: AP worst at 87 avg days late, SP best at 22 avg days late
-- Black Friday stress test (2017-11):
--   late rate nearly tripled: 5.2% (Oct) to 14.3% (Nov), back to 8.4% (Dec)
--   avg delivery days also spiked: 12 to 15, recovered slower than late rate
--   verdict: operations bent but recovered within 30 days, did not break


-- Task 3 - Review score vs delivery lateness (1-star autopsy)

SELECT 
	CASE WHEN julianday(o.delivered_at) > julianday(o.estimated_delivery) 
     THEN 'late' ELSE 'on time' END AS delivery_status,
	 AVG(r.review_score) avg_review,
	 COUNT(*)
FROM orders o INNER JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'  
AND o.delivered_at IS NOT NULL 
AND julianday(o.shipped_at) <= julianday(o.delivered_at) 
GROUP BY delivery_status
ORDER BY avg_review  ASC


-- TASK 3 - REVIEW SCORE VS DELIVERY LATENESS
-- on-time orders: avg review 4.29 (88,630 orders)
-- late orders: avg review 2.57 (7,699 orders)
-- gap: 1.72 points on a 5-point scale
-- late delivery does not nudge scores down -- it nearly halves them
-- full chain confirmed: distance -> slow delivery -> late -> bad review
-- dashboard: delivery performance and satisfaction must share a page

-- Task 4 - Revenue concentration (top sellers, top categories share)


SELECT
    seller_id,
    revenue,
    RANK() OVER (ORDER BY revenue DESC) AS rank,
    ROUND(SUM(revenue) OVER (ORDER BY revenue DESC 
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) 
          * 100.0 / SUM(revenue) OVER (), 2) AS cumulative_pct
FROM (
    SELECT seller_id, SUM(price + freight_value) AS revenue
    FROM order_items
    GROUP BY seller_id
) AS t
ORDER BY rank;


-- TASK 4 - REVENUE CONCENTRATION
-- top 135 sellers (4.4% of 3,095) hold 50% of platform revenue
-- top 562 sellers (18% of 3,095) hold 80% of platform revenue
-- bottom 82% of sellers generate only 20% of revenue
-- concentration risk: losing top 5% of sellers = losing half of revenue
-- window functions used: RANK() + SUM() OVER() for cumulative share
-- feeds Phase 6: seller leaderboard page


-- Task 5 - Repeat purchase rate (the retention reality)


WITH customer_orders AS (
	
    SELECT c.customer_unique_id,COUNT(o.order_id) AS total_orders
    FROM  orders o 
    INNER JOIN  customers c ON o.customer_id = c.customer_id -- Fixed join column
    WHERE o.order_status = 'delivered'  
    GROUP BY  c.customer_unique_id
)
SELECT 
    CASE WHEN total_orders = 1 THEN 'single purchase'
         WHEN total_orders = 2 THEN 'double purchase'
    ELSE 'multiple purchase' END AS purchase_status,
    COUNT(*) AS number_of_customers, 
	ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_orders), 2) AS pct
FROM customer_orders
GROUP BY 
    CASE 
        WHEN total_orders = 1 THEN 'single purchase'
        WHEN total_orders = 2 THEN 'double purchase'
        ELSE 'multiple purchase'
    END
ORDER BY 
    number_of_customers DESC;
	
	
	
-- TASK 5 - REPEAT PURCHASE RATE
-- single purchase: 90,557 customers (97.0%)
-- double purchase: 2,573 customers (2.76%)
-- multiple purchase (3+): 228 customers (0.24%)
-- only 3% of customers ever returned
-- platform grows entirely through new customer acquisition
-- repeat base (2,801 customers) = most valuable segment, largely invisible
-- retention is the single biggest strategic weakness in this dataset
-- feeds Phase 6: executive summary page headline finding


-- Task 6 - Seller scorecard (revenue, speed, satisfaction per seller)

WITH revenue AS(
	SELECT seller_id, SUM(price + freight_value) AS revenue_r
	FROM order_items
	GROUP BY seller_id
),
speed AS(
	SELECT oi.seller_id, ROUND(AVG(julianday(o.delivered_at) - julianday(o.purchased_at)), 1) AS avg_speed 
	FROM order_items oi
	INNER JOIN orders o ON oi.order_id = o.order_id
	WHERE o.order_status = 'delivered'  
	AND o.delivered_at IS NOT NULL 
	AND julianday(o.shipped_at) <= julianday(o.delivered_at) 
	GROUP BY oi.seller_id
),
satisfaction AS(
	SELECT oi.seller_id, ROUND(AVG(r.review_score), 2) AS avg_review
	FROM order_items oi
	INNER JOIN orders o ON oi.order_id = o.order_id
	INNER JOIN reviews r ON o.order_id = r.order_id
	GROUP BY oi.seller_id
)
SELECT r.seller_id, r.revenue_r, s.avg_speed, st.avg_review
FROM revenue r
JOIN speed s ON r.seller_id = s.seller_id
JOIN satisfaction st ON s.seller_id = st.seller_id
ORDER BY r.revenue_r DESC
LIMIT 5 

-- TASK 6 - SELLER SCORECARD
-- CTE structure: revenue + speed + satisfaction joined on seller_id
-- top seller: 249,640 revenue / 15.0 avg days / 4.12 review
-- outlier: 2nd highest revenue (239k) slowest of top 5 (22.4 days) / 3.35 review
-- general pattern: top revenue sellers run clean operations
-- exception: high revenue does not guarantee good operations (seller 2)
-- low revenue outlier flagged earlier: 1.0 review score despite fast delivery
-- feeds Phase 6: seller leaderboard page directly













