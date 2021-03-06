/***************************************************************************************************
-- Set Paremeters :gradstart = 'DD-MMM-YY' i.e '30-JUN-19'
                  :gradend = 'DD-MMM-YY' i.e '01-JUL-20'
***************************************************************************************************/

truncate table dxgrad_current;

insert into dxgrad_current
    (dxgrad_pidm,
     dxgrad_id,
     dxgrad_ssn,
     dxgrad_acyr,
     dxgrad_term_code_grad,
     dxgrad_dsugrad_dt,
     dxgrad_last_name,
     dxgrad_first_name,
     dxgrad_middle,
     dxgrad_suffix,
     dxgrad_birth_dt,
     dxgrad_sex,
     dxgrad_levl_code,
     dxgrad_dgmr_seqno,
     dxgrad_degc_code,
     dxgrad_degc_desc,
     dxgrad_grad_majr,
     dxgrad_dgmr_prgm,
     dxgrad_activity_dt,
     dxgrad_inst,
     dxgrad_ushe_majr_coll,
     dxgrad_grad_minr1,
     dxgrad_grad_minr2) (
    select
        shrdgmr_pidm,                      -- dxgrad_pidm
        spriden_id,                        -- dxgrad_id

           spbpers_ssn,                       -- dxgrad_ssn
        '1920',                            -- dxgrad_acyr
        shrdgmr_term_code_grad,            -- dxgrad_term_code_grad
        shrdgmr_grad_date,                 -- dxgrad_dsugrad_dt
        substr(spriden_last_name, 1, 15),  -- dxgrad_last_name
        substr(spriden_first_name, 1, 15), -- dxgrad_first_name
        substr(spriden_mi, 1, 15),         -- dxgrad_middle
        substr(spbpers_name_suffix, 1, 4), -- dxgrad_suffix
        spbpers_birth_date,                -- dxgrad_birth_dt
        spbpers_sex,                       -- dxgrad_sex
        shrdgmr_levl_code,                 -- dxgrad_levl_code
        shrdgmr_seq_no,                    -- dxgrad_dgmr_seqno
        substr(shrdgmr_degc_code, 1, 4),   -- dxgrad_degc_code
        stvdegc_desc,                      -- dxgrad_degc_desc
        shrdgmr_majr_code_1,               -- dxgrad_grad_majr
        shrdgmr_program,                   -- dxgrad_dgmr_prgm
        shrdgmr_activity_date,             -- dxgrad_activity_dt
        '3671',                            -- dxgrad_inst
        shrdgmr_coll_code_1,               -- dxgrad_ushe_majr_coll
        shrdgmr_majr_code_minr_1,          -- dxgrad_grad_minr1
        shrdgmr_majr_code_minr_2           -- dxgrad_grad_minr2
    from spbpers, stvmajr, shrdgmr, spriden, stvdegc
    where shrdgmr_pidm = spbpers_pidm(+)
      and shrdgmr_pidm = spriden_pidm
      and shrdgmr_majr_code_1 = stvmajr_code
      and shrdgmr_degc_code = stvdegc_code
      and shrdgmr_degs_code = 'AW'
      and spriden_change_ind is null
      and shrdgmr_grad_date between to_date(:gradstart) and to_date(:gradend) -- change every year
);


-- G-02 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Student ID
-- FIELD NAME:   G_ID
/* DEFINITION:   Use a Unique Identifier for graduating student. Social Security Number shall be
                 used (to facilitate student tracking) except in the rare case where the student
                 does not have SSN (i.e. international student) where an institutionally defined
                 number is used.                                                                  */
----------------------------------------------------------------------------------------------------

-- Use Banner ID where no SSN is found
update dxgrad_current
set dxgrad_ssn = dxgrad_id
where dxgrad_ssn is null
   or LENGTH(dxgrad_ssn) != '9'
   or dxgrad_ssn like '9%'
   or dxgrad_ssn in ('00000', '000000000', '');



-- G-03 --------------------------------------------------------------------------------------------
/* ELEMENT NAME: Name
   FIELD NAME:   G_LAST, G_FIRST, G_MIDDLE, G_SUFFIX
   DEFINITION:   The legal combination of names by which the student is known.                    */
----------------------------------------------------------------------------------------------------

update dxgrad_current
set dxgrad_suffix = upper(REPLACE(dxgrad_suffix, '.', ''))
where dxgrad_suffix is not null;

-- Check for bogus suffixes
select
    dxgrad_pidm,
    dxgrad_id,
    dxgrad_suffix
from dxgrad_current
where dxgrad_suffix is not null
  and upper(dxgrad_suffix) not in ('JR', 'SR', 'II', 'III', 'IV');
--

-- Use this query to fix bogus suffixes
/*
   UPDATE dxgrad_current
   SET    dxgrad_suffix = NULL
   WHERE  dxgrad_pidm IN (<<pidmshere>>)
   --
*/

/*
   UPDATE dxgrad_current
   SET    dxgrad_suffix = NULL
   WHERE  dxgrad_pidm IN ('109994','176556','270531');
*/


-- G-04 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Utah County Code
-- FIELD NAME:   G_COUNTY_ORIGIN
/* DEFINITION:   The Utah county code indicating the student�s county of origin as described at the
                 time of first application to the institution, and if the S_STATE_ORIGIN is UT.
                 Enter UT030 if county is Unknown. Enter UT097 if student is Out of State, Out of
                 US. Enter UT099 if student is Out of State, In the US.                           */
----------------------------------------------------------------------------------------------------

-- Fetch county code from SABSUPL table.
update dxgrad_current
set dxgrad_ut_cnty_code = (
    select
        (c.sabsupl_cnty_code_admit)
    from sabsupl c
    where c.sabsupl_pidm = dxgrad_pidm
      and c.sabsupl_appl_no || c.sabsupl_term_code_entry = (
        select MIN(d.sabsupl_appl_no || d.sabsupl_term_code_entry) from sabsupl d where d.sabsupl_pidm = dxgrad_pidm))
where dxgrad_ut_cnty_code is null;
--

update dxgrad_current
set dxgrad_ut_cnty_code = case LENGTH(dxgrad_ut_cnty_code)
                              when 1 then 'UT00' || dxgrad_ut_cnty_code
                              when 2 then 'UT0' || dxgrad_ut_cnty_code
                              when 3 then 'UT' || dxgrad_ut_cnty_code
                              when 4 then 'UT' || substr(dxgrad_ut_cnty_code, 2, 3)
                              when 5 then 'UT' || substr(dxgrad_ut_cnty_code, 3, 3)
                              else dxgrad_ut_cnty_code
                          end
where dxgrad_ut_cnty_code not like 'UT%';
--

update dxgrad_current
set dxgrad_ut_cnty_code = 'UT099'
where dxgrad_country_origin = 'US'
  and dxgrad_state_origin <> 'UT'
  and dxgrad_ut_cnty_code is null;
--

update dxgrad_current
set dxgrad_ut_cnty_code = 'UT097'
where dxgrad_country_origin <> 'US'
  and dxgrad_ut_cnty_code is null;
--

-- G-07 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Ethnic Origin
-- FIELD NAME:   G_ETHNIC
/* DEFINITION:   The racial and ethnic categories used to classify students.                      */
----------------------------------------------------------------------------------------------------

-- Set Non-Resident Aliens where spbpers_citz_code = '2'
update dxgrad_current
set dxgrad_ethn_n = 'N'
where EXISTS(select
                 spbpers_citz_code
             from spbpers, gorvisa
             where spbpers_pidm = dxgrad_pidm
               and gorvisa_pidm = dxgrad_pidm
               and spbpers_citz_code = '2'
               AND (gorvisa_visa_expire_date > sysdate OR gorvisa_visa_expire_date IS NULL))
  and dxgrad_ethn_n is null;


--

update dxgrad_current
set dxgrad_ethn_code = dxgrad_ethn_n
where dxgrad_ethn_code is null
  and dxgrad_ethn_n is not null;
--

-- Set Hispanic where spbpers_ethn_cde = '2'
update dxgrad_current
set dxgrad_ethn_h = 'H'
where EXISTS(select spbpers_ethn_cde from spbpers where spbpers_pidm = dxgrad_pidm and spbpers_ethn_cde = '2')
  and dxgrad_ethn_h is null
  and dxgrad_ethn_n is null;
--

update dxgrad_current
set dxgrad_ethn_code = dxgrad_ethn_h
where dxgrad_ethn_code is null
  and dxgrad_ethn_h is not null;
--

-- Set Hispanic where spbpers_ethn_code = 'H'
update dxgrad_current
set dxgrad_ethn_code = 'H',
    dxgrad_ethn_h    = 'H'
where dxgrad_pidm in (
    select spbpers_pidm from spbpers where dxgrad_pidm = spbpers_pidm and spbpers_ethn_code = 'H')
  and dxgrad_ethn_code is null;
--

-- Set Asian where gorprac_race_cde = 'A'
update dxgrad_current
set dxgrad_ethn_a = (
    select gorprac_race_cde from gorprac where gorprac_pidm = dxgrad_pidm and gorprac_race_cde = 'A')
where dxgrad_ethn_h is null
  and dxgrad_ethn_n is null;
--

update dxgrad_current
set dxgrad_ethn_code = dxgrad_ethn_a
where dxgrad_ethn_h is null
  and dxgrad_ethn_n is null
  and dxgrad_ethn_a is not null;
--

-- Set Black/African-American where gorprac_race_cde = 'B'
update dxgrad_current
set dxgrad_ethn_b = (
    select gorprac_race_cde from gorprac where gorprac_pidm = dxgrad_pidm and gorprac_race_cde = 'B')
