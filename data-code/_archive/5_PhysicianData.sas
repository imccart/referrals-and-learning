/* ------------------------------------------------------------ */
/* TITLE:		 Create Dataset of All Unique Physician IDs     */
/* AUTHOR:		 Ian McCarthy									*/
/* 				 Emory University								*/
/* DATE CREATED: 5/12/2015										*/
/* DATE EDITED:  2/23/2021										*/
/* CODE FILE ORDER: 5 of 8										*/
/*		Physician_Data_2007 - 2015  						    */
/* ------------------------------------------------------------ */

%LET year_data=2007;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
	DROP TABLE WORK.Carrier_Full;
	CREATE TABLE WORK.Carrier_Full AS
	SELECT CASE 
			WHEN a.PRF_PHYSN_NPI NE '' AND a.PRF_PHYSN_NPI NE '0000000000' THEN a.PRF_PHYSN_NPI
			WHEN a.PRF_PHYSN_NPI='' OR a.PRF_PHYSN_NPI='0000000000' THEN b.NPI
		ELSE ''
		END AS Physician_NPI, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, a.BETOS_CD
    FROM IN027710.BCARLINEK07_R6723 AS a
	LEFT JOIN PL027710.UPIN_NPI_Merge_2007 AS b
		ON a.PRF_PHYSN_UPIN=b.OP_PHYSN_UPIN;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location;
	CREATE TABLE WORK.Physician_Location AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location OUT=WORK.Physician_Location;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Location;
SET WORK.Physician_Location;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip, Zip_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Location_Claims;
SET WORK.Physician_Location;
	MERGE WORK.Wide_Phy_Zip (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;



/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_1,1,5) AS Carrier_Zip_Primary,
	  SUBSTR(d.Zip_2,1,5) AS Carrier_Zip_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_&year_data AS g
	  ON a.Physician_NPI=g.NPI
	ORDER BY Physician_NPI;
QUIT;




%LET year_data=2008;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
	DROP TABLE WORK.Carrier_Full;
	CREATE TABLE WORK.Carrier_Full AS
	SELECT CASE 
			WHEN a.PRF_PHYSN_NPI NE '' AND a.PRF_PHYSN_NPI NE '0000000000' THEN a.PRF_PHYSN_NPI
			WHEN a.PRF_PHYSN_NPI='' OR a.PRF_PHYSN_NPI='0000000000' THEN b.NPI
		ELSE ''
		END AS Physician_NPI, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, a.BETOS_CD
    FROM IN027710.BCARLINEK08_R6723 AS a
	LEFT JOIN PL027710.UPIN_NPI_Merge_2008 AS b
		ON a.PRF_PHYSN_UPIN=b.OP_PHYSN_UPIN;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location;
	CREATE TABLE WORK.Physician_Location AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location OUT=WORK.Physician_Location;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Location;
SET WORK.Physician_Location;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip, Zip_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Location_Claims;
SET WORK.Physician_Location;
	MERGE WORK.Wide_Phy_Zip (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;



/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_1,1,5) AS Carrier_Zip_Primary,
	  SUBSTR(d.Zip_2,1,5) AS Carrier_Zip_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_&year_data AS g
	  ON a.Physician_NPI=g.NPI
	ORDER BY Physician_NPI;
QUIT;





%LET year_data=2009;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
  DROP TABLE WORK.OrthoCarrier1;
  CREATE TABLE WORK.OrthoCarrier1 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, 
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_01 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier2;
  CREATE TABLE WORK.OrthoCarrier2 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_02 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


PROC SQL;
  DROP TABLE WORK.OrthoCarrier3;
  CREATE TABLE WORK.OrthoCarrier3 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_03 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier4;
  CREATE TABLE WORK.OrthoCarrier4 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_04 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier5;
  CREATE TABLE WORK.OrthoCarrier5 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_05 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier6;
  CREATE TABLE WORK.OrthoCarrier6 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_06 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier7;
  CREATE TABLE WORK.OrthoCarrier7 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_07 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier8;
  CREATE TABLE WORK.OrthoCarrier8 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_08 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier9;
  CREATE TABLE WORK.OrthoCarrier9 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_09 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier10;
  CREATE TABLE WORK.OrthoCarrier10 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_10 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier11;
  CREATE TABLE WORK.OrthoCarrier11 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_11 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier12;
  CREATE TABLE WORK.OrthoCarrier12 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2009.BCARRIER_LINE_12 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


DATA WORK.Carrier_Full;
	SET	WORK.OrthoCarrier1
  		WORK.OrthoCarrier2
		WORK.OrthoCarrier3
		WORK.OrthoCarrier4
		WORK.OrthoCarrier5
		WORK.OrthoCarrier6
		WORK.OrthoCarrier7
		WORK.OrthoCarrier8
		WORK.OrthoCarrier9
		WORK.OrthoCarrier10
		WORK.OrthoCarrier11
		WORK.OrthoCarrier12;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location1;
	CREATE TABLE WORK.Physician_Location1 AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip_Performing, count(distinct CLM_ID) AS Claims_Performing
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Location2;
	CREATE TABLE WORK.Physician_Location2 AS
	SELECT Physician_NPI, PHYSN_ZIP_CD AS Zip_POS, count(distinct CLM_ID) AS Claims_POS
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PHYSN_ZIP_CD
	ORDER BY Physician_NPI, PHYSN_ZIP_CD;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location1 OUT=WORK.Physician_Location1;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Location1;
SET WORK.Physician_Location1;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location1
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_Performing, Zip_Performing_);
%temp_wide(Claims_Performing, Claims_Performing_);

DATA WORK.Physician_Location1_Claims;
SET WORK.Physician_Location1;
	MERGE WORK.Wide_Phy_Zip_Performing (drop=_name_)
		  WORK.Wide_Phy_Claims_Performing (drop=_name_);
RUN;


