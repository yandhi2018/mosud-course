-- ФИО: _____________________
-- Группа: ___________________
-- Практическая работа № 2. Множества и мультимножества в SQL
-- Вариант 4: штат X = BA, штат Y = PE

-- Множество A: product_id товаров, купленных клиентами штата BA
-- (только заказы со статусом delivered)
-- Множество B: product_id товаров, купленных клиентами штата PE

-- =========================================================
-- 1. Запросы A и B: мощность мультимножества и мощность множества
-- =========================================================

-- A: все строки (мультимножество) и различающиеся product_id (множество)
SELECT
    count(*)                AS a_count_all,
    count(DISTINCT oi.product_id) AS a_count_distinct
FROM olist.order_items oi
JOIN olist.orders o      ON o.order_id = oi.order_id
JOIN olist.customers c   ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND c.customer_state = 'BA';

-- B: то же самое для штата PE
SELECT
    count(*)                AS b_count_all,
    count(DISTINCT oi.product_id) AS b_count_distinct
FROM olist.order_items oi
JOIN olist.orders o      ON o.order_id = oi.order_id
JOIN olist.customers c   ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND c.customer_state = 'PE';

-- Сами множества A и B как отдельные запросы (используются ниже)
-- A:
-- SELECT DISTINCT oi.product_id
-- FROM olist.order_items oi
-- JOIN olist.orders o ON o.order_id = oi.order_id
-- JOIN olist.customers c ON c.customer_id = o.customer_id
-- WHERE o.order_status = 'delivered' AND c.customer_state = 'BA';

-- =========================================================
-- 2. A ∪ B через UNION (множество) и UNION ALL (мультимножество)
-- =========================================================

-- UNION убирает повторы product_id, которые входят и в A, и в B
SELECT product_id FROM (
    SELECT DISTINCT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'BA'
) a
UNION
SELECT product_id FROM (
    SELECT DISTINCT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'PE'
) b;

-- UNION ALL сохраняет дубликаты: product_id, общие для A и B, встретятся дважды
SELECT product_id FROM (
    SELECT DISTINCT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'BA'
) a
UNION ALL
SELECT product_id FROM (
    SELECT DISTINCT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'PE'
) b;

-- Разница count(UNION ALL) - count(UNION) = |A ∩ B|, т.к. общие product_id
-- в UNION ALL учтены дважды, а в UNION - один раз.

-- =========================================================
-- 3. A ∩ B через INTERSECT
-- =========================================================

SELECT DISTINCT oi.product_id
FROM olist.order_items oi
JOIN olist.orders o ON o.order_id = oi.order_id
JOIN olist.customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered' AND c.customer_state = 'BA'
INTERSECT
SELECT DISTINCT oi.product_id
FROM olist.order_items oi
JOIN olist.orders o ON o.order_id = oi.order_id
JOIN olist.customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered' AND c.customer_state = 'PE';

-- =========================================================
-- 4. A − B и B − A через EXCEPT
-- =========================================================

-- A minus B: товары, которые покупали в BA, но не покупали в PE
SELECT DISTINCT oi.product_id
FROM olist.order_items oi
JOIN olist.orders o ON o.order_id = oi.order_id
JOIN olist.customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered' AND c.customer_state = 'BA'
EXCEPT
SELECT DISTINCT oi.product_id
FROM olist.order_items oi
JOIN olist.orders o ON o.order_id = oi.order_id
JOIN olist.customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered' AND c.customer_state = 'PE';

-- B minus A: товары, которые покупали в PE, но не покупали в BA
SELECT DISTINCT oi.product_id
FROM olist.order_items oi
JOIN olist.orders o ON o.order_id = oi.order_id
JOIN olist.customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered' AND c.customer_state = 'PE'
EXCEPT
SELECT DISTINCT oi.product_id
FROM olist.order_items oi
JOIN olist.orders o ON o.order_id = oi.order_id
JOIN olist.customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered' AND c.customer_state = 'BA';

