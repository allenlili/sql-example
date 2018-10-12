-- COMP9311 15s2 Project 2 Schema
--

-- ShortStrings are typically used for values appearing in tables in the UI
create domain ShortString as varchar(16);
create domain MediumString as varchar(64);
create domain LongString as varchar(256);
create domain TextString as varchar(4096);

-- ShortNames are typically used for values appearing in tables in the UI
create domain ShortName as varchar(16);
create domain MediumName as varchar(32);
create domain LongName as varchar(64);

-- If we could rely on having regexps, we could do a better job with these
create domain PhoneNumber as varchar(32);
create domain EmailString as varchar(64) check (value like '%@%');
create domain URLString as varchar(128) check (value like 'http://%');

create domain CareerType as char(2)
	check (value in ('UG','PG','RS'));

create domain GradeType as char(2)
	check (value in
		('AF', 'AS', 'CR', 'DF', 'DN', 'EC', 'FL', 'FN',
		 'GP', 'HD', 'LE', 'NA', 'NC', 'NF', 'PC', 'PE',
		 'PS', 'PT', 'RC', 'RD', 'RS', 'SS', 'SY', 'UF',
		 'WA', 'WC', 'WD', 'WJ', 'XE', 'A', 'B', 'C', 'D', 'E')
	);

create domain CourseYearType as integer
	check (value > 1945);  -- UNSW didn't exist before 1945


-- Countries: country codes and names

create table Countries (
	id          integer, -- PG: serial
	code        char(3) not null,
	name        LongName not null,
	primary key (id)
);