/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_Performing_1,1,5) AS Carrier_Zip_Perf_Primary,
	  SUBSTR(d.Zip_Performing_2,1,5) AS Carrier_Zip_Perf_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location1_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_&year_data AS g
	  ON a.Physician_NPI=g.NPI
	ORDER BY Physician_NPI;
QUIT;











%LET year_data=2010;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
  DROP TABLE WORK.OrthoCarrier1;
  CREATE TABLE WORK.OrthoCarrier1 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, 
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_01 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier2;
  CREATE TABLE WORK.OrthoCarrier2 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_02 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


PROC SQL;
  DROP TABLE WORK.OrthoCarrier3;
  CREATE TABLE WORK.OrthoCarrier3 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_03 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier4;
  CREATE TABLE WORK.OrthoCarrier4 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_04 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier5;
  CREATE TABLE WORK.OrthoCarrier5 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_05 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier6;
  CREATE TABLE WORK.OrthoCarrier6 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_06 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier7;
  CREATE TABLE WORK.OrthoCarrier7 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_07 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier8;
  CREATE TABLE WORK.OrthoCarrier8 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_08 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier9;
  CREATE TABLE WORK.OrthoCarrier9 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_09 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier10;
  CREATE TABLE WORK.OrthoCarrier10 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_10 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier11;
  CREATE TABLE WORK.OrthoCarrier11 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_11 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier12;
  CREATE TABLE WORK.OrthoCarrier12 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2010.BCARRIER_LINE_12 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


DATA WORK.Carrier_Full;
	SET	WORK.OrthoCarrier1
  		WORK.OrthoCarrier2
		WORK.OrthoCarrier3
		WORK.OrthoCarrier4
		WORK.OrthoCarrier5
		WORK.OrthoCarrier6
		WORK.OrthoCarrier7
		WORK.OrthoCarrier8
		WORK.OrthoCarrier9
		WORK.OrthoCarrier10
		WORK.OrthoCarrier11
		WORK.OrthoCarrier12;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location1;
	CREATE TABLE WORK.Physician_Location1 AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip_Performing, count(distinct CLM_ID) AS Claims_Performing
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Location2;
	CREATE TABLE WORK.Physician_Location2 AS
	SELECT Physician_NPI, PHYSN_ZIP_CD AS Zip_POS, count(distinct CLM_ID) AS Claims_POS
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PHYSN_ZIP_CD
	ORDER BY Physician_NPI, PHYSN_ZIP_CD;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location1 OUT=WORK.Physician_Location1;
	BY Physician_NPI DESCENDING Claims_Performing;
RUN;

DATA WORK.Physician_Location1;
SET WORK.Physician_Location1;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;


%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location1
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_Performing, Zip_Performing_);
%temp_wide(Claims_Performing, Claims_Performing_);

DATA WORK.Physician_Location1_Claims;
SET WORK.Physician_Location1;
	MERGE WORK.Wide_Phy_Zip_Performing (drop=_name_)
		  WORK.Wide_Phy_Claims_Performing (drop=_name_);
RUN;


/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_Performing_1,1,5) AS Carrier_Zip_Perf_Primary,
	  SUBSTR(d.Zip_Performing_2,1,5) AS Carrier_Zip_Perf_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location1_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_&year_data AS g
	  ON a.Physician_NPI=g.NPI
	ORDER BY Physician_NPI;
QUIT;





%LET year_data=2011;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
  DROP TABLE WORK.OrthoCarrier1;
  CREATE TABLE WORK.OrthoCarrier1 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, 
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_01 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier2;
  CREATE TABLE WORK.OrthoCarrier2 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_02 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


PROC SQL;
  DROP TABLE WORK.OrthoCarrier3;
  CREATE TABLE WORK.OrthoCarrier3 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_03 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier4;
  CREATE TABLE WORK.OrthoCarrier4 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_04 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier5;
  CREATE TABLE WORK.OrthoCarrier5 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_05 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier6;
  CREATE TABLE WORK.OrthoCarrier6 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_06 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier7;
  CREATE TABLE WORK.OrthoCarrier7 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_07 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier8;
  CREATE TABLE WORK.OrthoCarrier8 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_08 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier9;
  CREATE TABLE WORK.OrthoCarrier9 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_09 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier10;
  CREATE TABLE WORK.OrthoCarrier10 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_10 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier11;
  CREATE TABLE WORK.OrthoCarrier11 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_11 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier12;
  CREATE TABLE WORK.OrthoCarrier12 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2011.BCARRIER_LINE_12 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


DATA WORK.Carrier_Full;
	SET	WORK.OrthoCarrier1
  		WORK.OrthoCarrier2
		WORK.OrthoCarrier3
		WORK.OrthoCarrier4
		WORK.OrthoCarrier5
		WORK.OrthoCarrier6
		WORK.OrthoCarrier7
		WORK.OrthoCarrier8
		WORK.OrthoCarrier9
		WORK.OrthoCarrier10
		WORK.OrthoCarrier11
		WORK.OrthoCarrier12;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location1;
	CREATE TABLE WORK.Physician_Location1 AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip_Performing, count(distinct CLM_ID) AS Claims_Performing
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Location2;
	CREATE TABLE WORK.Physician_Location2 AS
	SELECT Physician_NPI, PHYSN_ZIP_CD AS Zip_POS, count(distinct CLM_ID) AS Claims_POS
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PHYSN_ZIP_CD
	ORDER BY Physician_NPI, PHYSN_ZIP_CD;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location1 OUT=WORK.Physician_Location1;
	BY Physician_NPI DESCENDING Claims_Performing;
RUN;

DATA WORK.Physician_Location1;
SET WORK.Physician_Location1;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location1
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_Performing, Zip_Performing_);
%temp_wide(Claims_Performing, Claims_Performing_);

