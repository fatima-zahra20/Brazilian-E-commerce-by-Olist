--Phase 1:
--Task 1  Row counts. Know how big each table is before anything else.
--Task 2  Schema inspection. Understand every column's name, type, and whether nulls exist.
--Task 3  Grain check. Confirm what one row actually represents in each table , this prevents bad joins later.
--Task 4  Relationship validation. Confirm that foreign keys actually match between tables.

--Task 1:  Row counts
SELECT COUNT(*) FROM customers;   -- 99 441
SELECT COUNT(*) FROM orders;      -- 99 441
SELECT COUNT(*) FROM reviews;     -- 99 224
SELECT COUNT(*) FROM products;    -- 32 951
SELECT COUNT(*) FROM payments;    --103 886
SELECT COUNT(*) FROM geolocation; -- 19 015
SELECT COUNT(*) FROM sellers;     --  3 095
SELECT COUNT(*) FROM order_items; --112 650


--Task 2: Schema inspection. 
--1:
SELECT * FROM customers LIMIT 5; 	-- customer_id , customer_unique_id , zip_code, city, state
SELECT * FROM orders LIMIT 5; 	 	-- order_id, customer_id 
SELECT * FROM reviews LIMIT 5;   	-- review_id , order_id
SELECT * FROM products LIMIT 5;  	-- product_id 
SELECT * FROM payments LIMIT 5;  	-- order_id 
SELECT * FROM geolocation LIMIT 5; 	-- zip_code , lat , lng , state , city
SELECT * FROM sellers LIMIT 5;		-- seller_id 
SELECT * FROM order_items LIMIT 5;  -- order_id , order_item_id , product_id , seller_id 
--2: 

PRAGMA table_info(customers) 
PRAGMA table_info(orders)    
PRAGMA table_info(reviews) 	
PRAGMA table_info(products)  
PRAGMA table_info(payments) 
PRAGMA table_info(geolocation) 
PRAGMA table_info(sellers)
PRAGMA table_info(order_items) 

--3: 


SELECT 
    COUNT(*) - COUNT(customer_id)      		 AS customer_id_nulls, -- 0
    COUNT(*) - COUNT(customer_unique_id)     AS customer_unique_id_nulls, -- 0
    COUNT(*) - COUNT(zip_code)   			 AS zip_code_nulls, -- 0
    COUNT(*) - COUNT(city) 					 AS city_nulls, -- 0
	COUNT(*) - COUNT(state) 				 AS state_nulls -- 0
FROM customers;


SELECT 
    COUNT(*) - COUNT(order_id)       AS order_id_nulls,  -- 0
    COUNT(*) - COUNT(customer_id)    AS customer_id_nulls, -- 0
    COUNT(*) - COUNT(order_status)   AS order_status_nulls, -- 0
    COUNT(*) - COUNT(purchased_at)   AS purchased_at_nulls, -- 0
	COUNT(*) - COUNT(approved_at)    AS approved_at_nulls, --160
	COUNT(*) - COUNT(shipped_at)     AS shipped_at_nulls,  --1783
	COUNT(*) - COUNT(delivered_at)   AS shipped_at_nulls,  --2965
	COUNT(*) - COUNT(estimated_delivery)     AS shipped_at_nulls  -- 0
FROM orders;


SELECT 
	COUNT(*) - COUNT(review_id)     	 AS review_id_nulls, -- 0
    COUNT(*) - COUNT(order_id)     		 AS order_id_nulls, -- 0
    COUNT(*) - COUNT(review_score)   	 AS review_score_nulls, -- 0
    COUNT(*) - COUNT(comment_title)   	 AS comment_title_nulls, -- 87 685 
    COUNT(*) - COUNT(comment_message)	 AS comment_message_nulls, -- 58 256
	COUNT(*) - COUNT(created_at)    	 AS created_at_nulls, -- 0
	COUNT(*) - COUNT(answered_at)     	 AS answered_at_nulls  -- 0
FROM reviews;


