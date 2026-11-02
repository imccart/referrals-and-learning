/* ------------------------------------------------------------ */
/* TITLE:         Physician characteristics                      */
/* AUTHOR:        Ian McCarthy                                   */
/*                Emory University                               */
/* DATE CREATED:  5/12/2015                                      */
/* DATE EDITED:   10/30/2026                                    */
/* CODE FILE ORDER: 5                                            */
/* INPUT:         carrier lines for the year (RIF monthly files, */
/*                or the request tables before 2009)             */
/*                MajorJoint_yyyy (step 1)                       */
/*                NPPES_yyyy (nppes.sas)                         */
/*                UPIN_NPI_Merge_yyyy (upin2npi.sas; before 2009)*/
/* OUTPUT:        OrthoPhysician_Data_yyyy                       */
/* ------------------------------------------------------------ */

/* For every physician billing carrier claims in the year: claim */
/* and patient counts, the two most frequent specialties, tax    */
/* IDs, performing-location zips and place-of-service zips       */
/* (from E&M claims), the operating-surgeon counts from the major*/
/* joint stays, and the NPPES record.                            */
/* The place-of-service zip is not on the pre-2009 request       */
/* tables, so those years carry it as blank; every year has the */
/* same columns.                                                 */

%LET excluded_npis = '9999999991','9999999992','9999999993','9999999994','9999999995','9999999996','9999999997','9999999998','9999999999';

%MACRO carrier_all_month(y, mm, out);
    PROC SQL;
        CREATE TABLE WORK.&out AS
        %IF &y < 2009 %THEN %DO;
        SELECT CASE
                WHEN a.PRF_PHYSN_NPI NE '' AND a.PRF_PHYSN_NPI NE '0000000000' THEN a.PRF_PHYSN_NPI
                WHEN a.PRF_PHYSN_NPI='' OR a.PRF_PHYSN_NPI='0000000000' THEN b.NPI
            ELSE ''
            END AS Physician_NPI, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
            '' AS PHYSN_ZIP_CD, a.BETOS_CD
        FROM %carrier_line_source(&y, &mm) AS a
        LEFT JOIN PL027710.UPIN_NPI_Merge_&y AS b
            ON a.PRF_PHYSN_UPIN=b.OP_PHYSN_UPIN;
        %END;
        %ELSE %DO;
        SELECT DISTINCT PRF_PHYSN_NPI AS Physician_NPI, a.CLM_ID, a.BENE_ID, a.PRVDR_SPCLTY, a.TAX_NUM, a.PRVDR_ZIP,
            a.PHYSN_ZIP_CD, a.BETOS_CD
        FROM %carrier_line_source(&y, &mm) AS a
        ORDER BY a.BENE_ID, a.PRF_PHYSN_NPI;
        %END;
    QUIT;
%MEND carrier_all_month;

/* one row per physician and value, ranked by claims, to wide    */
%MACRO rank_and_widen(ds, keyvar, cntvar, prefix_key, prefix_cnt, out);
    PROC SORT DATA=WORK.&ds OUT=WORK.&ds;
        BY Physician_NPI DESCENDING &cntvar;
    RUN;
    DATA WORK.&ds;
    SET WORK.&ds;
        BY Physician_NPI;
        IF first.Physician_NPI THEN n=1;
        ELSE n+1;
    RUN;
    PROC TRANSPOSE DATA=WORK.&ds OUT=WORK.Wide_&ds._key PREFIX=&prefix_key;
        BY Physician_NPI;
        ID n;
        VAR &keyvar;
    RUN;
    PROC TRANSPOSE DATA=WORK.&ds OUT=WORK.Wide_&ds._cnt PREFIX=&prefix_cnt;
        BY Physician_NPI;
        ID n;
        VAR &cntvar;
    RUN;
    DATA WORK.&out;
        MERGE WORK.Wide_&ds._key (drop=_name_)
              WORK.Wide_&ds._cnt (drop=_name_);
        BY Physician_NPI;
    RUN;
    PROC DATASETS LIB=WORK NOLIST;
        DELETE Wide_&ds._key Wide_&ds._cnt;
    QUIT;
%MEND rank_and_widen;

