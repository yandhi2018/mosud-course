-- ФИО: _____________________
-- Группа: ___________________
-- Практическая работа № 6; вариант 4.
-- Воспроизводимый запуск в Docker с ограниченной общей памятью.
SET max_parallel_workers_per_gather = 0;
-- Единица анализа: (customer_unique_id, customer_state).
-- customer_id в Olist создается для отдельного заказа; по нему счетчик почти всегда 1.
CREATE TEMP TABLE customer_counts AS
SELECT c.customer_unique_id,c.customer_state,count(o.order_id) AS order_count
FROM olist.customers c LEFT JOIN olist.orders o USING(customer_id)
GROUP BY c.customer_unique_id,c.customer_state;
CREATE INDEX ON customer_counts(customer_state);
ANALYZE customer_counts;
CREATE TEMP TABLE state_means AS
SELECT customer_state,avg(order_count) AS mean_count FROM customer_counts GROUP BY customer_state;
-- 1–2. Коррелированный скалярный подзапрос + EXISTS.
CREATE OR REPLACE TEMP VIEW via_subquery AS
SELECT c.* FROM customer_counts c WHERE c.order_count >
 (SELECT s.mean_count FROM state_means s
  WHERE s.customer_state IS NOT DISTINCT FROM c.customer_state)
 AND EXISTS (SELECT 1 FROM customer_counts s
  WHERE s.customer_state IS NOT DISTINCT FROM c.customer_state AND s.order_count<c.order_count);
-- EXISTS логически избыточен при превышении среднего, но явно показывает существование.
-- 3. Предварительная агрегация по штату + JOIN.
CREATE OR REPLACE TEMP VIEW via_cte AS
WITH means AS (SELECT customer_state,avg(order_count) AS mean_count
               FROM customer_counts GROUP BY customer_state)
SELECT c.* FROM customer_counts c JOIN means m
 ON m.customer_state IS NOT DISTINCT FROM c.customer_state WHERE c.order_count>m.mean_count;
SELECT * FROM via_cte ORDER BY order_count DESC,customer_unique_id LIMIT 30;
SELECT customer_state,count(*) AS above_average FROM via_cte GROUP BY customer_state ORDER BY customer_state;
-- 4. Материализация результатов, чтобы повторно не выполнять подзапросы.
CREATE TEMP TABLE result_subquery AS SELECT * FROM via_subquery;
CREATE TEMP TABLE result_cte AS SELECT * FROM via_cte;
SELECT 'subquery-cte' AS check_name,count(*) AS differences FROM
 (TABLE result_subquery EXCEPT TABLE result_cte) d
UNION ALL SELECT 'cte-subquery',count(*) FROM
 (TABLE result_cte EXCEPT TABLE result_subquery) d;
-- 5. ANY: больше хотя бы одного; ALL: не меньше всех (максимум в штате).
-- Для ANY/ALL кратность одинаковых значений не влияет на результат.
CREATE TEMP TABLE state_order_counts AS
SELECT DISTINCT customer_state,order_count FROM customer_counts;
SELECT c.* FROM customer_counts c WHERE c.order_count > ANY
 (SELECT s.order_count FROM state_order_counts s WHERE s.customer_state=c.customer_state)
ORDER BY c.order_count DESC,c.customer_unique_id LIMIT 10;
SELECT c.* FROM customer_counts c WHERE c.order_count >= ALL
 (SELECT s.order_count FROM state_order_counts s WHERE s.customer_state=c.customer_state)
ORDER BY c.customer_state,c.customer_unique_id LIMIT 30;
