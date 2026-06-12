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


--Task 2 — the Black Friday stress test.  