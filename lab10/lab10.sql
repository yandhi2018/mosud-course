-- ФИО: _____________________
-- Группа: ___________________
-- Практическая работа № 10; вариант 4.
-- Условие МОСУДПрак10.docx повторяет практическую №9.
-- Воспроизводимый запуск в Docker с ограниченной общей памятью.
SET max_parallel_workers_per_gather = 0;
CREATE SCHEMA IF NOT EXISTS lab;
CREATE TABLE IF NOT EXISTS lab.nf_4_coupons(
 coupon_code text CONSTRAINT pk_nf_4_coupons PRIMARY KEY,
 valid_from date NOT NULL,valid_to date NOT NULL,discount numeric(5,2) NOT NULL,
 CONSTRAINT ck_nf_4_dates CHECK(valid_from<valid_to),
 CONSTRAINT ck_nf_4_discount CHECK(discount>0 AND discount<=100));
CREATE TABLE IF NOT EXISTS lab.nf_4_customers(
 customer_id text CONSTRAINT pk_nf_4_customers PRIMARY KEY,
 customer_city text NOT NULL,
 CONSTRAINT fk_nf_4_customer FOREIGN KEY(customer_id) REFERENCES olist.customers(customer_id));
CREATE TABLE IF NOT EXISTS lab.nf_4_uses(
 coupon_code text NOT NULL CONSTRAINT fk_nf_4_coupon REFERENCES lab.nf_4_coupons,
 customer_id text NOT NULL CONSTRAINT fk_nf_4_uses_customer REFERENCES lab.nf_4_customers,
 use_date date NOT NULL,category_name text NOT NULL,
 CONSTRAINT pk_nf_4_uses PRIMARY KEY(coupon_code,customer_id,use_date));
INSERT INTO lab.nf_4_coupons VALUES
 ('NF4_A','2018-01-01','2019-01-01',5),('NF4_B','2018-01-01','2019-01-01',10),
 ('NF4_C','2018-01-01','2019-01-01',15) ON CONFLICT DO NOTHING;
INSERT INTO lab.nf_4_customers SELECT customer_id,customer_city FROM olist.customers
WHERE customer_city IS NOT NULL ORDER BY customer_id LIMIT 3 ON CONFLICT DO NOTHING;
WITH c AS (SELECT customer_id,row_number() OVER(ORDER BY customer_id) AS n
           FROM lab.nf_4_customers LIMIT 3),
seed(code,n,day,cat) AS (VALUES
 ('NF4_A',1,1,'beleza_saude'),('NF4_A',2,2,'beleza_saude'),
 ('NF4_B',1,3,'esporte_lazer'),('NF4_B',3,4,'esporte_lazer'),('NF4_C',3,5,'cama_mesa_banho'))
INSERT INTO lab.nf_4_uses SELECT code,customer_id,date '2018-02-01'+day,cat
FROM seed JOIN c USING(n) ON CONFLICT DO NOTHING;
-- Обратное соединение восстанавливает 5 использований.
SELECT u.*,c.valid_from,c.valid_to,c.discount,k.customer_city FROM lab.nf_4_uses u
JOIN lab.nf_4_coupons c USING(coupon_code) JOIN lab.nf_4_customers k USING(customer_id)
ORDER BY coupon_code,customer_id,use_date;
SELECT (SELECT count(*) FROM lab.nf_4_uses) AS uses,
 (SELECT count(*) FROM lab.nf_4_coupons) AS coupon_definitions,
 (SELECT count(*) FROM lab.nf_4_customers) AS customer_definitions;
