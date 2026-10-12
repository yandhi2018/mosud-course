-- ФИО: _____________________
-- Группа: ___________________
-- Практическая работа № 14; вариант 4.
-- Воспроизводимый запуск в Docker с ограниченной общей памятью.
SET max_parallel_workers_per_gather = 0;
-- Исходная неудачная форма.
CREATE OR REPLACE TEMP VIEW original_query AS
SELECT o.order_id FROM olist.orders o WHERE o.order_id NOT IN(SELECT r.order_id FROM olist.order_reviews r);
CREATE OR REPLACE TEMP VIEW optimized_query AS
SELECT o.order_id FROM olist.orders o WHERE NOT EXISTS
 (SELECT 1 FROM olist.order_reviews r WHERE r.order_id=o.order_id);
EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON) SELECT * FROM original_query;
EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON) SELECT * FROM optimized_query;
-- В исходной схеме обе стороны NOT NULL, поэтому на Olist результаты равны.
SELECT 'original-optimized' AS check_name,count(*) AS differences FROM
 (TABLE original_query EXCEPT TABLE optimized_query) d
UNION ALL SELECT 'optimized-original',count(*) FROM
 (TABLE optimized_query EXCEPT TABLE original_query) d;
SELECT count(*) AS orders_without_reviews FROM optimized_query;
-- Отдельно моделируем NULL в правой стороне без изменения Olist.
WITH ids AS(SELECT order_id FROM olist.order_reviews UNION ALL SELECT NULL::text)
SELECT 'not_in_with_null' AS form,count(*) AS orders FROM olist.orders o
WHERE o.order_id NOT IN(SELECT order_id FROM ids)
UNION ALL
SELECT 'not_exists_with_null',count(*) FROM olist.orders o
WHERE NOT EXISTS(SELECT 1 FROM ids WHERE ids.order_id=o.order_id);
-- Алгебра антисоединения: orders - π_orders(orders ⋈ reviews).
-- NOT EXISTS позволяет строить Hash Anti Join и явно выражает отсутствие соответствия.
-- Ускорение не гарантировано: сравниваем фактические планы, а не обещаем выигрыш.
