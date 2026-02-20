set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )

******************************************************************
**	Title:		Main file to build analytic data
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	6/18/2025
******************************************************************

******************************************************************
** Preliminaries
set more off
global ROOT_PATH "/home/imc969/files/dua_027710/"
global DATA_SAS "${ROOT_PATH}data-sas/"
global DATA_UPLOAD "${ROOT_PATH}data-external/"

global PROJ_PATH "/home/imc969/files/dua_027710/pcp-referrals/"
global CODE_FILES "${PROJ_PATH}data-code/stata/"
global LOG_PATH "${PROJ_PATH}logs/"
cd "${ROOT_PATH}stata-ado"

** global variables governing referral assignment
global PCP_First=1	/* limit E&M and Claim Referring physicians to PCPs before identifying referral */
global PCP_Only=1	/* require that referring physician is a PCP */
global RFR_Priority=0   /* look to the listed referring physician to supplement visit frequency? */
global PCP_Visit=2	/* Minimum number of visits to assign PCP as the referring physician */

if ${PCP_First}==1 {
	global PCP_Only=1
}

** global variables governing level of decision maker (physician vs practice)
global PCP_Practice=1   /* 0 denotes decision between physician and physician, 1 denotes decision at physician to practice */

** file paths based on global values
if ${PCP_Practice}==1 {
	global DATA_FINAL "${PROJ_PATH}data/pcp-practice-level/"
	global RESULTS_FINAL "${PROJ_PATH}results/pcp-practice-level"
} 
else if ${PCP_Practice}==0 {
	global DATA_FINAL "${PROJ_PATH}data/pcp-level/"
	global RESULTS_FINAL "${PROJ_PATH}results/pcp-level"	
}

******************************************************************
** Build data

** HRR and Zip data
do "${CODE_FILES}ZipHRR.do"

** Lat/Long data
insheet using "${DATA_UPLOAD}zip-latlong-nber.csv", clear
rename zcta5 zip
rename intptlat lat
rename intptlon lon
destring zip, force replace
drop if zip==.
save "${DATA_FINAL}LatLong.dta", replace

** Main referral dataset
log using "${LOG_PATH}BuildReferralData_`logdate'.log", replace
do "${CODE_FILES}R0_BuildReferralData.do"
log close


** Main choice dataset
log using "${LOG_PATH}BuildChoiceData_`logdate'.log", replace
do "${CODE_FILES}C0_BuildChoiceData.do"
log close
