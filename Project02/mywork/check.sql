--
-- check.sql ... checking functions
--
--

--
-- Helper functions
--

create or replace function
	proj2_table_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_class
	where relname=tname and relkind='r';
	return (_check = 1);
end;
$$ language plpgsql;

create or replace function
	proj2_view_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_class
	where relname=tname and relkind='v';
	return (_check = 1);
end;
$$ language plpgsql;

create or replace function
	proj2_function_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_proc
	where proname=tname;
	return (_check > 0);
end;
$$ language plpgsql;

-- proj2_check_result:
-- * determines appropriate message, based on count of
--   excess and missing tuples in user output vs expected output

create or replace function
	proj2_check_result(nexcess integer, nmissing integer) returns text
as $$
begin
	if (nexcess = 0 and nmissing = 0) then
		return 'correct';
	elsif (nexcess > 0 and nmissing = 0) then
		return 'too many result tuples';
	elsif (nexcess = 0 and nmissing > 0) then
		return 'missing result tuples';
	elsif (nexcess > 0 and nmissing > 0) then
		return 'incorrect result tuples';
	end if;
end;
$$ language plpgsql;

-- proj2_check:
-- * compares output of user view/function against expected output
-- * returns string (text message) containing analysis of results

create or replace function
	proj2_check(_type text, _name text, _res text, _query text) returns text
as $$
declare
	nexcess integer;
	nmissing integer;
	excessQ text;
	missingQ text;
begin
	if (_type = 'view' and not proj2_view_exists(_name)) then
		return 'No '||_name||' view; did it load correctly?';
	elsif (_type = 'function' and not proj2_function_exists(_name)) then
		return 'No '||_name||' function; did it load correctly?';
	elsif (not proj2_table_exists(_res)) then
		return _res||': No expected results!';
	else
		excessQ := 'select count(*) '||
			   'from (('||_query||') except '||
			   '(select * from '||_res||')) as X';
		-- raise notice 'Q: %',excessQ;
		execute excessQ into nexcess;
		missingQ := 'select count(*) '||
			    'from ((select * from '||_res||') '||
			    'except ('||_query||')) as X';
		-- raise notice 'Q: %',missingQ;
		execute missingQ into nmissing;
		return proj2_check_result(nexcess,nmissing);
	end if;
	return '???';
end;
$$ language plpgsql;

-- proj2_rescheck:
-- * compares output of user function against expected result
-- * returns string (text message) containing analysis of results

create or replace function
	proj2_rescheck(_type text, _name text, _res text, _query text) returns text
as $$
declare
	_sql text;
	_chk boolean;
begin
	if (_type = 'function' and not proj2_function_exists(_name)) then
		return 'No '||_name||' function; did it load correctly?';
	elsif (_res is null) then
		_sql := 'select ('||_query||') is null';
		-- raise notice 'SQL: %',_sql;
		execute _sql into _chk;
		-- raise notice 'CHK: %',_chk;
	else
		_sql := 'select ('||_query||') = '||quote_literal(_res);
		-- raise notice 'SQL: %',_sql;
		execute _sql into _chk;
		-- raise notice 'CHK: %',_chk;
	end if;
	if (_chk) then
		return 'correct';
	else
		return 'incorrect result';
	end if;
end;
$$ language plpgsql;

-- check_all:
-- * run all of the checks and return a table of results

drop type if exists TestingResult cascade;
create type TestingResult as (test text, result text);

create or replace function
	check_all() returns setof TestingResult
as $$
declare
	i int;
	testQ text;
	result text;
	out TestingResult;
	tests text[] := array[
				'q1', 'q2',  
				'q3a', 'q3b'
				];
begin
	for i in array_lower(tests,1) .. array_upper(tests,1)
	loop
		testQ := 'select check_'||tests[i]||'()';
		execute testQ into result;
		out := (tests[i],result);
		return next out;
	end loop;
	return;
end;
$$ language plpgsql;


--
-- Check functions for specific test-cases in Project 2
--



create or replace function check_q1() returns text
as $chk$
select proj2_check('function','q1','q1_expected',
                   $$select * from q1()$$)
$chk$ language sql;

create or replace function check_q2() returns text
as $chk$
select proj2_check('function','q2','q2_expected',
                   $$select * from q2('rooms')$$)
$chk$ language sql;

create or replace function check_q3a() returns text
as $chk$
select proj2_check('function','q3','q3a_expected',
                   $$select * from q3(3169329)$$)
$chk$ language sql;

create or replace function check_q3b() returns text
as $chk$
select proj2_check('function','q3','q3b_expected',
                   $$select * from q3(3270322)$$)
$chk$ language sql;



--
-- Tables of expected results for test cases
--



drop table if exists q1_expected;
create table q1_expected (
    	unswid integer, 
	name text, 
	roles text
);


drop table if exists q2_expected;
create table q2_expected (
    	"table" text, 
	"column" text, 
	nexamples integer
);