-- =========================================================
-- 5. Коммутативность объединения и пересечения
-- Если оба запроса ниже возвращают одинаковый ЕДИНСТВЕННЫЙ result set
-- (без учёта порядка строк), это подтверждает A ∪ B = B ∪ A.
-- Аналогично для INTERSECT: A ∩ B = B ∩ A.
-- Проверка "нулевой разностью": (A∪B) EXCEPT (B∪A) должно быть пусто,
-- и наоборот.
(
    SELECT DISTINCT oi.product_id FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'BA'
    UNION
    SELECT DISTINCT oi.product_id FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'PE'
)
EXCEPT
(
    SELECT DISTINCT oi.product_id FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'PE'
    UNION
    SELECT DISTINCT oi.product_id FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'BA'
);
-- Ожидаемый результат: 0 строк => A ∪ B = B ∪ A (коммутативность выполняется)

-- =========================================================
-- 6. Некоммутативность разности: показать, что A − B ≠ B − A
-- =========================================================

-- Сравниваем мощности A-B и B-A: если множества A и B не совпадают
-- полностью, то как правило |A-B| <> |B-A|, а сами множества различны.
SELECT 'A_minus_B' AS diff_name, count(*) AS cnt FROM (
    SELECT DISTINCT oi.product_id FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'BA'
    EXCEPT
    SELECT DISTINCT oi.product_id FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'PE'
) t
UNION ALL
SELECT 'B_minus_A', count(*) FROM (
    SELECT DISTINCT oi.product_id FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'PE'
    EXCEPT
    SELECT DISTINCT oi.product_id FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered' AND c.customer_state = 'BA'
) t;
-- Если cnt(A_minus_B) <> cnt(B_minus_A), это прямое доказательство,
-- что операция разности некоммутативна: A-B != B-A.

-- =========================================================
-- 7. Пересечение без INTERSECT, через EXISTS
-- =========================================================

SELECT DISTINCT a.product_id
FROM olist.order_items a
JOIN olist.orders oa ON oa.order_id = a.order_id
JOIN olist.customers ca ON ca.customer_id = oa.customer_id
WHERE oa.order_status = 'delivered' AND ca.customer_state = 'BA'
  AND EXISTS (
      SELECT 1
      FROM olist.order_items b
      JOIN olist.orders ob ON ob.order_id = b.order_id
      JOIN olist.customers cb ON cb.customer_id = ob.customer_id
      WHERE ob.order_status = 'delivered'
        AND cb.customer_state = 'PE'
        AND b.product_id = a.product_id
  );
-- Результат должен совпадать (как множество) с результатом INTERSECT из п.3

-- =========================================================
-- 8. Демонстрация дубликатов без DISTINCT/UNION
-- =========================================================

-- Здесь product_id заведомо не уникальны: один и тот же товар встречается
-- в нескольких позициях заказов (разные order_id/order_item_id).
-- Это мультимножество, а не множество.
SELECT oi.product_id
FROM olist.order_items oi
JOIN olist.orders o ON o.order_id = oi.order_id
JOIN olist.customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered' AND c.customer_state = 'BA';
-- Сравните: count(*) из этого запроса > count(DISTINCT product_id) из п.1,
-- значит дубликаты присутствуют.

-- =========================================================
-- 9. Итог: что возвращает множество, а что — мультимножество
-- =========================================================
-- UNION, INTERSECT, EXCEPT (без ALL)      -> результат-МНОЖЕСТВО (без дублей)
-- UNION ALL, INTERSECT ALL, EXCEPT ALL    -> результат-МУЛЬТИМНОЖЕСТВО (дубли сохраняются)
-- Обычный SELECT без DISTINCT             -> мультимножество по умолчанию,
--                                             т.к. SQL не удаляет повторяющиеся строки
-- SELECT DISTINCT                         -> явное приведение к множеству
