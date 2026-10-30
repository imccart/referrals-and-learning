/* ------------------------------------------------------------ */
/* TITLE:         SAS build driver                               */
/* AUTHOR:        Ian McCarthy                                   */
/*                Emory University                               */
/* DATE CREATED:  10/30/2026                                     */
/* PURPOSE:       Run the SAS side of the build in order. Set    */
/*                &code_path to the folder holding these         */
/*                programs on the seat. Every table lands in     */
/*                PL027710; the Stata build reads them from the  */
/*                library folder directly, so nothing is          */
/*                exported.                                       */
/* ------------------------------------------------------------ */

%LET code_path = /home/imc969/files/dua_027710/pcp-referrals/data-code/sas;

%INCLUDE "&code_path/0_config.sas";

/* crosswalks and reference files */
%INCLUDE "&code_path/upin2npi.sas";              /* UPIN and provider number to NPI, early years */
%INCLUDE "&code_path/nppes.sas";                 /* NPPES records by year */

/* the sample and its outcomes */
%INCLUDE "&code_path/1_major_joint.sas";         /* major joint stays; patient lists */
%INCLUDE "&code_path/2_outcomes.sas";            /* complications and readmissions */

/* physicians seen before surgery */
%INCLUDE "&code_path/3_carrier_visits.sas";      /* E&M visits of the patients; PCP subset */
%INCLUDE "&code_path/4_referral_assignment.sas"; /* physicians seen in the year before each stay */
%INCLUDE "&code_path/7_referring_physicians.sas";/* referring NPI on the surgeon's claims */

/* characteristics */
%INCLUDE "&code_path/5_physician_data.sas";      /* physician characteristics */
%INCLUDE "&code_path/6_patient_data.sas";        /* patient characteristics */
%INCLUDE "&code_path/8_locations.sas";           /* hospital and physician zips */
%INCLUDE "&code_path/9_patient_cci.sas";         /* Charlson index */
