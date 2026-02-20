/* ------------------------------------------------------------ 	*/
/* TITLE:		 	Assign Referring Physician to Inpatient Claims 	*/
/* AUTHOR:		 	Ian McCarthy									*/
/* 				 	Emory University								*/
/* DATE CREATED: 	1/2/2019										*/
/* DATE EDITED:  	4/28/2021										*/
/* CODE FILE ORDER: 4 of 8											*/
/* OUTPUT:			PreSurgery_Physicians_2008-2018					*/
/* ------------------------------------------------------------ 	*/

%LET year_data=2008;
%LET year_lag=2007;

/* Identify unique inpatient stays */
PROC SQL;
	DROP TABLE WORK.Unique_Stays;
	CREATE TABLE WORK.Unique_Stays AS
	SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
	FROM PL027710.MajorJoint_&year_data
	GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
QUIT;

DATA WORK.Carrier;
	SET	PL027710.OrthoCarrier_&year_data
  		PL027710.OrthoCarrier_&year_lag;
RUN;


/* Merge carrier file to inpatient claim */
/* Example: Take all ortho surgeries in year t and merge with all carrier claims */
/*			of those same patients in years t and t-1 */
PROC SQL;
	DROP TABLE WORK.Referrals_&year_data;
	CREATE TABLE WORK.Referrals_&year_data AS
	SELECT a.*, a.Date, b.*
	FROM WORK.Unique_Stays AS a 
	LEFT JOIN WORK.Carrier AS b
		ON a.BENE_ID=b.BENE_ID
		WHERE (b.Visit_Date <= a.Date)
		AND (b.Visit_Date > (a.Date-365)) 
		AND b.Physician_ID NE ''
		AND b.Physician_ID NE a.OP_PHYSN_NPI
	ORDER BY BENE_ID, Physician_ID, Visit_Date, Date;
QUIT;


/* Group merged data by physician, beneficiary, and date of inpatient admission */
PROC SQL;
	DROP TABLE PL027710.PreSurgery_Physicians_&year_data;
	CREATE TABLE PL027710.PreSurgery_Physicians_&year_data AS
	SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
		min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
	FROM WORK.Referrals_&year_data
	GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
QUIT;




%LET year_data=2009;
%LET year_lag=2008;

/* Identify unique inpatient stays */
PROC SQL;
	DROP TABLE WORK.Unique_Stays;
	CREATE TABLE WORK.Unique_Stays AS
	SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
	FROM PL027710.MajorJoint_&year_data
	GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
QUIT;

DATA WORK.Carrier;
	SET	PL027710.OrthoCarrier_&year_data
  		PL027710.OrthoCarrier_&year_lag;
RUN;


/* Merge carrier file to inpatient claim */
/* Example: Take all ortho surgeries in year t and merge with all carrier claims */
/*			of those same patients in years t and t-1 */
PROC SQL;
	DROP TABLE WORK.Referrals_&year_data;
	CREATE TABLE WORK.Referrals_&year_data AS
	SELECT a.*, a.Date, b.*
	FROM WORK.Unique_Stays AS a 
	LEFT JOIN WORK.Carrier AS b
		ON a.BENE_ID=b.BENE_ID
		WHERE (b.Visit_Date <= a.Date)
		AND (b.Visit_Date > (a.Date-365)) 
		AND b.Physician_ID NE ''
		AND b.Physician_ID NE a.OP_PHYSN_NPI
	ORDER BY BENE_ID, Physician_ID, Visit_Date, Date;
QUIT;


/* Group merged data by physician, beneficiary, and date of inpatient admission */
PROC SQL;
	DROP TABLE PL027710.PreSurgery_Physicians_&year_data;
	CREATE TABLE PL027710.PreSurgery_Physicians_&year_data AS
	SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
		min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
	FROM WORK.Referrals_&year_data
	GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
QUIT;



%LET year_data=2010;
%LET year_lag=2009;

/* Identify unique inpatient stays */
PROC SQL;
	DROP TABLE WORK.Unique_Stays;
	CREATE TABLE WORK.Unique_Stays AS
	SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
	FROM PL027710.MajorJoint_&year_data
	GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
QUIT;

DATA WORK.Carrier;
	SET	PL027710.OrthoCarrier_&year_data
  		PL027710.OrthoCarrier_&year_lag;
RUN;


