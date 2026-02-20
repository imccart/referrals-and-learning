/* ------------------------------------------------------------ 	*/
/* TITLE:		 	Find Major Joint Replacements initiated by phy 	*/
/* 				 	referral, clinic referral, or HMO referral  	*/
/* AUTHOR:		 	Ian McCarthy									*/
/* 				 	Emory University								*/
/* DATE CREATED: 	12/31/2018										*/
/* DATE EDITED:  	3/7/2024										*/
/* CODE FILE ORDER: 1 of XX 										*/
/* OUTPUT:			MajorJoint_2007-2018  							*/
/* ------------------------------------------------------------ 	*/

/* Create Table of Inpatient (Hospital Only) Stays for 2007 and 2008 */
/* need UPIN/NPI crosswalk for these data */

%macro process_joint_data1;
	%do year_data=2007 %to 2008;

	DATA WORK.InpatientStays_&year_data;
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
			RIF&year_data..INPATIENT_CLAIMS_12;
	RUN;

	PROC SQL;
		DROP TABLE PL027710.MajorJoint_&year_data;
		CREATE TABLE PL027710.MajorJoint_&year_data AS
		SELECT a.BENE_ID, a.CLM_ID, a.CLM_ADMSN_DT, a.NCH_BENE_DSCHRG_DT, a.CLM_FROM_DT, a.CLM_THRU_DT, a.PRVDR_NUM, 
			CASE
				WHEN a.ORG_NPI_NUM NE '' AND a.ORG_NPI_NUM NE '0000000000' THEN a.ORG_NPI_NUM
				WHEN a.ORG_NPI_NUM='' OR a.ORG_NPI_NUM='0000000000' THEN b.NPI
			ELSE ''
			END AS ORG_NPI_NUM,
			a.OP_PHYSN_UPIN,
			CASE 
				WHEN a.OP_PHYSN_NPI NE '' AND a.OP_PHYSN_NPI NE '0000000000' THEN a.OP_PHYSN_NPI
				WHEN a.OP_PHYSN_NPI='' OR a.OP_PHYSN_NPI='0000000000' THEN c.NPI
			ELSE ''
			END AS OP_PHYSN_NPI,
			a.CLM_DRG_CD, a.ADMTG_DGNS_CD, a.ICD_DGNS_CD1, a.PRNCPAL_DGNS_CD, a.ICD_PRCDR_CD1, 
			a.CLM_PMT_AMT, a.CLM_TOT_CHRG_AMT,
			a.ICD_DGNS_CD2, a.ICD_DGNS_CD3, a.ICD_DGNS_CD4, a.ICD_DGNS_CD5, a.ICD_DGNS_CD6, a.ICD_DGNS_CD7,
			a.ICD_DGNS_CD8, a.ICD_DGNS_CD9, a.ICD_DGNS_CD10,
			a.ICD_PRCDR_CD2, a.ICD_PRCDR_CD3, a.ICD_PRCDR_CD4, a.ICD_PRCDR_CD5,
			a.ICD_PRCDR_CD6, a.ICD_PRCDR_CD7, a.ICD_PRCDR_CD8, a.ICD_PRCDR_CD9, a.ICD_PRCDR_CD10,
			a.PTNT_DSCHRG_STUS_CD AS DCHRG_STS
		FROM WORK.InpatientStays_&year_data AS a
		LEFT JOIN PL027710.PRVN_NPI_Merge_&year_data AS b
			ON a.PRVDR_NUM=b.PRVDR_NUM
		LEFT JOIN PL027710.UPIN_NPI_Merge_&year_data AS c
			ON a.OP_PHYSN_UPIN=c.OP_PHYSN_UPIN
		WHERE CLM_SRC_IP_ADMSN_CD IN ("1","2","3")
		  AND (NCH_CLM_TYPE_CD="60")
		  AND (CLM_IP_ADMSN_TYPE_CD="3")
		  AND (CLM_DRG_CD IN ("469", "470", "461", "462", "485", "486", "487", "488", "489", "480", "481", "482", "483",
		    	"507", "508", "510", "511", "512"));
	QUIT;

	PROC SQL;
		DROP TABLE WORK.MajorJointPatient_&year_data;
		CREATE TABLE WORK.MajorJointPatient_&year_data AS
		SELECT DISTINCT BENE_ID, &year_data as Year
		FROM PL027710.MajorJoint_&year_data;
	QUIT;

	%END;

