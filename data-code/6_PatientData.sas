/* ------------------------------------------------------------ 	*/
/* TITLE:		 	Create dataset of all unique orthopedic 		*/
/*				 	patients and characteristics					*/
/* AUTHOR:		 	Ian McCarthy									*/
/* 				 	Emory University								*/
/* DATE CREATED: 	9/18/2017										*/
/* DATE EDITED:  	2/23/2021										*/
/* CODE FILE ORDER: 6 of 8											*/
/* OUTPUT:			OrthPatient_Data_2007-2018						*/
/* ------------------------------------------------------------ 	*/
%LET year_data=2007;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;




%LET year_data=2008;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;





%LET year_data=2009;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;






%LET year_data=2010;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;






%LET year_data=2011;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;






%LET year_data=2012;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;






%LET year_data=2013;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;






%LET year_data=2014;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;






%LET year_data=2015;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;






%LET year_data=2016;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;






%LET year_data=2017;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;






%LET year_data=2018;

PROC SQL;
	DROP TABLE WORK.Patient_Data;
	CREATE TABLE WORK.Patient_Data AS
		SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
		FROM MBSF.MBSF_ABCD_&year_data;
QUIT;


PROC SQL;
	DROP TABLE WORK.PatientSet;
	CREATE TABLE WORK.PatientSet AS
		SELECT DISTINCT BENE_ID
		FROM PL027710.MajorJoint_&year_data;
QUIT;

PROC SQL;
	DROP TABLE PL027710.OrthoPatient_Data_&year_data;
	CREATE TABLE PL027710.OrthoPatient_Data_&year_data AS
		SELECT a.BENE_ID, b.*
		FROM WORK.PatientSet AS a
		LEFT JOIN WORK.Patient_Data AS b
		ON a.BENE_ID=b.BENE_ID;
QUIT;
