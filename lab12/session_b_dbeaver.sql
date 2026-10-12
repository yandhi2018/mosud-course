-- Версия для DBeaver. Выполняйте блоками; не запускайте весь файл целиком.
-- Сеанс B. Выполнять БЛОКАМИ совместно с session_a.sql.
CREATE TEMP TABLE lab12_params(p1 text, p2 text, read_qty integer);
INSERT INTO lab12_params(p1,p2)
SELECT ids[1],ids[2] FROM (SELECT array_agg(product_id ORDER BY product_id) AS ids FROM lab.inventory) q;
SELECT pg_backend_pid() AS pid_b;

-- 1. B1, после A1:
BEGIN;
UPDATE lab12_params SET read_qty=(SELECT qty FROM lab.inventory WHERE product_id=lab12_params.p1);
-- B2, только после COMMIT A2: константа получена из устаревшего чтения.
UPDATE lab.inventory SET qty=(SELECT read_qty FROM lab12_params)-1 WHERE product_id=(SELECT p1 FROM lab12_params);
COMMIT;
SELECT qty FROM lab.inventory WHERE product_id=(SELECT p1 FROM lab12_params);

-- 2. B1, после A1: эта команда ждет COMMIT A2.
BEGIN;
SELECT qty FROM lab.inventory WHERE product_id=(SELECT p1 FROM lab12_params) FOR UPDATE;
-- B2, после возврата SELECT: он видит уже уменьшенный остаток.
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=(SELECT p1 FROM lab12_params);
COMMIT;

-- 3. Одновременно с A: атомарное резервирование.
UPDATE lab.inventory SET qty=qty-1,version=version+1
WHERE product_id=(SELECT p1 FROM lab12_params) AND qty>0 RETURNING qty;

-- 4. B4, между чтениями A в READ COMMITTED:
BEGIN;
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=(SELECT p1 FROM lab12_params) AND qty>0;
COMMIT;

-- 5. B5, между чтениями A в REPEATABLE READ:
BEGIN;
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=(SELECT p1 FROM lab12_params) AND qty>0;
COMMIT;

-- 6. B6, между двумя COUNT A:
BEGIN;
INSERT INTO lab.inventory_movements(product_id,delta,experiment)
VALUES((SELECT p1 FROM lab12_params),1,'lab12_manual');
COMMIT;

-- 7. B1 после A1:
BEGIN;
UPDATE lab.inventory SET version=version+1 WHERE product_id=(SELECT p2 FROM lab12_params);
-- B2 после начала ожидания A2:
UPDATE lab.inventory SET version=version+1 WHERE product_id=(SELECT p1 FROM lab12_params);
-- Если B — жертва: ROLLBACK; если выжил: COMMIT.
ROLLBACK;

-- 8. B1 после чтения A1, до UPDATE A2:
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT qty FROM lab.inventory WHERE product_id=(SELECT p1 FROM lab12_params);
-- B2 только после COMMIT A2:
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=(SELECT p1 FROM lab12_params) AND qty>0;
-- Ожидается 40001: could not serialize access due to concurrent update.
ROLLBACK;
-- Повтор всей транзакции с новым снимком:
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT qty FROM lab.inventory WHERE product_id=(SELECT p1 FROM lab12_params);
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=(SELECT p1 FROM lab12_params) AND qty>0 RETURNING qty;
COMMIT;
