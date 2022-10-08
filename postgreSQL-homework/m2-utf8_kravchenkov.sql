--=============== МОДУЛЬ 2. РАБОТА С БАЗАМИ ДАННЫХ =======================================
--= ПОМНИТЕ, ЧТО НЕОБХОДИМО УСТАНОВИТЬ ВЕРНОЕ СОЕДИНЕНИЕ И ВЫБРАТЬ СХЕМУ PUBLIC===========
SET search_path TO public;

--======== ОСНОВНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Выведите уникальные названия городов из таблицы городов.

	select distinct c.city 
	from city c 
	order by c.city asc;

--ЗАДАНИЕ №2
--Доработайте запрос из предыдущего задания, чтобы запрос выводил только те города,
--названия которых начинаются на “L” и заканчиваются на “a”, и названия не содержат пробелов.

	select distinct c.city 
	from city c
	where c.city like 'L%a' and c.city not like '% %'
	order by c.city asc;

--ЗАДАНИЕ №3
--Получите из таблицы платежей за прокат фильмов информацию по платежам, которые выполнялись 
--в промежуток с 17 июня 2005 года по 19 июня 2005 года включительно, 
--и стоимость которых превышает 1.00.
--Платежи нужно отсортировать по дате платежа.

	select
		p.payment_id,
		p.payment_date,
		p.amount 
	from payment p 
	where p.payment_date::date between '2005-06-17' and '2005-06-19'
		and amount > 1
	order by p.payment_date asc;

--ЗАДАНИЕ №4
-- Выведите информацию о 10-ти последних платежах за прокат фильмов.

	select
		p.payment_id,
		p.payment_date,
		p.amount 
	from payment p
	order by p.payment_date desc 
	limit 10;

--ЗАДАНИЕ №5
--Выведите следующую информацию по покупателям:
--  1. Фамилия и имя (в одной колонке через пробел)
--  2. Электронная почта
--  3. Длину значения поля email
--  4. Дату последнего обновления записи о покупателе (без времени)
--Каждой колонке задайте наименование на русском языке.

	select
		concat_ws(' ', c.first_name, c.last_name) as "Фамилия и имя",
		c.email as "Электронная почта",
		char_length(c.email) as "Длина Email",
		c.last_update::date as "Дата"
	from customer c;

--ЗАДАНИЕ №6
--Выведите одним запросом только активных покупателей, имена которых KELLY или WILLIE.
--Все буквы в фамилии и имени из верхнего регистра должны быть переведены в нижний регистр.

	select
		lower(c.last_name) as last_name,
		lower(c.first_name) as first_name,
		c.active
	from customer c
	where (c.first_name ilike 'kelly' or c.first_name ilike 'willie') 
		and c.active = 1;


--======== ДОПОЛНИТЕЛЬНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Выведите одним запросом информацию о фильмах, у которых рейтинг "R" 
--и стоимость аренды указана от 0.00 до 3.00 включительно, 
--а также фильмы c рейтингом "PG-13" и стоимостью аренды больше или равной 4.00.

	select
		f.film_id,
		f.title,
		f.description,
		f.rating,
		f.rental_rate
	from film f
	where (f.rating = 'R' and f.rental_rate >= 0 and f.rental_rate <= 3) 
		or (f.rating = 'PG-13' and f.rental_rate >= 4);

--ЗАДАНИЕ №2
--Получите информацию о трёх фильмах с самым длинным описанием фильма.

	select
		t.film_id,
		t.title,
		t.description
	from (
		select
			f.film_id,
			f.title,
			f.description,
			char_length(f.description) as description_length
		from film f
	) t
	order by t.description_length desc
	limit 3;

--ЗАДАНИЕ №3
-- Выведите Email каждого покупателя, разделив значение Email на 2 отдельных колонки:
--в первой колонке должно быть значение, указанное до @, 
--во второй колонке должно быть значение, указанное после @.

	select
		c.customer_id,
		c.email,
		left(c.email, strpos(c.email, '@') - 1) as "Email before @",
		right(c.email, strpos(c.email, '@') * -1) as "Email after @"
	from customer c;

--ЗАДАНИЕ №4
--Доработайте запрос из предыдущего задания, скорректируйте значения в новых колонках: 
--первая буква должна быть заглавной, остальные строчными.

	select
		c.customer_id,
		c.email,
		substring(
			left(c.email, strpos(c.email, '@') - 1) from 1 for 1) ||
			lower(
				substring(
					(left(c.email, strpos(c.email, '@') - 1)) from 2))
		as "Email before @",
		upper(
			substring(
				right(c.email, strpos(c.email, '@') * -1) from 1 for 1)) ||
				substring(
					right(c.email, strpos(c.email, '@') * -1) from 2)
		as "Email after @"
	from customer c;


