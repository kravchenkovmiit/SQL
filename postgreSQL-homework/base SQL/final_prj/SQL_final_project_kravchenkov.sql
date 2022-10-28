-- 1. В каких городах больше одного аэропорта?
--
-- Условие: -
--
-- Описание логики:
-- Выполнена группировка по городам. 
-- В результатах группировки отсеяны строки, где подсчитанное количество значений столбца airport_code <= 1.

select 
	a.city as "Город",
	string_agg(a.airport_code, ', ') as "Список кодов аэропортов"
from airports a
group by a.city
having count(a.airport_code) > 1;

-- 2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?
--
-- Условие: Подзапрос
--
-- Описание логики:
-- К таблице airports присоединяется таблица с перелетами flights. 
-- Отфильтровываются записи по судну, выполняющему перевозку: 
-- в подзапросе определяется код(ы) судна, имеющего максимальную дальность полета.
-- Далее отфильтровываются уникальные аэропорты.


--explain analyze --7595 52ms
select distinct
	a.airport_code,
	a.airport_name 
from airports a 
join flights f on 
	f.departure_airport = a.airport_code or 
	f.arrival_airport = a.airport_code
where f.aircraft_code in (
	select
		a.aircraft_code 
	from aircrafts a 
	where a."range" = (
		select
			max(a."range")
		from aircrafts a))
order by a.airport_code;


-- 3. Вывести 10 рейсов с максимальным временем задержки вылета
--
-- Условие: Оператор LIMIT
--
-- Описание логики:
-- Из таблицы перелетов flights отфильтровываются записи о вылетевших
-- рейсах (имеют статус 'Arrived' или 'Departed'). 
-- Записи обогащаются данными расчитанного времени задержки (delay).
-- Записи сортируются по времени задержки по убыванию. Выводятся 10 значений с максимальным временем.

select 
	f.*,
	f.actual_departure - f.scheduled_departure as delay
from flights f 
where f.status = 'Arrived' or f.status = 'Departed'
order by delay desc
limit 10;

-- 4. Были ли брони, по которым не были получены посадочные талоны?
--
-- Условие: Верный тип JOIN
--
-- Описание логики:
-- К таблице с данными о билетах и номерах перелетов присоединяется (ticket_flights) присоединяется таблица
-- с информацией о бронировании (boarding_passes) при помощи левого джойна.
-- В результирующей таблице для билетов с отсутствующими посадочными талонами
-- данные представлены в значениях NULL. Выполняется фильтрация и подсчет по данному признаку.

select 
	count(tf.ticket_no) as "Количество броней, по которым не были получены посадочные талоны"
from ticket_flights tf 
left join boarding_passes bp on 
	bp.ticket_no = tf.ticket_no and bp.flight_id = tf.flight_id 
where bp.boarding_no is null


-- 5. Найдите количество свободных мест для каждого рейса, 
-- их % отношение к общему количеству мест в самолете. 
-- Добавьте столбец с накопительным итогом - суммарное накопление количества 
-- вывезенных пассажиров из каждого аэропорта на каждый день. 
-- Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек 
-- уже вылетело из данного аэропорта на этом или более ранних рейсах в течении дня.
--
-- Условие: Оконная функция; подзапросы или/и cte
--
-- Описание логики:
-- В CTE к таблице перелетов присоединяем таблицу с данными о посадочных талонах.
-- Выполняем подсчет занятых мест для каждого рейса.
-- К результирующей таблице CTE присоединяем результат подсчета 
-- общего количества мест для каждого судна из таблицы seats.
-- При помощи вычисленных данных о количестве занятых мест 
-- и общем количестве мест на судне вычисляем данные о свободных местах.
-- Для вылетевших рейсов (имеют статус 'Arrived' или 'Departed') вычисляем 
-- сумму вывезенных пассажиров с накопительным итогом по каждому, дню для каждого аэропорта.

--explain analyze --16550 691ms
with cte as (
	select
		f.flight_id,
		f.aircraft_code,
		f.departure_airport,
		f.actual_departure,
		f.status,
		count(bp.seat_no) as "occupied_seats"
	from flights f 
	join boarding_passes bp on bp.flight_id = f.flight_id 
	group by f.flight_id
)
select 
	cte.flight_id as "ID полета",
	cte.aircraft_code as "Код судна",
	cte.departure_airport as "Аэропорт вылета",
	cte.actual_departure::date as "Дата вылета",
	cte.status as "Статус",
	cte."occupied_seats" as "Количество занятых мест",
	tt."total_seats" as "Общее количество мест",
	tt."total_seats" - cte."occupied_seats"	as "Количество свободных мест",
	round(
		(tt."total_seats" - cte."occupied_seats")::numeric * 100 / tt."total_seats",
			2) as "% свободных мест",
	case when cte.status = 'Arrived' or cte.status = 'Departed' 
		then sum(cte."occupied_seats") 
			over(partition by cte.departure_airport, cte.actual_departure::date 
			order by cte.actual_departure)
		else 0
	end as "Накопительное количество вывезенных пассажиров из аэропорта за день"
