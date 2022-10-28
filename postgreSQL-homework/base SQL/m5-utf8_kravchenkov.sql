--=============== МОДУЛЬ 5. РАБОТА С POSTGRESQL =======================================
--= ПОМНИТЕ, ЧТО НЕОБХОДИМО УСТАНОВИТЬ ВЕРНОЕ СОЕДИНЕНИЕ И ВЫБРАТЬ СХЕМУ PUBLIC===========
SET search_path TO public;

--======== ОСНОВНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Сделайте запрос к таблице payment и с помощью оконных функций добавьте вычисляемые колонки согласно условиям:
--Пронумеруйте все платежи от 1 до N по дате
--Пронумеруйте платежи для каждого покупателя, сортировка платежей должна быть по дате
--Посчитайте нарастающим итогом сумму всех платежей для каждого покупателя, сортировка должна 
--быть сперва по дате платежа, а затем по сумме платежа от наименьшей к большей
--Пронумеруйте платежи для каждого покупателя по стоимости платежа от наибольших к меньшим 
--так, чтобы платежи с одинаковым значением имели одинаковое значение номера.
--Можно составить на каждый пункт отдельный SQL-запрос, а можно объединить все колонки в одном запросе.

	select
		p.customer_id,
		p.payment_id,
		p.payment_date,
		row_number() over(order by p.payment_date) as column_1,
		row_number() over(partition by p.customer_id order by p.payment_date) as column_2,
		sum(p.amount) over(partition by p.customer_id order by p.payment_date, p.amount) as column_3,
		dense_rank() over(partition by p.customer_id order by p.amount desc) as column_4
	from payment p 
	order by p.customer_id, column_4


--ЗАДАНИЕ №2
--С помощью оконной функции выведите для каждого покупателя стоимость платежа и стоимость 
--платежа из предыдущей строки со значением по умолчанию 0.0 с сортировкой по дате.

	select
		p.customer_id,
		p.payment_id,
		p.payment_date,
		p.amount,
		coalesce(lag(p.amount, 1) over(partition by p.customer_id order by p.payment_date), 0,00) as last_amount
	from payment p


--ЗАДАНИЕ №3
--С помощью оконной функции определите, на сколько каждый следующий платеж покупателя больше или меньше текущего.

	select
		p.customer_id,
		p.payment_id,
		p.payment_date,
		p.amount,
		coalesce(
			p.amount -
			lead(p.amount, 1) over(partition by p.customer_id order by p.payment_date)
			, 0,00) as difference
	from payment p


--ЗАДАНИЕ №4
--С помощью оконной функции для каждого покупателя выведите данные о его последней оплате аренды.

	with cte as(
		select 
			p.customer_id,
			p.payment_id,
			p.payment_date,
			p.amount,
			max(p.payment_date) over(partition by p.customer_id) as max_date
		from payment p)
	select distinct 
		customer_id,
		payment_id,
		max_date as payment_date,
		amount
	from cte
	where max_date = payment_date 
	order by customer_id

--======== ДОПОЛНИТЕЛЬНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--С помощью оконной функции выведите для каждого сотрудника сумму продаж за август 2005 года 
--с нарастающим итогом по каждому сотруднику и по каждой дате продажи (без учёта времени) 
--с сортировкой по дате.

	select 
		p.staff_id,
		p.payment_date::date,
		sum(p.amount) as sum_amount, 
		sum(sum(p.amount)) over(partition by p.staff_id order by p.payment_date::date) as "sum"
	from payment p 
	where p.payment_date::date between '2005-08-01' and '2005-09-01'
	group by 1, 2


	--подзапрос с оконной функцией
	
	select 
		t.staff_id,
		to_char(t.payment_date, 'dd.mm.yyyy') as payment_date,
		t.sum_amount,
		t."sum"
	from (
	select 
		p.staff_id,
		p.payment_id,
		p.payment_date,
		p.amount,
		sum(p.amount) over(partition by p.staff_id, p.payment_date::date order by p.payment_date::date) as sum_amount,
		sum(p.amount) over(partition by p.staff_id order by p.payment_date::date) as "sum",
		max(p.payment_date) over(partition by p.staff_id, p.payment_date::date) as max_date
	from payment p
	where p.payment_date::date between '2005-08-01' and '2005-09-01'
	) as t
	where payment_date = max_date;

	--CTE с группировкой + оконная функция

	with cte as(
		select 
			p.staff_id,
			p.payment_date::date,
			sum(p.amount) as sum_amount
		from payment p 
		group by p.staff_id, p.payment_date::date
		having p.payment_date::date between '2005-08-01' and '2005-09-01'
		order by p.staff_id, p.payment_date::date
	)
	select
		staff_id,
		payment_date,
		sum_amount,
		sum(sum_amount) over(partition by staff_id order by payment_date)
	from cte;


--ЗАДАНИЕ №2
--20 августа 2005 года в магазинах проходила акция: покупатель каждого сотого платежа получал
--дополнительную скидку на следующую аренду. С помощью оконной функции выведите всех покупателей,
--которые в день проведения акции получили скидку

	select *
	from (
		select 
			p.customer_id,
			p.payment_date,
			row_number() over(order by p.payment_date) as payment_number
		from payment p 
		where p.payment_date::date = '20-08-2005'
	) as t
	where payment_number % 100 = 0


--ЗАДАНИЕ №3
--Для каждой страны определите и выведите одним SQL-запросом покупателей, которые попадают под условия:
-- 1. покупатель, арендовавший наибольшее количество фильмов
-- 2. покупатель, арендовавший фильмов на самую большую сумму
-- 3. покупатель, который последним арендовал фильм

	with cte as(
		select
			c.country,
			count(p.payment_id) over(partition by p.customer_id) as payment_number,
			sum(p.amount) over(partition by p.customer_id) as sum_amount,
			max(p.payment_date) over(partition by p.customer_id)  as last_date_customer,
			concat(c3.first_name, ' ', c3.last_name) as full_name 
		from country c
		inner join city c2 using(country_id)
		inner join address a using(city_id)
		inner join customer c3 using(address_id)
		inner join payment p using(customer_id)
	), cte_2 as (
	select 
		country,
		payment_number,
		max(payment_number) over(partition by country) as max_payment_number,
		sum_amount,
		max(sum_amount) over(partition by country) as max_amount,
		last_date_customer,
		max(last_date_customer) over(partition by country) as last_date_country,
		full_name
	from cte
	)
	select distinct 
		c4.country as "Страна",
		pn.full_name as "Покупатель, арендовавший наибольшее количество фильмов",
		ma.full_name as "Покупатель, арендовавший фильмов на самую большую сумму",
		ld.full_name as "Покупатель, который последним арендовал фильм"
	from country c4
	inner join (
		select country, full_name
		from cte_2
		where payment_number = max_payment_number
	) pn using(country)
	inner join (
		select country, full_name
		from cte_2
		where sum_amount = max_amount
	) ma using(country)
	inner join (
		select country, full_name
		from cte_2
		where last_date_customer = last_date_country
	) ld using(country)
	order by country;


