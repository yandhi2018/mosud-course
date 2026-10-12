-- ФИО: _____________________
-- Группа: ___________________
-- Практическая работа № 12; вариант 4.
-- Воспроизводимый запуск в Docker с ограниченной общей памятью.
SET max_parallel_workers_per_gather = 0;
CREATE SCHEMA IF NOT EXISTS lab;
CREATE TABLE IF NOT EXISTS lab.inventory(
 product_id text CONSTRAINT pk_inventory PRIMARY KEY REFERENCES olist.products(product_id),
 qty integer NOT NULL CONSTRAINT ck_inventory_qty CHECK(qty>=0),
 version integer NOT NULL DEFAULT 0);
INSERT INTO lab.inventory(product_id,qty)
SELECT product_id,10 FROM olist.order_items GROUP BY product_id
ORDER BY count(*) DESC,product_id LIMIT 100 ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS lab.inventory_movements(
 movement_id bigint GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_movements PRIMARY KEY,
 product_id text NOT NULL CONSTRAINT fk_movement_product REFERENCES lab.inventory(product_id),
 delta integer NOT NULL CONSTRAINT ck_movement_delta CHECK(delta<>0),
 experiment text NOT NULL,created_at timestamp NOT NULL DEFAULT clock_timestamp());
-- Значения для двух окон берутся одинаково и детерминированно.
SELECT product_id,qty,version FROM lab.inventory ORDER BY product_id LIMIT 2;
-- Сохраняем и восстанавливаем резервирование через ROLLBACK.
BEGIN;
WITH reserved AS(
 UPDATE lab.inventory SET qty=qty-1,version=version+1
 WHERE product_id=(SELECT min(product_id) FROM lab.inventory) AND qty>0 RETURNING product_id,qty)
SELECT * FROM reserved;
ROLLBACK;
-- Перед экспериментами session_a/session_b сохранить qty и version:
-- CREATE TABLE lab.inventory_backup12 AS TABLE lab.inventory;
-- После: UPDATE lab.inventory i SET qty=b.qty,version=b.version
--        FROM lab.inventory_backup12 b WHERE b.product_id=i.product_id;
-- Удалять следует только собственную резервную копию и помеченные экспериментальные движения.