DATA WORK.Physician_Location1_Claims;
SET WORK.Physician_Location1;
	MERGE WORK.Wide_Phy_Zip_Performing (drop=_name_)
		  WORK.Wide_Phy_Claims_Performing (drop=_name_);
RUN;


/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_Performing_1,1,5) AS Carrier_Zip_Perf_Primary,
	  SUBSTR(d.Zip_Performing_2,1,5) AS Carrier_Zip_Perf_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location1_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_&year_data AS g
	  ON a.Physician_NPI=g.NPI
	ORDER BY Physician_NPI;
QUIT;




%LET year_data=2012;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
  DROP TABLE WORK.OrthoCarrier1;
  CREATE TABLE WORK.OrthoCarrier1 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, 
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_01 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier2;
  CREATE TABLE WORK.OrthoCarrier2 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_02 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


PROC SQL;
  DROP TABLE WORK.OrthoCarrier3;
  CREATE TABLE WORK.OrthoCarrier3 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_03 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier4;
  CREATE TABLE WORK.OrthoCarrier4 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_04 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier5;
  CREATE TABLE WORK.OrthoCarrier5 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_05 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier6;
  CREATE TABLE WORK.OrthoCarrier6 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_06 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier7;
  CREATE TABLE WORK.OrthoCarrier7 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_07 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier8;
  CREATE TABLE WORK.OrthoCarrier8 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_08 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier9;
  CREATE TABLE WORK.OrthoCarrier9 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_09 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier10;
  CREATE TABLE WORK.OrthoCarrier10 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_10 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier11;
  CREATE TABLE WORK.OrthoCarrier11 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_11 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier12;
  CREATE TABLE WORK.OrthoCarrier12 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2012.BCARRIER_LINE_12 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


DATA WORK.Carrier_Full;
	SET	WORK.OrthoCarrier1
  		WORK.OrthoCarrier2
		WORK.OrthoCarrier3
		WORK.OrthoCarrier4
		WORK.OrthoCarrier5
		WORK.OrthoCarrier6
		WORK.OrthoCarrier7
		WORK.OrthoCarrier8
		WORK.OrthoCarrier9
		WORK.OrthoCarrier10
		WORK.OrthoCarrier11
		WORK.OrthoCarrier12;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location1;
	CREATE TABLE WORK.Physician_Location1 AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip_Performing, count(distinct CLM_ID) AS Claims_Performing
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Location2;
	CREATE TABLE WORK.Physician_Location2 AS
	SELECT Physician_NPI, PHYSN_ZIP_CD AS Zip_POS, count(distinct CLM_ID) AS Claims_POS
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PHYSN_ZIP_CD
	ORDER BY Physician_NPI, PHYSN_ZIP_CD;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location1 OUT=WORK.Physician_Location1;
	BY Physician_NPI DESCENDING Claims_Performing;
RUN;
PROC SORT DATA=WORK.Physician_Location2 OUT=WORK.Physician_Location2;
	BY Physician_NPI DESCENDING Claims_POS;
RUN;

DATA WORK.Physician_Location1;
SET WORK.Physician_Location1;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

DATA WORK.Physician_Location2;
SET WORK.Physician_Location2;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location1
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_Performing, Zip_Performing_);
%temp_wide(Claims_Performing, Claims_Performing_);

DATA WORK.Physician_Location1_Claims;
SET WORK.Physician_Location1;
	MERGE WORK.Wide_Phy_Zip_Performing (drop=_name_)
		  WORK.Wide_Phy_Claims_Performing (drop=_name_);
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location2
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_POS, Zip_POS_);
%temp_wide(Claims_POS, Claims_POS_);

DATA WORK.Physician_Location2_Claims;
SET WORK.Physician_Location2;
	MERGE WORK.Wide_Phy_Zip_POS (drop=_name_)
		  WORK.Wide_Phy_Claims_POS (drop=_name_);
RUN;


/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_Performing_1,1,5) AS Carrier_Zip_Perf_Primary,
	  SUBSTR(d.Zip_Performing_2,1,5) AS Carrier_Zip_Perf_Secondary,
	  SUBSTR(h.Zip_POS_1,1,5) AS Carrier_Zip_POS_Primary,
	  SUBSTR(h.Zip_POS_2,1,5) AS Carrier_Zip_POS_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location1_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_&year_data AS g
	  ON a.Physician_NPI=g.NPI
	LEFT JOIN WORK.Physician_Location2_Claims AS h
	  ON a.Physician_NPI=h.Physician_NPI
	ORDER BY Physician_NPI;
QUIT;




%LET year_data=2013;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
  DROP TABLE WORK.OrthoCarrier1;
  CREATE TABLE WORK.OrthoCarrier1 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, 
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_01 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier2;
  CREATE TABLE WORK.OrthoCarrier2 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_02 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


PROC SQL;
  DROP TABLE WORK.OrthoCarrier3;
  CREATE TABLE WORK.OrthoCarrier3 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_03 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier4;
  CREATE TABLE WORK.OrthoCarrier4 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_04 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier5;
  CREATE TABLE WORK.OrthoCarrier5 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_05 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier6;
  CREATE TABLE WORK.OrthoCarrier6 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_06 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier7;
  CREATE TABLE WORK.OrthoCarrier7 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_07 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier8;
  CREATE TABLE WORK.OrthoCarrier8 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_08 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier9;
  CREATE TABLE WORK.OrthoCarrier9 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_09 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier10;
  CREATE TABLE WORK.OrthoCarrier10 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_10 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier11;
  CREATE TABLE WORK.OrthoCarrier11 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_11 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier12;
  CREATE TABLE WORK.OrthoCarrier12 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2013.BCARRIER_LINE_12 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


