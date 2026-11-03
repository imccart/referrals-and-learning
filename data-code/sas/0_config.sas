/* ------------------------------------------------------------ */
/* TITLE:         Configuration and shared macros                */
/* AUTHOR:        Ian McCarthy                                   */
/*                Emory University                               */
/* DATE CREATED:  10/30/2026                                     */
/* PURPOSE:       Year ranges, year-specific rules, and the      */
/*                month-stacking macro used by every step.       */
/*                Run first in the session; the others use it.  */
/* ------------------------------------------------------------ */

/* Libraries. PL027710 (project), RIFyyyy, MBSF, MD_PPAS,         */
/* PROVIDER, NPPES10-NPPES15, IN027710, and _UPLDS are mounted by */
/* the seat; nothing is declared here.                           */


/* ============================================================ */
/* Year ranges                                                   */
/* ============================================================ */
%LET year_first = 2007;   /* surgeries, outcomes, carrier visits, physicians, patients */
%LET year_last  = 2018;
%LET year_ref_first = 2008;   /* referral assignment and referring-physician steps use year-1 */
%LET year_loc_first = 2009;   /* physician and hospital locations (POS and MBSF availability) */
%LET year_cci_first = 2008;   /* Charlson index */


/* ============================================================ */
/* Year-specific rules                                           */
/* ============================================================ */

/* NPPES: last vintage held is 2015; later years reuse it.       */
%LET nppes_last = 2015;
%MACRO nppes_year(y);
    %SYSFUNC(MIN(&y, &nppes_last))
%MEND nppes_year;

/* UPIN and provider-number crosswalks exist for 2007-2009; the   */
/* 2007-2008 inpatient claims carry NPIs only partly and are      */
/* filled from them (step 1). From 2009 the claim NPIs are used.  */
%LET npi_direct_first = 2009;
%LET upin_last = 2008;   /* UPIN crosswalk built through this year; provider-number crosswalk through npi_direct_first */

/* MD-PPAS (physician specialty): first and last vintage held.    */
/* Years outside the range use the nearest vintage.              */
%LET mdppas_first = 2008;
%LET mdppas_last  = 2017;
%MACRO mdppas_year(y);
    %SYSFUNC(MAX(&mdppas_first, %SYSFUNC(MIN(&y, &mdppas_last))))
%MEND mdppas_year;

/* Carrier lines for 2007-2008 in the physician step come from    */
/* the original request tables, one per year; from 2009 from the  */
/* RIF monthly files. The carrier-visit step reads the RIF files  */
/* for every year, as it always has.                              */
%MACRO carrier_line_source(y, mm);
    %IF &y < 2009 %THEN IN027710.BCARLINEK%SUBSTR(&y,3,2)_R6723;
    %ELSE RIF&y..BCARRIER_LINE_&mm;
%MEND carrier_line_source;

/* Provider of Services columns were renamed from 2011.           */
%MACRO pos_cols(y);
    %IF &y <= 2010 %THEN %DO;
        %GLOBAL pos_name pos_cnty pos_state pos_prvdr pos_parent;
        %LET pos_name   = FACILITY_NAME;
        %LET pos_cnty   = FIPS_CNTY;
        %LET pos_state  = FIPS_STATE;
        %LET pos_prvdr  = PROV_NUM;
        %LET pos_parent = PARENT_PROV_NUM;
    %END;
    %ELSE %DO;
        %GLOBAL pos_name pos_cnty pos_state pos_prvdr pos_parent;
        %LET pos_name   = FAC_NAME;
        %LET pos_cnty   = FIPS_CNTY_CD;
        %LET pos_state  = FIPS_STATE_CD;
        %LET pos_prvdr  = PRVDR_NUM;
        %LET pos_parent = PARENT_PROVIDER_NUMBER;
    %END;
%MEND pos_cols;


/* ============================================================ */
/* Sample definition                                             */
/* ============================================================ */

/* Major joint replacement DRGs (MS-DRG 2008 onward and the       */
/* CMS-DRG codes used before it).                                */
%LET mj_drg_list = "469", "470", "461", "462", "485", "486", "487", "488", "489", "480", "481", "482", "483",
                   "507", "508", "510", "511", "512";


/* ============================================================ */
/* Table names                                                   */
/* ============================================================ */

/* Step 3's carrier-visit table. physician-referral-formation     */
/* writes OrthoCarrier_yyyy to the same library, so this project  */
/* uses its own name.                                             */
%LET carrier_tbl = MJ_OrthoCarrier;


/* ============================================================ */
/* Month stacking                                                */
/* ============================================================ */

/* Run a query once per month of year &y and stack the twelve     */
/* results. The query is a macro that takes (y, mm, out) and      */
/* writes WORK.&out; this wrapper calls it twelve times and sets  */
/* the stack together as WORK.&stack. For 2007-2008 the carrier   */
/* source is one table, so the query runs once with mm=01.        */
%MACRO stack_months(query, y, stack, single_if_request=0);
    %LOCAL m mm;
    %IF &single_if_request = 1 AND &y < 2009 %THEN %DO;
        %&query(&y, 01, &stack._m01);
        DATA WORK.&stack;
            SET WORK.&stack._m01;
        RUN;
        PROC DELETE DATA=WORK.&stack._m01; RUN;
    %END;
    %ELSE %DO;
        %DO m = 1 %TO 12;
            %LET mm = %SYSFUNC(PUTN(&m, Z2.));
            %&query(&y, &mm, &stack._m&mm);
        %END;
        DATA WORK.&stack;
            SET %DO m = 1 %TO 12; WORK.&stack._m%SYSFUNC(PUTN(&m, Z2.)) %END;;
        RUN;
        PROC DATASETS LIB=WORK NOLIST;
            DELETE &stack._m:;
        QUIT;
    %END;
%MEND stack_months;
