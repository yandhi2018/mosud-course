-- ФИО: _____________________
-- Группа: ___________________
-- Практическая работа № 13; вариант 4.
-- Воспроизводимый запуск в Docker с ограниченной общей памятью.
SET max_parallel_workers_per_gather = 0;
-- Тестируем только собственные индексы; PK и чужие индексы не затрагиваем.
DROP INDEX IF EXISTS olist.idx_lab13_score_date;
DROP INDEX IF EXISTS olist.idx_lab13_low_date;
SELECT indexname,indexdef FROM pg_indexes WHERE schemaname='olist' AND tablename='order_reviews';
SELECT count(*) AS selected_rows FROM olist.order_reviews
WHERE review_score=1 AND review_creation_date>=timestamp '2018-01-01'
 AND review_creation_date<timestamp '2018-02-01';
-- До индекса.
EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON) SELECT * FROM olist.order_reviews
WHERE review_score=1 AND review_creation_date>=timestamp '2018-01-01'
 AND review_creation_date<timestamp '2018-02-01';
-- Равенство первым, диапазон вторым.
CREATE INDEX idx_lab13_score_date ON olist.order_reviews(review_score,review_creation_date);
ANALYZE olist.order_reviews;
EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON) SELECT * FROM olist.order_reviews
WHERE review_score=1 AND review_creation_date>=timestamp '2018-01-01'
 AND review_creation_date<timestamp '2018-02-01';
-- Низкая селективность: почти все оценки.
EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON) SELECT * FROM olist.order_reviews WHERE review_score>=1;
SELECT pg_size_pretty(pg_relation_size('olist.idx_lab13_score_date')) AS composite_size;
-- Другой тип индекса: частичный, только отрицательные отзывы.
CREATE INDEX idx_lab13_low_date ON olist.order_reviews(review_creation_date) WHERE review_score<=2;
ANALYZE olist.order_reviews;
EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON) SELECT * FROM olist.order_reviews
WHERE review_score<=2 AND review_creation_date>=timestamp '2018-01-01'
 AND review_creation_date<timestamp '2018-02-01';
SELECT pg_size_pretty(pg_relation_size('olist.idx_lab13_low_date')) AS partial_size;
-- Воспроизведение: CREATE INDEX idx_lab13_score_date ON olist.order_reviews(review_score,review_creation_date);
-- CREATE INDEX idx_lab13_low_date ON olist.order_reviews(review_creation_date) WHERE review_score<=2;
DROP INDEX IF EXISTS olist.idx_lab13_score_date;
DROP INDEX IF EXISTS olist.idx_lab13_low_date;
