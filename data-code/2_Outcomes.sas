/* ------------------------------------------------------------ */
/* TITLE:		 	Collect outcome data for ortho procedures	*/
/* AUTHOR:		 	Ian McCarthy								*/
/* 				 	Emory University							*/
/* DATE CREATED: 	10/15/2019									*/
/* DATE EDITED:  	4/9/2024									*/
/* CODE FILE ORDER: 2 of XX										*/
/* OUTPUT:			OrthoOutcomes_2007-2018						*/
/* ------------------------------------------------------------ */

/* emergency department claims from revenue codes: 0450-0459, 0981 */
/* need these to identify ED visits that did not lead to IP stays */
/* ignore unplanned ED visits as outcome for now (conditionally irrelevant for physician quality) */


%macro process_joint_outcomes;
	%do year_data=2007 %to 2018;
	%LET year_post=%eval(&year_data+1);

	/* Initial Inpatient Stays */
	PROC SQL;
		DROP TABLE WORK.IP_Patients;
		CREATE TABLE WORK.IP_Patients AS
		SELECT DISTINCT BENE_ID, CLM_ADMSN_DT AS Initial_Admit, NCH_BENE_DSCHRG_DT AS Initial_Discharge,
			CLM_ID AS Initial_ID, CLM_PMT_AMT AS Initial_Mcare_Spend,
			CLM_TOT_CHRG_AMT AS Initial_Mcare_Charge
		FROM PL027710.MajorJoint_&year_data;
	QUIT;

	/* Collect Episode Inpatient Claims */
	DATA WORK.InpatientStack;
		SET	RIF&year_data..INPATIENT_CLAIMS_01
	  		RIF&year_data..INPATIENT_CLAIMS_02
			RIF&year_data..INPATIENT_CLAIMS_03
			RIF&year_data..INPATIENT_CLAIMS_04
			RIF&year_data..INPATIENT_CLAIMS_05
			RIF&year_data..INPATIENT_CLAIMS_06
			RIF&year_data..INPATIENT_CLAIMS_07
			RIF&year_data..INPATIENT_CLAIMS_08
			RIF&year_data..INPATIENT_CLAIMS_09
			RIF&year_data..INPATIENT_CLAIMS_10
			RIF&year_data..INPATIENT_CLAIMS_11
			RIF&year_data..INPATIENT_CLAIMS_12
			RIF&year_post..INPATIENT_CLAIMS_01
			RIF&year_post..INPATIENT_CLAIMS_02
			RIF&year_post..INPATIENT_CLAIMS_03;
	RUN;

	PROC SQL;
		DROP TABLE WORK.IP_Unplanned_Readmit;
		CREATE TABLE WORK.IP_Unplanned_Readmit AS
		SELECT a.BENE_ID, CLM_ID, CLM_PMT_AMT, CLM_TOT_CHRG_AMT, 
			  CLM_ADMSN_DT AS Admit, NCH_BENE_DSCHRG_DT AS Discharge,
			  ADMTG_DGNS_CD, ICD_DGNS_CD1, PRNCPAL_DGNS_CD,
			  ICD_DGNS_CD2, ICD_DGNS_CD3, ICD_DGNS_CD4, ICD_DGNS_CD5, ICD_DGNS_CD6, ICD_DGNS_CD7,
			  ICD_DGNS_CD8, ICD_DGNS_CD9, ICD_DGNS_CD10,
			  ICD_PRCDR_CD1, ICD_PRCDR_CD2, ICD_PRCDR_CD3, ICD_PRCDR_CD4, ICD_PRCDR_CD5,
			  ICD_PRCDR_CD6, ICD_PRCDR_CD7, ICD_PRCDR_CD8, ICD_PRCDR_CD9, ICD_PRCDR_CD10,
			  PTNT_DSCHRG_STUS_CD AS DCHRG_STS,
			  b.Initial_Admit, b.Initial_Discharge, b.Initial_ID
		FROM WORK.InpatientStack AS a
		INNER JOIN WORK.IP_Patients AS b
			ON a.BENE_ID=b.BENE_ID
		WHERE (NCH_CLM_TYPE_CD="60")
		  AND (CLM_IP_ADMSN_TYPE_CD NE "3");
	QUIT;

	PROC SQL;
		DROP TABLE WORK.IP_Initial;
		CREATE TABLE WORK.IP_Initial AS
		SELECT BENE_ID, CLM_ID, CLM_PMT_AMT, CLM_TOT_CHRG_AMT, 
			  CLM_ADMSN_DT AS Admit, NCH_BENE_DSCHRG_DT AS Discharge,
			  ADMTG_DGNS_CD, ICD_DGNS_CD1, PRNCPAL_DGNS_CD,
			  ICD_DGNS_CD2, ICD_DGNS_CD3, ICD_DGNS_CD4, ICD_DGNS_CD5, ICD_DGNS_CD6, ICD_DGNS_CD7,
			  ICD_DGNS_CD8, ICD_DGNS_CD9, ICD_DGNS_CD10,
			  ICD_PRCDR_CD1, ICD_PRCDR_CD2, ICD_PRCDR_CD3, ICD_PRCDR_CD4, ICD_PRCDR_CD5,
			  ICD_PRCDR_CD6, ICD_PRCDR_CD7, ICD_PRCDR_CD8, ICD_PRCDR_CD9, ICD_PRCDR_CD10,
			  DCHRG_STS, CLM_ADMSN_DT AS Initial_Admit, NCH_BENE_DSCHRG_DT AS Initial_Discharge,
			  CLM_ID AS Initial_ID
		FROM PL027710.MajorJoint_&year_data;
	QUIT;

	DATA WORK.IP_Unplanned;
		SET WORK.IP_Unplanned_Readmit WORK.IP_Initial;
	RUN;

	PROC SORT DATA=WORK.IP_Unplanned;
		BY BENE_ID CLM_ID Admit Discharge Initial_Admit Initial_Discharge Initial_ID;
	RUN;

	PROC TRANSPOSE DATA=WORK.IP_Unplanned OUT=WORK.IP_Unplanned_DIAG;
		BY BENE_ID CLM_ID Admit Discharge Initial_Admit Initial_Discharge Initial_ID;
		VAR ADMTG_DGNS_CD PRNCPAL_DGNS_CD ICD_DGNS_CD1 ICD_DGNS_CD2 ICD_DGNS_CD3 ICD_DGNS_CD4
				ICD_DGNS_CD5 ICD_DGNS_CD6 ICD_DGNS_CD7 ICD_DGNS_CD8 ICD_DGNS_CD9 ICD_DGNS_CD10;
	RUN;
	
	PROC SQL;
		DROP TABLE WORK.IP_Unplanned_DIAG_Match1;
		CREATE TABLE WORK.IP_Unplanned_DIAG_Match1 AS
		SELECT a.BENE_ID, a.CLM_ID, a.Admit, a.Discharge, a.Initial_Admit, a.Initial_Discharge, a.Initial_ID,
			   a.icd_code1, b.icd_code2, b.Category, b.Days_from_discharge
		FROM (SELECT BENE_ID, CLM_ID, Admit, Discharge, Initial_Admit, Initial_Discharge, Initial_ID, 
				col1 AS icd_code1 FROM WORK.IP_Unplanned_DIAG WHERE Admit<'01OCT2015'd) AS a
		INNER JOIN (SELECT Category, Days_from_discharge, 
						COMPRESS(TRANWRD(SUBSTR(ICD9_Diagnosis_Desc, 1, INDEX(ICD9_Diagnosis_Desc, ' ') -1), '.', '')) AS icd_code2
						FROM PL027710.QUALITY_ICD9_DIAGNOSIS) AS b
			ON a.icd_code1=b.icd_code2
		WHERE a.Admit>=a.Initial_Admit AND a.Admit<=(a.Initial_Discharge + b.Days_from_discharge);
	QUIT;

	PROC SQL;
		DROP TABLE WORK.IP_Unplanned_DIAG_Match2;
		CREATE TABLE WORK.IP_Unplanned_DIAG_Match2 AS
		SELECT a.BENE_ID, a.CLM_ID, a.Admit, a.Discharge, a.Initial_Admit, a.Initial_Discharge, a.Initial_ID,
			   a.icd_code1, b.icd_code2, b.Category, b.Days_from_discharge
		FROM (SELECT BENE_ID, CLM_ID, Admit, Discharge, Initial_Admit, Initial_Discharge, Initial_ID, 
				col1 AS icd_code1 FROM WORK.IP_Unplanned_DIAG WHERE Admit>='01OCT2015'd) AS a
		INNER JOIN (SELECT Category, Days_from_discharge, 
						COMPRESS(TRANWRD(SUBSTR(ICD10_Diagnosis, 1, INDEX(ICD10_Diagnosis, ' ') -1), '.', '')) AS icd_code2
						FROM PL027710.QUALITY_ICD10_DIAGNOSIS) AS b
			ON a.icd_code1=b.icd_code2
		WHERE a.Admit>=a.Initial_Admit AND a.Admit<=(a.Initial_Discharge + b.Days_from_discharge);
	QUIT;

	DATA WORK.IP_Unplanned_DIAG_Match;
		SET WORK.IP_Unplanned_DIAG_Match1 WORK.IP_Unplanned_DIAG_Match2;
	RUN;

	PROC TRANSPOSE DATA=WORK.IP_Unplanned OUT=WORK.IP_Unplanned_PROC;
		BY BENE_ID CLM_ID Admit Discharge Initial_Admit Initial_Discharge Initial_ID;
		VAR ICD_PRCDR_CD1 ICD_PRCDR_CD2 ICD_PRCDR_CD3 ICD_PRCDR_CD4 ICD_PRCDR_CD5
			  ICD_PRCDR_CD6 ICD_PRCDR_CD7 ICD_PRCDR_CD8 ICD_PRCDR_CD9 ICD_PRCDR_CD10;
	RUN;
	
	PROC SQL;
		DROP TABLE WORK.IP_Unplanned_PROC_Match1;
		CREATE TABLE WORK.IP_Unplanned_PROC_Match1 AS
		SELECT a.BENE_ID, a.CLM_ID, a.Admit, a.Discharge, a.Initial_Admit, a.Initial_Discharge, a.Initial_ID,
			   a.icd_code1, b.icd_code2, b.Category
		FROM (SELECT BENE_ID, CLM_ID, Admit, Discharge, Initial_Admit, Initial_Discharge, Initial_ID, 
				col1 AS icd_code1 FROM WORK.IP_Unplanned_PROC WHERE Admit<'01OCT2015'd) AS a
		INNER JOIN (SELECT Category,
						COMPRESS(TRANWRD(SUBSTR(ICD9_Procedure_Desc, 1, INDEX(ICD9_Procedure_Desc, ' ') -1), '.', '')) AS icd_code2
						FROM PL027710.QUALITY_ICD9_PROCEDURE) AS b
			ON a.icd_code1=b.icd_code2;
	QUIT;

	PROC SQL;
		DROP TABLE WORK.IP_Unplanned_PROC_Match2;
		CREATE TABLE WORK.IP_Unplanned_PROC_Match2 AS
		SELECT a.BENE_ID, a.CLM_ID, a.Admit, a.Discharge, a.Initial_Admit, a.Initial_Discharge, a.Initial_ID,
			   a.icd_code1, b.icd_code2, b.Category
		FROM (SELECT BENE_ID, CLM_ID, Admit, Discharge, Initial_Admit, Initial_Discharge, Initial_ID, 
				col1 AS icd_code1 FROM WORK.IP_Unplanned_PROC WHERE Admit>='01OCT2015'd) AS a
		INNER JOIN (SELECT Category,
						COMPRESS(TRANWRD(SUBSTR(ICD10_Procedure, 1, INDEX(ICD10_Procedure, ' ') -1), '.', '')) AS icd_code2
						FROM PL027710.QUALITY_ICD10_PROCEDURE) AS b
			ON a.icd_code1=b.icd_code2;
	QUIT;

	DATA WORK.IP_Unplanned_PROC_Match;
		SET WORK.IP_Unplanned_PROC_Match1 WORK.IP_Unplanned_PROC_Match2;
	RUN;

	PROC SQL;
		DROP TABLE WORK.IP_Complications;
		CREATE TABLE WORK.IP_Complications AS
		SELECT a.*, b.Proc_Code_Required, c.Category AS Proc_Code_Observed
		FROM WORK.IP_Unplanned_DIAG_Match AS a
		LEFT JOIN (SELECT DISTINCT Category AS Proc_Code_Required 
					FROM PL027710.QUALITY_ICD9_PROCEDURE) AS b
			ON a.Category=b.Proc_Code_Required
		LEFT JOIN WORK.IP_Unplanned_PROC_Match AS c
			ON a.BENE_ID=c.BENE_ID AND a.Admit=c.Admit AND a.Discharge=c.Discharge
				AND a.CLM_ID=c.CLM_ID AND a.Category=c.Category;
	QUIT;

	PROC SQL;
		DROP TABLE PL027710.IP_Complications_&year_data;
		CREATE TABLE PL027710.IP_Complications_&year_data AS
		SELECT BENE_ID, Initial_Admit, Initial_Discharge, Initial_ID, Category, COUNT(DISTINCT CLM_ID) AS Event_Count 
		FROM (SELECT * 
			  FROM WORK.IP_COMPLICATIONS 
			  WHERE Proc_Code_Required='' OR (Proc_Code_Required NE '' AND Proc_Code_Observed NE ''))
		GROUP BY BENE_ID, Initial_Admit, Initial_Discharge, Initial_ID, Category;
	QUIT;

	PROC SQL;
		DROP TABLE PL027710.IP_Readmit_&year_data;
		CREATE TABLE PL027710.IP_Readmit_&year_data AS
		SELECT BENE_ID, Initial_Admit, Initial_Discharge, Initial_ID, 'Readmit' AS Category, COUNT(DISTINCT CLM_ID) AS Event_Count
		FROM WORK.IP_Unplanned
		WHERE Admit>Initial_Discharge AND Admit<=Initial_Discharge+90
		GROUP BY BENE_ID, Initial_Admit, Initial_Discharge, Initial_ID;
	QUIT;

	DATA PL027710.OrthoOutcomes_&year_data;
		SET PL027710.IP_Complications_&year_data PL027710.IP_Readmit_&year_data;
	RUN;

	PROC SORT data=PL027710.OrthoOutcomes_&year_data;
		BY BENE_ID Initial_Admit Initial_Discharge Initial_ID Category Event_Count;
	RUN;

	%END;

%mend process_joint_outcomes;

%process_joint_outcomes;