SELECT 
	COUNT(*) - COUNT(product_id)     		 AS product_id_nulls, -- 0
    COUNT(*) - COUNT(category)     			 AS category_nulls, -- 0
    COUNT(*) - COUNT(name_length)   		 AS name_length_nulls, --610
    COUNT(*) - COUNT(description_length)   	 AS description_length_nulls, --610
    COUNT(*) - COUNT(photos_qty)			 AS photos_qty_nulls, --610
	COUNT(*) - COUNT(weight_g)    			 AS weight_g_nulls, --2
	COUNT(*) - COUNT(length_cm)    		 	 AS length_cm_nulls , --2
	COUNT(*) - COUNT(height_cm)    		 	 AS height_cm_nulls, --2
	COUNT(*) - COUNT(width_cm)     			 AS width_cm_nulls --2
FROM products;


SELECT 
	COUNT(*) - COUNT(order_id)     			 AS order_id_nulls, -- 0
    COUNT(*) - COUNT(payment_sequential)     AS payment_sequential_nulls,  -- 0
    COUNT(*) - COUNT(payment_type)   		 AS payment_type_nulls, -- 0
    COUNT(*) - COUNT(payment_installments)   AS payment_installments_nulls, -- 0
    COUNT(*) - COUNT(payment_value)			 AS payment_value_nulls -- 0
FROM payments;


SELECT 
	COUNT(*) - COUNT(zip_code)  AS zip_code_nulls, -- 0
    COUNT(*) - COUNT(lat)       AS lat_nulls,  -- 0
    COUNT(*) - COUNT(lng)       AS lng_nulls, -- 0
    COUNT(*) - COUNT(city)      AS city_nulls, -- 0
    COUNT(*) - COUNT(state)		AS state_nulls -- 0
FROM geolocation;


SELECT 
	COUNT(*) - COUNT(seller_id)  AS seller_id_nulls, -- 0
    COUNT(*) - COUNT(zip_code)   AS zip_code_nulls,  -- 0
    COUNT(*) - COUNT(city)       AS city_nulls, -- 0
    COUNT(*) - COUNT(state)		 AS state_nulls -- 0
FROM sellers;




SELECT 
	COUNT(*) - COUNT(order_id) 		  AS order_id_nulls, -- 0
    COUNT(*) - COUNT(order_item_id)   AS order_item_id_nulls,  -- 0
    COUNT(*) - COUNT(product_id)      AS product_id_nulls, -- 0
    COUNT(*) - COUNT(seller_id)		  AS seller_id_nulls, -- 0
	COUNT(*) - COUNT(shipping_limit)  AS shipping_limit_nulls, -- 0
	COUNT(*) - COUNT(price) 		  AS price_nulls, -- 0
	COUNT(*) - COUNT(freight_value)   AS freight_value_nulls -- 0
FROM order_items;


--Task 3: Grain check. 
-- CUSTOMERS_TABLE 
SELECT customer_unique_id , COUNT(*) AS c 
FROM customers 
GROUP BY customer_unique_id 
HAVING c > 1;
----------------------------------------
SELECT customer_id , COUNT(*) AS c -- One Row one customer / customer_id is the actual PKEY
FROM customers 
GROUP BY customer_id 
HAVING c > 1;
----------------------------------------
SELECT COUNT(DISTINCT customer_id) , customer_unique_id
FROM customers
GROUP BY customer_unique_id
--Task 4 — Relationship validation.
-- Discussion  : This table represents two ids : 1: customer_unique_id which is a real person that never changes, 
-- 			   2 the customer_id which is a diffrent id given to the person each time they place an order. 

--ORDERS_TABLE 
SELECT customer_id , COUNT(*) AS c 
FROM orders
GROUP BY customer_id 
HAVING c > 1
----------------------------------------
SELECT order_id , COUNT(*) AS c 
FROM orders
GROUP BY order_id 
HAVING c > 1
--Task 4 — Relationship validation.
-- Discussion  : This table has order_id as Pkey , the customer_id is a Fkey from customers and has no dupes too which is expected,
--			   because every order placed creates a customer id in the customers table and the order is unique because it is the actual order 

----------------------------------------
--REVIEWS_TABLE SELECT * FROM reviews LIMIT 5;
SELECT order_id , review_id, COUNT(*) AS c 
FROM reviews
GROUP BY order_id ,review_id
HAVING c > 1

