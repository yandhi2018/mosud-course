-- ФИО: _____________________
-- Группа: ___________________
-- Практическая работа № 5; вариант 4.
-- Воспроизводимый запуск в Docker с ограниченной общей памятью.
SET max_parallel_workers_per_gather = 0;
-- Исходное множество категорий: все известные категории products.
CREATE OR REPLACE TEMP VIEW category_universe AS
SELECT DISTINCT product_category_name AS category FROM olist.products
WHERE product_category_name IS NOT NULL;
CREATE OR REPLACE TEMP VIEW sales_states AS
SELECT DISTINCT p.product_category_name AS category,c.customer_state AS state
FROM olist.products p JOIN olist.order_items i USING(product_id)
JOIN olist.orders o USING(order_id) JOIN olist.customers c USING(customer_id)
WHERE o.order_status='delivered' AND p.product_category_name IS NOT NULL;
-- 1. Делитель варианта 4.
CREATE OR REPLACE TEMP VIEW divisor AS
WITH target_states(state) AS (VALUES ('GO'::text),('DF'),('MT'))
SELECT * FROM target_states;
-- 2. Для каждого штата существует продажа категории.
CREATE OR REPLACE TEMP VIEW division_exists AS
SELECT u.category FROM category_universe u
WHERE NOT EXISTS (SELECT 1 FROM divisor t WHERE NOT EXISTS
 (SELECT 1 FROM sales_states s WHERE s.category=u.category AND s.state=t.state));
-- 3. LEFT JOIN от универсального множества сохраняет корректность при пустом S.
CREATE OR REPLACE TEMP VIEW division_count AS
SELECT u.category FROM category_universe u
LEFT JOIN sales_states s ON s.category=u.category AND s.state IN (SELECT state FROM divisor)
GROUP BY u.category HAVING count(DISTINCT s.state)=(SELECT count(*) FROM divisor);
-- 4. Делитель минус покрытые штаты должен быть пуст.
CREATE OR REPLACE TEMP VIEW division_except AS
SELECT u.category FROM category_universe u WHERE NOT EXISTS
 (SELECT state FROM divisor EXCEPT SELECT state FROM sales_states s WHERE s.category=u.category);
SELECT * FROM division_exists ORDER BY category;
-- 5. Все четыре разности должны быть пусты.
SELECT 'exists-count' AS check_name,count(*) AS differences FROM
 (SELECT * FROM division_exists EXCEPT SELECT * FROM division_count) d
UNION ALL SELECT 'count-exists',count(*) FROM
 (SELECT * FROM division_count EXCEPT SELECT * FROM division_exists) d
UNION ALL SELECT 'exists-except',count(*) FROM
 (SELECT * FROM division_exists EXCEPT SELECT * FROM division_except) d
UNION ALL SELECT 'except-exists',count(*) FROM
 (SELECT * FROM division_except EXCEPT SELECT * FROM division_exists) d;
-- 6. Число заказов одной категории по каждому из обязательных штатов.
WITH chosen AS (SELECT category FROM division_exists ORDER BY category LIMIT 1)
SELECT x.category,t.state,count(DISTINCT o.order_id) AS orders
FROM chosen x CROSS JOIN divisor t
LEFT JOIN olist.customers c ON c.customer_state=t.state
LEFT JOIN olist.orders o ON o.customer_id=c.customer_id AND o.order_status='delivered'
 AND EXISTS (SELECT 1 FROM olist.order_items i JOIN olist.products p USING(product_id)
             WHERE i.order_id=o.order_id AND p.product_category_name=x.category)
GROUP BY x.category,t.state ORDER BY t.state;
-- 7. Пустой делитель: все категории универсального множества.
CREATE OR REPLACE TEMP VIEW divisor AS SELECT NULL::text AS state WHERE false;
SELECT (SELECT count(*) FROM category_universe) AS universe,
       (SELECT count(*) FROM division_exists) AS via_exists,
       (SELECT count(*) FROM division_count) AS via_count,
       (SELECT count(*) FROM division_except) AS via_except;
-- 8. Продавцы во всех трех штатах.
WITH target_states(state) AS (VALUES ('GO'::text),('DF'),('MT')),
coverage AS (SELECT DISTINCT i.seller_id,c.customer_state AS state FROM olist.order_items i
 JOIN olist.orders o USING(order_id) JOIN olist.customers c USING(customer_id)
 WHERE o.order_status='delivered')
SELECT s.seller_id FROM olist.sellers s WHERE NOT EXISTS
 (SELECT 1 FROM target_states t WHERE NOT EXISTS
  (SELECT 1 FROM coverage c WHERE c.seller_id=s.seller_id AND c.state=t.state))
ORDER BY s.seller_id;