where dxgrad_ethn_h is null
  and dxgrad_ethn_n is null;
--

update dxgrad_current
set dxgrad_ethn_code = dxgrad_ethn_b
where dxgrad_ethn_h is null
  and dxgrad_ethn_n is null
  and dxgrad_ethn_b is not null;
--

-- Set Native-American/American-Indian where gorprac_race_cde = 'I'
update dxgrad_current
set dxgrad_ethn_i = (
    select gorprac_race_cde from gorprac where gorprac_pidm = dxgrad_pidm and gorprac_race_cde = 'I')
where dxgrad_ethn_h is null
  and dxgrad_ethn_n is null;
--

update dxgrad_current
set dxgrad_ethn_code = dxgrad_ethn_i
where dxgrad_ethn_h is null
  and dxgrad_ethn_n is null
  and dxgrad_ethn_i is not null;
--

-- Set Native-Hawaiian/Pacific-Islander where gorprac_race_cde = 'P'
update dxgrad_current
set dxgrad_ethn_p = (
    select gorprac_race_cde from gorprac where gorprac_pidm = dxgrad_pidm and gorprac_race_cde = 'P')
where dxgrad_ethn_h is null
  and dxgrad_ethn_n is null
  and dxgrad_ethn_i is not null;
--

update dxgrad_current
set dxgrad_ethn_code = dxgrad_ethn_p
where dxgrad_ethn_h is null
  and dxgrad_ethn_n is null
  and dxgrad_ethn_p is not null;
--

-- Set White/Caucasian where gorprac_race_cde = 'W'
update dxgrad_current
set dxgrad_ethn_w = (
    select gorprac_race_cde from gorprac where gorprac_pidm = dxgrad_pidm and gorprac_race_cde = 'W')
where dxgrad_ethn_h is null
  and dxgrad_ethn_n is null;
--

update dxgrad_current
set dxgrad_ethn_code = dxgrad_ethn_w
where dxgrad_ethn_h is null
  and dxgrad_ethn_n is null
  and dxgrad_ethn_w is not null;
--

-- Set ethn code to '2' where students have more than one ethn code
update dxgrad_current d1
set d1.dxgrad_ethn_code = '2'
where d1.dxgrad_ethn_h is null
  and d1.dxgrad_ethn_n is null
  and d1.dxgrad_pidm in (
    select distinct
        d2.dxgrad_pidm
    from dxgrad_current d2
    where LENGTH(d2.dxgrad_ethn_a || d2.dxgrad_ethn_b || d2.dxgrad_ethn_h || d2.dxgrad_ethn_i || d2.dxgrad_ethn_p ||
                 d2.dxgrad_ethn_w) > 1);
--

-- Set ethn code to '2' where ethnicity is unknown
update dxgrad_current
set dxgrad_ethn_code = 'U',
    dxgrad_ethn_u    = 'U'
where dxgrad_ethn_code is null;
--

-- Show a count of each ethnic/race code
select
    dxgrad_ethn_code,
    count(distinct (dxgrad_pidm))
from dxgrad_current
group by dxgrad_ethn_code;
--

-- SET the ethnic/race description based on validation table STVETHN
update dxgrad_current
set dxgrad_ethnic_desc = (
    select stvethn_desc
    from stvethn
    where dxgrad_ethn_code = stvethn_code);
--

update dxgrad_current
set dxgrad_ethnic_desc = 'Two or More Races'
where dxgrad_ethn_code = '2';
--

update dxgrad_current
set dxgrad_ethnic_desc = 'Non-Resident Alien'
where dxgrad_ethn_code = 'N';
--

-- G-08 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Date of Graduation
-- FIELD NAME:   G_DATE
/* DEFINITION:   The calendar date the formal award was conferred by the institution.             */
----------------------------------------------------------------------------------------------------

/* First, check for invalid graduation dates. Dates in the future should not be in this table. Run
   the below query and email results (if any) to Graduation Office and have them correct grad date
   if they belong in current year grad file

 * This picks up any with prior term code grads that will be in next years report but may really be
   coded wrong. If so, need to do special INSERT to add the pidm with shrdgmr_grad_date in error if
   Sheri Gowers hasn't fixed yet, but intends to. */

select
    shrdgmr_pidm as pidm,
    spriden_id as "Banner Id",
    spriden_last_name as "Last",
    spriden_first_name as "First",
    spriden_mi as mi,
    shrdgmr_seq_no,
    shrdgmr_degc_code,
    shrdgmr_degs_code,
    shrdgmr_majr_code_1,
    shrdgmr_appl_date,
    shrdgmr_grad_date,
    shrdgmr_activity_date,
    shrdgmr_term_code_grad,
    shrdgmr_acyr_code,
    shrdgmr_user_id
from shrdgmr, spriden
where shrdgmr_pidm = spriden_pidm
  and shrdgmr_degs_code = 'AW'
  and spriden_entity_ind = 'P'
  and shrdgmr_grad_date >= to_date('30-JUN-20') -- change every year
  and spriden_change_ind is null;
--

-- G-09 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: CIP Code
-- FIELD NAME:   G_CIP
/* DEFINITION:   Use the 2010 version of the Classification of Instructional Programs (CIP) to best
                 identify the specific programs in which the degree is awarded. Thus, report a
                 bachelor�s degree in Business Administration with a business economics major in
                 Business/Managerial Economics (520601), not in Business, General (520101).       */
----------------------------------------------------------------------------------------------------

-- Fetch CIP Codes from CIP2010 Table
-- Fetch CIP Codes from CIP2010 Table
update dxgrad_current
set dxgrad_cipc_code = (select distinct stvmajr_cipc_code
from stvmajr, shrdgmr
    where stvmajr_code = shrdgmr_majr_code_1
      and dxgrad_pidm = shrdgmr_pidm
      and dxgrad_grad_majr = stvmajr_code
      and dxgrad_degc_code = shrdgmr_degc_code);

-- This query checks for null CIP Codes as there should always be a CIP Code.
select
    (case
         when (
                  select count(*) from dxgrad_current where dxgrad_dsugrad_dt is null or dxgrad_cipc_code is null) > 0
             then 'YES'
         else 'NO'
     end) as "Missing Cip Code?"
from dual;
--

-- G-10 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Degree Type
-- FIELD NAME:   G_DEG_TYPE
/* DEFINITION:   The Level of Degree or Certificate Completed for the award conferred. Refer to the
                 Degree Type Table for all degrees.                                               */
----------------------------------------------------------------------------------------------------

-- Fix errors that sometimes occur, producing an invalid majr code

--     -- RN, GE, PARA, then GC
--     UPDATE dxgrad_current SET dxgrad_grad_majr = 'RN'   WHERE dxgrad_dgmr_prgm = 'AAS-ADN';     --
--     UPDATE dxgrad_current SET dxgrad_grad_majr = 'GE'   WHERE dxgrad_dgmr_prgm = 'AS-GENED';    --
--     UPDATE dxgrad_current SET dxgrad_grad_majr = 'PARA' WHERE dxgrad_dgmr_prgm = 'CERT-PARA';   --
--     UPDATE dxgrad_current SET dxgrad_grad_majr = 'GC'   WHERE dxgrad_dgmr_prgm = 'CERT-GCOM-C'; --
--

-- LPN
--     UPDATE dxgrad_current
--     SET    dxgrad_grad_majr = 'LPN'
--     WHERE  dxgrad_pidm IN
--            (
--              SELECT dxgrad_pidm
--              FROM   dxgrad_current
--              WHERE  dxgrad_dgmr_prgm  = 'CERT-LPN'
--              AND    dxgrad_grad_majr <> 'LPN'
--            )
--     AND    dxgrad_degc_code = 'CER'
--     AND    dxgrad_grad_majr = 'NURS';
--

-- EMS
--     UPDATE dxgrad_current
--     SET    dxgrad_grad_majr = 'EMS'
--     WHERE  dxgrad_dgmr_prgm = 'CERT-EMT-I'
--     AND    dxgrad_grad_majr = 'EMT';


--

-- G-11 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Graduation GPA
-- FIELD NAME:   G_GPA
/* DEFINITION:   Student's overall cumulative GPA tied to their graduation award. All credit hours
                 should represent average course grade on a 4.0 scale.                            */
----------------------------------------------------------------------------------------------------
--select * from student_courses@dscir where dsc_pidm = '252747'
-- select * from shrtgpa where shrtgpa_pidm = '252747'

-- Calculate and populate the GPA from SHRTGPA
update dxgrad_current
set dxgrad_gpa = (
    select
        lpad((sum(shrtgpa_quality_points) / sum(shrtgpa_gpa_hours) * 1000), 4, '0')
    from shrtgpa
    where shrtgpa_pidm = dxgrad_pidm
      and shrtgpa_levl_code = dxgrad_levl_code
      and shrtgpa_term_code <= dxgrad_term_code_grad)
where dxgrad_gpa is null;


--

-- G-12 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Cumulative Undergraduate Transfer Semester Credit Hours Accepted
-- FIELD NAME:   G_TRANS
/* DEFINITION:   Total number of undergraduate credit hours accepted to date at your institution.
                 (e.g. Transfer credit from another institution). This does not include credits
                 earned at your institution (see S-20). This does not include AP, CLEP, Challenge,
                 or Military Credit. These hours are included in the G_HRS_OTHER field. Hours
                 should all be converted to semester hours.                                       */
----------------------------------------------------------------------------------------------------

