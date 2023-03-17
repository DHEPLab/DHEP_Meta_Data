PROC PRINTTO LOG='/home/u62056075/DHE_Lab/Log/DTC_cleaning.log' new; run;
/********************************************************************************************
*
* Project : DHEP Lab
*
* Program name : DTC_cleaning
*
* Author : Zhijie Duan
*
* Purpose : This program is the data cleaning program in preparation for meta-analysis.
*
* Note: Standard header taken from :
* https://www.phusewiki.org/wiki/index.php?title=Program_Header
*********************************************************************************************/
%PUT %UPCASE(no)TE: Program being run by 730432936;
OPTIONS NOFULLSTIMER;

/* Assign a libref mydata that accesses the DHEP data folder. */
LIBNAME mydata '/home/u62056075/DHE_Lab/New_Data/DTC';

/* Import the dta file dtc_all */
FILENAME reffile1 '/home/u62056075/DHE_Lab/New_Data/DTC/dtc_all.dta';
PROC IMPORT DATAFILE=reffile1
	DBMS=DTA
	OUT=work.dtc_all;
RUN;

/* Import the dta file dtc_all_addmed */
FILENAME reffile2 '/home/u62056075/DHE_Lab/New_Data/DTC/dtc_all_addmed.dta';
PROC IMPORT DATAFILE=reffile2
	DBMS=DTA
	OUT=work.dtc_all_addmed;
RUN;

/* Split the SP based on disease type - Viral Diarrhea */
PROC SQL;
	CREATE TABLE case0_data AS
	SELECT *, 5 AS clinic_level /* level 5 = Online doctor */
	FROM dtc_all_addmed (keep=case0_: case_type_combine antibiotic corrmedi)
	WHERE case0_case_type=1;
QUIT;

DATA case0_data_formatted;
	SET case0_data;
	FORMAT case0_: f32.; * dta to sas data needs variable length reformat;
RUN;

/* Split the SP based on disease type - Angina */
PROC SQL;
	CREATE TABLE case1_data AS
	SELECT *, 5 AS clinic_level /* level 5 = Online doctor */
	FROM dtc_all_addmed (keep=case1_: case_type_combine antibiotic corrmedi)
	WHERE case1_case_type=1;
QUIT;

DATA case1_data_formatted;
	SET case1_data;
	FORMAT case1_: f32.; * dta to sas data needs variable length reformat;
RUN;

/* Split the SP based on disease type - Bacterial Diarrhea */
PROC SQL;
	CREATE TABLE case3_data AS
	SELECT *, 5 AS clinic_level /* level 5 = Online doctor */
	FROM dtc_all_addmed (keep=case3_: case_type_combine antibiotic corrmedi)
	WHERE case3_case_type=1;
QUIT;

DATA case3_data_formatted;
	SET case3_data;
	FORMAT case3_: f32.; * dta to sas data needs variable length reformat;
RUN;

/* Split the SP based on disease type - TB */
PROC SQL;
	CREATE TABLE case7_data AS
	SELECT *, 5 AS clinic_level /* level 5 = Online doctor */
	FROM dtc_all_addmed (keep=case7_: case_type_combine antibiotic corrmedi)
	WHERE case7_case_type=1;
QUIT;

DATA case7_data_formatted;
	SET case7_data;
	FORMAT case7_: f32.; * dta to sas data needs variable length reformat;
RUN;

/* Rename the variables: diagnostic process, diagnosis outcomes, disease management */
/* Diagnostic process ask patients questions vary by disease
   Create an index measure for each disease
   Compare percent of recommended questions across diseases */
/* variable name + index + survey name */

/* Seven data sets, for each, create three baby data sets
   DTC_vignette, DTC_SP, DTC_doctor */
/* I only find DTC_SP in the shared folder */
/* All questions in 1 or 0, calculate the completion rate by ourselves */
%MACRO dtc_separation(df, case, disease_num, q_num, e_num, disease_abbrev, diag);
DATA new_&case._data;
	disease_type=&disease_num.; * viral diarrhea is type 3;
	SET &case._data_formatted;
	rec_completed_q_pct=round(&case._r_q_num/&q_num., 0.0001);
	rec_completed_e_pct=round(&case._e_q_num/&e_num., 0.0001);
	rec_completed_qe_pct=round(&case._r_qe_num/(&q_num.+&e_num.), 0.0001);
	DROP &case._interview_key &case._survey_start &case._SP_name &case._enumerator_name
		 &case._q1: &case._case_type &case._version &case._platform_code &case._survey_end
		 &case._sssys_irnd &case._has_errors &case._interview_status case_type_combine
		 &case._q2: &case._q3: &case._q4: &case._q5: &case._q6: &case._e: &case._diag:
		 &case._r_q_pct &case._r_e_pct &case._r_qe_pct &case._r_m_ad_num;
	RENAME &case._interview_id=interview_id
		   &case._q7_1=consultation_fee
		   &case._q7_13=medication_fee
		   &case._r_q_num=rec_q_completed_num
		   &case._r_e_num=rec_e_completed_num
		   &case._r_qe_num=rec_qe_completed_num
		   &case._r_e1-&case._r_e&e_num.=rec_e1-rec_e&e_num.
		   &case._r_q1-&case._r_q&q_num.=rec_q1-rec_q&q_num.;
RUN;

DATA mydata.DTC_SP_&disease_abbrev.;
	SET new_&case._data (DROP=&case._q7:);
	IF &case._corrdiag&diag.=1 THEN diag_outcome=1; * fully corrcet;
	ELSE IF &case._pcorrdiag&diag.=1 THEN diag_outcome=2; * partially corrcet;
	ELSE IF &case._wrongdiag&diag.=1 THEN diag_outcome=3; * wrong;
	ELSE diag_outcome=0; * no diagnosis for this item;
	DROP &case._corrdiag: &case._pcorrdiag: &case._wrongdiag:
		 &case._refer_level ;
	RENAME &case._refer=if_refer
		   &case._hospital=if_hospitalize
		   &case._revisit=if_revisit
		   &case._chinesemedicine=if_chinesemedicine
		   &case._herbmedicine=if_herbmedicine
		   antibiotic=if_antibiotic
		   corrmedi=if_correct_medi; * These are disease treatmtent/management variables;
RUN;
%MEND dtc_separation;

/* Call macro functions to create specific datasets for each selected disease */
%dtc_separation(df=case0_data_formatted, case=case0, disease_num=3, q_num=18, e_num=5, disease_abbrev=vdiarr, diag=1);
%dtc_separation(df=case1_data_formatted, case=case1, disease_num=1, q_num=16, e_num=6, disease_abbrev=angina, diag=0);
%dtc_separation(df=case3_data_formatted, case=case3, disease_num=2, q_num=19, e_num=5, disease_abbrev=bdiarr, diag=1);
%dtc_separation(df=case7_data_formatted, case=case7, disease_num=4, q_num=22, e_num=7, disease_abbrev=tb, diag=1);