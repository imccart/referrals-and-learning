/* ------------------------------------------------------------ */
/* TITLE:         Office visits of the major joint patients      */
/* AUTHOR:        Ian McCarthy                                   */
/*                Emory University                               */
/* DATE CREATED:  12/31/2018                                     */
/* DATE EDITED:   10/30/2026                                    */
/* CODE FILE ORDER: 3                                            */
/* INPUT:         RIFyyyy.BCARRIER_LINE_01-12                    */
/*                MajorJointPatients_Unique (step 1)             */
/*                MD_PPAS.MDPPAS_V24_yyyy                        */
/* OUTPUT:        &carrier_tbl._yyyy (MJ_OrthoCarrier_yyyy):     */
/*                  all E&M visits of the patients               */
/*                PCPCarrier_yyyy: the visits to PCPs            */
/* ------------------------------------------------------------ */

/* Evaluation and management visits (BETOS M) by any physician   */
/* for every patient who ever had a major joint replacement in   */
/* the sample, one row per physician, patient, and visit date.   */
/* The PCP subset keeps physicians MD-PPAS classifies as primary */
/* care (SPEC_BROAD=1) in the visit year's vintage.              */

%MACRO em_visits_month(y, mm, out);
    PROC SQL;
        CREATE TABLE WORK.&out AS
        SELECT DISTINCT PRF_PHYSN_NPI AS Physician_ID, a.BENE_ID, CLM_THRU_DT AS Visit_Date, TAX_NUM AS Phy_Tax_ID
        FROM RIF&y..BCARRIER_LINE_&mm AS a
        INNER JOIN PL027710.MajorJointPatients_Unique AS b
            ON a.BENE_ID=b.BENE_ID
        WHERE FIRST(BETOS_CD)="M"
        ORDER BY a.BENE_ID, CLM_THRU_DT, PRF_PHYSN_NPI;
    QUIT;
%MEND em_visits_month;

%MACRO carrier_visits;
%DO y = &year_first %TO &year_last;

    %stack_months(em_visits_month, &y, Carrier_&y);

    DATA PL027710.&carrier_tbl._&y;
        SET WORK.Carrier_&y;
    RUN;
    PROC DELETE DATA=WORK.Carrier_&y; RUN;

    %IF &y >= &mdppas_first %THEN %DO;
    PROC SQL;
        DROP TABLE PL027710.PCPCarrier_&y;
        CREATE TABLE PL027710.PCPCarrier_&y AS
        SELECT DISTINCT a.Physician_ID, a.BENE_ID, a.Visit_Date
        FROM PL027710.&carrier_tbl._&y AS a
        INNER JOIN (SELECT NPI FROM MD_PPAS.MDPPAS_V24_%mdppas_year(&y) WHERE SPEC_BROAD=1) AS b
            ON a.Physician_ID=b.NPI;
    QUIT;
    %END;

%END;
%MEND carrier_visits;

%carrier_visits;