-- Calculate and populate transfer hours (if any) from SHTRGPA
update dxgrad_current
set dxgrad_trans_hrs = (
    select
        round(sum(shrtgpa_hours_earned), 1) * 10
    from shrtgpa, shrtrit, stvsbgi
 where shrtgpa_levl_code = dxgrad_levl_code
      and shrtgpa_trit_seq_no = shrtrit_seq_no
      and shrtgpa_pidm = shrtrit_pidm
      and shrtgpa_pidm = dxgrad_pidm
      and shrtgpa_gpa_type_ind = 'T'
      and shrtgpa_term_code <= dxgrad_term_code_grad
      and shrtrit_sbgi_code = stvsbgi_code
      and stvsbgi_code < '999999'
      and stvsbgi_srce_ind is not null
    group by shrtgpa_pidm);
-- where dxgrad_trans_hrs is null;



-- G-13 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Total Hours at Graduation
-- FIELD NAME:   G_GRAD_HRS
/* DEFINITION:   Total number of overall undergraduate hours when the student graduated. This field
                 should include all hours, except for remedial hours which should not be included
                 (i.e. S20 + G07 + G09 � G10 = G08). Hours should be converted to semester hours. */
----------------------------------------------------------------------------------------------------
-- this query needs to be at the bottom because, for some unknown reason, running it earlier in the
-- script will not populate most of the students a problem to solve another day.

-- Prime the field with zeros
update dxgrad_current
set dxgrad_grad_hrs = '0'
where dxgrad_grad_hrs is null;


-- Calculate and populate total hours from SHRTGPA minus remedial hours
update dxgrad_current a
set a.dxgrad_grad_hrs = ( -- Total Hours
                            select
                                round(sum(shrtgpa_hours_earned), 1) * 10
                            from shrtgpa
                            where shrtgpa_pidm = a.dxgrad_pidm
                              and shrtgpa_levl_code = dxgrad_levl_code
                              and shrtgpa_term_code <= dxgrad_term_code_grad
                            group by shrtgpa_pidm) - dxgrad_remed_hrs;






/*
Manual Fixes: These corrections are being applied because we are finding graduates that have
earned credits that are less than the required credits for their pursed degree / program.
Various issues are causing this, hence the below update statement.
See comments here:
https://dixiestate-my.sharepoint.com/:x:/r/personal/d00436636_dixie_edu/_layouts/15/Doc.aspx?sourcedoc=%7BC56A5DDB-3CB4-48A3-AA3A-8B1510265857%7D&file=dxgrad_current_grad_rem_fixes_1920.xlsx&action=default&mobileredirect=true
 */

UPDATE dxgrad_current
   SET dxgrad_grad_hrs = 620
 WHERE dxgrad_pidm = '176016'
   AND dxgrad_dgmr_prgm = 'AS-GENED';

UPDATE dxgrad_current
   SET dxgrad_grad_hrs = 660
 WHERE dxgrad_pidm = '218609'
   AND dxgrad_dgmr_prgm = 'AS-GENED';

UPDATE dxgrad_current
   SET dxgrad_grad_hrs = 600
 WHERE dxgrad_pidm = '231103'
   AND dxgrad_dgmr_prgm = 'AS-GENED';

UPDATE dxgrad_current
   SET dxgrad_grad_hrs = 650
 WHERE dxgrad_pidm = '240547'
   AND dxgrad_dgmr_prgm = 'AS-GENED';

UPDATE dxgrad_current
   SET dxgrad_grad_hrs = 1200
WHERE dxgrad_pidm = '226437' and dxgrad_dgmr_prgm = 'BS-ACCT';

COMMIT ;

-- G-COM14 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Accepted Credit from Other Sources
-- FIELD NAME:   G_HRS_OTHER
/* DEFINITION:   Hours from AP credit, CLEP test, Language test, Challenge, Military etc. Hours
                 should all be converted to semester hours.                                       */
----------------------------------------------------------------------------------------------------

-- Calculate and populate other hours from SHRTRCE and SHRTRIT
update dxgrad_current
set dxgrad_other_hrs = (
    select
        round(sum(shrtrce_credit_hours), 1) * 10
    from shrtrce, shrtrit, stvsbgi
    where shrtrce_pidm = dxgrad_pidm
      and shrtrce_pidm = shrtrit_pidm
      and shrtrce_trit_seq_no = shrtrit_seq_no
      and shrtrit_sbgi_code = stvsbgi_code
      and stvsbgi_code > '999999'
      and stvsbgi_srce_ind is null
      and stvsbgi_code not in ('DSU001', 'ELC')
    group by shrtrce_pidm);

--

-- G-15 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Remedial Hours
-- FIELD NAME:   G_REMEDIAL_HRS
/* DEFINITION:   Remedial Hours included in S-20. Should all be converted to semester hours.      */
----------------------------------------------------------------------------------------------------

/* How many graduates have remedial education credits ATTEMPTED from DSC. This is used to update
   students in dxgrad_current (most recent graduates) with a value to indicate the total amount of
   DevEd credits (no earned on shrtckg) SLCC -DevEd courses are determined by which departments owns
   the courses. SLCC uses department code but DSC will have to use subjects and course numbers which
   are different quarter and semester.
 * This will add up remedial hours, including hours for repeats that were taken as of term code grad
 * 8/7/07 after sending grad0607 McKell called about -hours in G-08 g_grad_hrs. Found that when stu
   took remedial and they were minused FROM G-08 below that if rem hrs more than actually earned
   cased -hrs in cum. example: if student took 23 cum atmpt, but earned 8 and had 11 rem hrs then.
 * 8/6/12 first time repeated remedial hrs were excluded. prior gradfiles has repeats in rem hrs
 * 8/6/12 originally used using shrtckn_repeat_sys_ind <> 'M' and should have been using
   shrtckn_repeat_course_ind <> 'E' (E = not counted in GPA, I = Repeat counted in GPA) */

-- Calculate and populate remedial hours from SHRTCKG and SHRTCKN
UPDATE dxgrad_current
    SET    dxgrad_remed_hrs = 0 ;


UPDATE dxgrad_current
    SET    dxgrad_remed_hrs =
           (SELECT round(sum(shrtckg_credit_hours), 1) * 10
              FROM shrtckg a,
                   shrtckn b,
                   shrgrde c
             WHERE shrtckg_term_code = shrtckn_term_code
               AND shrtckg_pidm = shrtckn_pidm
               AND shrtckg_grde_code_final = shrgrde_code
               AND shrgrde_levl_code = 'UG'
               AND shrtckg_pidm = dxgrad_pidm
               AND shrtckn_subj_code IN ('ENGL', 'MATH', 'ESL', 'ESOL')
               AND shrtckn_crse_numb < '1000'
               AND shrtckg_grde_code_final IN (SELECT DISTINCT
                                                      shrgrde_code
                                                 FROM shrgrde
                                                WHERE shrgrde_passed_ind = 'Y')
               AND (shrtckn_repeat_course_ind <> 'E' OR shrtckn_repeat_course_ind IS NULL)
               AND shrtckn_term_code <= dxgrad_term_code_grad
               AND dxgrad_levl_code != 'GR'
               AND shrtckg_term_code > '199830'
               AND shrtckg_tckn_seq_no = shrtckn_seq_no
               AND shrtckg_final_grde_chg_date = (SELECT max(shrtckg_final_grde_chg_date)
                                            FROM shrtckg a1,
                                                 shrtckn b1
                                           WHERE a1.shrtckg_pidm = b1.shrtckn_pidm
                                             AND a1.shrtckg_term_code = b1.shrtckn_term_code
                                             AND a1.shrtckg_tckn_seq_no = b1.shrtckn_seq_no
                                             AND a1.shrtckg_term_code = a.shrtckg_term_code
                                             AND a1.shrtckg_pidm = a.shrtckg_pidm
                                             AND b1.shrtckn_crse_numb = b.shrtckn_crse_numb
                                             AND b1.shrtckn_subj_code = b.shrtckn_subj_code
                                             AND a1.shrtckg_tckn_seq_no = b1.shrtckn_seq_no)
             GROUP BY shrtckg_pidm
           );

/*
 Setting remaing values to null in order to calculate dxgrad_grad_hrs
 */
UPDATE dxgrad_current
   SET dxgrad_remed_hrs = 0
 WHERE dxgrad_remed_hrs IS NULL;



-- G-16 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Previous Degree Type
-- FIELD NAME:   G_PREV_DEG_TYPE
/* DEFINITION:   Type of highest degree awarded earned prior to this reporting period at any
                 institution; including your own institution.                                     */
----------------------------------------------------------------------------------------------------

