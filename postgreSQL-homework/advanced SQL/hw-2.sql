-- Задание 1. Напишите функцию, которая принимает на вход название должности (например, стажер),
-- а также даты периода поиска, и возвращает количество вакансий, опубликованных по этой должности в заданный период.

create or replace function count_vacancies (pos_title varchar(250), start_date date, end_date date) returns int4 as $$
declare vacancies int4;
begin
	if start_date is null and end_date is null
		then 
			start_date = (select min(v.create_date) from vacancy v);
			end_date = (select current_date);
	elseif start_date is null
		then start_date = (select min(v.create_date) from vacancy v);
	elseif end_date is null
		then end_date = (select current_date);
	elseif end_date < start_date
		then raise exception 'Дата окончания не может быть меньше даты начала';
	end if;
	select count(v.vac_title)
	from vacancy v
	where v.vac_title = pos_title and v.create_date between start_date and end_date and (v.closure_date <= end_date or v.closure_date is null)
	into vacancies;
	return vacancies;
end;
$$ language plpgsql

-- Задание 2. Напишите триггер, срабатывающий тогда, когда в таблицу position добавляется значение grade,
-- которого нет в таблице-справочнике grade_salary. Триггер должен возвращать предупреждение пользователю
-- о несуществующем значении grade.

create trigger check_grade 
before insert or update on "position"
for each row execute function grade_warning()

create or replace function grade_warning () returns trigger as $$
begin
	if new.grade is not null and new.grade not in (select g.grade from grade_salary g)
		then raise exception 'Указанный грейд не существует';
	end if;
	return new;
end;
$$ language plpgsql

-- Задание 3. Создайте таблицу employee_salary_history с полями:
--		- emp_id - id сотрудника
--		- salary_old - последнее значение salary (если не найдено, то 0)
--		- salary_new - новое значение salary
--		- difference - разница между новым и старым значением salary
--		- last_update - текущая дата и время
-- Напишите триггерную функцию, которая срабатывает при добавлении новой записи 
-- о сотруднике или при обновлении значения salary в таблице employee_salary, 
-- и заполняет таблицу employee_salary_history данными.

create table employee_salary_history (
	esh_id serial primary key,
	emp_id int4 not null,
	salary_old numeric(12,2) not null,
	salary_new numeric(12,2) not null,
	difference numeric(12,2) not null,
	last_update timestamp default now(),
	foreign key (emp_id) references employee(emp_id)
);

create trigger employee_salary 
after insert or update on employee_salary
for each row execute function employee_salary_log();

create or replace function employee_salary_log () returns trigger as $$
declare esh_emp_id int4 = new.emp_id;
	salary_old numeric(12,2) = 0;
	salary_new numeric(12,2) = new.salary;
	difference numeric(12,2) = new.salary;
	count_emp int = (select count(es.order_id) from employee_salary es where es.emp_id = esh_emp_id);
begin
	if tg_op = 'INSERT'
		then 
			if count_emp > 1
				then salary_old = (
						select es.salary
						from employee_salary es
						where es.emp_id = esh_emp_id
						order by es.effective_from desc
						offset 1
						limit 1);
					difference = salary_new - salary_old;
			end if;
	elseif tg_op = 'UPDATE'
		then
			salary_old = old.salary;
			difference = salary_new - salary_old;
	end if;
	insert into employee_salary_history (emp_id, salary_old, salary_new, difference)
	values (esh_emp_id, salary_old, salary_new, difference);
	return new;
end;
$$ language plpgsql
						
-- Задание 4. Напишите процедуру, которая содержит в себе транзакцию на вставку данных в таблицу employee_salary. 
-- Входными параметрами являются поля таблицы employee_salary.

create or replace procedure insert_employee_salary(
   order_id int4,
   emp_id int4, 
   salary numeric(12,2),
   effective_from date
) as $$
begin
	insert into employee_salary (order_id, emp_id, salary, effective_from)
	values (order_id, emp_id, salary, effective_from);
	
    commit;
end;
$$ language plpgsql