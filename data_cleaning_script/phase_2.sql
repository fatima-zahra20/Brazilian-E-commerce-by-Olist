-- Phase 2 DATA QUALITY ASSESSMENT
-- Task 1  Interpret and classify nulls (acceptable vs problematic)
-- Task 2  Validate date sequence logic (purchased > approved > shipped > delivered)
-- Task 3  Detect outliers (extreme or impossible values)
-- Task 4  Referential integrity (foreign keys match across tables)
-- Task 5  Business logic checks (rules that should always be true)

-- Task 1  Interpret and classify nulls (acceptable vs problematic)
-- CUSTOMERS / PAYMENTS / GEOLOCATION / SELLERS /ORDER_ITEMS : 0 nulls
-- OEDERS : 
	COUNT(*) - COUNT(approved_at)    AS approved_at_nulls, --160  
	COUNT(*) - COUNT(shipped_at)     AS shipped_at_nulls,  --1783 
	COUNT(*) - COUNT(delivered_at)   AS delivered_at_nulls,  --2965 
	
-- REVIEWS : 
	COUNT(*) - COUNT(comment_title)   	 AS comment_title_nulls, -- 87 685 -- Empty strings
    COUNT(*) - COUNT(comment_message)	 AS comment_message_nulls, -- 58 256 -- Empty strings
	
-- PRODUCTS :
	COUNT(*) - COUNT(name_length)   		 AS name_length_nulls, --610
    COUNT(*) - COUNT(description_length)   	 AS description_length_nulls, --610
    COUNT(*) - COUNT(photos_qty)			 AS photos_qty_nulls, --610
	COUNT(*) - COUNT(weight_g)    			 AS weight_g_nulls, --2
	COUNT(*) - COUNT(length_cm)    		 	 AS length_cm_nulls , --2
	COUNT(*) - COUNT(height_cm)    		 	 AS height_cm_nulls, --2
	COUNT(*) - COUNT(width_cm)     			 AS width_cm_nulls --2
	
--OEDERS------------------------------------------------
--COUNT(*) - COUNT(approved_at)    AS approved_at_nulls, --160 
SELECT o.order_id , o.approved_at , p.payment_sequential
FROM orders o
LEFT OUTER JOIN payments p 
ON o.order_id = p.order_id
WHERE approved_at IS NULL

-- approved_at nulls (160 orders) FLAGGED AS PROBLEM
-- These orders have payment records but no approval timestamp
-- Money collected but order never formally approved
-- Could indicate a system processing error
-- Must be excluded from delivery time and fulfillment analysis



--COUNT(*) - COUNT(shipped_at)     AS shipped_at_nulls,  --1783 
SELECT  COUNT(*),order_status
FROM orders
WHERE shipped_at IS NULL 
GROUP BY order_status 
--approved - canceled - created - delivered - invoiced - processing - unavailable 

SELECT o.order_id , o.shipped_at , o.order_status 
FROM orders o 
INNER JOIN order_items i
ON o.order_id = i.order_id
WHERE o.shipped_at IS NULL AND o.order_status = 'approved'
--3 records approved not yet shipped 

SELECT o.order_id , o.shipped_at , o.order_status 
FROM orders o 
INNER JOIN order_items i
ON o.order_id = i.order_id
WHERE o.shipped_at IS NULL AND o.order_status = 'delivered'
--2 records dilivered and not yet shipped (weird)

SELECT o.order_id , o.shipped_at , o.order_status 
FROM orders o 
INNER JOIN order_items i
ON o.order_id = i.order_id
WHERE o.shipped_at IS NULL AND o.order_status = 'shipped' -- nothing -- good 

-- shipped_at nulls mostly acceptable by order_status
-- canceled, created, invoiced, processing, unavailable  expected, no issue
-- delivered with null shipped_at 2 records /approved 3 records, flagged as data quality issue
-- small enough to exclude from analysis without impacting results

--COUNT(*) - COUNT(delivered_at)   AS delivered_at_nulls,  --2965 