update dxgrad_current
set dxgrad_prev_degr = (
    select distinct
        case
            when prev_degree_max_lvl like 'CER0' then '01'
            when prev_degree_max_lvl like 'CER1' then '02'
            when prev_degree_max_lvl like 'A%' then '03'
            when prev_degree_max_lvl like 'B%' then '05'
            when prev_degree_max_lvl like 'M%' then '07'
        end
    from (
        select
            pidm,
            case
                when deg_rank_1 > deg_rank_2 then deg_desc_1
                when deg_rank_1 > deg_rank_3 then deg_desc_1
                when deg_rank_2 > deg_rank_1 then deg_desc_2
                when deg_rank_2 > deg_rank_3 then deg_desc_2
                when deg_rank_3 > deg_rank_1 then deg_desc_3
                when deg_rank_3 > deg_rank_2 then deg_desc_3
                when (deg_rank_2 > deg_rank_1 or deg_rank_2 > deg_rank_3) then deg_desc_2
                else coalesce(deg_desc_1, deg_desc_2, deg_desc_3)
            end as prev_degree_max_lvl
        from (
            with cte_prev_dgr as (
                select shrdgmr_pidm, max(shrdgmr_seq_no) as shrdgmr_seq_no
                from shrdgmr
                where shrdgmr_seq_no > 1
                group by shrdgmr_pidm),
                -- Grabs Highest Degree earned from a previous institution (SORDEGR)
                cte_prev_dgr2 as (
                    select
                        sordegr_pidm as pidm,
                        max(sordegr_degc_date) as max_sordegr_degc_date,
                        max(case
                                when stvdegc_dlev_code = 'DR' then '5'
                                when stvdegc_dlev_code = 'MA' then '4'
                                when stvdegc_dlev_code = 'BA' then '3'
                                when stvdegc_dlev_code = 'AS' then '2'
                                when stvdegc_dlev_code = 'LA' then '1'
                                else '0'
                            end) as deg_rank
                    from saturn.sordegr, saturn.stvdegc, spriden
                    where sordegr_pidm = spriden_pidm
                      and sordegr_degc_code = stvdegc_code
                      and stvdegc_acat_code >= 20
                      and sordegr_degc_code <> '000000'
                      and spriden_change_ind is null
                      and sordegr_degc_date <= to_date('01-JUN-2019')
                    group by sordegr_pidm),

                -- used to align pidm and degree to choose whichever degree is the highest level (rank)
                cte_prev_dgr3 as (
                    select
                        pidm,
                        stvdegc_code,
                        deg_rank
                    from cte_prev_dgr2, saturn.sordegr, saturn.stvdegc, spriden
                    where pidm = sordegr_pidm
                      and case
                              when stvdegc_dlev_code = 'DR' then '5'
                              when stvdegc_dlev_code = 'MA' then '4'
                              when stvdegc_dlev_code = 'BA' then '3'
                              when stvdegc_dlev_code = 'AS' then '2'
                              when stvdegc_dlev_code = 'LA' then '1'
                              else '0'
                          end = deg_rank
                      and max_sordegr_degc_date = sordegr_degc_date
                      and sordegr_pidm = spriden_pidm
                      and sordegr_degc_code = stvdegc_code
                      and stvdegc_acat_code >= 20
                      and sordegr_degc_code <> '000000'
                      and spriden_change_ind is null
                      and sordegr_degc_date <= to_date('01-JUN-2019')),
                -- Grab degrees from Transferred In Students (SHRTRAM)
                cte_prev_deg4 as (
                    select
                        shrtram_pidm,
                        shrtram_degc_code,
                        case
                            when stvdegc_dlev_code = 'DR' then '5'
                            when stvdegc_dlev_code = 'MA' then '4'
                            when stvdegc_dlev_code = 'BA' then '3'
                            when stvdegc_dlev_code = 'AS' then '2'
                            when stvdegc_dlev_code = 'LA' then '1'
                            else '0'
                        end as deg_rank_3
                    from stvdegc, shrtram, spriden
                    where shrtram_pidm = spriden_pidm
                      and shrtram_degc_code = stvdegc_code
                      and stvdegc_acat_code >= 20
                      and shrtram_degc_code <> '000000'
                      and spriden_change_ind is null)

            select distinct
                s1.shrdgmr_pidm as pidm,
                s2.shrdgmr_degc_code as deg_desc_1,
                shrdgmr_program as program,
                shrdgmr_levl_code as student_level,
                case
                    when shrdgmr_degc_code like 'M%' then '4'
                    when shrdgmr_degc_code like 'B%' then '3'
                    when shrdgmr_degc_code like 'A%' then '2'
                    when shrdgmr_degc_code like 'C%' then '1'
                    when shrdgmr_degc_code like 'L%' then '1'
                    else '0'
                end as deg_rank_1,
                s3.deg_rank as deg_rank_2,
                s3.stvdegc_code as deg_desc_2,
                deg_rank_3,
                shrtram_degc_code as deg_desc_3,
                coalesce(greatest(s3.deg_rank, case
                                                   when shrdgmr_degc_code like 'M%' then '4'
                                                   when shrdgmr_degc_code like 'B%' then '3'
                                                   when shrdgmr_degc_code like 'A%' then '2'
                                                   when shrdgmr_degc_code like 'C%' then '1'
                                                   when shrdgmr_degc_code like 'L%' then '1'
                                                   else '0'
                                               end), case
                                                         when shrdgmr_degc_code like 'M%' then '4'
                                                         when shrdgmr_degc_code like 'B%' then '3'
                                                         when shrdgmr_degc_code like 'A%' then '2'
                                                         when shrdgmr_degc_code like 'C%' then '1'
                                                         when shrdgmr_degc_code like 'L%' then '1'
                                                         else '0'
                                                     end, s3.deg_rank) as greatest_deg_rank
            from cte_prev_dgr s1
            left join shrdgmr s2 on s1.shrdgmr_pidm = s2.shrdgmr_pidm and s2.shrdgmr_seq_no = s1.shrdgmr_seq_no - 1
            left join cte_prev_dgr3 s3 on s3.pidm = s1.shrdgmr_pidm
            left join cte_prev_deg4 s4 on s4.shrtram_pidm = s1.shrdgmr_pidm
            where s2.shrdgmr_seq_no <> s1.shrdgmr_seq_no) s1)
    where dxgrad_pidm = pidm);

--

-- Use this query to view records that were just updated
/* SELECT *
   FROM   dxgrad_current
   WHERE  dxgrad_prev_degr IS NOT NULL;
*/ --

-- G-17 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: IPEDS Award Level Code
-- FIELD NAME:   G_IPEDS
/* DEFINITION:   The Award Level codes that correspond with the IPEDS Completion Survey.          */
----------------------------------------------------------------------------------------------------

-- Set IPEDS Level based on level code and program credit hours

update dxgrad_current dx
set dxgrad_ipeds_levl = (
    with cte_max_term_code_eff as (
        select
            shrdgmr_pidm as pidm,
            max(smbpgen_term_code_eff) as max_smbpgen_term_code_eff,
            shrdgmr_program
        from shrdgmr s1
        left join smbpgen s2 on smbpgen_program = shrdgmr_program
        group by shrdgmr_pidm, shrdgmr_program)

    select distinct
        case
            when shrdgmr_levl_code = 'UG' then case
                                                   when smbpgen_req_credits_overall between 1 and 8 then '1A'
                                                   when smbpgen_req_credits_overall between 9 and 29 then '1B'
                                                   when smbpgen_req_credits_overall between 30 and 59 then '02'
                                                   when smbpgen_req_credits_overall between 60 and 119 then '03'
                                                   when smbpgen_req_credits_overall > 119 then '05'
                                               end
            when shrdgmr_levl_code = 'GR' and smbpgen_req_credits_overall > 0 then '07'
        end AS ipeds_awrd_lvl_2
    from shrdgmr s1
    left join smbpgen s2 on s2.smbpgen_program = s1.shrdgmr_program
    inner join cte_max_term_code_eff s3 on s3.pidm = s1.shrdgmr_pidm and s3.shrdgmr_program = s2.smbpgen_program and
                                           s3.max_smbpgen_term_code_eff = s2.smbpgen_term_code_eff
    where dx.dxgrad_pidm = s1.shrdgmr_pidm
      and dx.dxgrad_dgmr_prgm = s1.shrdgmr_program
      and dx.dxgrad_levl_code = s1.shrdgmr_levl_code
      and shrdgmr_grad_date > to_date(:gradstart)
      and shrdgmr_grad_date < to_date(:gradend));

-- Updates IPEDS Level if program is missing from (smbpgen)
update dxgrad_current
set dxgrad_ipeds_levl = case
                            when dxgrad_degc_code = 'CER1' then '02'
                            when dxgrad_degc_code like 'A%' then '03'
                            when dxgrad_degc_code like 'B%' then '05'
                            when dxgrad_degc_code like 'M%' then '07'
                        end
where dxgrad_ipeds_levl is null;

-- Updates IPEDS Level Certificates to conform with IPEDS reporting
update dxgrad_current
set dxgrad_ipeds_levl = '1A'
where dxgrad_dgmr_prgm in ('CERT-CNA', 'CERT-PHLB', 'CERT-EMT-A');

update dxgrad_current
set dxgrad_ipeds_levl = '1B'
where dxgrad_dgmr_prgm in
      ('CERT-DFOR', 'CERT-ENTR', 'CERT-EMT', 'CERT-MAKER', 'CERT-SRM', 'CERT-MMJ', 'CERT-SCCM', 'CERT-SM', 'CERT-SCCM',
       'CERT-MMJ', 'CERT-SRM', 'CERT-PWRT', 'CERT-SM', 'CERT-DSGN', 'CERT-BIOT', 'CERT-CPFD');


-- G-18 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Required Hours for Degree
-- FIELD NAME:   G_REQ_HRS_DEG
/* DEFINITION:   The minimum number of credit hours required for the degree including any course
                 pre-requisites. Not to include any major remedial hours. Hours should all be
                 converted to semester hours.                                                     */
----------------------------------------------------------------------------------------------------

-- To compile the degrees' required hours, we will have to create a table for hours, load it with
-- data, and query against it with the dxgrad table.

-- Fetch hours for degree from the hrstodegAYAY table where AYAY is the graduating year