/* Merge carrier file to inpatient claim */
/* Example: Take all ortho surgeries in year t and merge with all carrier claims */
/*			of those same patients in years t and t-1 */
PROC SQL;
	DROP TABLE WORK.Referrals_&year_data;
	CREATE TABLE WORK.Referrals_&year_data AS
	SELECT a.*, a.Date, b.*
	FROM WORK.Unique_Stays AS a 
	LEFT JOIN WORK.Carrier AS b
		ON a.BENE_ID=b.BENE_ID
		WHERE (b.Visit_Date <= a.Date)
		AND (b.Visit_Date > (a.Date-365)) 
		AND b.Physician_ID NE ''
		AND b.Physician_ID NE a.OP_PHYSN_NPI
	ORDER BY BENE_ID, Physician_ID, Visit_Date, Date;
QUIT;


/* Group merged data by physician, beneficiary, and date of inpatient admission */
PROC SQL;
	DROP TABLE PL027710.PreSurgery_Physicians_&year_data;
	CREATE TABLE PL027710.PreSurgery_Physicians_&year_data AS
	SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
		min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
	FROM WORK.Referrals_&year_data
	GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
QUIT;



%LET year_data=2011;
%LET year_lag=2010;

/* Identify unique inpatient stays */
PROC SQL;
	DROP TABLE WORK.Unique_Stays;
	CREATE TABLE WORK.Unique_Stays AS
	SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
	FROM PL027710.MajorJoint_&year_data
	GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
QUIT;

DATA WORK.Carrier;
	SET	PL027710.OrthoCarrier_&year_data
  		PL027710.OrthoCarrier_&year_lag;
RUN;


/* Merge carrier file to inpatient claim */
/* Example: Take all ortho surgeries in year t and merge with all carrier claims */
/*			of those same patients in years t and t-1 */
PROC SQL;
	DROP TABLE WORK.Referrals_&year_data;
	CREATE TABLE WORK.Referrals_&year_data AS
	SELECT a.*, a.Date, b.*
	FROM WORK.Unique_Stays AS a 
	LEFT JOIN WORK.Carrier AS b
		ON a.BENE_ID=b.BENE_ID
		WHERE (b.Visit_Date <= a.Date)
		AND (b.Visit_Date > (a.Date-365)) 
		AND b.Physician_ID NE ''
		AND b.Physician_ID NE a.OP_PHYSN_NPI
	ORDER BY BENE_ID, Physician_ID, Visit_Date, Date;
QUIT;


/* Group merged data by physician, beneficiary, and date of inpatient admission */
PROC SQL;
	DROP TABLE PL027710.PreSurgery_Physicians_&year_data;
	CREATE TABLE PL027710.PreSurgery_Physicians_&year_data AS
	SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
		min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
	FROM WORK.Referrals_&year_data
	GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
QUIT;



%LET year_data=2012;
%LET year_lag=2011;

/* Identify unique inpatient stays */
PROC SQL;
	DROP TABLE WORK.Unique_Stays;
	CREATE TABLE WORK.Unique_Stays AS
	SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
	FROM PL027710.MajorJoint_&year_data
	GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
QUIT;

DATA WORK.Carrier;
	SET	PL027710.OrthoCarrier_&year_data
  		PL027710.OrthoCarrier_&year_lag;
RUN;


/* Merge carrier file to inpatient claim */
/* Example: Take all ortho surgeries in year t and merge with all carrier claims */
/*			of those same patients in years t and t-1 */
PROC SQL;
	DROP TABLE WORK.Referrals_&year_data;
	CREATE TABLE WORK.Referrals_&year_data AS
	SELECT a.*, a.Date, b.*
	FROM WORK.Unique_Stays AS a 
	LEFT JOIN WORK.Carrier AS b
		ON a.BENE_ID=b.BENE_ID
		WHERE (b.Visit_Date <= a.Date)
		AND (b.Visit_Date > (a.Date-365)) 
		AND b.Physician_ID NE ''
		AND b.Physician_ID NE a.OP_PHYSN_NPI
	ORDER BY BENE_ID, Physician_ID, Visit_Date, Date;
QUIT;


/* Group merged data by physician, beneficiary, and date of inpatient admission */
PROC SQL;
	DROP TABLE PL027710.PreSurgery_Physicians_&year_data;
	CREATE TABLE PL027710.PreSurgery_Physicians_&year_data AS
	SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
		min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
	FROM WORK.Referrals_&year_data
	GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
QUIT;



%LET year_data=2013;
%LET year_lag=2012;

/* Identify unique inpatient stays */
PROC SQL;
	DROP TABLE WORK.Unique_Stays;
	CREATE TABLE WORK.Unique_Stays AS
	SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
	FROM PL027710.MajorJoint_&year_data
	GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
QUIT;

DATA WORK.Carrier;
	SET	PL027710.OrthoCarrier_&year_data
  		PL027710.OrthoCarrier_&year_lag;
RUN;


