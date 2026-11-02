/* ------------------------------------------------------------ */
/* TITLE:         NPPES physician records by year                */
/* AUTHOR:        Ian McCarthy                                   */
/*                Emory University                               */
/* DATE CREATED:  5/12/2015                                      */
/* DATE EDITED:   10/30/2026                                    */
/* INPUT:         NPPES10.NPPES_DEC2010 through                  */
/*                NPPES15.NPPES_DEC2015                          */
/* OUTPUT:        NPPES_yyyy for &year_first through &nppes_last */
/* ------------------------------------------------------------ */

/* The December NPPES file of each year, with the primary        */
/* taxonomy code picked out. The earliest file held is 2010 and  */
/* serves 2007-2009; years after &nppes_last reuse that year's   */
/* table (see %nppes_year in the config).                       */

%MACRO nppes;
%DO y = &year_first %TO &nppes_last;
    %LET src = %SYSFUNC(MAX(&y, 2010));
    PROC SQL;
        DROP TABLE PL027710.NPPES_&y;
        CREATE TABLE PL027710.NPPES_&y AS
        SELECT *,
            CASE
                WHEN HPPTS_1='Y' THEN HPTC_1
                WHEN HPPTS_2='Y' THEN HPTC_2
                WHEN HPPTS_3='Y' THEN HPTC_3
                WHEN HPPTS_4='Y' THEN HPTC_4
                WHEN HPPTS_5='Y' THEN HPTC_5
                ELSE ''
            END AS Specialty_HPTC, &y AS Year
        FROM NPPES%SUBSTR(&src,3,2).NPPES_DEC&src;
    QUIT;
%END;
%MEND nppes;

%nppes;