from cte
join (
	select
		s.aircraft_code,
		count(s.seat_no) as "total_seats"
	from seats s
	group by s.aircraft_code
) tt on tt.aircraft_code = cte.aircraft_code;


-- 6. Найдите процентное соотношение перелетов по типам самолетов от общего количества.
-- 
-- Условие: Подзапрос или окно; оператор ROUND
--
-- Описание логики:
-- Для судов из таблицы перелетов flights рассчитан процент перелетов 
-- относительного количества всех перелетов, определенного в подзапросе.

select 
	f.aircraft_code, 
	round(count(f.flight_id)::numeric * 100 / 
			(select 
				count(f.flight_id) 
			from flights f), 2) as "% перелетов от общего количества"
from flights f  
group by f.aircraft_code;


-- 7. Были ли города, в которые можно добраться бизнес - классом дешевле, 
-- чем эконом-классом в рамках перелета?
-- 
-- Условие: CTE
--
-- Описание логики:
-- В CTE для значений из таблицы ticket_flights определены минимальные
-- и максимальные цены билетов для каждого перелета по классам 'Business' и 'Economy'.
-- Выполнено объединение таблиц CTE для вывода в строку минимальных и максимальных 
-- значений цен билетов как для класса 'Business', так и 'Economy'.
-- В окончательный вывод производится отбор первого значения отсортированного результата сравнения
-- минимальной цены для класса 'Business' с максимальной ценой для класса 'Economy' по каждому рейсу.

--explain analyze --72949 673ms
with cte as(
	select
		tf.flight_id,
		tf.fare_conditions,
		min(tf.amount),
		max(tf.amount)
	from ticket_flights tf
	group by 
		tf.flight_id,
		tf.fare_conditions
	having tf.fare_conditions = 'Business' or tf.fare_conditions = 'Economy'
)
select
	case when c.fare_conditions = 'Business' and c.min < c2.max 
	then 'Да'
	else 'Нет'
	end as "Были ли города, в которые можно добраться бизнес - классом дешевле?"
from cte c
join cte c2 on 
	c.flight_id = c2.flight_id and 
	c.fare_conditions <> c2.fare_conditions
where c.fare_conditions = 'Business'
order by "Были ли города, в которые можно добраться бизнес - классом дешевле?"
limit 1


-- 8. Между какими городами нет прямых рейсов?
--
-- Условие: Декартово произведение в предложении FROM; 
-- 			самостоятельно созданные представления (если облачное подключение, то без представления); 
-- 			оператор EXCEPT
--
-- Описание логики:
-- В созданном не материализованном представлении flights_city к таблице с перелетами flights
-- присоединена таблица airports для вывода списка пар городов, между которыми осуществляются перелеты.
-- В первом операторе select объединены таблицы со списком аэропортов airports для вывода полного списка
-- пар городов.
-- При помощи оператора except из результатов первого оператора select (полный список пар городов) удалены результаты вывода
-- материализованного представления (список пар городов, между которыми осуществляются перелеты).

create or replace view flights_city as
	select distinct 
		a.city as city_1,
		a2.city as city_2
	from flights f 
	join airports a on
		a.airport_code = f.departure_airport
	join airports a2 on
		a2.airport_code = f.arrival_airport;
select 
	a.city as city_1,
	a2.city as city_2
from airports a, airports a2
where a.city <> a2.city
except 
select *
from flights_city
order by city_1, city_2;


-- 9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, 
-- сравните с допустимой максимальной дальностью перелетов в самолетах, обслуживающих эти рейсы
--
-- Условие: Оператор RADIANS или использование sind/cosd; CASE
--
-- Описание логики:
-- В подзапросе объединены таблицы перелетов и аэропортов для вычисления расстояния 
-- между аэропортами в рамках перелета.
-- К результатам подзапроса присоединена таблица с информацией о судах.
-- В финальном выводе выполнено сравнение расстояний между аэропортами с дальностью полета судна
-- для вычисления запаса хода в рамках перелета.


select 
	t.flight_id as "ID рейса",
	t.departure_airport as "Аэропорт вылета",
	t.arrival_airport as "Аэропорт прилета",
	t.distance as "Расстояние",
	t.aircraft_code as "Код судна",
	a3."range" as "Максимальная дальность полета",
	case when a3."range" > t.distance then a3."range" - t.distance
		else 0
	end as "Запас хода"
from (
	select 
		f.flight_id,
		f.departure_airport,
		f.arrival_airport,
		f.aircraft_code,
		round(6371 * (acos(
			sin(radians(a.latitude)) * sin(radians(a2.latitude)) +
			cos(radians(a.latitude)) * cos(radians(a2.latitude)) *
			cos(radians(a.longitude) - radians(a2.longitude)) 
			))::numeric, 2) as distance
	from flights f 
	join airports a on
		a.airport_code = f.departure_airport
	join airports a2 on
		a2.airport_code = f.arrival_airport) t
join aircrafts a3 on
	a3.aircraft_code  = t.aircraft_code
order by "Запас хода";