SELECT o.order_id , o.delivered_at , o.order_status 
FROM orders o 
INNER JOIN order_items i
ON o.order_id = i.order_id
WHERE o.delivered_at IS NULL AND o.order_status = 'shipped'
--approved - canceled - created - invoiced - processing - unavailable - shipped are all ok to have empty delivered_at except delivered 

SELECT o.order_id , o.delivered_at , o.order_status 
FROM orders o 
INNER JOIN order_items i
ON o.order_id = i.order_id
WHERE o.delivered_at IS NULL AND o.order_status = 'delivered'
-- 8 records with delivered status and without delivered_at date (weird)

-- delivered_at nulls  mostly acceptable by order_status
-- delivered with null delivered_at 8 records, flagged as data quality issue
-- small enough to exclude from analysis without impacting results
-- BUT must filter intentionally in delivery time calculations
-- or these 8 will silently skew the average delivery time
------------------------------------------------------------
-- REVIEWS -------------------------------------------------
-- we don't really care about these , because the clients didn't leave any text 
------------------------------------------------------------
-- PRODUCTS ------------------------------------------------

--	name_length_nulls, --610
--  description_length_nulls, --610
--  photos_qty_nulls, --610
--  Same Number - worth checking

SELECT p.product_id , p.category 
FROM products p 
INNER JOIN order_items i 
ON p.product_id = i.product_id
WHERE p.name_length IS NULL 
AND p.description_length IS NULL 
AND p.photos_qty IS NULL
-- only one category , unknown 
-- these products were actually sold (appear in order_items)
-- incomplete listings  never properly set up by sellers
-- will appear as 'unknown' category in revenue analysis
-- flag when doing category analysis in Phase 4

-- weight_g_nulls, --2
-- length_cm_nulls , --2
-- height_cm_nulls, --2
-- width_cm_nulls --2

SELECT p.product_id , p.category 
FROM products p 
INNER JOIN order_items i 
ON p.product_id = i.product_id
WHERE p.weight_g IS NULL 
AND p.length_cm IS NULL 
AND p.height_cm IS NULL
AND width_cm IS NULL
-- 2 products with null dimensions (weight, length, height, width)
-- one in 'baby' category, one in 'unknown'
-- both were sold appear in order_items
-- freight calculations for these products may be uncorrect
-- flag when analyzing freight values in Phase 4
------------------------------------------------------------


-- Task 2  Validate date sequence logic (purchased > approved > shipped > delivered)

-- SELECT * FROM orders LIMIT 5  
-- purchased_at > approved_at > shipped_at > delivered_at 

SELECT order_id , order_status , purchased_at , approved_at 
FROM orders 
WHERE purchased_at  >  approved_at
-- Empty table (normal case) 


SELECT order_id , order_status  , approved_at , shipped_at 
FROM orders 
WHERE approved_at  >  shipped_at
--1359 are shiped before they got approved (weird)
SELECT order_id , order_status  , approved_at , shipped_at 
FROM orders 
WHERE approved_at <  shipped_at
-- 96 285 are approved before they got shipped (normal case)


SELECT order_id , order_status , shipped_at , delivered_at 
FROM orders 
WHERE shipped_at  >  delivered_at
-- 23 order_id are delivred before they got shipped (weird)
SELECT order_id , order_status , shipped_at , delivered_at 
FROM orders 
WHERE shipped_at  <  delivered_at
-- 96443 are delivred after they got shipped (normal case)
-- 1,359 orders: shipped_at before approved_at
-- possibly explainable  boleto payments confirm slowly, sellers ship early
-- not necessarily an error, but flagged
-- 23 orders: delivered_at before shipped_at
-- impossible sequence confirmed data quality error
-- exclude from delivery time analysis

SELECT order_id , order_status , delivered_at , estimated_delivery 
FROM orders 
WHERE estimated_delivery  <  delivered_at --7827
SELECT order_id , order_status , delivered_at , estimated_delivery 
FROM orders 
WHERE estimated_delivery  >  delivered_at --88649
SELECT order_id , order_status , delivered_at , estimated_delivery 
FROM orders 
WHERE estimated_delivery = delivered_at -- 0 