/* Merge carrier file to inpatient claim */
/* Example: Take all ortho surgeries in year t and merge with all carrier claims */
/*			of those same patients in years t and t-1 */
PROC SQL;
	DROP TABLE WORK.Referrals_&year_data;
	CREATE TABLE WORK.Referrals_&year_data AS
	SELECT a.*, a.Date, b.*
	FROM WORK.Unique_Stays AS a 
	LEFT JOIN WORK.Carrier AS b
		ON a.BENE_ID=b.BENE_ID
		WHERE (b.Visit_Date <= a.Date)
		AND (b.Visit_Date > (a.Date-365)) 
		AND b.Physician_ID NE ''
		AND b.Physician_ID NE a.OP_PHYSN_NPI
	ORDER BY BENE_ID, Physician_ID, Visit_Date, Date;
QUIT;


/* Group merged data by physician, beneficiary, and date of inpatient admission */
PROC SQL;
	DROP TABLE PL027710.PreSurgery_Physicians_&year_data;
	CREATE TABLE PL027710.PreSurgery_Physicians_&year_data AS
	SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
		min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
	FROM WORK.Referrals_&year_data
	GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
QUIT;



%LET year_data=2014;
%LET year_lag=2013;

/* Identify unique inpatient stays */
PROC SQL;
	DROP TABLE WORK.Unique_Stays;
	CREATE TABLE WORK.Unique_Stays AS
	SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
	FROM PL027710.MajorJoint_&year_data
	GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
QUIT;

DATA WORK.Carrier;
	SET	PL027710.OrthoCarrier_&year_data
  		PL027710.OrthoCarrier_&year_lag;
RUN;


/* Merge carrier file to inpatient claim */
/* Example: Take all ortho surgeries in year t and merge with all carrier claims */
/*			of those same patients in years t and t-1 */
PROC SQL;
	DROP TABLE WORK.Referrals_&year_data;
	CREATE TABLE WORK.Referrals_&year_data AS
	SELECT a.*, a.Date, b.*
	FROM WORK.Unique_Stays AS a 
	LEFT JOIN WORK.Carrier AS b
		ON a.BENE_ID=b.BENE_ID
		WHERE (b.Visit_Date <= a.Date)
		AND (b.Visit_Date > (a.Date-365)) 
		AND b.Physician_ID NE ''
		AND b.Physician_ID NE a.OP_PHYSN_NPI
	ORDER BY BENE_ID, Physician_ID, Visit_Date, Date;
QUIT;


/* Group merged data by physician, beneficiary, and date of inpatient admission */
PROC SQL;
	DROP TABLE PL027710.PreSurgery_Physicians_&year_data;
	CREATE TABLE PL027710.PreSurgery_Physicians_&year_data AS
	SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
		min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
	FROM WORK.Referrals_&year_data
	GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
QUIT;



%LET year_data=2015;
%LET year_lag=2014;

/* Identify unique inpatient stays */
PROC SQL;
	DROP TABLE WORK.Unique_Stays;
	CREATE TABLE WORK.Unique_Stays AS
	SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
	FROM PL027710.MajorJoint_&year_data
	GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
QUIT;

DATA WORK.Carrier;
	SET	PL027710.OrthoCarrier_&year_data
  		PL027710.OrthoCarrier_&year_lag;
RUN;


/* Merge carrier file to inpatient claim */
/* Example: Take all ortho surgeries in year t and merge with all carrier claims */
/*			of those same patients in years t and t-1 */
PROC SQL;
	DROP TABLE WORK.Referrals_&year_data;
	CREATE TABLE WORK.Referrals_&year_data AS
	SELECT a.*, a.Date, b.*
	FROM WORK.Unique_Stays AS a 
	LEFT JOIN WORK.Carrier AS b
		ON a.BENE_ID=b.BENE_ID
		WHERE (b.Visit_Date <= a.Date)
		AND (b.Visit_Date > (a.Date-365)) 
		AND b.Physician_ID NE ''
		AND b.Physician_ID NE a.OP_PHYSN_NPI
	ORDER BY BENE_ID, Physician_ID, Visit_Date, Date;
QUIT;


/* Group merged data by physician, beneficiary, and date of inpatient admission */
PROC SQL;
	DROP TABLE PL027710.PreSurgery_Physicians_&year_data;
	CREATE TABLE PL027710.PreSurgery_Physicians_&year_data AS
	SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
		min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
	FROM WORK.Referrals_&year_data
	GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
QUIT;



%LET year_data=2016;
%LET year_lag=2015;

/* Identify unique inpatient stays */
PROC SQL;
	DROP TABLE WORK.Unique_Stays;
	CREATE TABLE WORK.Unique_Stays AS
	SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
	FROM PL027710.MajorJoint_&year_data
	GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
