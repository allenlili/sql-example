-- COMP9311 15s2 Project 1
--
-- MyMyUNSW Solution Template

-- Q1: ...
create or replace view familyname
as
	select people.family
	from people 
	where people.family not like '% %' and family not like '%-%'
	group by people.family
	having count(people.family) = 1
	order by people.family desc
;

create or replace view maxlength
as
	select max(length(family)) from familyname
;

create or replace view Q1(familyName)
as
	select family 
	from familyname
	where length(familyname.family) = (select * from maxlength)
;


-- Q2: ...
create or replace view subjectsemester
as
	select subjects.code,substring(cast(semesters.year as varchar),3)||semesters.term 
	from courses,subjects,semesters
	where 
	subjects.id = courses.subject and 
	semesters.id = courses.semester and 
	courses.id in 
	(
		select course
		from course_enrolments
		where 
		grade = 'A' OR grade = 'B' OR grade = 'C'
		group by course
	)
	order by subjects.code
;

create or replace view Q2(subject,semester)
as
	select * from subjectsemester
;


-- Q3: ...
create or replace view calratio
as
	select cast(uoc/eftsload as numeric(4,1)) as ratio, count(id) as nsubjects
	from subjects
	where eftsload != null or eftsload !=0
	group by cast(uoc/eftsload as NUMERIC(4,1))
	order by ratio
;

create or replace view Q3(ratio,nsubjects)
as
	select ratio,nsubjects from calratio order by ratio
;


-- Q4: ...
create or replace view Q4(orgunit)
as
	select distinct orgunits.longname
	from orgunits
	where id
	not in(
		select orgunits.id
		from orgunit_groups,orgunits
		where 
		orgunit_groups.member = orgunits.id
	)
	order by orgunits.longname
;


-- Q5: ...
create or replace view findyear 
as
	select subjects.code as code, subjects.longname as title, semesters.year as year
	from courses, subjects,semesters
	where courses.subject = subjects.id and 
			courses.semester = semesters.id and 
			subjects.code ilike 'COMP%' and year between 2008 and 2010
;

create or replace view Q5(code, title)
as
	select distinct code,title
	from findyear as f1
	where year = 2008 and
	not exists(
		select code,title,year from findyear where year = 2009 and code = f1.code
	)
	and
	not exists(
		select code,title,year from findyear where year = 2010 and code = f1.code
	)
;


-- Q6: ...
create or replace view findbyyearterm(code,title,stueval,year,term)
as 
select subjects.code,subjects.name,course_enrolments.stueval,semesters.year,semesters.term
from courses,course_enrolments,subjects,semesters
where courses.subject = subjects.id and 
	  course_enrolments.course = courses.id and 
	  courses.semester = semesters.id
order by subjects.code
;

create type EvalRecord as (code text, title text, rating numeric(4,2));

create or replace function findEvalOfSubjects(integer,text) returns setof EvalRecord
as $$
declare
	r record; curcode varchar := ''; er EvalRecord;
	counter integer := 0;  stuNumberEval float := 0; sumStuEval float := 0;
	tempCode varchar := ''; tempTitle varchar := ''; tempMax float := 0;
	maxStuEval float := 0;
begin
	for r in (select * from findbyyearterm where year = $1 and term = $2)
	loop
			if (r.code <> curcode) then
				if (curcode <> '') then
					if (counter > 10 and 3*stuNumberEval >= counter) then
						tempMax = cast(sumStuEval/stuNumberEval as numeric(4,2));
						if (tempMax >= maxStuEval) then
							maxStuEval = tempMax; er.code = tempCode; er.title = tempTitle; er.rating = tempMax;
							return next er;
						end if;
					end if;
				end if;
				curcode := r.code; counter := 0; stuNumberEval := 0; sumStuEval := 0;
			end if;
			if (r.stueval is not null) then
				sumStuEval := sumStuEval + r.stueval; stuNumberEval := stuNumberEval + 1;
			end if;
			counter := counter + 1; tempCode = r.code; tempTitle = r.title;
	end loop;
end;
$$ language plpgsql;

create or replace function Q6(integer,text) 
	returns setof EvalRecord 
as $$
declare 
	r record;
	el EvalRecord;
begin
	for r in (select * from findEvalOfSubjects($1,$2) where rating = (select max(rating) from findEvalOfSubjects($1,$2)))
	loop
			el = r;
			return next el;
	end loop;
end;
$$ language plpgsql
;


