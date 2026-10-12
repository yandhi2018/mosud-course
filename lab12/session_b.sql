-- Сеанс B. Выполнять БЛОКАМИ совместно с session_a.sql.
SELECT min(product_id) AS p1 FROM lab.inventory \gset
SELECT product_id AS p2 FROM lab.inventory WHERE product_id<>:'p1' ORDER BY product_id LIMIT 1 \gset
SELECT pg_backend_pid() AS pid_b;

-- 1. B1, после A1:
BEGIN;
SELECT qty AS read_qty FROM lab.inventory WHERE product_id=:'p1' \gset
-- B2, только после COMMIT A2: константа получена из устаревшего чтения.
UPDATE lab.inventory SET qty=:read_qty-1 WHERE product_id=:'p1';
COMMIT;
SELECT qty FROM lab.inventory WHERE product_id=:'p1';

-- 2. B1, после A1: эта команда ждет COMMIT A2.
BEGIN;
SELECT qty FROM lab.inventory WHERE product_id=:'p1' FOR UPDATE;
-- B2, после возврата SELECT: он видит уже уменьшенный остаток.
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=:'p1';
COMMIT;

-- 3. Одновременно с A: атомарное резервирование.
UPDATE lab.inventory SET qty=qty-1,version=version+1
WHERE product_id=:'p1' AND qty>0 RETURNING qty;

-- 4. B4, между чтениями A в READ COMMITTED:
BEGIN;
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=:'p1' AND qty>0;
COMMIT;

-- 5. B5, между чтениями A в REPEATABLE READ:
BEGIN;
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=:'p1' AND qty>0;
COMMIT;

-- 6. B6, между двумя COUNT A:
BEGIN;
INSERT INTO lab.inventory_movements(product_id,delta,experiment)
VALUES(:'p1',1,'lab12_manual');
COMMIT;

-- 7. B1 после A1:
BEGIN;
UPDATE lab.inventory SET version=version+1 WHERE product_id=:'p2';
-- B2 после начала ожидания A2:
UPDATE lab.inventory SET version=version+1 WHERE product_id=:'p1';
-- Если B — жертва: ROLLBACK; если выжил: COMMIT.
ROLLBACK;

-- 8. B1 после чтения A1, до UPDATE A2:
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT qty FROM lab.inventory WHERE product_id=:'p1';
-- B2 только после COMMIT A2:
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=:'p1' AND qty>0;
-- Ожидается 40001: could not serialize access due to concurrent update.
ROLLBACK;
-- Повтор всей транзакции с новым снимком:
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT qty FROM lab.inventory WHERE product_id=:'p1';
UPDATE lab.inventory SET qty=qty-1 WHERE product_id=:'p1' AND qty>0 RETURNING qty;
COMMIT;