QUIT;

DATA WORK.Carrier;
	SET	PL027710.OrthoCarrier_&year_data
  		PL027710.OrthoCarrier_&year_lag;
RUN;


/* Merge carrier file to inpatient claim */
/* Example: Take all ortho surgeries in year t and merge with all carrier claims */
/*			of those same patients in years t and t-1 */
PROC SQL;
	DROP TABLE WORK.Referrals_&year_data;
	CREATE TABLE WORK.Referrals_&year_data AS
	SELECT a.*, a.Date, b.*
	FROM WORK.Unique_Stays AS a 
	LEFT JOIN WORK.Carrier AS b
		ON a.BENE_ID=b.BENE_ID
		WHERE (b.Visit_Date <= a.Date)
		AND (b.Visit_Date > (a.Date-365)) 
		AND b.Physician_ID NE ''
		AND b.Physician_ID NE a.OP_PHYSN_NPI
	ORDER BY BENE_ID, Physician_ID, Visit_Date, Date;
QUIT;


/* Group merged data by physician, beneficiary, and date of inpatient admission */
PROC SQL;
	DROP TABLE PL027710.PreSurgery_Physicians_&year_data;
	CREATE TABLE PL027710.PreSurgery_Physicians_&year_data AS
	SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
		min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
	FROM WORK.Referrals_&year_data
	GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
QUIT;



%LET year_data=2017;
%LET year_lag=2016;

/* Identify unique inpatient stays */
PROC SQL;
	DROP TABLE WORK.Unique_Stays;
	CREATE TABLE WORK.Unique_Stays AS
	SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
	FROM PL027710.MajorJoint_&year_data
	GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
QUIT;

DATA WORK.Carrier;
	SET	PL027710.OrthoCarrier_&year_data
  		PL027710.OrthoCarrier_&year_lag;
RUN;


/* Merge carrier file to inpatient claim */
/* Example: Take all ortho surgeries in year t and merge with all carrier claims */
/*			of those same patients in years t and t-1 */
PROC SQL;
	DROP TABLE WORK.Referrals_&year_data;
	CREATE TABLE WORK.Referrals_&year_data AS
	SELECT a.*, a.Date, b.*
	FROM WORK.Unique_Stays AS a 
	LEFT JOIN WORK.Carrier AS b
		ON a.BENE_ID=b.BENE_ID
		WHERE (b.Visit_Date <= a.Date)
		AND (b.Visit_Date > (a.Date-365)) 
		AND b.Physician_ID NE ''
		AND b.Physician_ID NE a.OP_PHYSN_NPI
	ORDER BY BENE_ID, Physician_ID, Visit_Date, Date;
QUIT;


/* Group merged data by physician, beneficiary, and date of inpatient admission */
PROC SQL;
	DROP TABLE PL027710.PreSurgery_Physicians_&year_data;
	CREATE TABLE PL027710.PreSurgery_Physicians_&year_data AS
	SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
		min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
	FROM WORK.Referrals_&year_data
	GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
QUIT;



%LET year_data=2018;
%LET year_lag=2017;

/* Identify unique inpatient stays */
PROC SQL;
	DROP TABLE WORK.Unique_Stays;
	CREATE TABLE WORK.Unique_Stays AS
	SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
	FROM PL027710.MajorJoint_&year_data
	GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
QUIT;

DATA WORK.Carrier;
	SET	PL027710.OrthoCarrier_&year_data
  		PL027710.OrthoCarrier_&year_lag;
RUN;


/* Merge carrier file to inpatient claim */
/* Example: Take all ortho surgeries in year t and merge with all carrier claims */
/*			of those same patients in years t and t-1 */
PROC SQL;
	DROP TABLE WORK.Referrals_&year_data;
	CREATE TABLE WORK.Referrals_&year_data AS
	SELECT a.*, a.Date, b.*
	FROM WORK.Unique_Stays AS a 
	LEFT JOIN WORK.Carrier AS b
		ON a.BENE_ID=b.BENE_ID
		WHERE (b.Visit_Date <= a.Date)
		AND (b.Visit_Date > (a.Date-365)) 
		AND b.Physician_ID NE ''
		AND b.Physician_ID NE a.OP_PHYSN_NPI
	ORDER BY BENE_ID, Physician_ID, Visit_Date, Date;
QUIT;


/* Group merged data by physician, beneficiary, and date of inpatient admission */
PROC SQL;
	DROP TABLE PL027710.PreSurgery_Physicians_&year_data;
	CREATE TABLE PL027710.PreSurgery_Physicians_&year_data AS
	SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
		min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
	FROM WORK.Referrals_&year_data
	GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
QUIT;