update dxgrad_current dx
set dxgrad_req_hrs = (
    -- gets the max program effective term
    with cte_max_term_code_eff as (
        select max(smbpgen_term_code_eff) as max_smbpgen_term_code_eff, smbpgen_program
        from smbpgen
        group by smbpgen_program)

    select
        smbpgen_req_credits_overall
    from smbpgen s1
    inner join cte_max_term_code_eff s2
               on s2.smbpgen_program = s1.smbpgen_program and s2.max_smbpgen_term_code_eff = s1.smbpgen_term_code_eff
    where dx.dxgrad_dgmr_prgm = s1.smbpgen_program);

update dxgrad_current
set dxgrad_req_hrs = (
    select
        hrs_this_yr --nts::replace with variable.
    from dsc_programs_all
    where acyr_code = '1920'
      and dxgrad_dgmr_prgm = prgm_code
      and (dxgrad_degc_code = degc_code or dxgrad_grad_majr = majr_code)
      and rownum = 1 -- nts::need to clean up dsc_programs_all table so this isn't necessary.

)
where dxgrad_req_hrs is null;

update dxgrad_current dx
set dxgrad_req_hrs = 120
where dxgrad_dgmr_prgm in ('BS-ACCT', 'BS-BIOL-SET');

-- Fix CERT-CNA Grad Hours
UPDATE dxgrad_current
   SET dxgrad_req_hrs = 4
 WHERE (dxgrad_grad_hrs / 10) < dxgrad_req_hrs
   AND dxgrad_dgmr_prgm = 'CERT-CNA';

-- Fix BS-BU Grad Hours
UPDATE dxgrad_current
   SET dxgrad_req_hrs = 120
 WHERE (dxgrad_grad_hrs / 10) < dxgrad_req_hrs
   AND dxgrad_dgmr_prgm = 'BS-BU';

COMMIT ;


/* Now CHECK FOR NULLS.
   Aug08 found one stu with AAS-GCOM DGMR_PRGM and in dsc_programs
   it is AAS-GC (which the other 2 grads had as pgm code (soacurr has AAS-GC not GCOM))
   There's always gotta be one glitch.  I don't know why both are active in Banner Soacurr
   but I only added the one in dsc_programs
 * Aug09 CONM which ended before 0910 has students in teachout graduating 0910
   This will always be the case with 'most' ended programs, so UPDATE the NULLs found here
 * Aug10 CERT-GC was missing FROM dsc_programs0910, and also the ENGL-lit ptw etc soacurr
   codes, so I changed the UPDATE above to the 1011 version (current which had them) and
   ran again, BUT MAKE SURE YOU ADD:  WHERE dxgrad_req_hrs IS NULL OR all others will be null */

/*
   SELECT dxgrad_pidm, dxgrad_id, dxgrad_req_hrs, dxgrad_dgmr_prgm, dxgrad_degc_code,
          dxgrad_grad_majr, dxgrad_majr_conc1
   FROM   "ENROLL"."DXGRAD"
   WHERE  dxgrad_req_hrs IS NULL
   ORDER  BY dxgrad_degc_code, dxgrad_grad_majr;
*/


-- G-19 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: High School Codes
-- FIELD NAME:   G_HIGH_SCHOOL
/* DEFINITION:   Refer to S_HIGH_SCHOOL in the Students Data Dictionary for a complete list of high
                 schools. The High School or Special Secondary School code which uniquely identifies
                 each student�s secondary institution. The codes for any secondary institution
                 located within the United States can be found by accessing the URL
                 http://www.act.org/aap/regist/lookuphs.html                                      */
----------------------------------------------------------------------------------------------------

-- Fetch High School Code (match what is sent in enrollment).
update dxgrad_current
set dxgrad_hs_code = (
    select
        a.sorhsch_sbgi_code
    from sorhsch a
    where a.sorhsch_pidm = dxgrad_pidm
      and a.sorhsch_graduation_date is not null
      and a.sorhsch_trans_recv_date is not null
      and a.sorhsch_graduation_date = (
        select
            MAX(b.sorhsch_graduation_date)
        from sorhsch b
        where b.sorhsch_pidm = dxgrad_pidm
          and b.sorhsch_pidm = a.sorhsch_pidm
          and b.sorhsch_trans_recv_date is not null
          and b.sorhsch_pidm || b.sorhsch_trans_recv_date = (
            select
                MAX(c.sorhsch_pidm || c.sorhsch_trans_recv_date)
            from sorhsch c
            where c.sorhsch_pidm = dxgrad_pidm
              and c.sorhsch_pidm = b.sorhsch_pidm
              and c.sorhsch_trans_recv_date is not null
            group by c.sorhsch_pidm)
        group by b.sorhsch_pidm))
where dxgrad_hs_code is null;

--

-- Fetch high school codes that weren't found in the above query using the older method.
update dxgrad_current
set dxgrad_hs_code = (
    select sorhsch_sbgi_code from sorhsch where sorhsch_pidm = dxgrad_pidm and rownum < 2)
where dxgrad_hs_code is null;

-- Change out of country to 459150
update dxgrad_current
set dxgrad_hs_code = '459150'
where dxgrad_hs_code = '459999';
--

-- Change unknowns 459996 and 999999 to 459200
update dxgrad_current
set dxgrad_hs_code = '459200'
where dxgrad_hs_code in ('459996', '999999');
--

-- Set home schooling IMC outside of Utah 459600
update dxgrad_current
set dxgrad_hs_code = '459500'
where dxgrad_hs_code in ('459998', '969999');
--

-- Set Other In-State HS
update dxgrad_current
set dxgrad_hs_code = '459000'
where dxgrad_hs_code = '459994';
--

-- Set out of st HS
update dxgrad_current
set dxgrad_hs_code = '459100'
where dxgrad_hs_code = '459997';
--

-- Set Adult HS Diploma (UT)
update students_20132e
set s_high_school = '459050'
where s_high_school in ('459993');
--

-- GED to UT GED
update dxgrad_current
set dxgrad_hs_code = '459300'
where dxgrad_hs_code = '459995';
--

-- GED 2 to UT GED 2
update dxgrad_current
set dxgrad_hs_code = '459400'
where dxgrad_hs_code = '969999';
--

-- Search for those with HS unknown to see if they have a second hs coded in banner
/*
   SELECT sorhsch_sbgi_code, dxgrad_id, dxgrad_pidm, dxgrad_hs_code
   FROM   sorhsch, dxgrad_current
   WHERE  sorhsch_pidm       = dxgrad_pidm
   AND    dxgrad_hs_code     = '459200'
   AND    sorhsch_sbgi_code <> '459996';
   --
*/

-- G-20 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Unique USOE State Student Identifier
-- FIELD NAME:   G_SSID
/* DEFINITION:   The unique Utah State Student Identifier as assigned to each Utah public education
                 student by the Utah State Office of Education. This 9 digit number will appear on
                 all high school transcripts beginning the 2006-2007 academic year. Purpose: to
                 coordinate public education and higher education information technology systems to
                 allow individual student academic achievement to be tracked through both education
                 systems in accordance with 53A-1-603.5 and 53B-1-109.                            */
----------------------------------------------------------------------------------------------------

-- Fetch known SSIDs from GORADID.
update dxgrad_current
set dxgrad_ssid = (
    select
        substr(goradid_additional_id, 0, 10)
    from goradid g1
    where goradid_pidm = dxgrad_pidm
      and goradid_adid_code = 'SSID'
      and goradid_additional_id <> '*'
      and goradid_version = (
        select
            g2.goradid_version
        from goradid g2
        where g2.goradid_pidm = dxgrad_pidm
          and g2.goradid_adid_code = 'SSID'
          and g2.goradid_additional_id <> '*'))
where dxgrad_ssid is null;
--

-- Fetch known SSIDs from SOAHSCH.
update dxgrad_current
set dxgrad_ssid = (
    select sorhsbj_subj_gpa from sorhsbj where sorhsbj_pidm = dxgrad_pidm and sorhsbj_sbjc_code = 'SSID')
where dxgrad_ssid is null;
--

-- Fetch known SSIDs from the SSID table (grad date <= 2008).
update dxgrad_current
set dxgrad_ssid = (
    select
        i.ssid_ushe
    from ssid i
    where dxgrad_hs_code between '450000' and '458999'
      and dxgrad_pidm = i.pidm
      and dxgrad_hs_code = hscode_ushe
      and dxgrad_ssid is null)
where dxgrad_ssid is null;
--

-- Set invalid SSID to blank
update dxgrad_current
set dxgrad_ssid = null
where dxgrad_ssid like '3%'
   or dxgrad_ssid like '#%'
   or dxgrad_ssid like '%.%'
   or dxgrad_ssid like '%*%';
--

-- G-25 --------------------------------------------------------------------------------------------
/* ELEMENT NAME: Term of Graduation
   FIELD NAME:   G_TERM
   DEFINITION:   The current (USHE) term in which the student graduated.                          */
----------------------------------------------------------------------------------------------------

update dxgrad_current
set dxgrad_ushe_term = case substr(dxgrad_term_code_grad, 5, 1)
                           when '3' then '1'
                           when '4' then '2'
                           when '2' then '3'
                       end;
--

-- G-27 --------------------------------------------------------------------------------------------
-- ELEMENT NAME: Major Description
-- FIELD NAME:   dxgrad_ushe_majr_desc
/* DEFINITION:   Major Description is now used by USHE and should match CIP Code. This query pulls
                 the description from a table which has data directly from USHE.                  */
----------------------------------------------------------------------------------------------------

update dxgrad_current
set dxgrad_ushe_majr_desc = (
    select stvcipc_desc
    from stvcipc
    where stvcipc_code = dxgrad_cipc_code);

