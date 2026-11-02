/* ------------------------------------------------------------ */
/* TITLE:         Physicians seen before surgery                 */
/* AUTHOR:        Ian McCarthy                                   */
/*                Emory University                               */
/* DATE CREATED:  1/2/2019                                       */
/* DATE EDITED:   10/30/2026                                    */
/* CODE FILE ORDER: 4                                            */
/* INPUT:         MajorJoint_yyyy (step 1)                       */
/*                &carrier_tbl._yyyy and _yyyy-1 (step 3)        */
/* OUTPUT:        PreSurgery_Physicians_yyyy                     */
/* ------------------------------------------------------------ */

/* For each stay in year t, every physician the patient visited  */
/* in the 365 days before the admission (years t and t-1), other */
/* than the operating surgeon, with the visit count and the      */
/* first and last visit dates. The Stata build picks the         */
/* referring PCP from these.                                     */

%MACRO referral_assignment;
%DO y = &year_ref_first %TO &year_last;
    %LET y_lag = %EVAL(&y - 1);

    PROC SQL;
        DROP TABLE WORK.Unique_Stays;
        CREATE TABLE WORK.Unique_Stays AS
        SELECT DISTINCT BENE_ID, CLM_FROM_DT AS Date, OP_PHYSN_NPI, ORG_NPI_NUM AS Facility_ID
        FROM PL027710.MajorJoint_&y
        GROUP BY BENE_ID, CLM_FROM_DT, ORG_NPI_NUM, OP_PHYSN_NPI;
    QUIT;

    DATA WORK.Carrier;
        SET PL027710.&carrier_tbl._&y
            PL027710.&carrier_tbl._&y_lag;
    RUN;

    PROC SQL;
        DROP TABLE WORK.Referrals_&y;
        CREATE TABLE WORK.Referrals_&y AS
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

    PROC SQL;
        DROP TABLE PL027710.PreSurgery_Physicians_&y;
        CREATE TABLE PL027710.PreSurgery_Physicians_&y AS
        SELECT Physician_ID, BENE_ID, Date, Phy_Tax_ID, count(BENE_ID) AS Visits, max(Visit_Date) AS Max_Visit_Date FORMAT=DATE9.,
            min(Visit_Date) AS Min_Visit_Date FORMAT=DATE9.
        FROM WORK.Referrals_&y
        GROUP BY BENE_ID, Date, Physician_ID, Phy_Tax_ID;
    QUIT;

    PROC DATASETS LIB=WORK NOLIST;
        DELETE Unique_Stays Carrier Referrals_&y;
    QUIT;

%END;
%MEND referral_assignment;

%referral_assignment;
