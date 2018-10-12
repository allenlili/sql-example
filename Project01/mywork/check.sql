-- COMP9311 15s2 Project 1 Check
--
-- MyMyUNSW Check

create or replace function
	proj1_table_exists(tname text) returns boolean
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
	proj1_view_exists(tname text) returns boolean
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
	proj1_function_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_proc
	where proname=tname;
	return (_check > 0);
end;
$$ language plpgsql;

-- proj1_check_result:
-- * determines appropriate message, based on count of
--   excess and missing tuples in user output vs expected output

create or replace function
	proj1_check_result(nexcess integer, nmissing integer) returns text
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

-- proj1_check:
-- * compares output of user view/function against expected output
-- * returns string (text message) containing analysis of results

create or replace function
	proj1_check(_type text, _name text, _res text, _query text) returns text
as $$
declare
	nexcess integer;
	nmissing integer;
	excessQ text;
	missingQ text;
begin
	if (_type = 'view' and not proj1_view_exists(_name)) then
		return 'No '||_name||' view; did it load correctly?';
	elsif (_type = 'function' and not proj1_function_exists(_name)) then
		return 'No '||_name||' function; did it load correctly?';
	elsif (not proj1_table_exists(_res)) then
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
		return proj1_check_result(nexcess,nmissing);
	end if;
	return '???';
end;
$$ language plpgsql;

-- proj1_rescheck:
-- * compares output of user function against expected result
-- * returns string (text message) containing analysis of results

create or replace function
	proj1_rescheck(_type text, _name text, _res text, _query text) returns text
as $$
declare
	_sql text;
	_chk boolean;
begin
	if (_type = 'function' and not proj1_function_exists(_name)) then
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
				'q1', 'q2', 'q3', 'q4', 'q5', 'q6'
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
-- Check functions for specific test-cases in Project 1
--

create or replace function check_q1() returns text
as $chk$
select proj1_check('view','q1','q1_expected',
                   $$select * from q1$$)
$chk$ language sql;

create or replace function check_q2() returns text
as $chk$
select proj1_check('view','q2','q2_expected',
                   $$select * from q2 order by semester, subject$$)
$chk$ language sql;

create or replace function check_q3() returns text
as $chk$
select proj1_check('view','q3','q3_expected',
                   $$select * from q3 order by ratio$$)
$chk$ language sql;

create or replace function check_q4() returns text
as $chk$
select proj1_check('view','q4','q4_expected',
                   $$select * from q4 order by orgunit$$)
$chk$ language sql;

create or replace function check_q5() returns text
as $chk$
select proj1_check('view','q5','q5_expected',
                   $$select * from q5 order by code$$)
$chk$ language sql;

create or replace function check_q6() returns text
as $chk$
select proj1_check('function','q6','q6_expected',
                   $$select * from q6(2007,'S2')$$)
$chk$ language sql;

--
-- Tables of expected results for test cases
--

drop table if exists q1_expected;
create table q1_expected (
    familyName LongName
);

drop table if exists q2_expected;
create table q2_expected (
	subject char(8),
	semester char(4)
);

drop table if exists q3_expected;
create table q3_expected (
	ratio numeric(4,1),
	nsubjects integer
);

drop table if exists q4_expected;
create table q4_expected (
    orgunit LongString
);


drop table if exists q5_expected;
create table q5_expected (
    code char(8), 
	title LongName
);

drop table if exists q6_expected;
create table q6_expected (
    code char(8),
    title MediumName,
    rating numeric(4,2)
);




COPY q1_expected (familyName) FROM stdin;
Kunnawuttipreechachan
Chonbodeechalermroong
\.


COPY q2_expected (subject,semester) FROM stdin;
MNGT5201	09S1
MNGT5211	09S1
MNGT5232	09S1
MNGT5272	09S1
MNGT5383	09S1
MNGT5585	09S1
MNGT5221	09S2
MNGT5241	09S2
MNGT5251	09S2
MNGT5282	09S2
MNGT5306	09S2
MNGT5310	09S2
MNGT5321	09S2
MNGT5325	09S2
MNGT5352	09S2
MNGT5357	09S2
MNGT5589	09S2
MNGT5591	09S2
MNGT5312	10X1
MNGT5322	10X1
MNGT5356	10X1
MNGT5374	10X1
MNGT5388	10X1
MNGT5395	10X1
MNGT5521	10X1
\.



