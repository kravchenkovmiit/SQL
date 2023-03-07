-- -- -- Работа с командной строкой
-- 1.1. Создайте новую базу данных с любым названием
createdb -h localhost -p 5432 -U postgres netology1

-- 1.2. Восстановите бэкап учебной базы данных в новую базу данных с помощью psql
psql -h localhost -p 5432 -U postgres -d netology1 < ./System_analist/SQL/postgreSQL-homework/advanced\ SQL/hr.sql 

-- 1.3. Выведите список всех таблиц восстановленной базы данных
-- см. скриншот "task-1.3.png"

-- 1.4. Выполните SQL-запрос на выборку всех полей из любой таблицы восстановленной базы данных
-- см. скриншот "task-1.4.png"


-- -- -- Работа с пользователями
-- 2.1. Создайте нового пользователя MyUser, которому разрешен вход, но не задан пароль и права доступа.
create role MyUser with login;

-- 2.2. Задайте пользователю MyUser любой пароль сроком действия до последнего дня текущего месяца.
alter role MyUser with password '123' valid until '31.03.2023';

-- 2.3. Дайте пользователю MyUser права на чтение данных из двух любых таблиц восстановленной базы данных.
grant usage on schema hr to MyUser;
-- права на чтение из таблиц city и address
grant select on hr.city, hr.address to MyUser;

-- 2.4. Заберите право на чтение данных ранее выданных таблиц
revoke usage on schema hr from MyUser;
revoke select on hr.city, hr.address from MyUser;

-- 2.5. Удалите пользователя MyUser.
drop role if exists MyUser;

-- -- -- Работа с транзакциями
-- 3.1. Начните транзакцию
begin;

-- 3.2. Добавьте в таблицу projects новую запись
	insert into hr.projects(project_id ,name, employees_id, amount, assigned_id, created_at)
		values ((select max(p.project_id) from hr.projects p) + 1,
		'СНТ-Заря', '{24, 51, 133, 312}', 4000543, 516, current_timestamp);

-- 3.3. Создайте точку сохранения
	SAVEPOINT my_savepoint;

-- 3.4. Удалите строку, добавленную в п.3.2
	delete from hr.projects where project_id = (select max(p.project_id) from hr.projects p);

-- 3.5. Откатитесь к точке сохранения
	rollback to savepoint my_savepoint;

-- 3.6. Завершите транзакцию
commit;

