-- Задание 1. Выполните горизонтальное партиционирование для таблицы inventory учебной базы dvd-rental:

--		- создайте 2 партиции по значению store_id
--		- создайте индексы для каждой партиции
--		- заполните партиции данными из родительской таблицы
--		- для каждой партиции создайте правила на внесение, обновление, удаление данных. Напишите команды SQL для проверки работы правил.


create table store_1 
(check (store_id = 1)) inherits (inventory);

create table store_2 
(check (store_id = 2)) inherits (inventory);

create index store_1_inventory_id_idx on store_1 (inventory_id);
create index store_2_inventory_id_idx on store_2 (inventory_id);

alter table only store_1    
	add constraint store_1_pkey primary key (inventory_id);

alter table only store_2   
	add constraint store_2_pkey primary key (inventory_id);

alter table rental drop constraint rental_inventory_id_fkey;

WITH cte AS (  
	DELETE FROM ONLY inventory     
	WHERE store_id = 1 RETURNING *)
INSERT INTO store_1   
SELECT * FROM cte;

WITH cte AS (  
	DELETE FROM ONLY inventory      
	WHERE store_id = 2 RETURNING *)
INSERT INTO store_2   
SELECT * FROM cte;

create rule store_insert_1 as on insert to inventory
where (store_id = 1)
do instead insert into store_1 values (new.*);

create rule store_insert_2 as on insert to inventory
where (store_id = 2)
do instead insert into store_2 values (new.*);

create rule store_update_1 as on update to inventory
where (new.store_id = 1 and new.store_id <> old.store_id)
do (
	insert into store_1 values (new.*);
	delete from store_2 where inventory_id = new.inventory_id;
);

create rule store_update_2 as on update to inventory
where (new.store_id = 2 and new.store_id <> old.store_id)
do (
	insert into store_2 values (new.*);
	delete from store_1 where inventory_id = new.inventory_id;
);

insert into inventory   
values ((select max(inventory_id) + 1 from inventory), 98, 1, now());

update inventory 
set store_id = 2
where inventory_id = (select max(inventory_id) from inventory);

select * from inventory
where inventory_id >= 4550


-- Задание 2. Создайте новую базу данных и в ней 2 таблицы для хранения данных по инвентаризации каждого магазина,
-- которые будут наследоваться из таблицы inventory базы dvd-rental. 
-- Используя шардирование и модуль postgres_fdw создайте подключение к новой базе данных и необходимые внешние таблицы
-- в родительской базе данных для наследования. Распределите данные по внешним таблицам.
-- Напишите SQL-запросы для проверки работы внешних таблиц.

create database stores;

create table store_1_s (
	inventory_id int4 NOT NULL,
	film_id int2 NOT NULL,
	store_id int2 NOT null check (store_id = 1),
	last_update timestamp NOT NULL DEFAULT now()
);
create index store_1_inventory_id_idx on store_1_s (inventory_id);

create table store_2_s (
	inventory_id int4 NOT NULL,
	film_id int2 NOT NULL,
	store_id int2 NOT NULL check (store_id = 2),
	last_update timestamp NOT NULL DEFAULT now()
);
create index store_2_inventory_id_idx on store_2_s (inventory_id);

create schema extensions;
create extension postgres_fdw;

create server stores_server
foreign data wrapper postgres_fdw
options (host 'localhost', port '5432', dbname 'stores');

create user mapping for postgres
server stores_server
options (user 'postgres', password 'Bn9RLO');

create foreign table store_1 (
	inventory_id int4 NOT NULL,
	film_id int2 NOT NULL,
	store_id int2 NOT null,
	last_update timestamp NOT NULL DEFAULT now()) 
inherits (inventory)
server stores_server
options (schema_name 'public', table_name 'store_1_s');

create foreign table store_2 (
	inventory_id int4 NOT NULL,
	film_id int2 NOT NULL,
	store_id int2 NOT null,
	last_update timestamp NOT NULL DEFAULT now()) 
inherits (inventory)
server stores_server
options (schema_name 'public', table_name 'store_2_s');

create or replace function inventory_insert_tgf() returns trigger as $$
begin
	if new.inventory_id in (select inventory_id from inventory) then
		raise exception 'Ключ (inventory_id)=(%) уже существует.', new.inventory_id;
	elsif new.store_id = 1 then 
		insert into store_1 values (new.*);
	elsif new.store_id = 2 then
		insert into store_2 values (new.*);
	else raise exception 'Отсутствует шард';
	end if;
	return null;
end; $$ language plpgsql;

create trigger inventory_insert_tg    
before insert on inventory
for each row execute function inventory_insert_tgf();

alter table rental drop constraint rental_inventory_id_fkey;

WITH cte AS (  
    DELETE FROM ONLY inventory      
    WHERE store_id = 1 RETURNING *)
INSERT INTO store_1   
SELECT * FROM cte;

WITH cte AS (  
    DELETE FROM ONLY inventory      
    WHERE store_id = 2 RETURNING *)
INSERT INTO store_2   
SELECT * FROM cte;

insert into inventory   
values ((select max(inventory_id) + 1 from inventory), 77, 1, now());

insert into inventory   
values ((select max(inventory_id) + 1 from inventory), 99, 2, now());

delete from inventory where inventory_id = (select max(inventory_id) from inventory);
