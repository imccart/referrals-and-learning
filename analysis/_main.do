set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )

******************************************************************
**	Title:		Main file to call analysis files, etc.
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	5/25/2025
******************************************************************

******************************************************************
** Paths
set more off
global ROOT_PATH "/home/imc969/files/dua_027710/"
global DATA_SAS "${ROOT_PATH}data-sas/"
global DATA_UPLOAD "${ROOT_PATH}data-external/"

global PROJ_PATH "/home/imc969/files/dua_027710/pcp-referrals/"
global CODE_FILES "${PROJ_PATH}analysis/"
global LOG_PATH "${PROJ_PATH}logs/"
global RESULTS_ROOT "${PROJ_PATH}results/"
cd "${ROOT_PATH}stata-ado"


******************************************************************
** Global Variables

** referral assignment
global PCP_First=1	/* limit E&M and Claim Referring physicians to PCPs before identifying referral */
global PCP_Only=1	/* require that referring physician is a PCP */
global RFR_Priority=0   /* look to the listed referring physician on the claim as first indicator of referring physician */

if ${PCP_First}==1 {
	global PCP_Only=1
}

** global variables governing level of decision maker (physician vs practice)
global PCP_Practice=0   /* 0 denotes decision between physician and physician, 1 denotes decision at physician to practice */

** file paths based on global values
if ${PCP_Practice}==1 {
	global DATA_FINAL "${PROJ_PATH}data/pcp-practice-level/"
	global RESULTS_FINAL "${PROJ_PATH}results/pcp-practice-level/"
} 
else if ${PCP_Practice}==0 {
	global DATA_FINAL "${PROJ_PATH}data/pcp-level/"
	global RESULTS_FINAL "${PROJ_PATH}results/pcp-level/"	
}


** choice sets and sizes
global OUTSIDE_OPTION=0
global SPEC_MIN=20

** time-varying congestion
global CONG_t=1
if ${CONG_t}==1 {
	global RESULTS_FINAL "${RESULTS_FINAL}time_vary/"
}


******************************************************************
** Preliminary code

do "${CODE_FILES}A0-programs.do"		/* Programs and functions */
do "${CODE_FILES}A0-intermediate-data.do"	/* Temporary datasets used throughout analysis */
		
		
******************************************************************
** Analysis

do "${CODE_FILES}A1-desc-stats.do"
do "${CODE_FILES}A2-reduced-form.do"
do "${CODE_FILES}A3-mnl-myopic.do"
do "${CODE_FILES}A4-mnl-distance.do"
do "${CODE_FILES}A5-structural-myopic.do"
do "${CODE_FILES}A6-structural-forward-looking.do"

******************************************************************		
** Output Results


do "${CODE_FILES}O2-structural-myopic-summary.do"
do "${CODE_FILES}O3-structural-fwdlooking-summary.do"




******************************************************************
** ANALYSIS SANDBOX
use "${DATA_FINAL}ChoiceData_HRR1_1_1_0.dta", clear
do "${CODE_FILES}_clean-analysis.do"

** prepare for cmclogit syntax
egen referral=group(bene_id admit)
keep Practice_ID Specialist_ID choice referral case_obs casevar common_ref prop_failures_run prop_patients_run ///
	pair_success_run spec_qual pair_patients_run bene_spec_distance bene_distance diff_dist prac_vi pair_new ///
	fmly_np_* Year
sum fmly_np_*
drop fmly_np_0
cmset Practice_ID referral case_obs
		
qui sum spec_qual
local rho=r(mean)
gen m=.
local eta=1
replace m=(`rho'*`eta' + pair_success_run)/(`eta' + pair_patients_run)

** estimate and save results
gsort casevar -common_ref
gen time_period=(Year>2015)
cmclogit choice m diff_dist fmly_np_* ib(freq).Specialist_ID if time_period==0, noconstant iterate(20)		


** fixed point convergence problems
preserve
drop if abs(xi_j)>6
gen m=spec_qual
gen pat_count=0
forvalues i=1/200 {
	local i=2
	gen exp_uij_`i'=exp(coef_dist*diff_dist + coef_m*m + fmly_agg + xi_j + iv_pat*pat_count)
	bys casevar: egen sum_exp_uij_`i'=sum(exp_uij_`i')
	gen pij_`i'=exp_uij_`i'/sum_exp_uij_`i'
	bys Specialist_ID: egen pred`i'=sum(pij_`i')
	replace pat_count=0.5*pred`i'+0.5*pat_count
	drop exp_uij sum_exp_uij pij
}
keep if Specialist_ID==1043209513
keep if _n==1
keep pred*
gen spec=1
reshape long pred, i(spec) j(patients)
restore
