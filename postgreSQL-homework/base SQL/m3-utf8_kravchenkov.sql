--=============== МОДУЛЬ 3. ОСНОВЫ SQL =======================================
--= ПОМНИТЕ, ЧТО НЕОБХОДИМО УСТАНОВИТЬ ВЕРНОЕ СОЕДИНЕНИЕ И ВЫБРАТЬ СХЕМУ PUBLIC===========
SET search_path TO public;

--======== ОСНОВНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Выведите для каждого покупателя его адрес проживания, 
--город и страну проживания.

	select distinct 
		concat(c.last_name, ' ', c.first_name) as "Customer name",
		a.address,
		c2.city,
		c3.country 
	from customer c
	left join address a using(address_id)
	left join city c2 using(city_id)
	left join country c3 using(country_id)

--ЗАДАНИЕ №2
--С помощью SQL-запроса посчитайте для каждого магазина количество его покупателей.

	select
		c.store_id as "ID магазина",
		count(c.customer_id) as "Количество покупателей"
	from customer c
	group by c.store_id 

--Доработайте запрос и выведите только те магазины, 
--у которых количество покупателей больше 300-от.
--Для решения используйте фильтрацию по сгруппированным строкам 
--с использованием функции агрегации.

	select
		c.store_id as "ID магазина",
		count(c.customer_id) as "Количество покупателей"
	from customer c
	group by c.store_id 
	having count(c.customer_id) > 300

-- Доработайте запрос, добавив в него информацию о городе магазина, 
--а также фамилию и имя продавца, который работает в этом магазине.

	select 
		t."ID магазина",
		t."Количество покупателей",
		c2.city as "Город",
		concat(s2.last_name, ' ', s2.first_name) as "Имя сотрудника"
	from city c2
	inner join address a using(city_id)
	inner join store s using(address_id)
	inner join (
			select
				c.store_id as "ID магазина",
				count(c.customer_id) as "Количество покупателей"
			from customer c
			group by c.store_id 
			having count(c.customer_id) > 300
	) as t on t."ID магазина" = s.store_id
	inner join staff s2 on s2.staff_id = s.manager_staff_id 

--ЗАДАНИЕ №3
--Выведите ТОП-5 покупателей, 
--которые взяли в аренду за всё время наибольшее количество фильмов

	select 
		concat(c.last_name, ' ', c.first_name) as "Фамилия и имя покупателя",
		t."Количество фильмов"
	from customer c
	inner join (
		select 	
			count(r.rental_id) as "Количество фильмов",
			r.customer_id
		from rental r
		inner join customer c using(customer_id)
		group by r.customer_id 
		order by "Количество фильмов" desc 
	) as t on t.customer_id = c.customer_id 
	limit 5

--ЗАДАНИЕ №4
--Посчитайте для каждого покупателя 4 аналитических показателя:
--  1. количество фильмов, которые он взял в аренду
--  2. общую стоимость платежей за аренду всех фильмов (значение округлите до целого числа)
--  3. минимальное значение платежа за аренду фильма
--  4. максимальное значение платежа за аренду фильма

	select 
		concat(c.last_name, ' ', c.first_name) as "Фамилия и имя покупателя",
		t."Количество фильмов",
		tt."Общая стоимость платежей",
		tt."Минимальная стоимость платежа",
		tt."Максимальная стоимость платежа"
	from customer c
	inner join (
		select 	
			count(r.rental_id) as "Количество фильмов",
			r.customer_id
		from rental r
		inner join customer c using(customer_id)
		group by r.customer_id 
		order by "Количество фильмов" desc 
	) as t on t.customer_id = c.customer_id
	inner join (
		select
			round(sum(p.amount), 0) as "Общая стоимость платежей",
			max(p.amount) as "Максимальная стоимость платежа",
			min(p.amount) as "Минимальная стоимость платежа",
			p.customer_id
		from payment p 
		group by p.customer_id
	) as tt on tt.customer_id = c.customer_id

--ЗАДАНИЕ №5
--Используя данные из таблицы городов составьте одним запросом всевозможные пары городов таким образом,
 --чтобы в результате не было пар с одинаковыми названиями городов. 
 --Для решения необходимо использовать декартово произведение.
 
	select 
		c1.city as "Город 1",
		c2.city as "Город 2"
	from city c1
	cross join city c2
	where c1.city <> c2.city 

--ЗАДАНИЕ №6
--Используя данные из таблицы rental о дате выдачи фильма в аренду (поле rental_date)
--и дате возврата фильма (поле return_date), 
--вычислите для каждого покупателя среднее количество дней, за которые покупатель возвращает фильмы.
 
	select 
		r.customer_id as "ID покупателя",
		round(avg(r.return_date::date - r.rental_date::date), 2) as "Среднее количество дней на возврат"
	from rental r 
	group by r.customer_id 
	order by r.customer_id 

--======== ДОПОЛНИТЕЛЬНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Посчитайте для каждого фильма сколько раз его брали в аренду и значение общей стоимости аренды фильма за всё время.

	select 
		t."Название фильма",
		t."Рейтинг",
		c."name" as "Жанр",
		t."Год выпуска",
		l."name" as "Язык",
		t."Количество аренд",
		"Общая стоимость аренды"
	from (
		select
			f.film_id,
			f.language_id,
			f.title as "Название фильма",
			f.rating as "Рейтинг",
			f.release_year as "Год выпуска",
			count(p.payment_id) as "Количество аренд",
			sum(p.amount) as "Общая стоимость аренды"
		from film f 
		inner join inventory i using(film_id)
		inner join rental r using(inventory_id)
		inner join payment p using(rental_id)
		group by f.film_id 
	) as t
	inner join film_category fc using(film_id)
	inner join category c using(category_id)
	inner join "language" l using(language_id)
	order by "Название фильма" asc;

--ЗАДАНИЕ №2
--Доработайте запрос из предыдущего задания и выведите с помощью запроса фильмы, которые ни разу не брали в аренду.

	select 
		t."Название фильма",
		t."Рейтинг",
		c."name" as "Жанр",
		t."Год выпуска",
		l."name" as "Язык",
		t."Количество аренд",
		"Общая стоимость аренды"
	from (
		select
			f.film_id,
			f.language_id,
			f.title as "Название фильма",
			f.rating as "Рейтинг",
			f.release_year as "Год выпуска",
			count(p.payment_id) as "Количество аренд",
			sum(p.amount) as "Общая стоимость аренды"
		from film f 
		left join inventory i using(film_id)
		left join rental r using(inventory_id)
		left join payment p using(rental_id)
		group by f.film_id 
		having count(p.payment_id) = '0'
	) as t
	inner join film_category fc using(film_id)
	inner join category c using(category_id)
	inner join "language" l using(language_id)
	order by "Название фильма" asc;



--ЗАДАНИЕ №3
--Посчитайте количество продаж, выполненных каждым продавцом. Добавьте вычисляемую колонку "Премия".
--Если количество продаж превышает 7300, то значение в колонке будет "Да", иначе должно быть значение "Нет".

	select 
		p.staff_id,
		count(p.payment_id) as "Количество продж",
		case 
			when count(p.payment_id) > 7300 then 'Да'
			else 'Нет'
		end  as "Премия"
	from payment p 
	group by p.staff_id 





