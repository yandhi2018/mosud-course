-- ФИО: _____________________
-- Группа: ___________________
-- Практическая работа № 11; вариант 4.
-- Воспроизводимый запуск в Docker с ограниченной общей памятью.
SET max_parallel_workers_per_gather = 0;
CREATE SCHEMA IF NOT EXISTS lab;
CREATE OR REPLACE VIEW lab.v_order_summary AS
WITH items AS(SELECT order_id,count(*) AS item_count,sum(price+freight_value) AS total
            FROM olist.order_items GROUP BY order_id)
SELECT o.order_id,o.order_purchase_timestamp,o.order_status,c.customer_state,
 coalesce(i.item_count,0) AS item_count,coalesce(i.total,0) AS total
FROM olist.orders o JOIN olist.customers c USING(customer_id) LEFT JOIN items i USING(order_id);
CREATE MATERIALIZED VIEW IF NOT EXISTS lab.mv_monthly_state_sales AS
SELECT date_trunc('month',order_purchase_timestamp)::date AS month,customer_state,
 count(*) AS orders,sum(total) AS total FROM lab.v_order_summary
WHERE order_status='delivered' GROUP BY 1,2;
REFRESH MATERIALIZED VIEW lab.mv_monthly_state_sales;
-- Три CTE: месячные итоги, среднее штата, месяцы выше среднего.
WITH monthly AS(SELECT * FROM lab.mv_monthly_state_sales),
means AS(SELECT customer_state,avg(total) AS average FROM monthly GROUP BY customer_state),
above AS(SELECT m.*,s.average FROM monthly m JOIN means s USING(customer_state) WHERE m.total>s.average)
SELECT * FROM above WHERE customer_state='PR' ORDER BY month;
CREATE TABLE IF NOT EXISTS lab.geo_tree(
 node_id text CONSTRAINT pk_geo_tree PRIMARY KEY,
 parent_id text CONSTRAINT fk_geo_parent REFERENCES lab.geo_tree(node_id),
 node_type text NOT NULL CONSTRAINT ck_geo_type CHECK(node_type IN('country','state','city')),
 node_name text NOT NULL);
INSERT INTO lab.geo_tree VALUES('BR',NULL,'country','Brazil') ON CONFLICT DO NOTHING;
INSERT INTO lab.geo_tree SELECT 'ST:'||customer_state,'BR','state',customer_state
FROM olist.customers WHERE customer_state IS NOT NULL GROUP BY customer_state ON CONFLICT DO NOTHING;
WITH cities AS(SELECT customer_state,customer_city,count(*) AS customers
 FROM olist.customers WHERE customer_state IS NOT NULL AND customer_city IS NOT NULL GROUP BY 1,2),
ranked AS(SELECT *,row_number() OVER(PARTITION BY customer_state ORDER BY customers DESC,customer_city) AS rn FROM cities)
INSERT INTO lab.geo_tree SELECT 'CT:'||customer_state||':'||customer_city,'ST:'||customer_state,'city',customer_city
FROM ranked WHERE rn<=20 ON CONFLICT DO NOTHING;
-- Поддерево PR, базовая часть: только корень; рекурсивная: дети текущих узлов.
WITH RECURSIVE tree AS(
 SELECT 0 AS depth,node_id,node_name,ARRAY[node_id] AS path FROM lab.geo_tree WHERE node_id='ST:PR'
 UNION ALL SELECT t.depth+1,g.node_id,g.node_name,t.path||g.node_id
 FROM tree t JOIN lab.geo_tree g ON g.parent_id=t.node_id WHERE NOT g.node_id=ANY(t.path))
SELECT depth,node_id,array_to_string(path,' -> ') AS path,node_name FROM tree ORDER BY path;
-- Обратная рекурсия от выбранного реального города PR.
WITH RECURSIVE ancestors AS(
 SELECT 0 AS depth,node_id,parent_id,node_name,ARRAY[node_id] AS path FROM lab.geo_tree
 WHERE node_id=(SELECT min(node_id) FROM lab.geo_tree WHERE parent_id='ST:PR')
 UNION ALL SELECT a.depth+1,g.node_id,g.parent_id,g.node_name,a.path||g.node_id
 FROM ancestors a JOIN lab.geo_tree g ON g.node_id=a.parent_id WHERE NOT g.node_id=ANY(a.path))
SELECT depth,node_id,array_to_string(path,' -> ') AS path,node_name FROM ancestors ORDER BY depth;
WITH RECURSIVE descendants AS(
 SELECT node_id AS root,node_id,ARRAY[node_id] AS path FROM lab.geo_tree WHERE node_type='state'
 UNION ALL SELECT d.root,g.node_id,d.path||g.node_id FROM descendants d JOIN lab.geo_tree g ON g.parent_id=d.node_id
 WHERE NOT g.node_id=ANY(d.path))
SELECT root,count(*)-1 AS descendants FROM descendants GROUP BY root ORDER BY root;
-- Цикл только в временной копии: BR -> штат -> BR.
CREATE TEMP TABLE geo_cycle AS TABLE lab.geo_tree;
UPDATE geo_cycle SET parent_id='ST:PR' WHERE node_id='BR';
WITH RECURSIVE safe AS(
 SELECT node_id,parent_id,ARRAY[node_id] AS path FROM geo_cycle WHERE node_id='BR'
 UNION ALL SELECT g.node_id,g.parent_id,s.path||g.node_id FROM safe s
 JOIN geo_cycle g ON g.parent_id=s.node_id WHERE NOT g.node_id=ANY(s.path))
SELECT count(*) AS safe_nodes FROM safe;
