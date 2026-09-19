# lab01. Развёртывание PostgreSQL и загрузка Olist

- **Версия PostgreSQL:** 17 (образ `postgres:17`, запущен через Docker Compose,
  `docker-compose.yml`). Хост-порт проброшен как `5433:5432`, т.к. порт 5432
  уже занят локальной Windows-службой `postgresql-x64-17`.
- **Способ импорта:** `psql \copy` с хоста (`psql -h localhost -p 5433 -U student -d olist`)
  для каждой из 9 таблиц по отдельности, в порядке, совместимом с внешними
  ключами (сначала `customers`, `products`, `sellers`,
  `product_category_name_translation`, `geolocation`, затем `orders`, затем
  `order_items`, `order_payments`, `order_reviews`).
- **Параметры подключения:** host=`localhost`, port=`5433`, db=`olist`,
  user=`student` (пароль не публикуется, задаётся через переменную окружения
  `POSTGRES_PASSWORD` в `docker-compose.yml`).

## Фактическое число строк в 9 таблицах

| Таблица | Строк | Совпадает с ориентиром задания |
|---|---:|:---:|
| customers | 99 441 | ✅ |
| geolocation | 1 000 163 | ✅ |
| orders | 99 441 | ✅ |
| order_items | 112 650 | ✅ |
| order_payments | 103 886 | ✅ |
| order_reviews | 99 224 | ✅ |
| products | 32 951 | ✅ |
| sellers | 3 095 | ✅ |
| product_category_name_translation | 71 | ✅ |

`lab01/check.sql` также подтвердил: 0 NULL в ключевых полях
(`customer_id`, `order_id`, `product_id`, `seller_id`) и 0 «осиротевших»
строк по всем 6 проверенным связям (order_items→orders/products/sellers,
orders→customers, order_payments→orders, order_reviews→orders). `ANALYZE`
выполнен для всех 9 таблиц схемы `olist`.
