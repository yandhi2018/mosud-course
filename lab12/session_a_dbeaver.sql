-- Версия для DBeaver. Выполняйте блоками; не запускайте весь файл целиком.
-- Сеанс A. Выполнять БЛОКАМИ по указанному порядку, не целиком.
-- ФИО: ____________________; группа: ____________________; вариант 4.
-- DBeaver: выполнить подготовку в двух отдельных соединениях; затем блоки по порядку.
CREATE TEMP TABLE lab12_params(p1 text, p2 text, read_qty integer);
INSERT INTO lab12_params(p1,p2)
SELECT ids[1],ids[2] FROM (SELECT array_agg(product_id ORDER BY product_id) AS ids FROM lab.inventory) q;
SELECT pg_backend_pid() AS pid_a;
-- Сохранение исходных значений перед первым экспериментом, только в A.
CREATE TABLE IF NOT EXISTS lab.inventory_backup12 AS TABLE lab.inventory;

-- 1. Потерянное обновление. A1; B1; A2; B2.
-- A1:
BEGIN;
UPDATE lab12_params SET read_qty=(SELECT qty FROM lab.inventory WHERE product_id=lab12_params.p1);
-- Ожидать B1: оба прочли 10 (если исходный qty другой, сравнить с qty-2).
-- A2:
UPDATE lab.inventory SET qty=(SELECT read_qty FROM lab12_params)-1 WHERE product_id=(SELECT p1 FROM lab12_params);
COMMIT;
-- После B2 итог 9 вместо 8. Перед каждым следующим экспериментом восстановить:
UPDATE lab.inventory i SET qty=b.qty,version=b.version
FROM lab.inventory_backup12 b WHERE b.product_id=i.product_id;

-- 2. Блокировка строки. A1; B1 (ждет); A2; B2.
-- A1:
BEGIN;
SELECT qty FROM lab.inventory WHERE product_id=(SELECT p1 FROM lab12_params) FOR UPDATE;
-- B выполняет SELECT FOR UPDATE; A может проверить ожидание:
SELECT application_name,wait_event_type,wait_event FROM pg_stat_activity WHERE wait_event_type='Lock';
-- A2:
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=(SELECT p1 FROM lab12_params);
COMMIT;
-- После B2 получится исходный qty-2. Восстановить как выше.

-- 3. Атомарный UPDATE: выполнить одновременно с B, без SELECT в приложении.
UPDATE lab.inventory SET qty=qty-1,version=version+1
WHERE product_id=(SELECT p1 FROM lab12_params) AND qty>0 RETURNING qty;
-- Для проверки последней единицы перед запуском обоих UPDATE выставить qty=1 в A.

-- 4. READ COMMITTED: A1; B4; A2.
-- A1:
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT qty FROM lab.inventory WHERE product_id=(SELECT p1 FROM lab12_params);
-- Ожидать UPDATE + COMMIT B4.
-- A2: новое значение видимо.
SELECT qty FROM lab.inventory WHERE product_id=(SELECT p1 FROM lab12_params);
COMMIT;

-- 5. REPEATABLE READ: A1; B5; A2.
-- A1:
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT qty FROM lab.inventory WHERE product_id=(SELECT p1 FROM lab12_params);
-- Ожидать UPDATE + COMMIT B5.
-- A2: значение из первого снимка сохраняется.
SELECT qty FROM lab.inventory WHERE product_id=(SELECT p1 FROM lab12_params);
COMMIT;

-- 6. Фантом: A1; B6; A2.
-- A1:
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT count(*) FROM lab.inventory_movements WHERE experiment='lab12_manual';
-- B6 вставляет одну строку и фиксирует.
-- A2:
SELECT count(*) FROM lab.inventory_movements WHERE experiment='lab12_manual';
COMMIT;

-- 7. Deadlock: A1; B1; A2 (ждет); B2 (цикл).
-- A1:
BEGIN;
UPDATE lab.inventory SET version=version+1 WHERE product_id=(SELECT p1 FROM lab12_params);
-- После B1:
-- A2:
UPDATE lab.inventory SET version=version+1 WHERE product_id=(SELECT p2 FROM lab12_params);
-- Один сеанс получает SQLSTATE 40P01. Жертва: ROLLBACK; выживший: COMMIT.
ROLLBACK;

-- 8. SERIALIZABLE: A1; B1; A2; B2 (40001 и повтор).
-- A1:
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT qty FROM lab.inventory WHERE product_id=(SELECT p1 FROM lab12_params);
-- После B1:
-- A2:
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=(SELECT p1 FROM lab12_params) AND qty>0;
COMMIT;

-- Финал, после завершения транзакций обоих сеансов:
UPDATE lab.inventory i SET qty=b.qty,version=b.version
FROM lab.inventory_backup12 b WHERE b.product_id=i.product_id;
DELETE FROM lab.inventory_movements WHERE experiment='lab12_manual';
