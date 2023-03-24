
create table employee_salary_history (
	person_id int4 not null,
	pos_id int4 not null,
	salary numeric(12,2) not null,
	last_update timestamp default now(),
	primary key (person_id, pos_id),
	foreign key (person_id, pos_id) references employee(person_id, pos_id)
);

create trigger employee_salary 
after update of salary on employee
for each row execute function employee_salary_log();


create or replace function employee_salary_log () returns trigger as $$
declare	salary_old numeric(12,2) = old.salary;
begin
	insert into employee_salary_history (person_id, pos_id, salary)
	values (new.person_id, new.pos_id, salary_old);
	return new;
end;
$$ language plpgsql