-- Buildings: building information
-- e.g. (1234, 'MB', 'Morven Brown Buildings', 'C20')
--      (5678, 'K17', 'CSE Buildings', 'K17')
--      (4321, 'EE', 'Electrical Engineering Buildings', 'G17)

create table Buildings (
	id          integer, -- PG: serial
	name        ShortName not null,
	longname    LongName not null,
	gridref     char(3),
	primary key (id)
);


-- RoomTypes: different kinds of rooms on campus
-- e.g. 'Lecture Theatre', 'Tutorial Room', 'Office', ...

create table RoomTypes (
	id          integer, -- PG: serial
	description MediumString not null,
	primary key (id)
);


-- Rooms: room information

create table Rooms (
	id          integer, -- PG: serial
	rtype       integer references RoomTypes(id),
	name        ShortName not null,
	longname    LongName,
	roomNum     ShortString,
	capacity    integer check (capacity >= 0),
	building    integer not null references Buildings(id),
	primary key (id)
);


-- Facilities: things in rooms (e.g. data projector, OHP, etc.)

create table Facilities (
	id          integer, -- PG: serial
	description MediumString not null,
	primary key (id)
);


-- RoomFacilities: which facilities are available in which rooms

create table RoomFacilities (
	room        integer references Rooms(id),
	facility    integer references Facilities(id),
	primary key (room,facility)
);


-- OrgUnitTypes: kinds of organisational units at UNSW
-- notes:
--   examples: 'Faculty', 'School', 'Division',...
--   used so that people can invent other new units in the future

create table OrgUnitTypes (
	id          integer, -- PG: serial
	name        ShortName not null,
	primary key (id)
);


-- OrgUnits: organisational units (e.g. schools, faculties, ...)
-- notes:
--   "utype" classifies the organisational unit
--

create table OrgUnits (
	id          integer, -- PG: serial
	utype       integer not null references OrgUnitTypes(id),
	name        ShortName not null,
	longname    LongName,
	unswid      ShortString,
	office      integer references Rooms(id),
	phone       PhoneNumber,
	email       EmailString,
	website     URLString,
	primary key (id)
);


-- UnitGroups: how organisational units are related
-- allows for a multi-level hierarchy of groups

create table UnitGroups (
	owner	    integer references OrgUnits(id),
	member      integer references OrgUnits(id),
	primary key (owner,member)
);


-- Teaching Periods (aka terms, sessions)
-- notes:
--   the "ord" attribute specifies the order of sessions within a year
--     (needed because lexical ordering on "sess" attribute doesn't work)
--   "endEnrol" gives the date of the HECS census (last day to enrol)
--   "endWD" gives the last date to withdraw (without failure)
--
-- And, of course, a better way to do this would be to plug in the Events
-- table (and its friends) from Assignment 1 and implement each Term as a
-- WholeDay/Timespan event with startDate,endDate dates. The mid-semester
-- break would be implemented similarly, and the endEnrol and endWD dates
-- could be done as Deadline/OneOff events

create table Terms (
	id          integer, -- PG: serial
	year        CourseYearType,
	sess        char(2) not null check (sess in ('S1','S2','X1','X2')),
	starting    date not null,
	ending      date not null,
	startBrk    date,
	endBrk      date,
	endEnrol    date,
	endWD       date,
	primary key (id)
);


-- PublicHolidays: days when regular teaching is cancelled
-- These could be done as WholeDay/OneOff Events, but they would also
--   need to generate exceptions for all of the Class Events scheduled
--   on those days
-- Notice that there's no primary key; there could be several holidays
--   (e.g. different religions) on the same date

create table PublicHolidays (
	term        integer references Terms(id),
	description MediumString, -- e.g. Good Friday, Easter Day
	day         date
);


-- StaffRoles: roles for staff within the UNSW organisation
-- handles job classes under which staff are employed
-- e.g. "Associate Lecturer", "Professor", "Administrative Assistant",
--      "Computer Systems Officer", "Clerk", "Caterer"
-- and also handles specific roles for some staff members
-- e.g. "Vice Chancellor", "Dean", "Head of School",
--      "Teaching Director", "Admin Assistant to Dean",
--      "School Office Manager", ...
-- this could either describe the specific duties under the
--   job classification, or duties that are additional to the
--   basic job classification
-- notes:
--   in the real NSS, hooks to the HR system would be here
--   for example, we might have base salary for each role
--   which represent a job classification

create domain RoleType as ShortName
	check (value in ('academic','admin','technical','general'));

create table StaffRoles (
	id          integer, -- PG: serial
	rtype       RoleType,
	description MediumString not null,
	primary key (id)
);


-- People super-class
-- contains:
--   unique id internal to database
--   personal information
--   home contact info
-- notes:
--   family,given names are displayed on transcripts
--   sortname is to handle unusual names (e.g. de Kleer as K)
--   name is what will be displayed (except on transcripts)
--        it allows preferred form of name(s) to be used
--   phone numbers are assumed to be Australian numbers
--   the phone field sizes allow for future expansion of phone #s
--   familyname is allowed to be null for people with only one name
--   the "not null" fields indicate which info is compulsory
--   nowadays, people are required to have an email address
--   the password field is used by the web interface
--   allows people in the database who are not staff or students
--     e.g. members of the University Council

create table People (
	id          integer, -- PG: serial
	password    ShortString not null,
	unswid      integer, -- staff/student id (can be null)
	family      LongName,
	given       LongName not null,
	title       ShortName, -- e.g. "Prof", "A/Prof", "Dr", ...
	sortname    LongName not null,
	name        LongName not null,
	street      MediumString,
	city        MediumString,
	state       ShortString,
	postcode    ShortString,
	country     integer references Countries(id),
	homephone   PhoneNumber, -- should be not null
	mobphone    PhoneNumber,
	email       EmailString not null,
	homepage    URLString,
	gender      char(1) check (gender in ('m','f')),
	birthday    date,
	origin      integer references Countries(id),  -- country where born
	primary key (id)
);


-- Student (sub-class): enrolment type

create table Students (
	id          integer references People(id),
	stype       varchar(5) check (stype in ('local','intl')),
	primary key (id)
);

-- StudentGroups: groups of students (used in specifying quotas)
-- uses SQL queries stored in the database to extract lists of
--   students belonging to particular classes
-- decided to use this approach rather than explicitly storing
--   lists of (student,group) pairs because these lists would
--   be very large and hard to setup and maintain
-- of course, with this approach, getting a list of students
--   in a given group requires something beyond SQL (e.g. PLpgSQL)

create table StudentGroups (
	id          integer, -- PG: serial
	name        LongName unique not null,
	definition  LongString not null, -- SQL query to get student(id)'s
--	creator     integer references People(id) not null,
--	created     date not null,
	primary key (id)
);


-- Staff (sub-class): employment and on-campus contact info
-- all staff have a unique staff id different to their person id
-- anyone who teaches a class has to be entered in this table
--   (they would normally be entered into the UNSW HR database)

create table Staff (
	id          integer references People(id),
	office      integer references Rooms(id),
	phone       PhoneNumber, -- full number, not just extension
	employed    date not null,
	supervisor  integer references Staff(id),
	primary key (id)
);


-- Affiliation: staff roles and association to organisational units
-- notes:
--   most staff will be attached to only one unit
--   "role" will describe things like "Professor", "Head of School", ...
--   if this is their job class for HR, isPrimary is true

create table Affiliation (
	staff       integer references Staff(id),
	orgUnit     integer references OrgUnits(id),
	role        integer references StaffRoles(id),
	isPrimary   boolean, -- is this role the basis for their employment?
	starting    date not null, -- when they commenced this role
	ending      date,  -- when they finshed; null means current
	primary key (staff,orgUnit,role,starting)
);


-- Programs: academic details of a degree program
-- notes:
--   the "code" field is used for compatability with current UNSW practice
--     e.g. 3978 is the code for the computer science degree

create table Programs (
	id          integer, -- PG: serial
	code        char(4) not null, -- e.g. 3978, 3645, 3648
	name        LongName,
	uoc         integer check (uoc >= 0),
	offeredBy   integer references OrgUnits(id),
	firstOffer  integer references Terms(id), -- should be not null
	lastOffer   integer references Terms(id), -- null means current
	career      CareerType,
	duration    integer,  -- #months
	tminuoc     integer,  -- min UOC per semester
	tmaxuoc     integer,  -- max UOC per semester
	tavguoc     integer,  -- average UOC per semester
	description TextString, -- PG: text
	objectives  TextString, -- PG: text
	othernotes  TextString, -- PG: text
--	creator     integer not null references Staff(id),
--	created     date not null,
	primary key (id)
);


-- Streams: academic details of a major/minor stream(s) in a degree

create table Streams (
	id          integer, -- PG: serial
	code        char(10) not null, -- e.g. COMPA13978, COMPH13978
	name        LongName,
	offeredBy   integer references OrgUnits(id),
	stype       ShortString,
	outline     TextString,
	firstOffer  integer references Terms(id), -- should be not null
	lastOffer   integer references Terms(id), -- null means current
	primary key (id)
);


-- ProgramStream: which program(s) each stream is used for

create table ProgramStream (
	program     integer references Programs(id),
	stream      integer references Streams(id),
	primary key (program,stream)
);


-- Degrees: titles of degrees (awards)

create table Degrees (
	id          integer, -- PG: serial
	name        MediumName, -- e.g. BSc, BSc(CompSci), BE, PhD
	fullname    LongName,  -- e.g. Bachelor of Science
	primary key (id)
);


-- ProgramDegree: degrees awarded for each program
--   a concurrent degree will have two entries for one program

create table ProgramDegree (
	program     integer references Programs(id),
	degree      integer references Degrees(id),
	primary key (program,degree)
);


-- DegreesAwarded: info about student being awarded a degree

create table DegreesAwarded (
	student     integer references Students(id),
	program     integer references Programs(id),
	graduated   date,	
	primary key (student,program)
);


-- AcademicStanding: kinds of academic standing at UNSW
-- e.g. 'good', 'probation1', 'probation2',...
-- An enumerated-type table

create table AcademicStanding (
	id          integer,
	standing    ShortName not null,
	notes       TextString,
	primary key (id)
);


-- Subjects: academic details of a course (version)
-- "code" is standard UNSW course code (e.g. COMP3311)
-- "firstOffer" and "lastOffer" indicate a timespan during
--   which this subject was offered to students; if "lastOffer"
--   is null, then the subject is still running
-- Note: UNSW calls subjects "courses"

create table Subjects (
	id          integer, -- PG: serial
	code        char(8) not null,
--	              PG: check (code ~ '[A-Z]{4}[0-9]{4}'),
	name        MediumName not null,
	longname    LongName,
	uoc         integer check (uoc >= 0),
	offeredBy   integer references OrgUnits(id),
	firstOffer  integer references Terms(id), -- should be not null
	lastOffer   integer references Terms(id), -- null means current
	eftsload    float,
	career      CareerType,
	syllabus    TextString, -- PG: text
	contactHPW  float, -- contact hours per week
	excluded    integer, -- references AcadObjectGroups(id),
	equivalent  integer, -- references AcadObjectGroups(id),
--	creator     integer not null references Staff(id),
--	created     date not null,
	primary key (id)
);


-- ProgramEnrolments: student's enrolment in a program in one semester
-- notes:
--   "standing" refers to the students academic standing
--   "wam" is computed from marks in enrolment records

create table ProgramEnrolments (
	id          integer,
	student     integer references Students(id),
	term        integer references Terms(id),
	program     integer references Programs(id),
	wam         real,
	standing    integer references AcademicStanding(id),
	advisor     integer references Staff(id),
	interview   date,
	notes       TextString,
	primary key (id)
);


-- StreamEnrolments: student's enrolment in streams in one semester

create table StreamEnrolments (
	partOf      integer references ProgramEnrolments(id),
	stream      integer references Streams(id),
	primary key (partOf,stream)
);


-- Course: info about an offering of a subject in a given semester
-- we insist on knowing the lecturer because there's no point running
--   a course unless you've got someone organised to lecture it
-- Note: UNSW calls courses "course offerings"

create table Courses (
	id          integer, -- PG: serial
	subject     integer not null references Subjects(id),
	term        integer not null references Terms(id),
	homepage    URLString,
	primary key (id)
);


-- CourseRoles: roles for staff involved in a course
-- e.g. "LIC", "Course Admin", "Tutor", ...

create table CourseRoles (
	id          integer, -- PG: serial
	name        ShortName,
	description MediumString,
	primary key (id)
);


-- CourseStaff: various staff involved in a course
-- allows one Staff to have multiple roles in a course

create table CourseStaff (
	course      integer references Courses(id),
	staff       integer references Staff(id),
	role        integer references CourseRoles(id),
	primary key (course,staff,role)
);


-- CourseQuotas: quotas for various classes of students in a course
-- if there's no quota, there's no entry in this table
-- alternatively, we could have allowed quota to be null
--   and used that as a mechanism for indicating "no quota"

create table CourseQuotas (
	course      integer references Courses(id),
	sgroup      integer references StudentGroups(id),
	quota       integer not null,
	primary key (course,sgroup)
);


-- CourseEnrolments: student's enrolment in a course offering
-- null grade means "currently enrolled"
-- if course is graded SY/FL, then mark always remains null

create table CourseEnrolments (
	student     integer references Students(id),
	course      integer references Courses(id),
	mark        integer check (mark >= 0 and mark <= 100),
	grade       GradeType,
	stuEval     integer check (stuEval >= 1 and stuEval <= 6),
	primary key (student,course)
);


-- CourseEnrolmentWaitList: waiting lists for course enrolment
-- entries only stay on this list until students are enrolled,
--   and then they are deleted
-- the "applied" date is used as the basis for FIFO
--   allocation of places

create table CourseEnrolmentWaitList (
	student     integer references Students(id),
	course      integer references Courses(id),
	applied     timestamp not null,
	primary key (student,course)
);


-- Books: textbook details

create table Books (
	id          integer, -- PG: serial
	isbn        varchar(20) unique,
	title       LongString not null,
	authors     LongString not null,
	publisher   LongString not null,
	edition     integer,
	pubYear     integer not null check (pubYear > 1900),
	primary key (id)
);


-- CourseBooks: relates books to courses
-- books are related to a Course rather than a Subject because texts
--   may change over time, even if the syllabus remains constant

create table CourseBooks (
	course      integer references Courses(id),
	book        integer references Books(id),
	bktype      varchar(10) not null check (bktype in ('Text','Reference')),
	primary key (course,book)
);


-- ClassType: names for different kinds of class
-- e.g. "Lecture", "Tutorial", "Lab Class", ...

create table ClassTypes (
	id          integer, -- PG: serial
	name        MediumName not null,
	description LongString,
	primary key (id)
);


-- Classes: a specific regular teaching event in a course
-- we ignore streams, since they make class registration too messy
-- we don't allow day/time/place info to be null; this forces us to
--   already organise a time/place before we enter them in the system
-- weekly repetitions are handled by (repeats=1 or repeats is null)
-- we assume that all classes are multiples of 1-hour in duration
--   and cannot start before 8am or finish after 11pm)

create table Classes (
	id          integer, -- PG: serial
	course      integer not null references Courses(id),
	room        integer not null references Rooms(id),
	ctype       integer not null references ClassTypes(id),
	dayOfWk     integer not null check (dayOfWk >= 0 and dayOfWk <= 6),
	                                  -- Sun=0 Mon=1 Tue=2 ... Sat=6
	startTime   integer not null check (startTime >= 8 and startTime <= 22),
	endTime     integer not null check (endTime >= 9 and endTime <= 23),
	                                  -- time of day, between 8am and 11pm
	startDate   date not null,
	endDate     date not null,
	repeats     integer, -- every X weeks
	primary key (id)
);


-- ClassTeachers: who teaches which class
-- unfortunately, no way to describe how two staff who
--   are allocated to a given class teach together
--   e.g. teach on alternating weeks

create table ClassTeachers (
	class       integer references Classes(id),
	teacher     integer references Staff(id),
	primary key (class,teacher)
);


-- ClassEnrolments: one student's enrolment in a class

create table ClassEnrolments (
	student     integer references Students(id),
	class       integer references Classes(id),
	primary key (student,class)
);


-- ClassEnrolmentWaitList: waiting lists for class enrolment

create table ClassEnrolmentWaitList (
	student     integer references Students(id),
	class       integer references Classes(id),
	applied     timestamp not null,
	primary key (student,class)
);


-- ExternalSubjects: represents courses from other institutions
-- used to ensure consistency in awarding advanced standing
-- if student X gets advanced standing based on course Y at Z,
--   then a later student who has done course Y at Z can be given
--   the same advanced standing
-- to do this properly, we'd need to set up a table of external
--   institutions and use a foreign key ... as it stands, if
--   people award credit for the same course, but spell either
--   the course name or the institution name differently, it
--   will be treated as a different course

create table ExternalSubjects (
	id          integer,
	extsubj     LongName not null,
	institution LongName not null,
	yearOffered CourseYearType,
	equivTo     integer not null references Subjects(id),
--	creator     integer not null references Staff(id),
--	created     date not null,
	primary key (id)
);


-- Variations: replacement of one subject or another in a program
-- handles several cases (which are more or less similar):
--   advanced standing for courses studied either at UNSW or elsewhere
--   substitution of one course for another to satisfy requirements
--   exemption from one course, to use as a prerequisite
-- in the case of exemptions, no credit is granted towards a program;
--   the subject is being recorded to use as a pre-req
-- the substitution is for one subject towards the requirements
--   of one stream
-- there are two sub-cases represented in this single table:
--   the subject is an internal UNSW subject (internal equivalence)
--   the subject is from outside UNSW (external equivalence)
-- can't enter Advanced Standing without saying who you are, since
--   Advanced Standing is like awarding a pass in a UNSW course
-- if we wanted to record external subjects being used as a basis
--   for pre-requisites but not credit (i.e. exemption), we would
--   need to add a new field to indicate that no credit was involved

create domain VariationType as ShortName
	check (value in ('advstanding','substitution','exemption'));

create table Variations (
	student     integer references Students(id),
	program     integer references Programs(id),
	subject     integer references Subjects(id),
	vtype       VariationType not null,
	intEquiv    integer references Subjects(id),
	extEquiv    integer references ExternalSubjects(id),
	yearPassed  CourseYearType,
	mark        integer check (mark > 0), -- if we know it
	approver    integer not null references Staff(id),
	approved    date not null,
	primary key (student,program,subject),
	constraint  TwoCases check
	            ((intEquiv is null and extEquiv is not null)
		     or
		     (intEquiv is not null and extEquiv is null))
);

-- AcadObjectGroups: groups of different kinds of academic objects
--  academic objects = courses OR streams OR programs OR requirements

-- different kinds of academic objects that can be grouped
-- each group consists of a set of objects of the same type

create domain AcadObjectGroupType as ShortName
	check (value in (
		'subject',      -- group of subjects
		'stream',       -- group of streams
		'program',      -- group of programs
		'requirement'   -- group of requirements
	));

-- how to interpret combinations of objects in groups

create domain AcadObjectGroupLogicType as ShortName
	check (value in ( 'and', 'or'));

-- how groups are defined

create domain AcadObjectGroupDefType as ShortName
	check (value in ('enumerated', 'pattern', 'query'));

-- there are some constraints in this table that we haven't implemented
-- e.g. only groups of requirements have logic
-- e.g. nesting of requirements happens via the requirements table,
--      not via the parent attribute in this table

create table AcadObjectGroups (
	id          integer,
	name        LongName,
	gtype       AcadObjectGroupType not null,
	glogic      AcadObjectGroupLogicType,
	gdefBy      AcadObjectGroupDefType not null,
	parent      integer, -- references AcadObjectGroups(id),
	definition  LongString, -- if pattern or query-based group
	primary key (id)
);

alter table AcadObjectGroups
	add foreign key (parent) references AcadObjectGroups(id);

alter table Subjects
	add foreign key (excluded) references AcadObjectGroups(id);

alter table Subjects
	add foreign key (equivalent) references AcadObjectGroups(id);

-- Each kind of AcademicObjectGroup requires it own membership relation

create table SubjGroupMembers (
	subject     integer references Subjects(id),
	acobjgroup  integer references AcadObjectGroups(id),
	primary key (subject,acobjgroup)
);

create table StreamGroupMembers (
	stream      integer references Streams(id),
	acobjgroup  integer references AcadObjectGroups(id),
	primary key (stream,acobjgroup)
);

create table ProgGroupMembers (
	program     integer references Programs(id),
	acobjgroup  integer references AcadObjectGroups(id),
	primary key (program,acobjgroup)
);

create table ReqGroupMembers (
	requirement integer, -- references Requirements(id),
	acobjgroup  integer references AcadObjectGroups(id),
	primary key (requirement,acobjgroup)
);


-- Requirements: representation for course/stream/program rules
-- this captures the entire Requirements sub-class hierarchy
--   miscellaneous (e.g. industrial training)
--   uoc requirements (e.g. at least 144UOC)
--   course requirements (e.g. at most 72UOC of level 1 courses)
--   program requirements (e.g. must be enrolled in 3648)
-- note that because we've collapsed the subclass hierarchy into
--   a single table, and some 

create domain RequirementType as ShortName
	check (value in (
		'compound',     -- requirement via logic expression
		'inSubject',    -- enrolled in subject (co-req)
		'inStream',     -- enrolled in stream from StreamGroup
		'inProgram',    -- enrolled in program from ProgramGroup
		'doneSubject',  -- completed course (pre-req)
		'doneStream',   -- completed all requirements for Stream
		'doneProgram',  -- completed all requirements for Program
		'uoc',          -- completed min <= UOC <= max
		'wam',          -- has min <= WAM <= max
		'stage',        -- enrolled in min <= stage <= max
		'misc'          -- other (non-computable) requirements
	));

create table Requirements (
	id          integer, -- PG: serial
	name        LongName,
	reqtype     RequirementType not null,
	reqGroup    integer references AcadObjectGroups(id),
	reqMin      integer,
	reqMax      integer,
	isCore      boolean,
	isNegated   boolean,
	description LongString,
	primary key (id)
);

alter table ReqGroupMembers
	add foreign key (requirement) references Requirements(id);


-- ReqSatisfied: indication for misc requirements being satisfied
-- satisfaction of other requirements can be computed based on
--   other factors such as WAM, UOC passed, courses completed, etc.

create table ReqSatisfied (
	student     integer references Students(id),
	requirement integer references Requirements(id),
	completed   date not null,
	primary key (student,requirement)
);


-- ReusableRequirements: requirements that can be re-used
-- For some double-degree programs, some courses count towards
--  both degrees (e.g. Maths in combined Science/Engineering)

create table ReusableRequirements (
	acObjGroup  integer references AcadObjectGroups(id),
	reqt1       integer references Requirements(id),
	reqt2       integer references Requirements(id),
	primary key (acObjGroup,reqt1,reqt2)
);


-- ProgramRequirements: which requirements apply to which programs
--   all requirements must be satisfied to complete the program
--   some requirements will require streams to be completed

create table ProgramRequirements (
	program     integer references Programs(id),
	requirement integer references Requirements(id),
	primary key (program,requirement)
);


-- StreamRequirements: which requirements apply to which streams
--   all requirements must be satisfied to complete the stream

create table StreamRequirements (
	stream      integer references Streams(id),
	requirement integer references Requirements(id),
	primary key (stream,requirement)
);


-- SubjectPrereq: pre-requisite requirements for a Subject
--   may have several for a given Subject
--   all need to be satisfied before Subject can be taken

create table SubjectPrereq (
	subject     integer references Subjects(id),
	requirement integer references Requirements(id),
	primary key (subject,requirement)
);


-- SubjectCoreq: co-requisite requirements for a Subject
--
-- No longer required ... UNSW dumped co-reqs
-- 
-- create table SubjectCoreq (
-- 	subject     integer references Subjects(id),
-- 	requirement integer references Requirements(id),
-- 	primary key (subject,requirement)
-- );


-- Schedules: suggestions on when requirements should be attempted
--   (e.g. COMP1921 in s2 of year 1, 12UOC of 30UOC COMP3/4 courses in year 3)
--  Each schedule entry specifies when, in a given program/stream,
--   you should satisfy a given requirement, and how much of the requirement
--  The "uoc" value indicates how many UOC from the requirement might be
--   satisfied at this schedule point (e.g. 12UOC from a 30UOC requirement)
--  This allows us to spread individual requirements over the degree
--  Some programs may not specify down to the semester level, but only
--   specify the stages in which a requirement should be met
--  Specifying a schedule for a program is optional; if no schedule is
--   given the the requirements are given in the order supplied

create table Schedules (
	program     integer not null references Programs(id),
	stream      integer not null references Streams(id),
	requirement integer not null references Requirements(id),
	uoc         integer check (uoc > 0), -- if null, whole requirement
	stage       integer not null check (stage > 0 and stage < 10),
	semester    integer check (semester = 1 or semester = 2),
	primary key (program,stream,requirement)
);
