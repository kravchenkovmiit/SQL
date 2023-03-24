---------------------------
-- Создание структуры БД --
---------------------------

-- сотрудники

create table "user" (
	id uuid default extensions.uuid_generate_v4(),
	last_name varchar(30) not null,
	first_name varchar(20) not null,
	dismissed boolean not null default false,
	CONSTRAINT user_pkey primary key (id)
);

CREATE INDEX idx_last_name ON "user"(last_name);

-- список контрагентов

create table account (
	id uuid default extensions.uuid_generate_v4(),
	name varchar(80) not null,
	CONSTRAINT account_pkey primary key (id)
);

CREATE INDEX idx_name ON account(name);

-- список контактов контрагентов

create table contact (
	id uuid default extensions.uuid_generate_v4(),
	last_name varchar(30) not null,
	first_name varchar(20) not null,
	account_id uuid not null,
	CONSTRAINT contact_pkey primary key (id),
	CONSTRAINT contact_account_id_fkey FOREIGN KEY (account_id) REFERENCES account(id)
);

CREATE INDEX idx_contact_last_name ON contact(last_name);
CREATE INDEX idx_account_id ON contact(account_id);

-- данные по заявкам на курьера

create type courier_status as enum ('В очереди', 'Выполняется', 'Выполнено', 'Отменен');

create table courier (
	id uuid default extensions.uuid_generate_v4(),
	from_place varchar(150) not null,
	where_place varchar(150) not null,
	name varchar(150) not null,
	account_id uuid not null,
	contact_id uuid not null,
	description text null,
	user_id uuid not null,
	status courier_status not null default 'В очереди',
	created_date date not null default now(),
	CONSTRAINT courier_pkey primary key (id),
	CONSTRAINT courier_account_id_fkey FOREIGN KEY (account_id) REFERENCES account(id),
	CONSTRAINT courier_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contact(id),
	CONSTRAINT courier_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user"(id)
);

CREATE INDEX idx_courier_status ON courier(status);
CREATE INDEX idx_courier_account_id ON courier(account_id);

-- Создание вспомогательной функции

create or replace function random_str (x int) returns text as $$
declare val text;
begin
	val = repeat(
	substring(
		'абвгдеёжзийклмнопрстуфхцчшщьыъэюя',
		((random() + 0.5) * 3)::integer,
		((random() +0.5)*16.5)::integer),
	((random() + 0.5)*4)::integer);
	val = substring(val, 1, (random() * (x - 1))::integer + 1);
	return val;
end;
$$ language plpgsql


-- Создание процедуры для генерации тестовых данных

create or replace procedure insert_test_data(value int4) as $$
begin
	for i in 1..value
	loop
		-- user
		insert into "user" (id, last_name, first_name, dismissed)
		values (extensions.uuid_generate_v4(), initcap(random_str(30)),initcap(random_str(20)), (random()::integer)::boolean);
	
		-- account
		insert into account (id, name)
		values (extensions.uuid_generate_v4(), random_str(90)::varchar(80));
		
		-- contact
		for i in 1..2
		loop
			insert into contact (id, last_name, first_name, account_id)
			values (extensions.uuid_generate_v4(), initcap(random_str(30)),initcap(random_str(20)), (
				select
					id 
				from account
				order by random()
				limit 1));
		end loop;
	
		-- courier
		for i in 1..5
		loop
			insert into courier (id, from_place, where_place, name, account_id, contact_id, description, user_id, status, created_date)
			values (extensions.uuid_generate_v4(),
				initcap(concat(
					random_str(150),
					', ',
					((random()+0.5)*180)::int))::varchar(150),	-- from_place
				initcap(concat(
					random_str(150),
					', ',
					((random()+0.5)*180)::int))::varchar(150),	-- where_place
				initcap(random_str(160))::varchar(150),		-- name
				(select							-- account_id
					id 
				from account
				order by random()
				limit 1),
				(select							-- contact_id
					id 
				from contact
				order by random()
				limit 1),
				case 
					when random() < 0.5 then null
					else random_str (300)
					end,						-- description
				(select							-- user_id
					id 
				from "user"
				order by random()
				limit 1),
				(select unnest(enum_range(null::courier_status))
				offset random()*3
				limit 1),
				(now() - interval '1 day' * round(random() * 200))::date	-- created_date
				);
		end loop;
	end loop;
	commit;
end;
$$ language plpgsql


-- Создание процедуры для удаления тестовых данных

create or replace procedure erase_test_data() as $$
begin
	truncate courier cascade;
	truncate contact cascade;
	truncate account  cascade;
	truncate "user" cascade;
	commit;
end;
$$ language plpgsql;


-- Процедура по добавлению новой записи о заявке на курьера

create or replace procedure add_courier(from_place varchar(150), where_place varchar(150), name varchar(150), account_id uuid, contact_id uuid, description text, user_id uuid) as $$
begin
	insert into courier (from_place, where_place, name, account_id, contact_id, description, user_id)
		values (from_place, where_place, name, account_id, contact_id, description, user_id);
	commit;
end;
$$ language plpgsql


-- Функция по получению записей о заявках на курьера

