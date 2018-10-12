-- COMP9311 15s2 Project 2
--
-- MyMyUNSW Solution Template

-- Q1: ...
create or replace view findQualifiedStaff as
select distinct staff as id
	from affiliation a1
	where exists(
		select staff 
		from affiliation a2
		where a2.starting > a1.ending and a1.staff = a2.staff
	)
;
create type EmploymentRecord as (unswid integer, name text, roles text);
create or replace function Q1() 
	returns setof EmploymentRecord 
as $$
DECLARE 
	record1 RECORD; record2 RECORD; er EmploymentRecord; mark boolean := FALSE; starting date := NULL; ending date := NULL;
BEGIN
	FOR record1 in (SELECT * FROM findQualifiedStaff) LOOP
		FOR record2 in
			SELECT
				people.unswid AS unswid, 
				people.given AS given, 
				people.family AS family,
				staffroles.description AS description, 
				affiliation.starting AS starting, 
				affiliation.ending AS ending
			FROM affiliation,staffroles,people
			WHERE affiliation.role = staffroles.id AND affiliation.staff = people.id AND people.id = record1.id
			ORDER BY people.sortname, affiliation.starting LOOP
			IF mark IS FALSE THEN
				er.unswid := record2.unswid;
				er.name := split_part(record2.given,' ',1)||' '||record2.family;
				er.roles := '';
				mark := TRUE;
			END IF;
			starting := record2.starting; ending := record2.ending;
			IF starting IS NOT NULL AND ending IS NOT NULL THEN
				er.roles := er.roles || record2.description || ' (' || starting || '..' || ending || ')'||E'\n';
			ELSIF starting IS NOT NULL AND ending IS NULL THEN
				er.roles := er.roles || record2.description || ' (' || starting || '..' || ')'||E'\n';
			ELSIF starting IS NULL AND ending IS NOT NULL THEN
				er.roles := er.roles || record2.description || ' (' || '..' || ending || ')'||E'\n';
			ELSE
				er.roles := er.roles;
			END IF;
		END LOOP;
		RETURN NEXT er;
		er.unswid := 0; er.name := ''; er.roles := ''; mark := FALSE; starting := NULL; ending := NULL;
	END LOOP;
END ; 
$$ language plpgsql;




-- Q2: ...
create type TrailingSpaceRecord as ("table" text, "column" text, nexamples integer);
create or replace function Q2("table" text) 
	returns setof TrailingSpaceRecord
as $$
declare
	attr Record; attribute_name text; attribute_type text; 
	tableid oid; query text; tuple text;
	number1 int := 0; number2 int := 0;
	ts TrailingSpaceRecord;
begin
	tableid := (select relfilenode from pg_class where relname = "table");
	for attr in (select attname,atttypid from pg_attribute where attrelid = tableid AND attnum > 0) loop
		attribute_name := attr.attname;
		attribute_type := (select typcategory from pg_type where oid = attr.atttypid); 
		if attribute_type = 'S' then
			ts.table := "table"; ts.column := attribute_name; ts.nexamples := 0; 
			query := 'select '||quote_ident(attribute_name)||' from '||quote_ident("table");
			for tuple in execute(query) loop
				tuple := ltrim(cast(tuple as text),' ');
				number1 = char_length(tuple);
				tuple := rtrim(cast(tuple as text),' ');
				number2 = char_length(tuple);
				if number1 != number2 then
					ts.nexamples := ts.nexamples + 1;
				end if;
			end loop;
			if ts.nexamples > 0 then
				return next ts;
			end if;
		end if;
	end loop;
end;	
$$ language plpgsql;



-- Q3: transcript with variations
create or replace function Q3(_sid integer) returns setof TranscriptRecord
as $$
declare
	rec TranscriptRecord;
	recv1 TranscriptRecord;
	recv2 TranscriptRecord;
	UOCtotal integer := 0;
	UOCpassed integer := 0;
	wsum integer := 0;
	wam integer := 0;
	x integer;
	tr Record;
	es Record; --externalsubjects
	sb Record; --subjects		
begin
	select s.id into x
	from   Students s join People p on (s.id = p.id)
	where  p.unswid = _sid;
	if (not found) then
		raise EXCEPTION 'Invalid student %',_sid;
	end if;
	for rec in
		select su.code, substr(t.year::text,3,2)||lower(t.sess),
			su.name, e.mark, e.grade, su.uoc
		from   CourseEnrolments e join Students s on (e.student = s.id)
			join People p on (s.id = p.id)
			join Courses c on (e.course = c.id)
			join Subjects su on (c.subject = su.id)
			join Terms t on (c.term = t.id)
		where  p.unswid = _sid
		order by t.starting,su.code
	loop
		if (rec.grade = 'SY') then
			UOCpassed := UOCpassed + rec.uoc;
		elsif (rec.mark is not null) then
			if (rec.grade in ('PT','PC','PS','CR','DN','HD')) then
				-- only counts towards creditted UOC
				-- if they passed the course
				UOCpassed := UOCpassed + rec.uoc;
			end if;
			-- we count fails towards the WAM calculation
			UOCtotal := UOCtotal + rec.uoc;
			-- weighted sum based on mark and uoc for course
			wsum := wsum + (rec.mark * rec.uoc);
		end if;
		return next rec;
	end loop;
------------------------------------------------------------------
	for tr in 
		select *
		from variations,subjects 
		where variations.subject = subjects.id and student = x 
		order by code loop
		-- recv1
		if tr.vtype = 'advstanding' then
			UOCpassed := UOCpassed + tr.uoc;
			recv1 := (tr.code, null, 'Advanced standing, based on ...', null, null, tr.uoc);
		elseif tr.vtype = 'substitution' then
			recv1 := (tr.code, null, 'Substitution, based on ...', null, null, null);
		else
			recv1 := (tr.code, null, 'Exemption, based on ...', null, null, null);
		end if;
		return next recv1;
		-- recv2
		if tr.intequiv is not null then
			select * into sb from subjects where id = tr.intequiv;
			recv2 := (null, null, 'studying '||cast(sb.code as text)||' at UNSW', null, null, null);
		else
			select * into es from externalsubjects where id = tr.extequiv;
			recv2 := (null, null, 'study at '||es.institution, null, null, null);
		end if;
		return next recv2;
	end loop;
-------------------------------------------------------------------
	if (UOCtotal = 0) then
		rec := (null,null,'No WAM available',null,null,null);
	else
		wam := wsum / UOCtotal;
		rec := (null,null,'Overall WAM',wam,null,UOCpassed);
	end if;
	-- append the last record containing the WAM
	return next rec;
	return;
end;
$$ language plpgsql;