-- DSU - Age ---------------------------------------------------------------------------------------
-- ELEMENT NAME: Age
-- FIELD NAME:   dxgrad_age (not required for USHE File)
/* DEFINITION:   The age of the student at the time of graduation.                                */
----------------------------------------------------------------------------------------------------

update dxgrad_current
set dxgrad_age = (
    select
        f_calculate_age(dxgrad_dsugrad_dt, spbpers_birth_date, spbpers_dead_date)
    from spbpers
    where spbpers_pidm = dxgrad_pidm);

--

-- DSU-Concentration -------------------------------------------------------------------------------
-- ELEMENT NAME: Concentration Code Outcomes
-- FIELD NAME:   dxgrad_majr_conc1, dxgrad_majr_conc2
/* DEFINITION:   Concentrations are not used by USHE.                                             */
----------------------------------------------------------------------------------------------------

-- Set first concentration
update dxgrad_current
set dxgrad_majr_conc1 = (
    select
        MAX(a.shvacur_majr_code_conc_1)
    from shvacur a
    where a.shvacur_pidm = dxgrad_pidm
      and a.shvacur_program = dxgrad_dgmr_prgm
      and a.shvacur_key_seqno = dxgrad_dgmr_seqno
      and a.shvacur_cact_code = 'ACTIVE'
      and a.shvacur_order > 0);
--

-- Set second concentration
update dxgrad_current
set dxgrad_majr_conc2 = (
    select
        MAX(a.shvacur_majr_code_conc_2)
    from shvacur a
    where a.shvacur_pidm = dxgrad_pidm
      and a.shvacur_key_seqno = dxgrad_dgmr_seqno
      and a.shvacur_program = dxgrad_dgmr_prgm
      and a.shvacur_cact_code = 'ACTIVE'
      and a.shvacur_order > 0);
--

-- DSU-Major-Description ---------------------------------------------------------------------------
-- ELEMENT NAME: Major Description
-- FIELD NAME:   dxgrad_majr_conc1, dxgrad_majr_conc2
/* DEFINITION:   Major Description is not used by USHE.                                           */
----------------------------------------------------------------------------------------------------
/*
 First uses major description from dsc_pgroams_current.  Then looks at STVMAJR.
 */
UPDATE dxgrad_current
   SET dxgrad_majr_desc = (SELECT majr_desc
                             FROM dsc_programs_current
                            WHERE prgm_code = dxgrad_dgmr_prgm);

UPDATE dxgrad_current
   SET dxgrad_majr_desc = (SELECT stvmajr_desc
                             FROM stvmajr
                            WHERE dxgrad_grad_majr = stvmajr_code)
 WHERE dxgrad_majr_desc IS NULL;




-- DSU - HS Grad Date ------------------------------------------------------------------------------
-- ELEMENT NAME: High School Grad Date
-- FIELD NAME:   dxgrad_gsgrad_dt (not required for USHE File)
/* DEFINITION:   The date on which the student graduated high school.                             */
----------------------------------------------------------------------------------------------------

-- Fetch known graduation dates from SORHSCH.
update dxgrad_current
set dxgrad_hsgrad_dt = (
    select
        to_char(a.sorhsch_graduation_date, 'YYYYMMDD')
    from sorhsch a
    where a.sorhsch_pidm = dxgrad_pidm
      and a.sorhsch_graduation_date is not null
      --AND    a.sorhsch_trans_recv_date IS NOT NULL
      and a.sorhsch_graduation_date = (
        select
            MAX(b.sorhsch_graduation_date)
        from sorhsch b
        where b.sorhsch_pidm = dxgrad_pidm
          and b.sorhsch_pidm = a.sorhsch_pidm
          --AND    b.sorhsch_trans_recv_date IS NOT NULL
--                      AND    b.sorhsch_pidm ||b.sorhsch_trans_recv_date =
--                             (
--                               SELECT MAX(c.sorhsch_pidm||c.sorhsch_trans_recv_date)        
--                               FROM   sorhsch c
--                               WHERE  c.sorhsch_pidm = dxgrad_pidm
--                               AND    c.sorhsch_pidm = b.sorhsch_pidm
--                               AND    c.sorhsch_trans_recv_date IS NOT NULL 	     
--                               GROUP  BY c.sorhsch_pidm
--                             )
        group by b.sorhsch_pidm));
--

-- DSU - Country of Origin -------------------------------------------------------------------------
-- ELEMENT NAME: Country of Origin
-- FIELD NAME:   dxgrad_country_origin (not required for USHE File)
/* DEFINITION:   The student's country of residence at the time of application.                   */
----------------------------------------------------------------------------------------------------

-- Fetch students country of origin.
update dxgrad_current
set dxgrad_country_origin = (
    select
        a.sabsupl_natn_code_admit
    from sabsupl a
    where a.sabsupl_pidm = dxgrad_pidm
      and a.sabsupl_appl_no || a.sabsupl_term_code_entry = (
        select MIN(b.sabsupl_appl_no || b.sabsupl_term_code_entry) from sabsupl b where b.sabsupl_pidm = dxgrad_pidm));
--

-- DSU - State of Origin ---------------------------------------------------------------------------
-- ELEMENT NAME: State of Origin
-- FIELD NAME:   dxgrad_state_origin (not required for USHE File)
/* DEFINITION:   The student's state of residence at the time of application.                     */
----------------------------------------------------------------------------------------------------

-- Fetch students country of origin.
update dxgrad_current
set dxgrad_state_origin = (
    select
        a.sabsupl_stat_code_admit
    from sabsupl a
    where a.sabsupl_pidm = dxgrad_pidm
      and a.sabsupl_appl_no || a.sabsupl_term_code_entry = (
        select MIN(b.sabsupl_appl_no || b.sabsupl_term_code_entry) from sabsupl b where b.sabsupl_pidm = dxgrad_pidm));
--

-- DSU-Initial-Term --------------------------------------------------------------------------------
-- ELEMENT NAME: Initial Term
-- FIELD NAME:   dxgrad_initial_term
/* DEFINITION:   The term code for student's first term at DSU.                                   */
----------------------------------------------------------------------------------------------------

update dxgrad_current
set dxgrad_initial_term = nvl((
                                  select MIN(banner_term)
                                  from students03@dscir
                                  where dxgrad_pidm = dsc_pidm and s_entry_action in ('FF', 'FH', 'TU')), (
                                  select MIN(banner_term) from students03@dscir where dxgrad_pidm = dsc_pidm));
--

-- DSU-Initial-Entry-Action ------------------------------------------------------------------------
-- ELEMENT NAME: Entry Action
-- FIELD NAME:   dxgrad_initial_ea
/* DEFINITION:   The entry action code for student's first term at DSU (FF, FH or TU).            */
----------------------------------------------------------------------------------------------------

-- s_entry_action first get those in DSCIR
update dxgrad_current
set dxgrad_initial_ea = (
    select distinct
        s_entry_action
    from bailey.students03@dscir
    where dxgrad_pidm = dsc_pidm
      and substr(dsc_term_code, 0, 5) || 0 = dxgrad_initial_term
      and substr(dsc_term_code, 5, 2) in ('3E', '43', '23') -- Only Sum EOT, Fall 3rd and Spr 3rd
);
--

-- Need to fix any records with CS, HS, or RS:

-- Check for a transfer record. If student has one, assign TU.
update dxgrad_current
set dxgrad_initial_ea = 'TU'
where dxgrad_pidm in (
    select
        b.sgbstdn_pidm
    from sgbstdn b
    where b.sgbstdn_styp_code in ('T')
      and b.sgbstdn_pidm = dxgrad_pidm
      and b.sgbstdn_term_code_eff = (
        select
            MAX(a.sgbstdn_term_code_eff)
        from sgbstdn a, dxgrad_current d
        where a.sgbstdn_pidm = b.sgbstdn_pidm
          and a.sgbstdn_pidm = d.dxgrad_pidm
          and a.sgbstdn_term_code_eff <= dxgrad_term_code_grad))
  and (dxgrad_initial_ea in ('F', 'C', 'H', 'R', 'CS', 'HS', 'RS') or dxgrad_initial_ea is null);
--

-- If student is not a transfer, determine FF or FH by High School Grad Date and Age
update dxgrad_current
set dxgrad_initial_ea = case
                            when dxgrad_hsgrad_dt is null then (case
                                                                    when dxgrad_age <= 18 then 'FH'
                                                                    when dxgrad_age > 18 then 'FF'
                                                                    else 'FF'
                                                                end)
                            when (case
                                      when substr(dxgrad_initial_term, 5, 1) = '1'
                                          then to_number(substr(dxgrad_initial_term, 0, 4) || '0101')
                                      when substr(dxgrad_initial_term, 5, 1) = '2'
                                          then to_number(substr(dxgrad_initial_term, 0, 4) || '0801')
                                      when substr(dxgrad_initial_term, 5, 1) = '3'
                                          then to_number(substr(dxgrad_initial_term, 0, 4) || '0501')
                                  end) - to_number(dxgrad_hsgrad_dt) > '10000' then 'FF'
                            else 'FH'
                        end
where (dxgrad_initial_ea in ('F', 'C', 'H', 'R', 'CS', 'HS', 'RS') or dxgrad_initial_ea is null);
--

-- DSU-Initial-PT-FT-Status ------------------------------------------------------------------------
-- ELEMENT NAME: Part-Time / Full-Time Status
-- FIELD NAME:   dxgrad_initial_pt_ft
/* DEFINITION:   The part-time or full-time status for student's first term at DSU (PT or FT).    */
----------------------------------------------------------------------------------------------------

