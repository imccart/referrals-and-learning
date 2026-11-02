/* ------------------------------------------------------------ */
/* TITLE:         UPIN and provider-number crosswalks to NPI     */
/* AUTHOR:        Ian McCarthy                                   */
/*                Emory University                               */
/* DATE CREATED:  5/12/2015                                      */
/* DATE EDITED:   10/30/2026                                    */
/* INPUT:         RIFyyyy.INPATIENT_CLAIMS_01-12                 */
/*                _UPLDS.UPIN2NPIXW (uploaded UPIN-NPI crosswalk)*/
/* OUTPUT:        UPIN_NPI_Merge_yyyy, Unique_UPIN_yyyy           */
/*                  (through &upin_last)                         */
/*                PRVN_NPI_Merge_yyyy, Unique_PRVN_yyyy           */
/*                  (through &npi_direct_first)                  */
/* ------------------------------------------------------------ */

/* Early inpatient claims identify the operating physician by    */
/* UPIN and the hospital by provider number, with the NPI only   */
/* partly filled. Each UPIN gets an NPI in three passes: the     */
/* unique NPI seen on other claims with that UPIN; failing that, */
/* the NPI from those claims that the uploaded crosswalk agrees  */
/* with; failing that, the unique NPI in the crosswalk. Each     */
/* provider number gets the unique NPI seen on claims with it.   */

