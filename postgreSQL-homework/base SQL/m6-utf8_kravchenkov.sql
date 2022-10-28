--=============== МОДУЛЬ 6. POSTGRESQL =======================================
--= ПОМНИТЕ, ЧТО НЕОБХОДИМО УСТАНОВИТЬ ВЕРНОЕ СОЕДИНЕНИЕ И ВЫБРАТЬ СХЕМУ PUBLIC===========
SET search_path TO public;

--======== ОСНОВНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Напишите SQL-запрос, который выводит всю информацию о фильмах 
--со специальным атрибутом "Behind the Scenes".

	select *
	from film f 
	where f.special_features && array['Behind the Scenes'];


--ЗАДАНИЕ №2
--Напишите еще 2 варианта поиска фильмов с атрибутом "Behind the Scenes",
--используя другие функции или операторы языка SQL для поиска значения в массиве.

	select *
	from film f 
	where f.special_features @> array['Behind the Scenes'];
	
	select *
	from film f 
	where 'Behind the Scenes' = any(f.special_features);

--ЗАДАНИЕ №3
--Для каждого покупателя посчитайте сколько он брал в аренду фильмов 
--со специальным атрибутом "Behind the Scenes.

--Обязательное условие для выполнения задания: используйте запрос из задания 1, 
--помещенный в CTE. CTE необходимо использовать для решения задания.

	with cte as (
		select *
		from film f 
		where f.special_features && array['Behind the Scenes'])
	select 
		r.customer_id,
		count(cte.film_id) as film_count
	from customer c 
	join rental r on r.customer_id = c.customer_id 
	join inventory i on i.inventory_id = r.inventory_id 
	join cte on cte.film_id = i.film_id
	group by r.customer_id
	order by r.customer_id;

--ЗАДАНИЕ №4
--Для каждого покупателя посчитайте сколько он брал в аренду фильмов
-- со специальным атрибутом "Behind the Scenes".

--Обязательное условие для выполнения задания: используйте запрос из задания 1,
--помещенный в подзапрос, который необходимо использовать для решения задания.

	select 
		r.customer_id,
		count(t.film_id) as film_count
	from customer c 
	join rental r on r.customer_id = c.customer_id 
	join inventory i on i.inventory_id = r.inventory_id 
	join (
		select *
		from film f 
		where f.special_features && array['Behind the Scenes']) t on t.film_id = i.film_id
	group by r.customer_id
	order by r.customer_id;

--ЗАДАНИЕ №5
--Создайте материализованное представление с запросом из предыдущего задания
--и напишите запрос для обновления материализованного представления

	create materialized view film_count_behind_the_scenes as
		select 
			r.customer_id,
			count(t.film_id) as film_count
		from customer c 
		join rental r on r.customer_id = c.customer_id 
		join inventory i on i.inventory_id = r.inventory_id 
		join (
			select *
			from film f 
			where f.special_features && array['Behind the Scenes']) t on t.film_id = i.film_id
		group by r.customer_id
		order by r.customer_id;

	refresh materialized view film_count_behind_the_scenes;

--ЗАДАНИЕ №6
--С помощью explain analyze проведите анализ скорости выполнения запросов
-- из предыдущих заданий и ответьте на вопросы:

--1. Каким оператором или функцией языка SQL, используемых при выполнении домашнего задания, 
--   поиск значения в массиве происходит быстрее
--2. какой вариант вычислений работает быстрее: 
--   с использованием CTE или с использованием подзапроса

	-- 1. Операторы && и @> работают немного быстрее функции any():
	--		&& и @>	(cost=67 time=0.8-2ms)
	--		any()	(cost=77 time=1.2-2ms)
	-- 2. В среднем оба варианта вычислений работают одинаково 
	--	(time=30-70ms cost=720)

--======== ДОПОЛНИТЕЛЬНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Выполняйте это задание в форме ответа на сайте Нетологии


--ЗАДАНИЕ №2
--Используя оконную функцию выведите для каждого сотрудника
--сведения о самой первой продаже этого сотрудника.

	select 
		t_payment.staff_id,
		f.film_id,
		f.title,
		t_payment.amount,
		t_payment.payment_date,
		c.last_name as customer_last_name,
		c.first_name as customer_first_name
	from (
		select 
			p.rental_id,
			p.staff_id,
			p.amount,
			p.payment_date,
			row_number() over(partition by p.staff_id order by p.payment_date asc)
		from payment p ) t_payment
	join rental r on t_payment.rental_id = r.rental_id 
	join customer c on r.customer_id = c.customer_id 
	join inventory i on r.inventory_id = i.inventory_id 
	join film f on i.film_id = f.film_id 
	where t_payment.row_number = 1;



--ЗАДАНИЕ №3
--Для каждого магазина определите и выведите одним SQL-запросом следующие аналитические показатели:
-- 1. день, в который арендовали больше всего фильмов (день в формате год-месяц-день)
-- 2. количество фильмов взятых в аренду в этот день
-- 3. день, в который продали фильмов на наименьшую сумму (день в формате год-месяц-день)
-- 4. сумму продажи в этот день

	with cte as(
		select
			i.store_id,
			count(p.payment_id) over(partition by i.store_id, p.payment_date::date),
			p.payment_date,
			sum(p.amount) over(partition by i.store_id, p.payment_date::date)
		from payment p 
		join rental r on p.rental_id = r.rental_id 
		join inventory i on r.inventory_id = i.inventory_id 
	)
	select 
		t_count.store_id as "ID магазина",
		t_count."День, в который арендовали больше всего фильмов"::date,
		t_count."Количество фильмов, взятых в аренду в этот день",
		t."День, в который продали фильмов на наименьшую сумму"::date,
		t."Сумма продажи в этот день"
	from (
		select *
		from (
			select
				cte.store_id,
				cte.payment_date as "День, в который арендовали больше всего фильмов",
				cte.count as "Количество фильмов, взятых в аренду в этот день",
				row_number() over(partition by cte.store_id order by cte.count desc) as row_count
			from cte) t
		where t.row_count = 1) t_count
	join (
		select *
		from (
			select *
			from (
				select 
					cte.store_id,
					cte.payment_date as "День, в который продали фильмов на наименьшую сумму",
					cte.sum as "Сумма продажи в этот день",
					row_number() over(partition by cte.store_id order by cte.sum asc) as row_sum
				from cte) t
			where t.row_sum = 1) t_sum 
	) t on t_count.store_id = t.store_id;