update dxgrad_current
set dxgrad_initial_pt_ft = (
    select
        s_pt_ft
    from bailey.students03@dscir
    where dxgrad_pidm = dsc_pidm
      and substr(dxgrad_initial_term, '0', '5') = substr(dsc_term_code, '0', '5')
      and substr(dsc_term_code, '6', '1') = case dxgrad_ushe_term when 1 then 'E' when 2 then '3' when 3 then '3' end)
where dxgrad_initial_term is not null;
--

update dxgrad_current
set dxgrad_initial_pt_ft = 'F'
where EXISTS(select
                 sum(sfrstcr_credit_hr)
             from sfrstcr, stvrsts
             where sfrstcr_pidm = dxgrad_pidm
               and sfrstcr_rsts_code = stvrsts_code
               and stvrsts_incl_sect_enrl = 'Y'
               and sfrstcr_term_code <= dxgrad_initial_term
               and sfrstcr_camp_code <> 'XXX'
             group by sfrstcr_pidm
             having SUM(sfrstcr_credit_hr) > 11.99) and dxgrad_initial_pt_ft not in ('F', 'P')
   or dxgrad_initial_pt_ft is null;
--

update dxgrad_current
set dxgrad_initial_pt_ft = 'P'
where dxgrad_initial_pt_ft not in ('F', 'P')
   or dxgrad_initial_pt_ft is null;
--

-- DSU-Initial-Degree-Intent -----------------------------------------------------------------------
-- ELEMENT NAME: Initial Degree Intent
-- FIELD NAME:   dxgrad_initial_degint
/* DEFINITION:   The Degree Intent for student's first term at DSU (i.e. 0, 1, 2, 4, etc.)        */
----------------------------------------------------------------------------------------------------

update dxgrad_current
set dxgrad_initial_degint = (
    select s_deg_intent
    from bailey.students03@dscir
    where dxgrad_pidm = dsc_pidm and dxgrad_initial_term = dsc_term_code)
where dxgrad_initial_term is not null;
--

update dxgrad_current
set dxgrad_initial_degint = null
where dxgrad_initial_degint not in ('1', '2', '3', '4', '5');
--

update dxgrad_current
set dxgrad_initial_degint = '4'
where dxgrad_degc_code like 'B%'
  and dxgrad_initial_degint is null;
--

update dxgrad_current
set dxgrad_initial_degint = '3'
where dxgrad_dgmr_prgm in ('AAS-RADT', 'AAS-RSTH', 'AAS-PTA', 'AAS-DHYG')
  and dxgrad_initial_degint is null;
--

update dxgrad_current
set dxgrad_initial_degint = '2'
where dxgrad_degc_code like 'A%'
  and dxgrad_initial_degint is null;
--

update dxgrad_current
set dxgrad_initial_degint = '1'
where dxgrad_degc_code like 'C%'
  and dxgrad_initial_degint is null;


update dxgrad_current
set dxgrad_initial_degint = '7'
where dxgrad_degc_code like 'M%'
  and dxgrad_initial_degint is null;



commit;
--

-- DSU-Initial-Sport -------------------------------------------------------------------------------
-- ELEMENT NAME: Initial Sport
-- FIELD NAME:   dxgrad_initial_sport
/* DEFINITION:   If/What sport a student participated in during their first term at DSU.          */
----------------------------------------------------------------------------------------------------

--
update dxgrad_current
set dxgrad_initial_sport = (
    select max(sgrsprt_actc_code)
    from sgrsprt
    where sgrsprt_pidm = dxgrad_pidm and dxgrad_initial_term = sgrsprt_term_code);
--

-- DSU-Pell-Paid -----------------------------------------------------------------------------------
-- ELEMENT NAME: Pell Paid
-- FIELD NAME:   dxgrad_pell_pd
/* DEFINITION:   Whether the student received Pell Grant Funding while earning the degree from which
                 they are now graduating.                                                         */
----------------------------------------------------------------------------------------------------

-- Mark students who have received Pell funding using RPRATRM. **This script can take a while.**
update dxgrad_current
set dxgrad_pell_pd = 'Y'
where dxgrad_pidm in (
    select
        rpratrm_pidm
    from rpratrm
    where rpratrm_pidm = dxgrad_pidm
      and rpratrm_term_code <= dxgrad_term_code_grad
      and rpratrm_fund_code in ('FPELL', 'FPELL1')
    group by rpratrm_pidm
    having sum(rpratrm_paid_amt) > 0)
  and dxgrad_pell_pd is null;
--

update dxgrad_current
set dxgrad_pell_pd = 'N'
where dxgrad_pell_pd is null;
--

-- Change-Nulls ------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- Set [Nulls] to [Zero]:
update dxgrad_current
set dxgrad_hsgrad_dt = '0'
where dxgrad_hsgrad_dt is null; --
update dxgrad_current
set dxgrad_grad_hrs = '0'
where dxgrad_grad_hrs is null; --
update dxgrad_current
set dxgrad_req_hrs = '0'
where dxgrad_req_hrs is null; --
update dxgrad_current
set dxgrad_remed_hrs = '0000'
where dxgrad_remed_hrs is null; --
update dxgrad_current
set dxgrad_other_hrs = '0000'
where dxgrad_other_hrs is null; --
update dxgrad_current
set dxgrad_trans_hrs = '00000'
where dxgrad_trans_hrs is null;
--



-- Re-Fetch county code from SABSUPL table.
update dxgrad_current
set dxgrad_ut_cnty_code = (
    select
        (c.sabsupl_cnty_code_admit)
    from sabsupl c
    where c.sabsupl_pidm = dxgrad_pidm
      and c.sabsupl_appl_no || c.sabsupl_term_code_entry = (
        select MIN(d.sabsupl_appl_no || d.sabsupl_term_code_entry) from sabsupl d where d.sabsupl_pidm = dxgrad_pidm))
where dxgrad_ut_cnty_code is null;
--

update dxgrad_current
set dxgrad_ut_cnty_code = case LENGTH(dxgrad_ut_cnty_code)
                              when 1 then 'UT00' || dxgrad_ut_cnty_code
                              when 2 then 'UT0' || dxgrad_ut_cnty_code
                              when 3 then 'UT' || dxgrad_ut_cnty_code
                              when 4 then 'UT' || substr(dxgrad_ut_cnty_code, 2, 3)
                              when 5 then 'UT' || substr(dxgrad_ut_cnty_code, 3, 3)
                              else dxgrad_ut_cnty_code
                          end
where dxgrad_ut_cnty_code not like 'UT%';
--

update dxgrad_current
set dxgrad_ut_cnty_code = 'UT099'
where dxgrad_country_origin = 'US'
  and dxgrad_state_origin <> 'UT'
  and dxgrad_ut_cnty_code is null;
--

update dxgrad_current
set dxgrad_ut_cnty_code = 'UT097'
where dxgrad_country_origin <> 'US'
  and dxgrad_ut_cnty_code is null;
--

-- delete grads outside the date range. These shouldn't be showing up, but are somehow are.
delete
    -- SELECT *
from dxgrad_current
where dxgrad_dsugrad_dt < to_date(:gradstart) -- update each year
   or dxgrad_dsugrad_dt > to_date(:gradend);
-- update each year
--

-- SELECT * FROM dxgrad_current WHERE dxgrad_gpa > 400

----------------------------------------------------------------------------------------------------
-- Other fixes

-- G-02d - USHE states SSN's can't start with 9, so change those SSNs to Banner IDs.
update dxgrad_current
set dxgrad_ssn = dxgrad_id
where dxgrad_ssn like '9%';
-- 0 updates

-- One-Time Fixes
-- UPDATE dxgrad_current SET dxgrad_ut_cnty_code = 'UT053' WHERE dxgrad_id = '00044185';

-- Find missing County Codes
update dxgrad_current
set dxgrad_ut_cnty_code = (
    select
        s_county_origin
    from students03@dscir s1
    where dsc_pidm = dxgrad_pidm
      and dsc_term_code = (
        select MAX(dsc_term_code)
        from students03@dscir s2
        where dsc_pidm = dxgrad_pidm and banner_term <= dxgrad_term_code_grad))
where dxgrad_ut_cnty_code is null;

-- Find missing State of Origin
update dxgrad_current
set dxgrad_state_origin = (
    select
        s_state_origin
    from students03@dscir s1
    where dsc_pidm = dxgrad_pidm
      and dsc_term_code = (
        select MAX(dsc_term_code)
        from students03@dscir s2
        where dsc_pidm = dxgrad_pidm and banner_term <= dxgrad_term_code_grad))
where dxgrad_state_origin is null;

/*
 FIXES
 Email from Misti Pierce:
 You will be able to remove Arianna Witham 00391116 from your list.  I have spoken with the student, and she will come back in fall 2020 to complete her remaining 3 credits.  I changed her status from �awarded� to �pending� in Banner.
 */

DELETE dxgrad_current
WHERE dxgrad_id = '00391116';

/* USHE Manual Fixes */
update dxgrad_current
set dxgrad_ssn = '483197366'
where'D' || dxgrad_id = 'D00375548';

update dxgrad_current
set dxgrad_ssn = '676645211'
where 'D' || dxgrad_id = 'D00418777';

update dxgrad_current
set dxgrad_ssn = '000395294'
where 'D' || dxgrad_id = 'D00395294';

update dxgrad_current
set dxgrad_hs_code = '051584'
where 'D' || dxgrad_id = 'D00389114';


