-- ФИО: _____________________
-- Группа: ___________________
-- Практическая работа № 4; вариант 4.
-- Воспроизводимый запуск в Docker с ограниченной общей памятью.
SET max_parallel_workers_per_gather = 0;
-- 1. Основной JOIN. Заказ : клиент = N:1; заказ : отзывы = 1:N.
-- Зерно результата: отзыв о заказе, а не заказ. Даты сравниваются по дням.
CREATE OR REPLACE TEMP VIEW main_reviews AS
SELECT o.order_id, c.customer_unique_id, c.customer_state,
       r.review_id, r.review_score,
       o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date AS delay_days,
       greatest(o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date, 0) AS late_days
FROM olist.orders o
JOIN olist.customers c ON c.customer_id = o.customer_id
JOIN olist.order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;
SELECT * FROM main_reviews ORDER BY order_id, review_id LIMIT 30;
SELECT review_score, count(*) AS reviews, round(avg(delay_days),2) AS avg_delay,
       count(*) FILTER (WHERE delay_days > 0) AS late_reviews
FROM main_reviews GROUP BY review_score ORDER BY review_score;

-- 3. LEFT JOIN сохраняет заказы без отзывов. Фильтр оценки в ON.
SELECT o.order_id, c.customer_state, r.review_id, r.review_score
FROM olist.orders o JOIN olist.customers c USING(customer_id)
LEFT JOIN olist.order_reviews r ON r.order_id=o.order_id AND r.review_score>=4
ORDER BY o.order_id, r.review_id LIMIT 30;
-- 4. Антисоединение (заказы без любого отзыва).
SELECT count(*) AS orders_without_reviews FROM olist.orders o
WHERE NOT EXISTS (SELECT 1 FROM olist.order_reviews r WHERE r.order_id=o.order_id);

-- 5. Ошибка: позиции 1:N и отзывы 1:M дают N*M строк на заказ.
CREATE OR REPLACE TEMP VIEW wrong_join AS
SELECT o.order_id, count(*) AS joined_rows, sum(i.price) AS inflated_price
FROM olist.orders o JOIN olist.order_items i USING(order_id)
JOIN olist.order_reviews r USING(order_id) GROUP BY o.order_id;
-- 6. Исправление: сначала обе дочерние таблицы сворачиваются до заказа.
CREATE OR REPLACE TEMP VIEW corrected_join AS
WITH items AS (SELECT order_id,count(*) AS item_count,sum(price) AS true_price
               FROM olist.order_items GROUP BY order_id),
reviews AS (SELECT order_id,count(*) AS review_count,avg(review_score) AS avg_score
            FROM olist.order_reviews GROUP BY order_id)
SELECT o.order_id,i.item_count,i.true_price,r.review_count,r.avg_score
FROM olist.orders o JOIN items i USING(order_id) JOIN reviews r USING(order_id);
SELECT w.*, c.item_count,c.review_count,c.true_price
FROM wrong_join w JOIN corrected_join c USING(order_id)
WHERE w.inflated_price<>c.true_price ORDER BY order_id LIMIT 10;
SELECT sum(w.inflated_price) AS wrong_total,sum(c.true_price) AS correct_total
FROM wrong_join w JOIN corrected_join c USING(order_id);
-- 7. π(order_id,unique_id,state,review_id,score,delay)
--    σ(delivered AND даты известны)(orders ⋈ customers ⋈ reviews).
-- Эквисоединение R ⋈(R.k=S.k) S = σ(R.k=S.k)(R × S).