%MACRO physician_data;
%DO y = &year_first %TO &year_last;

    %stack_months(carrier_all_month, &y, Carrier_Full, single_if_request=1);

    PROC SQL;
        DROP TABLE WORK.Physician_Carrier;
        CREATE TABLE WORK.Physician_Carrier AS
        SELECT Physician_NPI, count(distinct CLM_ID) AS Carrier_Claims, count(distinct BENE_ID) AS Carrier_Patients
        FROM WORK.Carrier_Full
        WHERE Physician_NPI NOT IN (&excluded_npis)
            AND Physician_NPI IS NOT NULL
        GROUP BY Physician_NPI;
    QUIT;

    /* specialties */
    PROC SQL;
        DROP TABLE WORK.Physician_Specialty;
        CREATE TABLE WORK.Physician_Specialty AS
        SELECT Physician_NPI, PRVDR_SPCLTY AS Specialty, count(distinct CLM_ID) AS Claims
        FROM WORK.Carrier_Full
        WHERE Physician_NPI NOT IN (&excluded_npis)
            AND Physician_NPI IS NOT NULL
        GROUP BY Physician_NPI, PRVDR_SPCLTY
        ORDER BY Physician_NPI, PRVDR_SPCLTY;
    QUIT;

    /* tax IDs */
    PROC SQL;
        DROP TABLE WORK.Physician_TaxIDs;
        CREATE TABLE WORK.Physician_TaxIDs AS
        SELECT Physician_NPI, TAX_NUM AS TaxID, count(distinct CLM_ID) AS Claims
        FROM WORK.Carrier_Full
        WHERE Physician_NPI NOT IN (&excluded_npis)
            AND Physician_NPI IS NOT NULL
        GROUP BY Physician_NPI, TAX_NUM
        ORDER BY Physician_NPI, TAX_NUM;
    QUIT;

    /* practice location from E&M billing: performing zip and place-of-service zip */
    PROC SQL;
        DROP TABLE WORK.Physician_Location1;
        CREATE TABLE WORK.Physician_Location1 AS
        SELECT Physician_NPI, PRVDR_ZIP AS Zip_Performing, count(distinct CLM_ID) AS Claims_Performing
        FROM WORK.Carrier_Full
        WHERE Physician_NPI NOT IN (&excluded_npis)
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
        WHERE Physician_NPI NOT IN (&excluded_npis)
            AND Physician_NPI IS NOT NULL
            AND (FIRST(BETOS_CD)="M")
        GROUP BY Physician_NPI, PHYSN_ZIP_CD
        ORDER BY Physician_NPI, PHYSN_ZIP_CD;
    QUIT;

    %rank_and_widen(Physician_Specialty, Specialty, Claims, Specialty_, Claims_, Physician_Specialty_Claims);
    %rank_and_widen(Physician_TaxIDs, TaxID, Claims, TaxID_, Claims_, Physician_TaxID_Claims);
    %rank_and_widen(Physician_Location1, Zip_Performing, Claims_Performing, Zip_Performing_, Claims_Performing_, Physician_Location1_Claims);
    %rank_and_widen(Physician_Location2, Zip_POS, Claims_POS, Zip_POS_, Claims_POS_, Physician_Location2_Claims);

    /* operating physicians on the major joint stays */
    PROC SQL;
        DROP TABLE WORK.OP_Physician_Inpatient;
        CREATE TABLE WORK.OP_Physician_Inpatient AS
        SELECT OP_PHYSN_NPI AS Physician_NPI, count(distinct CLM_ID) AS OP_Inpatient_Claims, count(distinct BENE_ID) AS OP_Inpatient_Patients,
            count(distinct ORG_NPI_NUM) AS OP_Inpatient_Facilities
        FROM PL027710.MajorJoint_&y
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

    DATA WORK.Physician_Append;
        SET WORK.Physician_Carrier
            WORK.Physician_Inpatient;
    RUN;

    PROC SQL;
        DROP TABLE WORK.Physicians;
        CREATE TABLE WORK.Physicians AS
        SELECT DISTINCT Physician_NPI
        FROM WORK.Physician_Append
        ORDER BY Physician_NPI;
    QUIT;

    /* assemble */
    PROC SQL;
        DROP TABLE PL027710.OrthoPhysician_Data_&y;
        CREATE TABLE PL027710.OrthoPhysician_Data_&y AS
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
        LEFT JOIN PL027710.NPPES_%nppes_year(&y) AS g
          ON a.Physician_NPI=g.NPI
        LEFT JOIN WORK.Physician_Location2_Claims AS h
          ON a.Physician_NPI=h.Physician_NPI
        ORDER BY Physician_NPI;
    QUIT;

    PROC DATASETS LIB=WORK NOLIST;
        DELETE Carrier_Full Physician_Carrier Physician_Specialty Physician_TaxIDs
               Physician_Location1 Physician_Location2
               Physician_Specialty_Claims Physician_TaxID_Claims Physician_Location1_Claims Physician_Location2_Claims
               OP_Physician_Inpatient Physician_Inpatient_All Physician_Inpatient Physician_Append Physicians;
    QUIT;

%END;
%MEND physician_data;

%physician_data;