commit;

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------


/**************************************************************************************************\
|                    STOP HERE AND RUN REPORTS FIRST BEFORE CREATING USHE's FILE                   |
\**************************************************************************************************/

----------------------------------------------------------------------------------------------------
select
    dxgrad_inst as g_inst,                                                                                  -- G-01
    case when LENGTH(dxgrad_ssn) <> '9' then lpad(dxgrad_ssn, 8, '0') else to_char(dxgrad_ssn) end as g_id, -- G-02
    dxgrad_last_name as g_last,                                                                             -- G-03
    dxgrad_first_name as g_first,                                                                           -- "
    dxgrad_middle as g_middle,                                                                              -- "
    dxgrad_suffix as g_suffix,                                                                              -- "
    dxgrad_ut_cnty_code as g_county_origin,                                                                 -- G-04
    to_char(dxgrad_birth_dt, 'YYYYMMDD') as g_dob,                                                          -- G-05
    dxgrad_sex as g_gender,                                                                                 -- G-06
    dxgrad_ethn_h as g_ethnic_h,                                                                            -- G-07
    dxgrad_ethn_a as g_ethnic_a,                                                                            -- "
    dxgrad_ethn_b as g_ethnic_b,                                                                            -- "
    dxgrad_ethn_i as g_ethnic_i,                                                                            -- "
    dxgrad_ethn_p as g_ethnic_p,                                                                            -- "
    dxgrad_ethn_w as g_ethnic_w,                                                                            -- "
    dxgrad_ethn_n as g_ethnic_n,                                                                            -- "
    dxgrad_ethn_u as g_ethnic_u,                                                                            -- "
    to_char(dxgrad_dsugrad_dt, 'YYYYMMDD') as g_date,                                                       -- G-08
    dxgrad_cipc_code as g_cip,                                                                              -- G-09
    dxgrad_degc_code as g_deg_type,                                                                         -- G-10
    lpad(dxgrad_gpa, 4, '0') as g_gpa,                                                                      -- G-11 - must be 4 digits
    lpad(nvl(to_char(dxgrad_trans_hrs), '00000'), 5, '0') as g_trans_total,                                 -- G-12 - must be 5 digits
    lpad(nvl(to_char(dxgrad_grad_hrs), '0000'), 4, '0') as g_grad_hrs,                                      -- G-13
    lpad(nvl(to_char(dxgrad_other_hrs), '0000'), 4, '0') as g_hrs_other,                                    -- G-14 - must be 4 digits
    lpad(nvl(to_char(dxgrad_remed_hrs), '0000'), 4, '0') as g_remedial_hrs,                                 -- G-15 - must be 4 digits
    dxgrad_prev_degr as g_prev_deg_type,                                                                    -- G-16
    dxgrad_ipeds_levl as g_ipeds,                                                                           -- G-17
    nvl(lpad(to_char(dxgrad_req_hrs), 3, '0'), '000') as g_req_hrs_deg,                                     -- G-18 - must be 3 digits
    dxgrad_hs_code as g_high_school,                                                                        -- G-19
    dxgrad_ssid as g_ssid,                                                                                  -- G-20
    'D' || dxgrad_id as g_banner_id,                                                                               -- G-21
    '' as g_we_earn_cont_hrs,                                                                               -- G-22
    '' as g_we_prgm_hrs,                                                                                    -- G-23
    dxgrad_acyr as g_fis_year,                                                                              -- G-24
    dxgrad_ushe_term as g_term,                                                                             -- G-25
    dxgrad_ushe_majr_coll as g_college,                                                                     -- G-26
    (
        select ciptitle
        from ushe_ref_cip2010
        where dxgrad_cipc_code = cip_code) as g_major,                                                      -- G-27
    dxgrad_degc_desc as g_deg_type_name                                                                     -- G-28
from dxgrad_current;


commit;


-- If all looks good, COMMIT;
-- Save the pipe-delimited data as dsc-grad-YY.txt where YY = AY End

/**************************************************************************************************\
|                    YOU ARE DONE! YOU CAN USE THE BELOW QUERIES FOR 2AB REPORT.                   |
\**************************************************************************************************/

--Check for where grad hrs is less than req hrs
SELECT dxgrad_pidm,
       dxgrad_id,
       dxgrad_grad_hrs / 10 AS dxgrad_grad_hrs,
       dxgrad_req_hrs,
       dxgrad_remed_hrs AS dxgrad_remed_hrs,
       dxgrad_trans_hrs as dxgrad_trans_hrs,
       dxgrad_dgmr_prgm,
       dxgrad_term_code_grad,
       dxgrad_levl_code
  FROM dxgrad_current
 WHERE (dxgrad_grad_hrs / 10) < dxgrad_req_hrs
 ORDER BY 1;

-- Checks for which USHE may ask you to verify numbers / counts: ------------------------------------

-- Count (Unduplicated)
select
    count(distinct dxgrad_pidm) as "G-36"
from dxgrad_current;

-- Count (Duplicated)
select
    count(dxgrad_pidm) as "G-37"
from dxgrad_current;

-- IPEDS Level Breakdown (Duplicated)
select
    dxgrad_ipeds_levl,
    count(dxgrad_pidm) as "G-38"
from dxgrad_current
group by dxgrad_ipeds_levl
order by dxgrad_ipeds_levl;

-- Gender Breakdown (Duplicated)
select
    dxgrad_sex,
    count(dxgrad_pidm) as "G-39"
from dxgrad_current
group by dxgrad_sex
order by dxgrad_sex;

-- Gender Breakdown (Unduplicated)
select
    dxgrad_sex,
    count(distinct dxgrad_pidm) as "G-40"
from dxgrad_current
group by dxgrad_sex
order by dxgrad_sex;

-- CIP Code Breakdown (Duplicated)
select
    dxgrad_cipc_code,
    -- dxgrad_majr_desc,
    count(dxgrad_pidm) as "G-41"
from dxgrad_current
group by dxgrad_cipc_code
order by dxgrad_cipc_code;

/*
 Final script to move graduates into dxgrad_all
 */

/*
 INSERT INTO dxgrad_all
    (
      dxgrad_pidm, dxgrad_id, dxgrad_acyr, dxgrad_term_code_grad, dxgrad_dsugrad_dt,
      dxgrad_last_name, dxgrad_first_name, dxgrad_middle, dxgrad_birth_dt, dxgrad_age, dxgrad_sex,
      dxgrad_ethn_code, dxgrad_ethnic_desc, dxgrad_ethn_h, dxgrad_ethn_a, dxgrad_ethn_b,
      dxgrad_ethn_i, dxgrad_ethn_p, dxgrad_ethn_w, dxgrad_ethn_n, dxgrad_ethn_u, dxgrad_prev_degr,
      dxgrad_hs_code, dxgrad_hsgrad_dt, dxgrad_ut_cnty_code, dxgrad_state_origin,
      dxgrad_country_origin, dxgrad_initial_ea, dxgrad_initial_term, dxgrad_initial_pt_ft,
      dxgrad_initial_degint, dxgrad_initial_sport, dxgrad_pell_pd, dxgrad_gpa, dxgrad_grad_hrs,
      dxgrad_other_hrs, dxgrad_trans_hrs, dxgrad_remed_hrs, dxgrad_req_hrs, dxgrad_degc_code,
      dxgrad_grad_majr, dxgrad_majr_desc, dxgrad_majr_conc1, dxgrad_majr_conc2, dxgrad_cipc_code,
      dxgrad_ipeds_levl, dxgrad_levl_code, dxgrad_dgmr_seqno, dxgrad_dgmr_prgm, dxgrad_activity_dt,
      dxgrad_ushe_majr_coll, dxgrad_ushe_majr_desc
    )

    SELECT dxgrad_pidm, dxgrad_id, dxgrad_acyr, dxgrad_term_code_grad, dxgrad_dsugrad_dt,
           dxgrad_last_name, dxgrad_first_name, dxgrad_middle, dxgrad_birth_dt, dxgrad_age,
           dxgrad_sex, dxgrad_ethn_code, dxgrad_ethnic_desc, dxgrad_ethn_h, dxgrad_ethn_a,
           dxgrad_ethn_b, dxgrad_ethn_i, dxgrad_ethn_p, dxgrad_ethn_w, dxgrad_ethn_n, dxgrad_ethn_u,
           dxgrad_prev_degr, dxgrad_hs_code, dxgrad_hsgrad_dt, dxgrad_ut_cnty_code,
           dxgrad_state_origin, dxgrad_country_origin, dxgrad_initial_ea, dxgrad_initial_term,
           dxgrad_initial_pt_ft, dxgrad_initial_degint, dxgrad_initial_sport, dxgrad_pell_pd,
           dxgrad_gpa, dxgrad_grad_hrs, dxgrad_other_hrs, dxgrad_trans_hrs, dxgrad_remed_hrs,
           dxgrad_req_hrs, dxgrad_degc_code, dxgrad_grad_majr, dxgrad_majr_desc, dxgrad_majr_conc1,
           dxgrad_majr_conc2, dxgrad_cipc_code, dxgrad_ipeds_levl, dxgrad_levl_code,
           dxgrad_dgmr_seqno, dxgrad_dgmr_prgm, dxgrad_activity_dt, dxgrad_ushe_majr_coll,
           dxgrad_ushe_majr_desc
    FROM   dxgrad_current;


COMMIT;

SELECT *
FROM dxgrad_all
WHERE dxgrad_acyr = '1920';

DELETE dxgrad_all
WHERE dxgrad_acyr = '1920';


*/




-- end of file