/* ------------------------------------------------------------ */
/* TITLE:         Patient characteristics                        */
/* AUTHOR:        Ian McCarthy                                   */
/*                Emory University                               */
/* DATE CREATED:  9/18/2017                                      */
/* DATE EDITED:   10/30/2026                                    */
/* CODE FILE ORDER: 6                                            */
/* INPUT:         MBSF.MBSF_ABCD_yyyy                            */
/*                MajorJoint_yyyy (step 1)                       */
/* OUTPUT:        OrthoPatient_Data_yyyy                         */
/* ------------------------------------------------------------ */

/* State, zip, birth and death dates, sex, and race from the     */
/* beneficiary summary file for every patient with a stay in     */
/* the year.                                                     */

%MACRO patient_data;
%DO y = &year_first %TO &year_last;

    PROC SQL;
        DROP TABLE WORK.Patient_Data;
        CREATE TABLE WORK.Patient_Data AS
            SELECT BENE_ID, STATE_CODE, ZIP_CD, BENE_BIRTH_DT, BENE_DEATH_DT, SEX_IDENT_CD AS Gender, BENE_RACE_CD AS Race
            FROM MBSF.MBSF_ABCD_&y;
    QUIT;

    PROC SQL;
        DROP TABLE WORK.PatientSet;
        CREATE TABLE WORK.PatientSet AS
            SELECT DISTINCT BENE_ID
            FROM PL027710.MajorJoint_&y;
    QUIT;

    PROC SQL;
        DROP TABLE PL027710.OrthoPatient_Data_&y;
        CREATE TABLE PL027710.OrthoPatient_Data_&y AS
            SELECT a.BENE_ID, b.*
            FROM WORK.PatientSet AS a
            LEFT JOIN WORK.Patient_Data AS b
            ON a.BENE_ID=b.BENE_ID;
    QUIT;

    PROC DATASETS LIB=WORK NOLIST;
        DELETE Patient_Data PatientSet;
    QUIT;

%END;
%MEND patient_data;

%patient_data;
