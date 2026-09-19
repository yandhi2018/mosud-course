-- ФИО: _____________________
-- Группа: ___________________
-- lab01/check.sql
-- Единый скрипт проверки после загрузки Olist: число строк, NULL в ключевых
-- полях, "осиротевшие" (orphan) ссылки, ANALYZE. Выполняется сверху вниз.

-- 1. Число строк в каждой из 9 таблиц (ориентир для сверки с заданием)
SELECT 'customers' AS table_name, count(*) AS row_count FROM olist.customers
UNION ALL SELECT 'geolocation', count(*) FROM olist.geolocation
UNION ALL SELECT 'orders', count(*) FROM olist.orders
UNION ALL SELECT 'order_items', count(*) FROM olist.order_items
UNION ALL SELECT 'order_payments', count(*) FROM olist.order_payments
UNION ALL SELECT 'order_reviews', count(*) FROM olist.order_reviews
UNION ALL SELECT 'products', count(*) FROM olist.products
UNION ALL SELECT 'sellers', count(*) FROM olist.sellers
UNION ALL SELECT 'product_category_name_translation', count(*) FROM olist.product_category_name_translation
ORDER BY table_name;

-- 2. NULL в ключевых полях (в норме должно быть 0 строк в каждом запросе)
SELECT 'customers.customer_id' AS field, count(*) AS null_count
FROM olist.customers WHERE customer_id IS NULL
UNION ALL
SELECT 'orders.order_id', count(*) FROM olist.orders WHERE order_id IS NULL
UNION ALL
SELECT 'orders.customer_id', count(*) FROM olist.orders WHERE customer_id IS NULL
UNION ALL
SELECT 'order_items.order_id', count(*) FROM olist.order_items WHERE order_id IS NULL
UNION ALL
SELECT 'order_items.product_id', count(*) FROM olist.order_items WHERE product_id IS NULL
UNION ALL
SELECT 'order_items.seller_id', count(*) FROM olist.order_items WHERE seller_id IS NULL
UNION ALL
SELECT 'products.product_id', count(*) FROM olist.products WHERE product_id IS NULL
UNION ALL
SELECT 'sellers.seller_id', count(*) FROM olist.sellers WHERE seller_id IS NULL;

-- 3. Осиротевшие ссылки: строки, которые не находят родителя по FK
-- (после ALTER TABLE ... ADD CONSTRAINT все они должны быть равны 0,
--  но полезно проверить и до наложения ключей)
SELECT 'orphan_order_items_without_order' AS check_name, count(*) AS orphan_count
FROM olist.order_items oi
LEFT JOIN olist.orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL

UNION ALL
SELECT 'orphan_order_items_without_product', count(*)
FROM olist.order_items oi
LEFT JOIN olist.products p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL

UNION ALL
SELECT 'orphan_order_items_without_seller', count(*)
FROM olist.order_items oi
LEFT JOIN olist.sellers s ON s.seller_id = oi.seller_id
WHERE s.seller_id IS NULL

UNION ALL
SELECT 'orphan_orders_without_customer', count(*)
FROM olist.orders o
LEFT JOIN olist.customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL

UNION ALL
SELECT 'orphan_payments_without_order', count(*)
FROM olist.order_payments op
LEFT JOIN olist.orders o ON o.order_id = op.order_id
WHERE o.order_id IS NULL

UNION ALL
SELECT 'orphan_reviews_without_order', count(*)
FROM olist.order_reviews r
LEFT JOIN olist.orders o ON o.order_id = r.order_id
WHERE o.order_id IS NULL;

-- 4. Сбор статистики планировщика по всей схеме olist
ANALYZE olist.customers;
ANALYZE olist.geolocation;
ANALYZE olist.orders;
ANALYZE olist.order_items;
ANALYZE olist.order_payments;
ANALYZE olist.order_reviews;
ANALYZE olist.products;
ANALYZE olist.sellers;
ANALYZE olist.product_category_name_translation;
