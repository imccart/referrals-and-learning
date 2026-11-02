/* ------------------------------------------------------------ */
/* TITLE:         Major joint replacement stays                  */
/* AUTHOR:        Ian McCarthy                                   */
/*                Emory University                               */
/* DATE CREATED:  12/31/2018                                     */
/* DATE EDITED:   10/30/2026                                    */
/* INPUT:         RIFyyyy.INPATIENT_CLAIMS_01-12                 */
/*                PRVN_NPI_Merge_yyyy, UPIN_NPI_Merge_yyyy        */
/*                (years before &npi_direct_first only)          */
/* OUTPUT:        MajorJoint_yyyy                                 */
/*                MajorJointPatients_ByYear                       */
/*                MajorJointPatients_Unique                       */
/* ------------------------------------------------------------ */

/* Inpatient stays for a major joint replacement DRG, admitted   */
/* on physician, clinic, or HMO referral (admission source 1-3), */
/* elective (admission type 3), hospital claims only (type 60).  */
/* Before &npi_direct_first the claims carry NPIs only partly,   */
/* so the hospital and operating-physician NPIs are filled from   */
/* the provider-number and UPIN crosswalks.                      */

%MACRO major_joint;
%DO y = &year_first %TO &year_last;

    DATA WORK.InpatientStays_&y;
        SET %DO m = 1 %TO 12; RIF&y..INPATIENT_CLAIMS_%SYSFUNC(PUTN(&m, Z2.)) %END;;
    RUN;

    PROC SQL;
        DROP TABLE PL027710.MajorJoint_&y;
        CREATE TABLE PL027710.MajorJoint_&y AS
        SELECT a.BENE_ID, a.CLM_ID, a.CLM_ADMSN_DT, a.NCH_BENE_DSCHRG_DT, a.CLM_FROM_DT, a.CLM_THRU_DT, a.PRVDR_NUM,
        %IF &y < &npi_direct_first %THEN %DO;
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
        %END;
        %ELSE %DO;
            a.ORG_NPI_NUM, a.OP_PHYSN_UPIN, a.OP_PHYSN_NPI,
        %END;
            a.CLM_DRG_CD, a.ADMTG_DGNS_CD, a.ICD_DGNS_CD1, a.PRNCPAL_DGNS_CD, a.ICD_PRCDR_CD1,
            a.CLM_PMT_AMT, a.CLM_TOT_CHRG_AMT,
            a.ICD_DGNS_CD2, a.ICD_DGNS_CD3, a.ICD_DGNS_CD4, a.ICD_DGNS_CD5, a.ICD_DGNS_CD6, a.ICD_DGNS_CD7,
            a.ICD_DGNS_CD8, a.ICD_DGNS_CD9, a.ICD_DGNS_CD10,
            a.ICD_PRCDR_CD2, a.ICD_PRCDR_CD3, a.ICD_PRCDR_CD4, a.ICD_PRCDR_CD5,
            a.ICD_PRCDR_CD6, a.ICD_PRCDR_CD7, a.ICD_PRCDR_CD8, a.ICD_PRCDR_CD9, a.ICD_PRCDR_CD10,
            a.PTNT_DSCHRG_STUS_CD AS DCHRG_STS
        FROM WORK.InpatientStays_&y AS a
        %IF &y < &npi_direct_first %THEN %DO;
        LEFT JOIN PL027710.PRVN_NPI_Merge_&y AS b
            ON a.PRVDR_NUM=b.PRVDR_NUM
        LEFT JOIN PL027710.UPIN_NPI_Merge_&y AS c
            ON a.OP_PHYSN_UPIN=c.OP_PHYSN_UPIN
        %END;
        WHERE a.CLM_SRC_IP_ADMSN_CD IN ("1","2","3")
          AND (a.NCH_CLM_TYPE_CD="60")
          AND (a.CLM_IP_ADMSN_TYPE_CD="3")
          AND (a.CLM_DRG_CD IN (&mj_drg_list));
    QUIT;

    PROC SQL;
        DROP TABLE WORK.MajorJointPatient_&y;
        CREATE TABLE WORK.MajorJointPatient_&y AS
        SELECT DISTINCT BENE_ID, &y AS Year
        FROM PL027710.MajorJoint_&y;
    QUIT;

    PROC DELETE DATA=WORK.InpatientStays_&y; RUN;

%END;

/* Patients by year and unique patients, for the carrier steps   */
DATA PL027710.MajorJointPatients_ByYear;
    SET %DO y = &year_first %TO &year_last; WORK.MajorJointPatient_&y %END;;
RUN;

PROC SQL;
    DROP TABLE PL027710.MajorJointPatients_Unique;
    CREATE TABLE PL027710.MajorJointPatients_Unique AS
    SELECT DISTINCT BENE_ID
    FROM PL027710.MajorJointPatients_ByYear;
QUIT;

%MEND major_joint;

%major_joint;
