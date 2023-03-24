--Задание 1. Создайте подключение к удаленному облачному серверу базы HR (база данных postgres, схема hr), используя модуль postgres_fdw.
--Напишите SQL-запрос на выборку любых данных используя 2 сторонних таблицы, соединенных с помощью JOIN.
--В качестве ответа на задание пришлите список команд, использовавшихся для настройки подключения, создания внешних таблиц,
--а также получившийся SQL-запрос.

-- create schema extensions

-- create extension postgres_fdw

create server pfdw_netology_server
foreign data wrapper postgres_fdw
options (host '51.250.106.132',  port '19001', dbname 'postgres')

create user mapping for postgres
server pfdw_netology_server
options (user 'netology', password 'NetoSQL2019')

create foreign table out_position (
	pos_id int4 NOT NULL,
	pos_title varchar(250) NOT NULL,
	pos_category varchar(100) NULL,
	unit_id int4 NULL,
	grade int4 NULL,
	address_id int4 NULL,
	manager_pos_id int4 NULL)
server pfdw_netology_server
options (schema_name 'hr', table_name 'position')

create foreign table out_grade_salary (
	grade int4 NOT NULL,
	min_salary numeric(12, 2) NOT NULL,
	max_salary numeric(12, 2) NOT NULL)
server pfdw_netology_server
options (schema_name 'hr', table_name 'grade_salary')

select distinct 
	p.pos_title,
	p.grade,
	gs.min_salary,
	gs.max_salary 
from out_position p
join out_grade_salary gs on p.grade = gs.grade 
order by gs.max_salary desc 

-- Задание 2. С помощью модуля tablefunc получите из таблицы projects базы HR таблицу с данными,
-- колонками которой будут: год, месяцы с января по декабрь, общий итог по стоимости всех проектов за год.
-- В качестве ответа на задание пришлите получившийся SQL-запрос.

--create extension tablefunc

select "year", coalesce("January", '0')::int8 as "January", coalesce("February",' 0')::int8 as "February", coalesce("March", '0')::int8 as "March",
	coalesce("April", '0')::int8 as "April", coalesce("May", '0')::int8 as "May", coalesce("June", '0')::int8 as "June", coalesce("July", '0')::int8 as "July",
	coalesce("August", '0')::int8 as "August", coalesce("September", '0')::int8 as "September", coalesce("October", '0')::int8 as "October",
	coalesce("November", '0')::int8 as "November", coalesce("December", '0')::int8 as "December", coalesce("Итого", '0') as "Итого"
from extensions.crosstab($$
	select coalesce(t.year::text, 'Итого')::text, coalesce(t.month::text, 'Итого')::text, t.sum
	from (
		select 
			extract('year' from p.created_at) as "year",
			extract('month' from p.created_at) as "month",
			sum(amount)
		from projects p
		group by cube (1, 2)
		order by 1, 2
	) t
	$$,
	$$ 
	select tt.month::text
	from (
		select distinct extract('month' from p.created_at) as "month"
		from projects p
		order by 1
	) tt
	union all
	select 'Итого'
	 $$) as 
		cst ("year" text, "January" numeric, "February" numeric, "March" numeric, "April" numeric, 
			"May" numeric, "June" numeric, "July" numeric, "August" numeric, "September" numeric,
			"October" numeric, "November" numeric, "December" numeric, "Итого" text)
	
-- Задание 3. Настройте модуль pg_stat_statements на локальном сервере PostgresSQL и выполните несколько любых SQL-запросов к базе.
-- В качестве ответа на задание пришлите скриншот со статистикой по выполненным запросам.

-- create extension pg_stat_statements;

select userid, dbid, queryid, query, calls, total_exec_time, min_exec_time, max_exec_time,
	mean_exec_time, stddev_exec_time, rows, wal_records, wal_bytes
from extensions.pg_stat_statements
where rows > 5

-- см. скриншот в приложении
			