drop table if exists q3a_expected;
create table q3a_expected (
    code character(8),
    term character(4),
    name text,
    mark integer,
    grade character(2),
    uoc integer
);

drop table if exists q3b_expected;
create table q3b_expected (
    code character(8),
    term character(4),
    name text,
    mark integer,
    grade character(2),
    uoc integer
);



COPY q1_expected (unswid, name, roles) FROM stdin;
8750155	Paul Compton	Professor (1990-02-26..2010-06-30)\nHead of School (1996-01-01..1999-06-30)\nHead of School (2004-01-01..2010-06-30)\n
2114572	Hye-Young Paik	Lecturer (2000-01-06..2003-12-20)\nLecturer (2005-07-01..2010-09-30)\nSenior Lecturer (2010-10-01..)\n
\.

COPY q2_expected ("table", "column", nexamples) FROM stdin;
rooms	longname	1
\.


COPY q3a_expected (code, term, name, mark, grade, uoc) FROM stdin;
COMP1711	05s1	Higher Computing 1A	76	DN	6
MATH1081	05s1	Discrete Mathematics	57	PS	6
MATH1131	05s1	Mathematics 1A	59	PS	6
PHYS1121	05s1	Physics 1A	56	PS	6
COMP1721	05s2	Higher Computing 1B	76	DN	6
ELEC1011	05s2	Electrical Engineering 1	62	PS	6
MATH1231	05s2	Mathematics 1B	61	PS	6
PHYS1601	05s2	Comp. Applic'ns in Exp. Sci. 1	94	HD	6
GENL0230	06x1	Law in the Information Age	78	DN	3
COMP2121	06s1	Microprocessors & Interfacing	50	PS	6
COMP2711	06s1	Higher Data Organisation	63	PS	6
COMP2920	06s1	Professional Issues and Ethics	73	CR	3
MATH2301	06s1	Mathematical Computing	48	PC	6
COMP2041	06s2	Software Construction	82	DN	6
COMP3421	06s2	Computer Graphics	68	CR	6
GENS4015	06s2	Brave New World	63	PS	3
INFS1602	06s2	Info Systems in Business	62	PS	6
PHYS2630	06s2	Electronics	63	PS	3
COMP3111	07s1	Software Engineering	67	CR	6
COMP3331	07s1	Computer Networks&Applications	66	CR	6
COMP3411	07s1	Artificial Intelligence	60	PS	6
GENL2020	07s1	Intro to Australian Legal Sys	69	CR	3
COMP3121	07s2	Algorithms & Programming Tech	54	PS	6
COMP3222	07s2	Digital Circuits and Systems	65	CR	6
MATH3411	07s2	Information, Codes and Ciphers	50	PS	6
GENS4001	08x1	Astronomy	84	DN	3
COMP3311	\N	Advanced standing, based on ...	\N	\N	6
\N	\N	study at The University of Sydney	\N	\N	\N
\N	\N	Overall WAM	64	\N	144
\.

COPY q3b_expected (code, term, name, mark, grade, uoc) FROM stdin;
COMP1911	07s1	Computing 1A	79	DN	6
ENGG1000	07s1	Engineering Design	63	PS	6
INFS1603	07s1	Business Databases	81	DN	6
MATH1131	07s1	Mathematics 1A	63	PS	6
COMP1921	07s2	Computing 1B	63	PS	6
INFS1602	07s2	Info Systems in Business	59	PS	6
MATH1081	07s2	Discrete Mathematics	59	PS	6
MATH1231	07s2	Mathematics 1B	73	CR	6
GENM0703	08x1	Concept of Phys Fitness&Health	63	PS	3
GENS8004	08x1	Ergonomics, Product & Safety	77	DN	3
ACCT1501	08s1	Accounting & Financial Mgt 1A	61	PS	6
COMP2911	08s1	Eng. Design in Computing	67	CR	6
COMP2920	08s1	Professional Issues and Ethics	83	DN	3
COMP2041	08s2	Software Construction	76	DN	6
COMP2121	08s2	Microprocessors & Interfacing	63	PS	6
COMP9315	08s2	Database Systems Implementat'n	52	PS	6
ARTS1450	09s1	Introductory Chinese A	68	CR	6
COMP3141	09s1	Software Sys Des&Implementat'n	73	CR	6
COMP9318	09s1	Data Warehousing & Data Mining	63	PS	6
COMP9321	09s1	Web Applications Engineering	75	DN	6
COMP3421	09s2	Computer Graphics	67	CR	6
COMP3711	09s2	Software Project Management	75	DN	6
COMP9322	09s2	Service-Oriented Architectures	71	CR	6
COMP9323	09s2	e-Enterprise Project	85	HD	6
GENC7003	09s2	Managing Your Business	73	CR	3
COMP3311	\N	Exemption, based on ...	\N	\N	\N
\N	\N	study at The University of Sydney	\N	\N	\N
\N	\N	Overall WAM	68	\N	138
\.