-- 7,827 orders delivered after estimated_delivery (8% late rate)
-- NOT a data error  a business performance metric
-- key metric for Phase 4: late delivery analysis by state/seller/month
-- estimated_delivery has no time component (midnight) 
-- exact equality with delivered_at never occurs
-- "late" definition should account for this in Phase 4



-- Task 3  Detect outliers (extreme or impossible values)
SELECT MAX(price), MIN(price), MAX(freight_value), MIN(freight_value)
FROM order_items -- 6735.0 -	0.85  -	409.68	 -  0.0  
SELECT MAX(payment_value), MIN(payment_value)
FROM payments  -- 0 to 13664
SELECT MAX(weight_g), MIN(weight_g)
FROM products -- 0 to 40425 


SELECT DISTINCT order_id, price , freight_value 
FROM order_items
WHERE freight_value = 0 -- 339 rows / price is never 0 

SELECT DISTINCT p.order_id , p.payment_value , p.payment_type
FROM payments p
INNER JOIN order_items o ON p.order_id = o.order_id
WHERE p.payment_value = 0 -- 5 rows

SELECT  DISTINCT p.product_id , p.weight_g
FROM products p
INNER JOIN order_items o ON p.product_id = o.product_id
WHERE p.weight_g = 0 -- 4 rows 

SELECT p.order_id , SUM(p.payment_value) , p.payment_type , p.payment_sequential
FROM payments p
INNER JOIN order_items o ON p.order_id = o.order_id
WHERE p.payment_sequential > 28 

-- OUTLIER FINDINGS (Task 3)
-- freight_value = 0 -339 orders: free shipping, acceptable
-- payment_value = 0 -5 orders, all voucher type: acceptable quirk
-- weight_g = 0- 4 distinct products, all sold : impossible value, flagged
-- price and payment maximums plausible  no action
-- pattern: data issues live in zeros/minimums, not maximums
-- 29-payment order (fa65dad1...) : RESOLVED
-- all 29 rows are vouchers with varying values
-- SUM(payments) = 457.99 = SUM(price + freight) : perfect match
-- legitimate voucher stacking, not a data error
-- weird but real: no action needed

-- Task 4  Referential integrity (foreign keys match across tables)

SELECT c.*
FROM order_items c
LEFT JOIN orders p ON c.order_id = p.order_id
WHERE p.order_id IS NULL; -- nothing , cool 
-----------------------------------------

SELECT c.*
FROM order_items c
LEFT JOIN products p ON c.product_id  = p.product_id 
WHERE p.product_id IS NULL; -- nothing , cool 
-----------------------------------------

SELECT c.*
FROM order_items c
LEFT JOIN sellers p ON c.seller_id   = p.seller_id  
WHERE p.seller_id  IS NULL; -- nothing , cool 
-----------------------------------------

SELECT c.*
FROM payments c
LEFT JOIN orders p ON c.order_id   = p.order_id  
WHERE p.order_id  IS NULL; -- nothing , cool 
-----------------------------------------

SELECT c.*
FROM reviews c
LEFT JOIN orders p ON c.order_id   = p.order_id  
WHERE p.order_id  IS NULL; -- nothing , cool 
-----------------------------------------

SELECT c.*
FROM orders c
LEFT JOIN customers p ON c.customer_id   = p.customer_id  
WHERE p.customer_id  IS NULL; -- nothing , cool 
-----------------------------------------

SELECT c.*
FROM sellers c
LEFT JOIN geolocation p ON c.zip_code   = p.zip_code  
WHERE p.zip_code  IS NULL; -- 7 rows 
-----------------------------------------

SELECT c.*
FROM customers c
LEFT JOIN geolocation p ON c.zip_code   = p.zip_code  
WHERE p.zip_code  IS NULL; --278

-- TASK 4 FINDINGS — referential integrity
-- all hard FK relationships clean: zero orphans in order_items => orders/products/sellers, payments => orders, reviews=> orders, orders =>customers
-- soft lookup gaps: 7 sellers + 278 customer rows have not too much 
-- impact: tiny holes in PBI coordinate map only
-- fallback: city/state columns still available for those rows

-- Task 5  Business logic checks (rules that should always be true)