DATA WORK.Carrier_Full;
	SET	WORK.OrthoCarrier1
  		WORK.OrthoCarrier2
		WORK.OrthoCarrier3
		WORK.OrthoCarrier4
		WORK.OrthoCarrier5
		WORK.OrthoCarrier6
		WORK.OrthoCarrier7
		WORK.OrthoCarrier8
		WORK.OrthoCarrier9
		WORK.OrthoCarrier10
		WORK.OrthoCarrier11
		WORK.OrthoCarrier12;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location1;
	CREATE TABLE WORK.Physician_Location1 AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip_Performing, count(distinct CLM_ID) AS Claims_Performing
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Location2;
	CREATE TABLE WORK.Physician_Location2 AS
	SELECT Physician_NPI, PHYSN_ZIP_CD AS Zip_POS, count(distinct CLM_ID) AS Claims_POS
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PHYSN_ZIP_CD
	ORDER BY Physician_NPI, PHYSN_ZIP_CD;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location1 OUT=WORK.Physician_Location1;
	BY Physician_NPI DESCENDING Claims_Performing;
RUN;
PROC SORT DATA=WORK.Physician_Location2 OUT=WORK.Physician_Location2;
	BY Physician_NPI DESCENDING Claims_POS;
RUN;

DATA WORK.Physician_Location1;
SET WORK.Physician_Location1;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

DATA WORK.Physician_Location2;
SET WORK.Physician_Location2;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location1
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_Performing, Zip_Performing_);
%temp_wide(Claims_Performing, Claims_Performing_);

DATA WORK.Physician_Location1_Claims;
SET WORK.Physician_Location1;
	MERGE WORK.Wide_Phy_Zip_Performing (drop=_name_)
		  WORK.Wide_Phy_Claims_Performing (drop=_name_);
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location2
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_POS, Zip_POS_);
%temp_wide(Claims_POS, Claims_POS_);

DATA WORK.Physician_Location2_Claims;
SET WORK.Physician_Location2;
	MERGE WORK.Wide_Phy_Zip_POS (drop=_name_)
		  WORK.Wide_Phy_Claims_POS (drop=_name_);
RUN;


/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_Performing_1,1,5) AS Carrier_Zip_Perf_Primary,
	  SUBSTR(d.Zip_Performing_2,1,5) AS Carrier_Zip_Perf_Secondary,
	  SUBSTR(h.Zip_POS_1,1,5) AS Carrier_Zip_POS_Primary,
	  SUBSTR(h.Zip_POS_2,1,5) AS Carrier_Zip_POS_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location1_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_&year_data AS g
	  ON a.Physician_NPI=g.NPI
	LEFT JOIN WORK.Physician_Location2_Claims AS h
	  ON a.Physician_NPI=h.Physician_NPI
	ORDER BY Physician_NPI;
QUIT;




%LET year_data=2014;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
  DROP TABLE WORK.OrthoCarrier1;
  CREATE TABLE WORK.OrthoCarrier1 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, 
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_01 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier2;
  CREATE TABLE WORK.OrthoCarrier2 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_02 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


PROC SQL;
  DROP TABLE WORK.OrthoCarrier3;
  CREATE TABLE WORK.OrthoCarrier3 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_03 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier4;
  CREATE TABLE WORK.OrthoCarrier4 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_04 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier5;
  CREATE TABLE WORK.OrthoCarrier5 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_05 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier6;
  CREATE TABLE WORK.OrthoCarrier6 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_06 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier7;
  CREATE TABLE WORK.OrthoCarrier7 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_07 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier8;
  CREATE TABLE WORK.OrthoCarrier8 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_08 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier9;
  CREATE TABLE WORK.OrthoCarrier9 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_09 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier10;
  CREATE TABLE WORK.OrthoCarrier10 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_10 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier11;
  CREATE TABLE WORK.OrthoCarrier11 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_11 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier12;
  CREATE TABLE WORK.OrthoCarrier12 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2014.BCARRIER_LINE_12 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


DATA WORK.Carrier_Full;
	SET	WORK.OrthoCarrier1
  		WORK.OrthoCarrier2
		WORK.OrthoCarrier3
		WORK.OrthoCarrier4
		WORK.OrthoCarrier5
		WORK.OrthoCarrier6
		WORK.OrthoCarrier7
		WORK.OrthoCarrier8
		WORK.OrthoCarrier9
		WORK.OrthoCarrier10
		WORK.OrthoCarrier11
		WORK.OrthoCarrier12;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location1;
	CREATE TABLE WORK.Physician_Location1 AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip_Performing, count(distinct CLM_ID) AS Claims_Performing
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Location2;
	CREATE TABLE WORK.Physician_Location2 AS
	SELECT Physician_NPI, PHYSN_ZIP_CD AS Zip_POS, count(distinct CLM_ID) AS Claims_POS
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PHYSN_ZIP_CD
	ORDER BY Physician_NPI, PHYSN_ZIP_CD;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location1 OUT=WORK.Physician_Location1;
	BY Physician_NPI DESCENDING Claims_Performing;
RUN;
PROC SORT DATA=WORK.Physician_Location2 OUT=WORK.Physician_Location2;
	BY Physician_NPI DESCENDING Claims_POS;
RUN;

DATA WORK.Physician_Location1;
SET WORK.Physician_Location1;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

DATA WORK.Physician_Location2;
SET WORK.Physician_Location2;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location1
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_Performing, Zip_Performing_);
%temp_wide(Claims_Performing, Claims_Performing_);

DATA WORK.Physician_Location1_Claims;
SET WORK.Physician_Location1;
	MERGE WORK.Wide_Phy_Zip_Performing (drop=_name_)
		  WORK.Wide_Phy_Claims_Performing (drop=_name_);
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location2
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_POS, Zip_POS_);
%temp_wide(Claims_POS, Claims_POS_);

DATA WORK.Physician_Location2_Claims;
SET WORK.Physician_Location2;
	MERGE WORK.Wide_Phy_Zip_POS (drop=_name_)
		  WORK.Wide_Phy_Claims_POS (drop=_name_);
