/* ------------------------------------------------------------ */
/* TITLE:         SAS build driver                              */
/* AUTHOR:        Ian McCarthy                                  */
/*                Emory University                              */
/* DATE CREATED:  10/30/2026                                    */
/* PURPOSE:       Run the SAS side of the build in order. Every */
/*                table lands in PL027710 for the Stata build.  */
/* ------------------------------------------------------------ */

%LET code_path = /sas/vrdc/users/imc969/files/dua_27710/pcp-referrals/data-code/sas;

%INCLUDE "&code_path/0_config.sas";

/* crosswalks and reference files */
%INCLUDE "&code_path/upin2npi.sas";
%INCLUDE "&code_path/nppes.sas";

/* the sample and its outcomes */
%INCLUDE "&code_path/1_major_joint.sas";
%INCLUDE "&code_path/2_outcomes.sas";

/* physicians seen before surgery */
%INCLUDE "&code_path/3_carrier_visits.sas";
%INCLUDE "&code_path/4_referral_assignment.sas";
%INCLUDE "&code_path/7_referring_physicians.sas";

/* characteristics */
%INCLUDE "&code_path/5_physician_data.sas";
%INCLUDE "&code_path/6_patient_data.sas";
%INCLUDE "&code_path/8_locations.sas";
%INCLUDE "&code_path/9_patient_cci.sas";