-- VALUE RANGES 
SELECT review_score FROM reviews WHERE review_score NOT BETWEEN 1 AND 5 -- rule N° 1 
-- COMPLETENESS ACROSS TABLES 
SELECT c.*
FROM orders c LEFT JOIN order_items p ON c.order_id = p.order_id
WHERE p.order_id IS NULL;  --775


SELECT c.order_id,c.order_status, COUNT(*)
FROM orders c LEFT JOIN order_items p ON c.order_id = p.order_id
WHERE p.order_id IS NULL AND c.order_status = 'shipped' AND c.order_id = 'bfbd0f9bdef84302105ad712db648a6c'
GROUP BY c.order_status , c.order_id 
 --775canceled created - invoiced - shipped(weird) -- just 1- unavailable

SELECT c.*
FROM orders c LEFT JOIN payments p ON c.order_id = p.order_id
WHERE p.order_id IS NULL; -- just 1
--hmm are they the same ? 
-- NO 
-- the two single-order anomalies are DIFFERENT orders: 'bfbd0f9b...'  status :'shipped', zero items , (other id) : has items, zero payment rows
-- both excluded from revenue/fulfillment analysis


-- REVIEW TIMESTAMP :
SELECT answered_at , created_at
FROM reviews 
WHERE answered_at  < created_at
-- empty 

-- STATUTS SANITY : 
SELECT DISTINCT order_status FROM orders -- all 8










-- If you are so lazy : read this 
-- ============================================================
-- PHASE 2 - DATA QUALITY ASSESSMENT - FINAL NOTES
-- ============================================================

-- TASK 1 - NULLS
-- approved_at nulls (160): have payment records but no approval, system error, FLAGGED
-- shipped_at nulls (1783): expected by status, except 2 'delivered' with no ship date, FLAGGED
-- delivered_at nulls (2965): expected by status, except 8 'delivered' with no delivery date, FLAGGED
-- review comment nulls (87k titles, 58k messages): optional fields, acceptable
-- 610 products with null name/description/photos: all category 'unknown', all sold, flag for category analysis
-- 2 products with null dimensions (1 baby, 1 unknown): sold, freight values unreliable

-- TASK 2 - DATE SEQUENCES
-- purchased > approved: clean
-- 1359 shipped before approved: possibly boleto payment delays, explainable, noted
-- 23 delivered before shipped: impossible, FLAGGED, exclude from delivery time analysis
-- 7827 delivered after estimated_delivery (~8% late rate): business metric for Phase 4, not an error
-- estimated_delivery has no time component (midnight), exact match with delivered_at never occurs

-- TASK 3 - OUTLIERS
-- freight_value = 0 (339 orders): free shipping, acceptable
-- payment_value = 0 (5 orders, all voucher): acceptable quirk
-- weight_g = 0 (4 distinct products, all sold): impossible, FLAGGED
-- price and payment maximums plausible, no action
-- 29-payment order RESOLVED: 29 vouchers, total paid 457.99 = order value exactly, legitimate

-- TASK 4 - REFERENTIAL INTEGRITY
-- all hard FK relationships clean, zero orphans:
--   order_items to orders/products/sellers, payments to orders,
--   reviews to orders, orders to customers
-- 7 sellers + 278 customer rows have zip codes missing from geolocation (~0.3%)
-- impact: small holes in PBI coordinate map, fallback to city/state columns

-- TASK 5 - BUSINESS LOGIC
-- review_score: all within 1-5, clean
-- 775 orders with no order_items: mostly 'unavailable' and 'canceled', explainable
--   except 1 order status 'shipped' with zero items, FLAGGED
-- 1 order with items but no payment record, FLAGGED (different order from above)
-- answered_at < created_at: clean
-- order_status: 8 legitimate values, no junk

-- EXCLUSION LIST FOR ANALYSIS PHASES:
-- 160 unapproved-with-payment orders (fulfillment analysis)
-- 23 delivered-before-shipped orders (delivery time analysis)
-- 8 delivered-with-no-date orders (delivery time analysis)
-- 1 shipped-with-no-items order (revenue analysis)
-- 1 no-payment order (revenue analysis)
-- 4 zero-weight products (freight analysis)