RUN;


/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_Performing_1,1,5) AS Carrier_Zip_Perf_Primary,
	  SUBSTR(d.Zip_Performing_2,1,5) AS Carrier_Zip_Perf_Secondary,
	  SUBSTR(h.Zip_POS_1,1,5) AS Carrier_Zip_POS_Primary,
	  SUBSTR(h.Zip_POS_2,1,5) AS Carrier_Zip_POS_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location1_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_&year_data AS g
	  ON a.Physician_NPI=g.NPI
	LEFT JOIN WORK.Physician_Location2_Claims AS h
	  ON a.Physician_NPI=h.Physician_NPI
	ORDER BY Physician_NPI;
QUIT;



%LET year_data=2015;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
  DROP TABLE WORK.OrthoCarrier1;
  CREATE TABLE WORK.OrthoCarrier1 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, 
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_01 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier2;
  CREATE TABLE WORK.OrthoCarrier2 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_02 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


PROC SQL;
  DROP TABLE WORK.OrthoCarrier3;
  CREATE TABLE WORK.OrthoCarrier3 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_03 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier4;
  CREATE TABLE WORK.OrthoCarrier4 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_04 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier5;
  CREATE TABLE WORK.OrthoCarrier5 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_05 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier6;
  CREATE TABLE WORK.OrthoCarrier6 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_06 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier7;
  CREATE TABLE WORK.OrthoCarrier7 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_07 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier8;
  CREATE TABLE WORK.OrthoCarrier8 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_08 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier9;
  CREATE TABLE WORK.OrthoCarrier9 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_09 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier10;
  CREATE TABLE WORK.OrthoCarrier10 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_10 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier11;
  CREATE TABLE WORK.OrthoCarrier11 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_11 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier12;
  CREATE TABLE WORK.OrthoCarrier12 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2015.BCARRIER_LINE_12 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


DATA WORK.Carrier_Full;
	SET	WORK.OrthoCarrier1
  		WORK.OrthoCarrier2
		WORK.OrthoCarrier3
		WORK.OrthoCarrier4
		WORK.OrthoCarrier5
		WORK.OrthoCarrier6
		WORK.OrthoCarrier7
		WORK.OrthoCarrier8
		WORK.OrthoCarrier9
		WORK.OrthoCarrier10
		WORK.OrthoCarrier11
		WORK.OrthoCarrier12;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location1;
	CREATE TABLE WORK.Physician_Location1 AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip_Performing, count(distinct CLM_ID) AS Claims_Performing
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Location2;
	CREATE TABLE WORK.Physician_Location2 AS
	SELECT Physician_NPI, PHYSN_ZIP_CD AS Zip_POS, count(distinct CLM_ID) AS Claims_POS
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PHYSN_ZIP_CD
	ORDER BY Physician_NPI, PHYSN_ZIP_CD;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location1 OUT=WORK.Physician_Location1;
	BY Physician_NPI DESCENDING Claims_Performing;
RUN;
PROC SORT DATA=WORK.Physician_Location2 OUT=WORK.Physician_Location2;
	BY Physician_NPI DESCENDING Claims_POS;
RUN;

DATA WORK.Physician_Location1;
SET WORK.Physician_Location1;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

DATA WORK.Physician_Location2;
SET WORK.Physician_Location2;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location1
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_Performing, Zip_Performing_);
%temp_wide(Claims_Performing, Claims_Performing_);

DATA WORK.Physician_Location1_Claims;
SET WORK.Physician_Location1;
	MERGE WORK.Wide_Phy_Zip_Performing (drop=_name_)
		  WORK.Wide_Phy_Claims_Performing (drop=_name_);
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location2
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_POS, Zip_POS_);
%temp_wide(Claims_POS, Claims_POS_);

DATA WORK.Physician_Location2_Claims;
SET WORK.Physician_Location2;
	MERGE WORK.Wide_Phy_Zip_POS (drop=_name_)
		  WORK.Wide_Phy_Claims_POS (drop=_name_);
RUN;


/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_Performing_1,1,5) AS Carrier_Zip_Perf_Primary,
	  SUBSTR(d.Zip_Performing_2,1,5) AS Carrier_Zip_Perf_Secondary,
	  SUBSTR(h.Zip_POS_1,1,5) AS Carrier_Zip_POS_Primary,
	  SUBSTR(h.Zip_POS_2,1,5) AS Carrier_Zip_POS_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location1_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_&year_data AS g
	  ON a.Physician_NPI=g.NPI
	LEFT JOIN WORK.Physician_Location2_Claims AS h
	  ON a.Physician_NPI=h.Physician_NPI
	ORDER BY Physician_NPI;
QUIT;



%LET year_data=2016;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
  DROP TABLE WORK.OrthoCarrier1;
  CREATE TABLE WORK.OrthoCarrier1 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, 
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_01 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier2;
  CREATE TABLE WORK.OrthoCarrier2 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_02 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


PROC SQL;
  DROP TABLE WORK.OrthoCarrier3;
  CREATE TABLE WORK.OrthoCarrier3 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_03 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier4;
  CREATE TABLE WORK.OrthoCarrier4 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_04 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier5;
  CREATE TABLE WORK.OrthoCarrier5 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_05 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier6;
  CREATE TABLE WORK.OrthoCarrier6 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_06 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier7;
  CREATE TABLE WORK.OrthoCarrier7 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_07 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier8;
  CREATE TABLE WORK.OrthoCarrier8 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_08 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier9;
  CREATE TABLE WORK.OrthoCarrier9 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_09 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier10;
  CREATE TABLE WORK.OrthoCarrier10 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_10 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier11;
  CREATE TABLE WORK.OrthoCarrier11 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_11 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier12;
  CREATE TABLE WORK.OrthoCarrier12 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2016.BCARRIER_LINE_12 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