SELECT COUNT(DISTINCT review_id) , order_id
FROM reviews
GROUP BY order_id
HAVING  COUNT(DISTINCT review_id) >= 3
--Task 4 — Relationship validation.
--Discussion : One order can have up to 3 reviews, This is unexpected from a business logic standpoint flagged for Phase 2 investigation.
--     		   one order means one costomer_id (not one customer_unique_id). 
-- 			   first query returns nothing that means an order_id and review_id creates unique key (review_id + order_id is the composite key )

----------------------------------------
--PRODUCTS_TABLE 
SELECT product_id , COUNT(*) AS c
FROM products
GROUP BY product_id
HAVING c > 1
--Task 4 — Relationship validation.
-- Discussion : This table has one Pkey , product_id , one product_id per row ,So products on its own tells nothing about sales , 
-- 				it only becomes useful when joined to order_items.


----------------------------------------

--PAYMENTS_TABLE SELECT * FROM payments LIMIT 5; 
SELECT order_id ,payment_sequential, COUNT(*) AS c 
FROM payments
GROUP BY order_id ,payment_sequential
HAVING c > 1

SELECT COUNT(DISTINCT order_id) , payment_installments
FROM payments
GROUP BY payment_installments
HAVING  COUNT(DISTINCT order_id) >= 1

SELECT order_id , COUNT(DISTINCT payment_type)
FROM payments
GROUP BY order_id
HAVING COUNT(DISTINCT payment_type) > 2

SELECT COUNT(order_id) , payment_sequential
FROM payments
GROUP BY payment_sequential
--Task 4 — Relationship validation.
-- Discussion : order_id is duplicated a lot during this table ,The true composite key is order_id + payment_sequential,
--				one customer_unique_id have many customer_ids which is many order_ids which many payments (dupes orders_ids)
-- 				In Brazil, paying in installments is common , but it doesn't create new rows 
-- 				the second query says it: payment_installments from 0 to 24
--				Maximum 2 different payment types per order, So what is actually creating this much dupes ?????
--				Duplicate order_id rows are caused by multiple payment methods (2,246 orders) and multiple vouchers applied to the 
--					same order AND The order with 29 sequential payments is flagged for Phase 2 investigation.


----------------------------------------
--GEOLOCATION_TABLE SELECT * FROM geolocation LIMIT 5; 
SELECT zip_code ,  COUNT(*) AS c 
FROM geolocation 
GROUP BY zip_code
HAVING c > 1 
--Task 4 — Relationship validation.
-- Discussion : Actually nothin is crazy , this is a seperated table that can be used to map on PBI and join other tables based on zip_code
-- 				also the zip_code is not repeated across the table 


----------------------------------------
--SELLERS_TABLE  SELECT * FROM sellers LIMIT 5;	

SELECT seller_id , COUNT(*) AS c 
FROM sellers 
GROUP BY seller_id 
HAVING c > 1
--Task 4 — Relationship validation. 
--Discussion : sellers is also a lookup table, similar to products and geolocation. It holds seller attributes like city, state, and zip code

----------------------------------------

--OERDER_ITEMS TABLE  SELECT * FROM order_items LIMIT 5;
SELECT order_id , COUNT(*) AS c 
FROM order_items 
GROUP BY order_id 
HAVING c > 1
-- Yes order_id is duped 

SELECT product_id , COUNT(*) AS c 
FROM order_items 
GROUP BY product_id 
HAVING c > 1
-- Yes product_id is duped 
SELECT seller_id , COUNT(*) AS c 
FROM order_items 
GROUP BY seller_id 
HAVING c > 1
-- Yes seller_id is duped
-- So what is the composit key 
SELECT  order_id,order_item_id, COUNT(*) AS c 
FROM order_items 
GROUP BY order_id,order_item_id
HAVING c > 1
--Task 4 — Relationship validation. 
-- composite key: order_id + order_item_id
-- order_id repeats because one order can have multiple items
-- order_item_id is a line number that resets with every new order (1,2,3...)
-- order_item_id alone is meaningless — only makes sense combined with order_id
-- seller_id and product_id are attributes (context) not part of the key
-- different items in the same order can belong to different sellers
-- this is the only table where money changes hands (price + freight_value)
-- all revenue, product, and seller analysis starts from this table
-- maximum 20 items found in a single order
