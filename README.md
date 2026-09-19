# mosud-course

Практикум по курсу МОСУД: SQL и математические модели управления данными.
Набор данных: Brazilian E-Commerce Public Dataset by Olist (CC BY-NC-SA 4.0),
СУБД: PostgreSQL 17 в Docker.

| Каталог | Работа |
|---|---|
| `lab01/` | Развёртывание PostgreSQL и загрузка Olist |
| `lab02/` | Множества и мультимножества в SQL (вариант 4: BA/PE) |
| `lab03/` | Выборка, проекция, переименование и реляционная алгебра (вариант 4: customers) |

## Быстрый запуск

1. Поднять базу: `docker compose up -d` в каталоге `lab01` (хост-порт 5433).
2. Применить `lab01/schema.sql`, загрузить 9 CSV Olist командами `\copy`
   (сами CSV в репозиторий не входят, см. `.gitignore`), выполнить `lab01/check.sql`.
3. Запускать `lab02/lab02.sql` и `lab03/lab03.sql`.

Подключение: host `localhost`, port `5433`, db `olist`, user `student`.
