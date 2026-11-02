/* ------------------------------------------------------------ */
/* TITLE:         Referring physician listed on the surgeon's    */
/*                claims                                         */
/* AUTHOR:        Ian McCarthy                                   */
/*                Emory University                               */
/* DATE CREATED:  1/2/2019                                       */
/* DATE EDITED:   10/30/2026                                    */
/* INPUT:         MajorJoint_yyyy, MajorJointPatients_Unique     */
/*                (step 1)                                       */
/*                RIFyyyy.BCARRIER_LINE_01-12                    */
/*                RIFyyyy.BCARRIER_CLAIMS_01-12                  */
/* OUTPUT:        ReferralsCarrier_yyyy                          */
/* ------------------------------------------------------------ */

/* For each stay, the operating surgeon's carrier lines for the  */
/* patient dated within the stay, with the referring physician   */
/* NPI from the claim header. The Stata build uses this as the   */
/* second source for the referring PCP, after the pre-surgery    */
/* visits of step 4.                                             */

%MACRO op_ref_month(y, mm, out);
    PROC SQL;
        CREATE TABLE WORK.OpCarrier_&mm AS
        SELECT DISTINCT a.PRF_PHYSN_NPI, a.BENE_ID, a.CLM_ID, b.CLM_FROM_DT, b.CLM_THRU_DT, a.CLM_THRU_DT AS claim_date
        FROM RIF&y..BCARRIER_LINE_&mm AS a
        INNER JOIN WORK.Unique_Stays AS b
            ON a.BENE_ID=b.BENE_ID AND a.PRF_PHYSN_NPI=b.OP_PHYSN_NPI
        HAVING claim_date>=b.CLM_FROM_DT AND claim_date<=b.CLM_THRU_DT
        ORDER BY a.BENE_ID, CLM_ID, PRF_PHYSN_NPI;
    QUIT;

    PROC SQL;
        CREATE TABLE WORK.RefCarrier_&mm AS
        SELECT DISTINCT RFR_PHYSN_NPI, a.BENE_ID, CLM_ID
        FROM RIF&y..BCARRIER_CLAIMS_&mm AS a
        INNER JOIN PL027710.MajorJointPatients_Unique AS b
            ON a.BENE_ID=b.BENE_ID
        ORDER BY a.BENE_ID, CLM_ID, RFR_PHYSN_NPI;
    QUIT;

    PROC SQL;
        CREATE TABLE WORK.&out AS
        SELECT a.*, b.RFR_PHYSN_NPI
        FROM WORK.OpCarrier_&mm AS a
        LEFT JOIN WORK.RefCarrier_&mm AS b
            ON a.BENE_ID=b.BENE_ID AND a.CLM_ID=b.CLM_ID
        ORDER BY a.BENE_ID, CLM_ID, PRF_PHYSN_NPI;
    QUIT;

    PROC DATASETS LIB=WORK NOLIST;
        DELETE OpCarrier_&mm RefCarrier_&mm;
    QUIT;
%MEND op_ref_month;

%MACRO referring_physicians;
%DO y = &year_ref_first %TO &year_last;

    PROC SQL;
        DROP TABLE WORK.Unique_Stays;
        CREATE TABLE WORK.Unique_Stays AS
        SELECT DISTINCT BENE_ID, CLM_FROM_DT, CLM_THRU_DT, OP_PHYSN_NPI
        FROM PL027710.MajorJoint_&y
        GROUP BY BENE_ID, CLM_FROM_DT, OP_PHYSN_NPI;
    QUIT;

    %stack_months(op_ref_month, &y, OpRef_&y);

    DATA PL027710.ReferralsCarrier_&y;
        SET WORK.OpRef_&y;
    RUN;

    PROC DATASETS LIB=WORK NOLIST;
        DELETE Unique_Stays OpRef_&y;
    QUIT;

%END;
%MEND referring_physicians;

%referring_physicians;