%MACRO upin2npi;
%DO y = &year_first %TO &npi_direct_first;

    DATA WORK.InpatientStays_&y;
        SET %DO m = 1 %TO 12; RIF&y..INPATIENT_CLAIMS_%SYSFUNC(PUTN(&m, Z2.)) %END;;
    RUN;

    %IF &y <= &upin_last %THEN %DO;

    /* pass 1: unique NPI on other claims with the same UPIN */
    PROC SQL;
        DROP TABLE WORK.UPIN_&y;
        CREATE TABLE WORK.UPIN_&y AS
        SELECT OP_PHYSN_UPIN, OP_PHYSN_NPI AS NPI, count(distinct CLM_ID) AS Claims
        FROM WORK.InpatientStays_&y
        WHERE OP_PHYSN_UPIN NE '' AND OP_PHYSN_NPI NE '0000000000' AND OP_PHYSN_NPI NE ''
        GROUP BY OP_PHYSN_UPIN, OP_PHYSN_NPI;
    QUIT;

    PROC SORT DATA=WORK.UPIN_&y OUT=WORK.UPIN_&y;
        BY OP_PHYSN_UPIN DESCENDING Claims;
    RUN;

    DATA WORK.UPIN_&y;
    SET WORK.UPIN_&y;
        BY OP_PHYSN_UPIN;
        IF first.OP_PHYSN_UPIN THEN n=1;
        ELSE n+1;
    RUN;

    PROC SQL;
        DROP TABLE WORK.UPIN_NPI1_&y;
        CREATE TABLE WORK.UPIN_NPI1_&y AS
        SELECT OP_PHYSN_UPIN, NPI
        FROM WORK.UPIN_&y
        GROUP BY OP_PHYSN_UPIN
        HAVING max(n)=1;
    QUIT;

    /* pass 2: NPI from claims that the crosswalk agrees with */
    PROC SQL;
        DROP TABLE WORK.UPIN_NPI_XWLK_&y;
        CREATE TABLE WORK.UPIN_NPI_XWLK_&y AS
        SELECT a.OP_PHYSN_UPIN, a.NPI
        FROM WORK.UPIN_&y AS a
        LEFT JOIN (SELECT DISTINCT upin, npi
                    FROM _UPLDS.UPIN2NPIXW
                    WHERE othpidty=2 AND entity=1 AND upintype<4) AS b
        ON a.OP_PHYSN_UPIN=b.upin
        WHERE a.NPI=b.npi;
    QUIT;

    DATA WORK.UPIN_NPI_XWLK_&y;
    SET WORK.UPIN_NPI_XWLK_&y;
        BY OP_PHYSN_UPIN;
        IF first.OP_PHYSN_UPIN THEN n=1;
        ELSE n+1;
    RUN;

    PROC SQL;
        DROP TABLE WORK.UPIN_NPI2_&y;
        CREATE TABLE WORK.UPIN_NPI2_&y AS
        SELECT OP_PHYSN_UPIN, NPI
        FROM WORK.UPIN_NPI_XWLK_&y
        GROUP BY OP_PHYSN_UPIN
        HAVING max(n)=1;
    QUIT;

    /* pass 3: unique NPI in the crosswalk for UPINs with no NPI on any claim */
    PROC SQL;
        DROP TABLE WORK.UPINXWLK_&y;
        CREATE TABLE WORK.UPINXWLK_&y AS
        SELECT DISTINCT OP_PHYSN_UPIN
        FROM WORK.InpatientStays_&y
        WHERE OP_PHYSN_UPIN NE '' AND (OP_PHYSN_NPI='' OR OP_PHYSN_NPI='0000000000');
    QUIT;

    PROC SQL;
        DROP TABLE WORK.XWLKOnly_&y;
        CREATE TABLE WORK.XWLKOnly_&y AS
        SELECT a.OP_PHYSN_UPIN, b.npi
        FROM WORK.UPINXWLK_&y AS a
        LEFT JOIN (SELECT DISTINCT upin, npi
                    FROM _UPLDS.UPIN2NPIXW
                    WHERE othpidty=2 AND entity=1 AND upintype<4) AS b
        ON a.OP_PHYSN_UPIN=b.upin
        HAVING b.npi NE '';
    QUIT;

    DATA WORK.XWLKOnly_&y;
    SET WORK.XWLKOnly_&y;
        BY OP_PHYSN_UPIN;
        IF first.OP_PHYSN_UPIN THEN n=1;
        ELSE n+1;
    RUN;

    PROC SQL;
        DROP TABLE WORK.UPIN_NPI3_&y;
        CREATE TABLE WORK.UPIN_NPI3_&y AS
        SELECT OP_PHYSN_UPIN, npi AS NPI
        FROM WORK.XWLKOnly_&y
        GROUP BY OP_PHYSN_UPIN
        HAVING max(n)=1;
    QUIT;

    /* final UPIN merge */
    PROC SQL;
        DROP TABLE PL027710.Unique_UPIN_&y;
        CREATE TABLE PL027710.Unique_UPIN_&y AS
        SELECT DISTINCT OP_PHYSN_UPIN
        FROM WORK.InpatientStays_&y
        WHERE OP_PHYSN_UPIN NE '';
    QUIT;

    PROC SQL;
        DROP TABLE PL027710.UPIN_NPI_Merge_&y;
        CREATE TABLE PL027710.UPIN_NPI_Merge_&y AS
        SELECT a.OP_PHYSN_UPIN,
            CASE
                WHEN b.NPI NE '' THEN b.NPI
                WHEN b.NPI='' AND c.NPI NE '' THEN c.NPI
                WHEN b.NPI='' AND c.NPI='' AND d.NPI NE '' THEN d.NPI
            ELSE ''
            END AS NPI
        FROM PL027710.Unique_UPIN_&y AS a
        LEFT JOIN WORK.UPIN_NPI1_&y AS b
            ON a.OP_PHYSN_UPIN=b.OP_PHYSN_UPIN
        LEFT JOIN WORK.UPIN_NPI2_&y AS c
            ON a.OP_PHYSN_UPIN=c.OP_PHYSN_UPIN
        LEFT JOIN WORK.UPIN_NPI3_&y AS d
            ON a.OP_PHYSN_UPIN=d.OP_PHYSN_UPIN;
    QUIT;

    PROC DATASETS LIB=WORK NOLIST;
        DELETE UPIN_&y UPIN_NPI1_&y UPIN_NPI_XWLK_&y UPIN_NPI2_&y UPINXWLK_&y XWLKOnly_&y UPIN_NPI3_&y;
    QUIT;

    %END;

    /* provider number to NPI: unique NPI on claims with the same provider number */
    PROC SQL;
        DROP TABLE WORK.PRVN_&y;
        CREATE TABLE WORK.PRVN_&y AS
        SELECT PRVDR_NUM, ORG_NPI_NUM AS NPI, count(distinct CLM_ID) AS Claims
        FROM WORK.InpatientStays_&y
        WHERE PRVDR_NUM NE '' AND ORG_NPI_NUM NE ''
        GROUP BY PRVDR_NUM, ORG_NPI_NUM;
    QUIT;

    DATA WORK.PRVN_&y;
    SET WORK.PRVN_&y;
        IF ANYALPHA(PRVDR_NUM)>0 THEN DELETE;
    RUN;

    PROC SORT DATA=WORK.PRVN_&y OUT=WORK.PRVN_&y;
        BY PRVDR_NUM DESCENDING Claims;
    RUN;

    DATA WORK.PRVN_&y;
    SET WORK.PRVN_&y;
        BY PRVDR_NUM;
        IF first.PRVDR_NUM THEN n=1;
        ELSE n+1;
    RUN;

    PROC SQL;
        DROP TABLE WORK.PRVN_NPI1_&y;
        CREATE TABLE WORK.PRVN_NPI1_&y AS
        SELECT PRVDR_NUM, NPI
        FROM WORK.PRVN_&y
        GROUP BY PRVDR_NUM
        HAVING max(n)=1;
    QUIT;

    PROC SQL;
        DROP TABLE PL027710.Unique_PRVN_&y;
        CREATE TABLE PL027710.Unique_PRVN_&y AS
        SELECT DISTINCT PRVDR_NUM
        FROM WORK.InpatientStays_&y
        WHERE PRVDR_NUM NE '';
    QUIT;

    PROC SQL;
        DROP TABLE PL027710.PRVN_NPI_Merge_&y;
        CREATE TABLE PL027710.PRVN_NPI_Merge_&y AS
        SELECT a.PRVDR_NUM, b.NPI
        FROM PL027710.Unique_PRVN_&y AS a
        LEFT JOIN WORK.PRVN_NPI1_&y AS b
            ON a.PRVDR_NUM=b.PRVDR_NUM;
    QUIT;

    PROC DATASETS LIB=WORK NOLIST;
        DELETE InpatientStays_&y PRVN_&y PRVN_NPI1_&y;
    QUIT;

%END;
%MEND upin2npi;

%upin2npi;