DATA WORK.Carrier_Full;
	SET	WORK.OrthoCarrier1
  		WORK.OrthoCarrier2
		WORK.OrthoCarrier3
		WORK.OrthoCarrier4
		WORK.OrthoCarrier5
		WORK.OrthoCarrier6
		WORK.OrthoCarrier7
		WORK.OrthoCarrier8
		WORK.OrthoCarrier9
		WORK.OrthoCarrier10
		WORK.OrthoCarrier11
		WORK.OrthoCarrier12;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location1;
	CREATE TABLE WORK.Physician_Location1 AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip_Performing, count(distinct CLM_ID) AS Claims_Performing
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Location2;
	CREATE TABLE WORK.Physician_Location2 AS
	SELECT Physician_NPI, PHYSN_ZIP_CD AS Zip_POS, count(distinct CLM_ID) AS Claims_POS
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PHYSN_ZIP_CD
	ORDER BY Physician_NPI, PHYSN_ZIP_CD;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location1 OUT=WORK.Physician_Location1;
	BY Physician_NPI DESCENDING Claims_Performing;
RUN;
PROC SORT DATA=WORK.Physician_Location2 OUT=WORK.Physician_Location2;
	BY Physician_NPI DESCENDING Claims_POS;
RUN;

DATA WORK.Physician_Location1;
SET WORK.Physician_Location1;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

DATA WORK.Physician_Location2;
SET WORK.Physician_Location2;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location1
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_Performing, Zip_Performing_);
%temp_wide(Claims_Performing, Claims_Performing_);

DATA WORK.Physician_Location1_Claims;
SET WORK.Physician_Location1;
	MERGE WORK.Wide_Phy_Zip_Performing (drop=_name_)
		  WORK.Wide_Phy_Claims_Performing (drop=_name_);
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location2
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_POS, Zip_POS_);
%temp_wide(Claims_POS, Claims_POS_);

DATA WORK.Physician_Location2_Claims;
SET WORK.Physician_Location2;
	MERGE WORK.Wide_Phy_Zip_POS (drop=_name_)
		  WORK.Wide_Phy_Claims_POS (drop=_name_);
RUN;


/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_Performing_1,1,5) AS Carrier_Zip_Perf_Primary,
	  SUBSTR(d.Zip_Performing_2,1,5) AS Carrier_Zip_Perf_Secondary,
	  SUBSTR(h.Zip_POS_1,1,5) AS Carrier_Zip_POS_Primary,
	  SUBSTR(h.Zip_POS_2,1,5) AS Carrier_Zip_POS_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location1_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_2015 AS g
	  ON a.Physician_NPI=g.NPI
	LEFT JOIN WORK.Physician_Location2_Claims AS h
	  ON a.Physician_NPI=h.Physician_NPI
	ORDER BY Physician_NPI;
QUIT;





%LET year_data=2017;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
  DROP TABLE WORK.OrthoCarrier1;
  CREATE TABLE WORK.OrthoCarrier1 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, 
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_01 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier2;
  CREATE TABLE WORK.OrthoCarrier2 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_02 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


PROC SQL;
  DROP TABLE WORK.OrthoCarrier3;
  CREATE TABLE WORK.OrthoCarrier3 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_03 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier4;
  CREATE TABLE WORK.OrthoCarrier4 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_04 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier5;
  CREATE TABLE WORK.OrthoCarrier5 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_05 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier6;
  CREATE TABLE WORK.OrthoCarrier6 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_06 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier7;
  CREATE TABLE WORK.OrthoCarrier7 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_07 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier8;
  CREATE TABLE WORK.OrthoCarrier8 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_08 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier9;
  CREATE TABLE WORK.OrthoCarrier9 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_09 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier10;
  CREATE TABLE WORK.OrthoCarrier10 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_10 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier11;
  CREATE TABLE WORK.OrthoCarrier11 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_11 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier12;
  CREATE TABLE WORK.OrthoCarrier12 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2017.BCARRIER_LINE_12 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


DATA WORK.Carrier_Full;
	SET	WORK.OrthoCarrier1
  		WORK.OrthoCarrier2
		WORK.OrthoCarrier3
		WORK.OrthoCarrier4
		WORK.OrthoCarrier5
		WORK.OrthoCarrier6
		WORK.OrthoCarrier7
		WORK.OrthoCarrier8
		WORK.OrthoCarrier9
		WORK.OrthoCarrier10
		WORK.OrthoCarrier11
		WORK.OrthoCarrier12;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location1;
	CREATE TABLE WORK.Physician_Location1 AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip_Performing, count(distinct CLM_ID) AS Claims_Performing
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Location2;
	CREATE TABLE WORK.Physician_Location2 AS
	SELECT Physician_NPI, PHYSN_ZIP_CD AS Zip_POS, count(distinct CLM_ID) AS Claims_POS
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PHYSN_ZIP_CD
	ORDER BY Physician_NPI, PHYSN_ZIP_CD;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location1 OUT=WORK.Physician_Location1;
	BY Physician_NPI DESCENDING Claims_Performing;
RUN;
PROC SORT DATA=WORK.Physician_Location2 OUT=WORK.Physician_Location2;
	BY Physician_NPI DESCENDING Claims_POS;
RUN;

DATA WORK.Physician_Location1;
SET WORK.Physician_Location1;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

DATA WORK.Physician_Location2;
SET WORK.Physician_Location2;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location1
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_Performing, Zip_Performing_);
%temp_wide(Claims_Performing, Claims_Performing_);

DATA WORK.Physician_Location1_Claims;
SET WORK.Physician_Location1;
	MERGE WORK.Wide_Phy_Zip_Performing (drop=_name_)
		  WORK.Wide_Phy_Claims_Performing (drop=_name_);
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location2
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_POS, Zip_POS_);
%temp_wide(Claims_POS, Claims_POS_);

