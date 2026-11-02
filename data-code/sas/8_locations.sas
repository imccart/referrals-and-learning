/* ------------------------------------------------------------ */
/* TITLE:         Hospital and physician locations               */
/* AUTHOR:        Ian McCarthy                                   */
/*                Emory University                               */
/* DATE CREATED:  12/16/2021                                     */
/* DATE EDITED:   10/30/2026                                    */
/* CODE FILE ORDER: 8                                            */
/* INPUT:         RIFyyyy.INPATIENT_CLAIMS_01-12                 */
/*                PROVIDER.POS_yyyy                              */
/*                RIFyyyy.BCARRIER_LINE_01-12                    */
/* OUTPUT:        Hospital_Location_yyyy                         */
/*                PhyLocation_yyyy                               */
/* ------------------------------------------------------------ */

/* Hospital zip codes by claim count from the facility zip on   */
/* every inpatient claim, with the Provider of Services zip as a */
/* fallback. Physician zips by claim count from the performing  */
/* zip and the place-of-service zip on every carrier line. The  */
/* Stata build keeps any zip with at least a tenth of a          */
/* provider's claims and converts zips to coordinates.           */
/* The beneficiary zip table the old program also built is read  */
/* by nothing and is not built.                                  */

%MACRO phy_location_month(y, mm, out);
    PROC SQL;
        CREATE TABLE WORK.&out AS
        SELECT PRF_PHYSN_NPI, SUBSTR(PRVDR_ZIP,1,5) as Phy_Zip_Perf, SUBSTR(PHYSN_ZIP_CD, 1, 5) as Phy_Zip_POS, count(*) AS Claim_Count
        FROM RIF&y..BCARRIER_LINE_&mm
        GROUP BY PRF_PHYSN_NPI, Phy_Zip_Perf, Phy_Zip_POS;
    QUIT;
%MEND phy_location_month;

%MACRO locations;
%DO y = &year_loc_first %TO &year_last;

    /* hospitals */
    DATA WORK.InpatientStays_&y;
        SET %DO m = 1 %TO 12; RIF&y..INPATIENT_CLAIMS_%SYSFUNC(PUTN(&m, Z2.)) %END;;
    RUN;

    PROC SQL;
        DROP TABLE WORK.Hospital_Location;
        CREATE TABLE WORK.Hospital_Location AS
        SELECT ORG_NPI_NUM AS Hosp_NPI, PRVDR_NUM AS Provider_Number,
            PRVDR_STATE_CD AS Hosp_State, SUBSTR(CLM_SRVC_FAC_ZIP_CD,1,5) AS Hosp_Zip,
            count(*) AS Claim_Count
        FROM WORK.InpatientStays_&y
        GROUP BY Hosp_NPI, PRVDR_NUM, Hosp_State, Hosp_Zip;
    QUIT;

    %pos_cols(&y);
    PROC SQL;
        DROP TABLE PL027710.Hospital_Location_&y;
        CREATE TABLE PL027710.Hospital_Location_&y AS
        SELECT a.*, b.&pos_name AS Hosp_Name_POS, b.&pos_cnty AS Hosp_County_POS, b.&pos_state AS Hosp_State_POS,
            b.&pos_prvdr AS Provider_Number, b.&pos_parent AS Parent_Provider_Number, b.ZIP_CD AS Hosp_Zip_POS
        FROM WORK.Hospital_Location AS a
        LEFT JOIN PROVIDER.POS_&y AS b
        ON a.Provider_Number=b.&pos_prvdr;
    QUIT;

    PROC DATASETS LIB=WORK NOLIST;
        DELETE InpatientStays_&y Hospital_Location;
    QUIT;

    /* physicians */
    %stack_months(phy_location_month, &y, PhyLocation);

    PROC SQL;
        DROP TABLE PL027710.PhyLocation_&y;
        CREATE TABLE PL027710.PhyLocation_&y AS
        SELECT DISTINCT a.PRF_PHYSN_NPI AS Physician_NPI, b.Phy_Zip_Perf, b.Claims_Perf,
            c.Phy_Zip_POS, c.Claims_POS
        FROM WORK.PhyLocation AS a
        LEFT JOIN (SELECT PRF_PHYSN_NPI, Phy_Zip_Perf, sum(Claim_Count) AS Claims_Perf
                     FROM WORK.PhyLocation
                     WHERE Phy_Zip_Perf IS NOT NULL
                     GROUP BY PRF_PHYSN_NPI, Phy_Zip_Perf) AS b
            ON a.PRF_PHYSN_NPI=b.PRF_PHYSN_NPI
        LEFT JOIN (SELECT PRF_PHYSN_NPI, Phy_Zip_POS, sum(Claim_Count) AS Claims_POS
                     FROM WORK.PhyLocation
                     WHERE Phy_Zip_POS IS NOT NULL
                     GROUP BY PRF_PHYSN_NPI, Phy_Zip_POS) AS c
            ON a.PRF_PHYSN_NPI=c.PRF_PHYSN_NPI
        WHERE Physician_NPI IS NOT NULL;
    QUIT;

    PROC DELETE DATA=WORK.PhyLocation; RUN;

%END;
%MEND locations;

%locations;