%mend process_joint_data1;

%process_joint_data1;



%macro process_joint_data2;
	%do year_data=2009 %to 2018;

	DATA WORK.InpatientStays_&year_data;
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
			RIF&year_data..INPATIENT_CLAIMS_12;
	RUN;

	PROC SQL;
		DROP TABLE PL027710.MajorJoint_&year_data;
		CREATE TABLE PL027710.MajorJoint_&year_data AS
		SELECT BENE_ID, CLM_ID, CLM_ADMSN_DT, NCH_BENE_DSCHRG_DT, CLM_FROM_DT, CLM_THRU_DT, PRVDR_NUM, ORG_NPI_NUM, OP_PHYSN_UPIN,
			OP_PHYSN_NPI, CLM_DRG_CD, ADMTG_DGNS_CD, ICD_DGNS_CD1, PRNCPAL_DGNS_CD, ICD_PRCDR_CD1,
			CLM_PMT_AMT, CLM_TOT_CHRG_AMT,
			ICD_DGNS_CD2, ICD_DGNS_CD3, ICD_DGNS_CD4, ICD_DGNS_CD5, ICD_DGNS_CD6, ICD_DGNS_CD7,
			ICD_DGNS_CD8, ICD_DGNS_CD9, ICD_DGNS_CD10,
			ICD_PRCDR_CD2, ICD_PRCDR_CD3, ICD_PRCDR_CD4, ICD_PRCDR_CD5,
			ICD_PRCDR_CD6, ICD_PRCDR_CD7, ICD_PRCDR_CD8, ICD_PRCDR_CD9, ICD_PRCDR_CD10,
			PTNT_DSCHRG_STUS_CD AS DCHRG_STS
		FROM WORK.InpatientStays_&year_data
		WHERE CLM_SRC_IP_ADMSN_CD IN ("1","2","3")
		  AND (NCH_CLM_TYPE_CD="60")
		  AND (CLM_IP_ADMSN_TYPE_CD="3")
		  AND (CLM_DRG_CD IN ("469", "470", "461", "462", "485", "486", "487", "488", "489", "480", "481", "482", "483",
		    	"507", "508", "510", "511", "512"));
	QUIT;

	PROC SQL;
		DROP TABLE WORK.MajorJointPatient_&year_data;
		CREATE TABLE WORK.MajorJointPatient_&year_data AS
		SELECT DISTINCT BENE_ID, &year_data as Year
		FROM PL027710.MajorJoint_&year_data;
	QUIT;


	%END;

%mend process_joint_data2;

%process_joint_data2;



/* Append unique patient datasets */

DATA PL027710.MajorJointPatients_ByYear;
	SET	WORK.MajorJointPatient_2007
  		WORK.MajorJointPatient_2008
		WORK.MajorJointPatient_2009
		WORK.MajorJointPatient_2010
		WORK.MajorJointPatient_2011
		WORK.MajorJointPatient_2012
		WORK.MajorJointPatient_2013
		WORK.MajorJointPatient_2014
		WORK.MajorJointPatient_2015
		WORK.MajorJointPatient_2016
		WORK.MajorJointPatient_2017
		WORK.MajorJointPatient_2018;
RUN;

PROC SQL;
	DROP TABLE PL027710.MajorJointPatients_Unique;
	CREATE TABLE PL027710.MajorJointPatients_Unique AS
	SELECT DISTINCT BENE_ID
	FROM PL027710.MajorJointPatients_ByYear;
QUIT;
