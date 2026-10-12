-- ФИО: _____________________
-- Группа: ___________________
-- Практическая работа № 7; вариант 4.
-- Воспроизводимый запуск в Docker с ограниченной общей памятью.
SET max_parallel_workers_per_gather = 0;
-- 1. Профиль всех неключевых потенциально необязательных столбцов.
-- JSON null соответствует SQL NULL; пустая строка пропуском здесь не считается.
SELECT table_name,column_name,count(*) FILTER (WHERE value='null'::jsonb) AS null_count
FROM (
 SELECT 'orders' AS table_name,j.key AS column_name,j.value FROM olist.orders t
 CROSS JOIN LATERAL jsonb_each(to_jsonb(t)) j WHERE j.key NOT IN ('order_id','customer_id')
 UNION ALL SELECT 'products',j.key,j.value FROM olist.products t
 CROSS JOIN LATERAL jsonb_each(to_jsonb(t)) j WHERE j.key<>'product_id'
 UNION ALL SELECT 'order_reviews',j.key,j.value FROM olist.order_reviews t
 CROSS JOIN LATERAL jsonb_each(to_jsonb(t)) j WHERE j.key NOT IN ('review_id','order_id')
) q GROUP BY table_name,column_name ORDER BY table_name,column_name;
-- 2. COUNT(column) исключает NULL.
SELECT count(*) AS all_orders,count(order_delivered_customer_date) AS known_delivery,
 count(*)-count(order_delivered_customer_date) AS missing_delivery FROM olist.orders;
-- 3. Оба обычных сравнения дают UNKNOWN.
SELECT count(*) AS wrong_eq FROM olist.orders WHERE order_delivered_customer_date=NULL;
SELECT count(*) AS wrong_ne FROM olist.orders WHERE order_delivered_customer_date<>NULL;
SELECT count(*) AS correct_null FROM olist.orders WHERE order_delivered_customer_date IS NULL;
SELECT count(*) AS correct_nonnull FROM olist.orders WHERE order_delivered_customer_date IS NOT NULL;
-- 4. Null-safe сравнение.
SELECT a,b,a=b AS ordinary_eq,a IS DISTINCT FROM b AS distinct_values
FROM (VALUES (1,1),(1,NULL),(NULL,NULL)) v(a,b);
-- 5. NULL отравляет NOT IN, но не коррелированный NOT EXISTS.
CREATE TEMP TABLE temp_ids(id text);
INSERT INTO temp_ids SELECT min(order_id) FROM olist.orders;
INSERT INTO temp_ids VALUES (NULL);
SELECT count(*) AS via_not_in FROM olist.orders WHERE order_id NOT IN (SELECT id FROM temp_ids);
SELECT count(*) AS via_not_exists FROM olist.orders o
WHERE NOT EXISTS (SELECT 1 FROM temp_ids t WHERE t.id=o.order_id);
-- 6. Сравниваем именно число уникальных заказов, а не строк соединения.
SELECT 'filter_on' AS filter_place,count(*) AS joined_rows,count(DISTINCT o.order_id) AS orders
FROM olist.orders o LEFT JOIN olist.order_reviews r ON r.order_id=o.order_id AND r.review_score>=4
UNION ALL
SELECT 'filter_where',count(*),count(DISTINCT o.order_id)
FROM olist.orders o LEFT JOIN olist.order_reviews r ON r.order_id=o.order_id WHERE r.review_score>=4;
-- 7. Текст по умолчанию и безопасное деление даже для пустой выборки.
SELECT review_id,coalesce(nullif(review_comment_message,''),'Комментарий отсутствует') AS comment
FROM olist.order_reviews ORDER BY review_id LIMIT 10;
SELECT count(*)::numeric/nullif(count(*) FILTER (WHERE false),0) AS safe_ratio FROM olist.orders;
-- 8. Доли пропусков, проценты.
SELECT 'orders_without_delivery' AS metric,count(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing,
 round(100.0*count(*) FILTER (WHERE order_delivered_customer_date IS NULL)/nullif(count(*),0),2) AS pct FROM olist.orders
UNION ALL SELECT 'products_without_category',count(*) FILTER (WHERE product_category_name IS NULL),
 round(100.0*count(*) FILTER (WHERE product_category_name IS NULL)/nullif(count(*),0),2) FROM olist.products
UNION ALL SELECT 'reviews_without_text',count(*) FILTER (WHERE nullif(review_comment_message,'') IS NULL),
 round(100.0*count(*) FILTER (WHERE nullif(review_comment_message,'') IS NULL)/nullif(count(*),0),2) FROM olist.order_reviews;
-- 9. Нет даты у отмененного заказа — естественно; у delivered — подозрительно.
SELECT order_status,count(*) AS orders,count(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing
FROM olist.orders GROUP BY order_status ORDER BY order_status;
