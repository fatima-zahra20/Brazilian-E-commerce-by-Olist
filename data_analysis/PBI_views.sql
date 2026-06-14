-- Should Olist invest in retention programs or double down on acquisition?
-- Where should Olist prioritize regional fulfillment centers or carrier partnerships?
-- Which sellers need account management attention, and which are flight risks based on declining scores?
-- Where should operations investment go first to maximize satisfaction recovery?




--Revenue health


CREATE VIEW vw_customer_retention AS
WITH customer_summary AS (
    SELECT
        c.customer_unique_id,
        strftime('%Y-%m', MIN(o.purchased_at)) AS first_purchase_month,
        COUNT(o.order_id) AS total_orders,
        CASE
            WHEN COUNT(o.order_id) = 1 THEN 'single'
            WHEN COUNT(o.order_id) = 2 THEN 'double'
            ELSE 'multiple'
        END AS purchase_status
    FROM customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    first_purchase_month,
    purchase_status,
    COUNT(*) AS number_of_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY first_purchase_month), 2) AS pct_of_cohort
FROM customer_summary
GROUP BY first_purchase_month, purchase_status
ORDER BY first_purchase_month ASC;




--Delivery performance

CREATE VIEW vw_delivery_by_state AS
WITH delivery_metrics AS (
    SELECT
        c.state,
        COUNT(o.order_id) AS number_of_orders,
        ROUND(AVG(julianday(o.delivered_at) - julianday(o.purchased_at)), 2) AS avg_delivery_days,
        ROUND(SUM(CASE WHEN julianday(o.delivered_at) > julianday(o.estimated_delivery) 
                       THEN 1 ELSE 0 END) * 100.0 / COUNT(o.order_id), 2) AS late_rate_pct
    FROM customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    AND o.delivered_at IS NOT NULL
    AND julianday(o.shipped_at) <= julianday(o.delivered_at)
    GROUP BY c.state
)
SELECT
    state,
    number_of_orders,
    avg_delivery_days,
    late_rate_pct,
    CASE
        WHEN late_rate_pct >= 15 AND number_of_orders >= 500 THEN 'high priority'
        WHEN late_rate_pct >= 10 AND number_of_orders >= 200 THEN 'medium priority'
        ELSE 'monitor'
    END AS investment_priority
FROM delivery_metrics
ORDER BY late_rate_pct DESC;


--Seller health

CREATE VIEW vw_seller_scorecard AS
WITH revenue AS (
    SELECT
        seller_id,
        SUM(price + freight_value) AS revenue_r,
        COUNT(DISTINCT order_id) AS order_count
    FROM order_items
    GROUP BY seller_id
),
speed AS (
    SELECT oi.seller_id,
        ROUND(AVG(julianday(o.delivered_at) - julianday(o.purchased_at)), 1) AS avg_speed
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    AND o.delivered_at IS NOT NULL
    AND julianday(o.shipped_at) <= julianday(o.delivered_at)
    GROUP BY oi.seller_id
),
satisfaction AS (
    SELECT oi.seller_id,
        ROUND(AVG(r.review_score), 2) AS avg_review
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    INNER JOIN reviews r ON o.order_id = r.order_id
    GROUP BY oi.seller_id
)
SELECT
    r.seller_id,
    r.revenue_r,
    r.order_count,
    s.avg_speed,
    st.avg_review,
    CASE
        WHEN r.revenue_r >= 50000 AND st.avg_review < 3.5 THEN 'needs immediate attention'
        WHEN r.revenue_r < 50000 AND st.avg_review < 3.0 THEN 'review for removal'
        WHEN st.avg_review >= 4.0 AND s.avg_speed <= 15 THEN 'healthy'
        ELSE 'monitor'
    END AS account_status
FROM revenue r
JOIN speed s ON r.seller_id = s.seller_id
JOIN satisfaction st ON s.seller_id = st.seller_id;


-- seller health

CREATE VIEW vw_seller_score_trend AS
SELECT
    oi.seller_id,
    strftime('%Y-%m', o.purchased_at) AS order_month,
    ROUND(AVG(r.review_score), 2) AS avg_monthly_review,
    COUNT(DISTINCT o.order_id) AS monthly_orders
FROM order_items oi
INNER JOIN orders o ON oi.order_id = o.order_id
INNER JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
AND o.delivered_at IS NOT NULL
GROUP BY oi.seller_id, strftime('%Y-%m', o.purchased_at)
ORDER BY oi.seller_id, order_month ASC;


--Customer satisfaction


CREATE VIEW vw_satisfaction_recovery AS
SELECT
    c.state,
    COUNT(*) AS late_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_on_late,
    CASE
        WHEN COUNT(*) >= 500 AND AVG(r.review_score) < 2.5 THEN 'high priority'
        WHEN COUNT(*) >= 200 AND AVG(r.review_score) < 3.0 THEN 'medium priority'
        ELSE 'monitor'
    END AS recovery_priority
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
INNER JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
AND o.delivered_at IS NOT NULL
AND julianday(o.shipped_at) <= julianday(o.delivered_at)
AND julianday(o.delivered_at) > julianday(o.estimated_delivery)
GROUP BY c.state
ORDER BY avg_review_on_late ASC;