DATA WORK.Physician_Location2_Claims;
SET WORK.Physician_Location2;
	MERGE WORK.Wide_Phy_Zip_POS (drop=_name_)
		  WORK.Wide_Phy_Claims_POS (drop=_name_);
RUN;


/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_Performing_1,1,5) AS Carrier_Zip_Perf_Primary,
	  SUBSTR(d.Zip_Performing_2,1,5) AS Carrier_Zip_Perf_Secondary,
	  SUBSTR(h.Zip_POS_1,1,5) AS Carrier_Zip_POS_Primary,
	  SUBSTR(h.Zip_POS_2,1,5) AS Carrier_Zip_POS_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location1_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_2015 AS g
	  ON a.Physician_NPI=g.NPI
	LEFT JOIN WORK.Physician_Location2_Claims AS h
	  ON a.Physician_NPI=h.Physician_NPI
	ORDER BY Physician_NPI;
QUIT;






%LET year_data=2018;
/* Physicians in Outpatient Office Claims Data (Carrier File) */
PROC SQL;
  DROP TABLE WORK.OrthoCarrier1;
  CREATE TABLE WORK.OrthoCarrier1 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP, 
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_01 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier2;
  CREATE TABLE WORK.OrthoCarrier2 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_02 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


PROC SQL;
  DROP TABLE WORK.OrthoCarrier3;
  CREATE TABLE WORK.OrthoCarrier3 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_03 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier4;
  CREATE TABLE WORK.OrthoCarrier4 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_04 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier5;
  CREATE TABLE WORK.OrthoCarrier5 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_05 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier6;
  CREATE TABLE WORK.OrthoCarrier6 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_06 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier7;
  CREATE TABLE WORK.OrthoCarrier7 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_07 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier8;
  CREATE TABLE WORK.OrthoCarrier8 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_08 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier9;
  CREATE TABLE WORK.OrthoCarrier9 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_09 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier10;
  CREATE TABLE WORK.OrthoCarrier10 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_10 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier11;
  CREATE TABLE WORK.OrthoCarrier11 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_11 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;

PROC SQL;
  DROP TABLE WORK.OrthoCarrier12;
  CREATE TABLE WORK.OrthoCarrier12 AS
  SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.BENE_ID, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
		a.PHYSN_ZIP_CD, a.BETOS_CD
  FROM RIF2018.BCARRIER_LINE_12 AS a
  LEFT JOIN PL027710.MajorJointPatients_Unique AS b
		ON a.BENE_ID=b.BENE_ID
  ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
QUIT;


DATA WORK.Carrier_Full;
	SET	WORK.OrthoCarrier1
  		WORK.OrthoCarrier2
		WORK.OrthoCarrier3
		WORK.OrthoCarrier4
		WORK.OrthoCarrier5
		WORK.OrthoCarrier6
		WORK.OrthoCarrier7
		WORK.OrthoCarrier8
		WORK.OrthoCarrier9
		WORK.OrthoCarrier10
		WORK.OrthoCarrier11
		WORK.OrthoCarrier12;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Carrier;
	CREATE TABLE WORK.Physician_Carrier AS
	SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
    FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI;
QUIT;

/* Find Physician Specialties */
PROC SQL;
	DROP TABLE WORK.Physician_Specialty;
	CREATE TABLE WORK.Physician_Specialty AS
	SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, PRVDR_SPCLTY
	ORDER BY Physician_NPI, PRVDR_SPCLTY;
QUIT;

/* Find Physician Tax IDs */
PROC SQL;
	DROP TABLE WORK.Physician_TaxIDs;
	CREATE TABLE WORK.Physician_TaxIDs AS
	SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI, TAX_NUM
	ORDER BY Physician_NPI, TAX_NUM;
QUIT;


/* Find Physician Practice Location (based on "Evaluation and Management" billing) */
PROC SQL;
	DROP TABLE WORK.Physician_Location1;
	CREATE TABLE WORK.Physician_Location1 AS
	SELECT Physician_NPI, PRVDR_ZIP AS Zip_Performing, count(distinct CLM_ID) AS Claims_Performing
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PRVDR_ZIP
	ORDER BY Physician_NPI, PRVDR_ZIP;
QUIT;

PROC SQL;
	DROP TABLE WORK.Physician_Location2;
	CREATE TABLE WORK.Physician_Location2 AS
	SELECT Physician_NPI, PHYSN_ZIP_CD AS Zip_POS, count(distinct CLM_ID) AS Claims_POS
	FROM WORK.Carrier_Full
	WHERE Physician_NPI NOT IN ('9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999')
		AND Physician_NPI IS NOT NULL 
		AND (FIRST(BETOS_CD)="M")
	GROUP BY Physician_NPI, PHYSN_ZIP_CD
	ORDER BY Physician_NPI, PHYSN_ZIP_CD;
QUIT;


/* Create "wide" data for physician specialties */
PROC SORT DATA=WORK.Physician_Specialty OUT=WORK.Physician_Specialty;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_Specialty;
SET WORK.Physician_Specialty;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Specialty
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Specialty, Specialty_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_Specialty_Claims;
SET WORK.Physician_Specialty;
	MERGE WORK.Wide_Phy_Specialty (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician tax IDs */
PROC SORT DATA=WORK.Physician_TaxIDs OUT=WORK.Physician_TaxIDs;
	BY Physician_NPI DESCENDING Claims;
RUN;

DATA WORK.Physician_TaxIDs;
SET WORK.Physician_TaxIDs;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_TaxIDs
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(TaxID, TaxID_);
%temp_wide(Claims, Claims_);

DATA WORK.Physician_TaxID_Claims;
SET WORK.Physician_TaxIDs;
	MERGE WORK.Wide_Phy_TaxID (drop=_name_)
		  WORK.Wide_Phy_Claims (drop=_name_);
RUN;


/* Create "wide" data for physician location (zip code) */
PROC SORT DATA=WORK.Physician_Location1 OUT=WORK.Physician_Location1;
	BY Physician_NPI DESCENDING Claims_Performing;
RUN;
PROC SORT DATA=WORK.Physician_Location2 OUT=WORK.Physician_Location2;
	BY Physician_NPI DESCENDING Claims_POS;
RUN;

DATA WORK.Physician_Location1;
SET WORK.Physician_Location1;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

DATA WORK.Physician_Location2;
SET WORK.Physician_Location2;
	BY Physician_NPI;
	IF first.Physician_NPI THEN n=1;
	ELSE n+1;
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location1
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_Performing, Zip_Performing_);
%temp_wide(Claims_Performing, Claims_Performing_);