COPY q3_expected (ratio,nsubjects) FROM stdin;
18.5	1
20.0	2
21.3	1
22.8	3
23.8	11
24.0	8866
24.1	113
48.0	9200
50.3	2
80.0	1
\.




COPY q4_expected (orgunit) FROM stdin;
Aboriginal Research and Resource Centre
Applied Science Program
Asia Pacific Health Res Centre
Australian Housing and Urban Research Institute
Australian Institute of Health Innovation
Australian New Zealand School of Government
Blcak Dog Institute
Board of Studies in Science and Mathematics
Boards
Building Construction Management Program
Building Research Centre
Built Environment Geography
Centre Energy & Env Market
Centre for Adv Numerical Computation in Eng & Sc
Centre for Cont Arts & Pol
Centre for Corporate Change
Centre for Management Accounting Development
Centre for Marine and Coastal Studies
Centre for Pensions and Super
Centre for Public Health
Centre for Public health & Eq
Centre for Sensory Research
Centre for Sustainable Built Environment
Cross Faculty Ownership
Defence & Security Apps Centre
Department of Chinese & Indonesian Studies
Department of Food Science and Technology
Department of French
Department of German & Russian Studies
Department of German and Russian Studies
Department of Japanese and Korean Studies
Department of Sociology and Social Anthropology
Department of Spanish and Latin American
Department of Textile Technology
Department of Wool and Animal Science
Div. Business and Humanities
Div. Eng Sci & Technology
Division of Registrar and Deputy Principal
Electrochemical and Minerals Processing
Faculties
Faculty of Life Sciences
Fridge
German Studies
Graduate Programs in Business and Technology
Graduate School of Engineering
Humanities Research Program
International Studies Unit
Korean Australasia Research Centre
Linguistics
Media Film & Theatre Studies
Modern Greek Studies
National Institute of Health
Natl Cannabis Prevention & Information Centre
Office of the Associate Dean (Education), Australian School of Business
Perinatal Reprod Epidemiology
Postgraduate Course Work
Postgraduate Research
Prep Program for Industry
Professional Development Centre
Professional Studies
Russian Studies
Sch Engineering & Information Technology
School of Applied Bioscience
School of Art Education
School of Biochemistry and Molecular Genetics
School of Biological Science
School of Chemical Sciences
School of Community Medicine
School of Geography
School of Geology
School of Health Services Management
School of History and Philosophy of Science
School of Industrial Relations and Org Behaviour
School of Information, Library and Archive Studies
School of International Business
School of Medical Education
School of Microbiology and Immunology
School of Music and Music Education
School of Obstetrics and Gynaecology
School of Paediatrics
School of Philosophy
School of Physiology and Pharmacology
School of Social Science and Policy
School of Social Work
School of Sociology and Anthropology
Science Administration
Student Administration Department
Student Information and Systems Office
Study Abroad Office
U/G Admissions Office
UC Engineering & Information Technology
UC Information Technology and Electrical Eng
UC School of Aerospace and Mechanical Engineering
UC School of Aerospace, Civil and Mechanical Eng
UC School of Chemistry
UC School of Civil Engineering
UC School of Computer Science
UC School of Economics and Management
UC School of Electrical Engineering
UC School of Geography and Oceanography
UC School of History
UC School of Humanities and Social Science
UC School of Language, Literature & Communication
UC School of Mathematics and Statistics
UC School of Physics
UC School of Politics
UNSW Asia
UNSW Key Centre for Mines
Unisearch
Violent Studies Unit
\.



COPY q5_expected (code, title) FROM stdin;
COMP2091	Computing 2
COMP3241	Real -Time Systems: Specification , Design & Imple
COMP4211	Advanced Architectures and Algorithms
COMP4314	Next Generation Database Systems
COMP9009	Advanced opics in Software Engineering
COMP9245	Real -Time Systems: Specification , Design & Imple
COMP9314	Next Generation Database Systems
COMP9416	Knowledge Based Systems
COMP9912	Project (24 Units of Credit)
\.



COPY q6_expected (code, title, rating) FROM stdin;
COMP9311	Database Systems	4.27
COMP3331	Computer Networks&Applications	4.27
\.