create or replace function get_courier () returns table (
	id uuid,  					--идентификатор заявки
	from_place varchar(150), 	--откуда
	where_place varchar(150), 	--куда
	name varchar(150), 			--название документа
	account_id uuid, 			--идентификатор контрагента
	account varchar(80), 		--название контрагента
	contact_id uuid, 			--идентификатор контакта
	contact text,				--фамилия и имя контакта через пробел
	description text,			--описание
	user_id uuid, 				--идентификатор сотрудника
	"user" text,				--фамилия и имя сотрудника через пробел
	status courier_status,		--статус заявки
	created_date date			--дата создания заявки
) as $$
begin
	return query 
		select
			c.id,  					--идентификатор заявки
			c.from_place, 			--откуда
			c.where_place, 			--куда
			c.name, 				--название документа
			c.account_id, 			--идентификатор контрагента
			a.name as account, 		--название контрагента
			c.contact_id, 			--идентификатор контакта
			concat(ct.last_name, ' ', ct.first_name) as contact,		--фамилия и имя контакта через пробел
			c.description,			--описание
			c.user_id, 				--идентификатор сотрудника
			concat(u.last_name, ' ', u.first_name) as "user",			--фамилия и имя сотрудника через пробел
			c.status,				--статус заявки
			c.created_date			--дата создания заявки
		from courier c
		join account a on a.id = c.account_id
		join contact ct on ct.id = c.contact_id
		join "user" u on u.id = c.user_id
		order by status, created_date;
	if not found 
		then raise notice 'Заявки отсутствуют';
	end if;
end;
$$ language plpgsql;


-- Процедура по изменению статуса заявки

create or replace procedure change_status(new_status courier_status, courier_id uuid) as $$
begin
	update courier cr
	set status = new_status
	where id = courier_id;
	commit;
end;
$$ language plpgsql;


-- Функция по получению записей о сотрудниках

create or replace function get_users () returns table ("user" text) as $$
begin
	return query 
		select
			concat(u.last_name, ' ', u.first_name) as "user"
		from "user" u
		where u.dismissed = false
		order by 1;
	if not found 
		then raise notice 'Сотрудники отсутствуют';
	end if;
end;
$$ language plpgsql;


-- Функция по получению записей о контрагентах

create or replace function get_accounts () returns table (account varchar(80)) as $$
begin
	return query 
		select
			a."name" as account
		from account a
		order by 1;
	if not found 
		then raise notice 'Контрагенты отсутствуют';
	end if;
end;
$$ language plpgsql;


-- Функция по получению записей о контактах

create or replace function get_contacts (account_id uuid) returns table (contact text) as $$
declare val uuid = account_id;
begin
	if val is not null then
		return query 
			select
				concat(c.last_name, ' ', c.first_name) as contact
			from contact c
			where c.account_id = val
			order by 1;
	else
		return query 
			select 'Выберите контрагента';
	end if;
	if not found 
		then raise notice 'Контрагенты отсутствуют';
	end if;
end;
$$ language plpgsql;


-- Нематериализованное представление со статистикой:

create or replace view courier_statistic as
	select
		a.id,								--идентификатор контрагента
		a."name" as account,				--название контрагента
		c_courier.c_cr as count_courier,	--количество заказов на курьера для каждого контрагента
		coalesce(c_complete.count, 0) as count_complete,	--количество завершенных заказов для каждого контрагента
		coalesce(c_canceled.count, 0) as count_canceled,	--количество отмененных заказов для каждого контрагента
		case								-- процентное изменение количества заказов текущего месяца к предыдущему месяцу для каждого контрагента
			when p_month.count is null then 0
			else (coalesce(c_month.count, 0) * 100/p_month.count - 100) 
		end as percent_relative_prev_month,
		c_courier.c_wp as count_where_place,--количество мест доставки для каждого контрагента
		c_courier.c_ct as count_contact,	--количество контактов по контрагенту, которым доставляются документы
		c_canceled.array_agg as cansel_user_array	--массив с идентификаторами сотрудников, по которым были заказы со статусом "Отменен" для каждого контрагента
	from account a
	join (select 
			c.account_id,
			count(c.id) as c_cr,
			count(c.where_place) as c_wp,
			count(c.contact_id) as c_ct
		from courier c
		group by 1) c_courier on a.id = c_courier.account_id
	left join (select 
			c.account_id,
			count(c.id)
		from courier c
		where c.status = 'Выполнено'
		group by 1) c_complete on a.id = c_complete.account_id
	left join (select 
			c.account_id,
			count(c.id),
			array_agg(c.user_id) 
		from courier c
		where c.status = 'Отменен'
		group by 1) c_canceled on a.id = c_canceled.account_id
	left join (select 
			c.account_id,
			count(c.id)
		from courier c
		where c.created_date::varchar(7) = current_date::varchar(7)
		group by 1) c_month on a.id = c_month.account_id
	left join (select 
			c.account_id,
			count(c.id)
		from courier c
		where c.created_date::varchar(7) = (current_date - interval '1 month')::varchar(7)
		group by 1) p_month on a.id = p_month.account_id
	order by 3 desc;


--------------------------

-- create role

create role netocourier with login password 'NetoSQL2022';

revoke all privileges on database "postgres" from netocourier;
revoke all privileges on database "postgres" from public;

grant connect on database "postgres" to netocourier;
grant all privileges on schema public to netocourier;
grant all privileges on all tables in schema public to netocourier;
grant all privileges on schema extensions to netocourier;
grant select on all tables in schema pg_catalog to netocourier;
grant select on all tables in schema information_schema to netocourier;

