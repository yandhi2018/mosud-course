-- ФИО: _____________________
-- Группа: ___________________
-- Практическая работа № 3. Выборка, проекция, переименование и реляционная алгебра
-- Вариант 4: отношение customers
-- Предикат: state IN ('SP','RJ','MG') AND city IS NOT NULL
-- Проекция: customer_unique_id, city, state

-- =========================================================
-- Исходное отношение и используемые атрибуты
-- =========================================================
-- Отношение: olist.customers
-- Атрибуты, участвующие в предикате: customer_state, customer_city
-- Атрибуты проекции: customer_unique_id, customer_city, customer_state

-- =========================================================
-- Реляционно-алгебраическое выражение
-- (с переименованием ρ для приведения имён атрибутов к именам варианта)
--
-- π customer_unique_id, city, state (
--     ρ (customer_city -> city, customer_state -> state) (
--         σ (customer_state IN {'SP','RJ','MG'} AND customer_city IS NOT NULL) (
--             olist.customers
--         )
--     )
-- )
-- =========================================================

-- =========================================================
-- 1. Прямая реализация выражения в SQL
-- =========================================================
SELECT
    customer_unique_id,
    customer_city  AS city,
    customer_state AS state
FROM olist.customers
WHERE customer_state IN ('SP', 'RJ', 'MG')
  AND customer_city IS NOT NULL;

-- =========================================================
-- 4. Разбиение сложного предиката на две последовательные выборки
-- σ(p1 AND p2)(R) = σ(p1)(σ(p2)(R)) — эквивалентность выборок
-- =========================================================
SELECT
    customer_unique_id,
    customer_city  AS city,
    customer_state AS state
FROM (
    SELECT *
    FROM (
        SELECT *
        FROM olist.customers
        WHERE customer_state IN ('SP', 'RJ', 'MG')   -- первая выборка σ(p1)
    ) step1
    WHERE customer_city IS NOT NULL                   -- вторая выборка σ(p2)
) step2;

-- Проверка эквивалентности (п.1) и (п.4): разность результатов должна быть
-- пустой в обе стороны.
(
    SELECT customer_unique_id, customer_city AS city, customer_state AS state
    FROM olist.customers
    WHERE customer_state IN ('SP', 'RJ', 'MG') AND customer_city IS NOT NULL
    EXCEPT
    SELECT customer_unique_id, customer_city AS city, customer_state AS state
    FROM (
        SELECT * FROM (
            SELECT * FROM olist.customers WHERE customer_state IN ('SP','RJ','MG')
        ) step1
        WHERE customer_city IS NOT NULL
    ) step2
)
UNION ALL
(
    SELECT customer_unique_id, customer_city AS city, customer_state AS state
    FROM (
        SELECT * FROM (
            SELECT * FROM olist.customers WHERE customer_state IN ('SP','RJ','MG')
        ) step1
        WHERE customer_city IS NOT NULL
    ) step2
    EXCEPT
    SELECT customer_unique_id, customer_city AS city, customer_state AS state
    FROM olist.customers
    WHERE customer_state IN ('SP', 'RJ', 'MG') AND customer_city IS NOT NULL
);
-- Ожидаемый результат: 0 строк => запросы (1) и (4) эквивалентны.

-- =========================================================
-- 5. Второй вариант: проекция ненужных столбцов выполняется раньше
-- (в источнике сначала отбрасываем лишние столбцы, затем фильтруем)
-- =========================================================
SELECT
    customer_unique_id,
    city,
    state
FROM (
    SELECT
        customer_unique_id,
        customer_city  AS city,
        customer_state AS state
    FROM olist.customers          -- проекция выполнена сразу на исходном отношении,
                                   -- лишние столбцы дальше не протаскиваются
) narrowed
WHERE state IN ('SP', 'RJ', 'MG')
  AND city IS NOT NULL;

-- =========================================================
-- 6. Проверка дубликатов в проекции: SELECT vs SELECT DISTINCT
-- =========================================================
-- customer_id уникален для каждой строки customers, а customer_unique_id -
-- нет: один и тот же покупатель (customer_unique_id) может иметь несколько
-- customer_id (регистрировался заново). После проекции на
-- (customer_unique_id, city, state) дубликаты возможны.

SELECT count(*) AS rows_no_distinct
FROM (
    SELECT customer_unique_id, customer_city AS city, customer_state AS state
    FROM olist.customers
    WHERE customer_state IN ('SP', 'RJ', 'MG') AND customer_city IS NOT NULL
) t;

SELECT count(*) AS rows_with_distinct
FROM (
    SELECT DISTINCT customer_unique_id, customer_city AS city, customer_state AS state
    FROM olist.customers
    WHERE customer_state IN ('SP', 'RJ', 'MG') AND customer_city IS NOT NULL
) t;

-- Если rows_no_distinct > rows_with_distinct, проекция без DISTINCT
-- породила дубликаты кортежей (customer_unique_id, city, state).