DATA WORK.Physician_Location1_Claims;
SET WORK.Physician_Location1;
	MERGE WORK.Wide_Phy_Zip_Performing (drop=_name_)
		  WORK.Wide_Phy_Claims_Performing (drop=_name_);
RUN;

%MACRO temp_wide(varname,prefix);
PROC TRANSPOSE DATA=WORK.Physician_Location2
	OUT=WORK.Wide_Phy_&varname PREFIX=&prefix;
	BY Physician_NPI;
	ID n;
VAR &varname;
RUN;

%MEND temp_wide;
%temp_wide(Zip_POS, Zip_POS_);
%temp_wide(Claims_POS, Claims_POS_);

DATA WORK.Physician_Location2_Claims;
SET WORK.Physician_Location2;
	MERGE WORK.Wide_Phy_Zip_POS (drop=_name_)
		  WORK.Wide_Phy_Claims_POS (drop=_name_);
RUN;


/* Operating and Attending Physicians in Inpatient Institutional Claims Data */
/* -- Operating physicians only (not worried about attending physicians) */

PROC SQL;
	DROP TABLE WORK.OP_Physician_Inpatient;
	CREATE TABLE WORK.OP_Physician_Inpatient AS
	SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients, 
        count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
    FROM PL027710.MajorJoint_&year_data
	GROUP BY OP_PHYSN_NPI;
QUIT;

DATA WORK.Physician_Inpatient_All;
	SET WORK.OP_Physician_Inpatient;
	ARRAY vars OP_Inpatient_Claims OP_Inpatient_Patients OP_Inpatient_Facilities;
	DO OVER vars;
	IF vars=. THEN vars=0;
	END;
RUN;

PROC SQL;
	DROP TABLE WORK.Physician_Inpatient;
	CREATE TABLE WORK.Physician_Inpatient AS
	SELECT Physician_NPI, sum(OP_Inpatient_Claims) AS OP_Claims, sum(OP_Inpatient_Patients) AS OP_Patients,
		sum(OP_Inpatient_Facilities) AS OP_Facilities
	FROM WORK.Physician_Inpatient_All
	WHERE Physician_NPI IS NOT NULL
	GROUP BY Physician_NPI
	ORDER BY Physician_NPI;
QUIT;

/* Append Physician Inpatient and Carrier Data */
DATA WORK.Physician_Append;
	SET WORK.Physician_Carrier
		WORK.Physician_Inpatient;
RUN;


/* Extract Unique Physician IDs from Full Physician Dataset */
PROC SQL;
	DROP TABLE WORK.Physicians;
	CREATE TABLE WORK.Physicians AS
	SELECT DISTINCT Physician_NPI
	FROM WORK.Physician_Append
	ORDER BY Physician_NPI;
QUIT;


/* Merge Unique Physician IDs with Inpatient and Carrier Data */
/* -- Also merge with NPPES data, tax ID, and specialty data */
PROC SQL;
	DROP TABLE PL027710.OrthoPhysician_Data_&year_data;
	CREATE TABLE PL027710.OrthoPhysician_Data_&year_data AS 
	SELECT a.*, b.*, c.*, SUBSTR(d.Zip_Performing_1,1,5) AS Carrier_Zip_Perf_Primary,
	  SUBSTR(d.Zip_Performing_2,1,5) AS Carrier_Zip_Perf_Secondary,
	  SUBSTR(h.Zip_POS_1,1,5) AS Carrier_Zip_POS_Primary,
	  SUBSTR(h.Zip_POS_2,1,5) AS Carrier_Zip_POS_Secondary,
	  e.Specialty_1 AS Primary_Specialty, e.Specialty_2 AS Secondary_Specialty, 
	  f.TaxID_1 AS Primary_TaxID, f.TaxID_2 AS Secondary_TaxID,
	  g.Entity_Type_Code AS NPPES_EntityCode, g.Credent AS NPPES_Cred, SUBSTR(g.PROV_LOC_ZIP,1,5) AS NPPES_Zip,
      g.PROV_LOC_STATE AS NPPES_State, g.PROV_LOC_CITY AS NPPES_City, g.Specialty_HPTC AS NPPES_HPTC,
	  g.UPDATE_DATE AS NPPES_Update
	FROM WORK.Physicians AS a
	LEFT JOIN WORK.Physician_Carrier AS b
	  ON a.Physician_NPI=b.Physician_NPI
	LEFT JOIN WORK.Physician_Inpatient AS c
	  ON a.Physician_NPI=c.Physician_NPI
	LEFT JOIN WORK.Physician_Location1_Claims AS d
	  ON a.Physician_NPI=d.Physician_NPI
	LEFT JOIN WORK.Physician_Specialty_Claims AS e
	  ON a.Physician_NPI=e.Physician_NPI
	LEFT JOIN WORK.Physician_TaxID_Claims AS f
	  ON a.Physician_NPI=f.Physician_NPI
	LEFT JOIN PL027710.NPPES_2015 AS g
	  ON a.Physician_NPI=g.NPI
	LEFT JOIN WORK.Physician_Location2_Claims AS h
	  ON a.Physician_NPI=h.Physician_NPI
	ORDER BY Physician_NPI;
QUIT;
