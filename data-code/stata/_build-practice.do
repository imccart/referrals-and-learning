set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )

******************************************************************
**	Title:		Build the analytic data, practice as the unit of choice
**	Author:		Ian McCarthy
**	Date Created:	11/2/2026
**	Notes:		_build-surgeon.do with the practice unit (D2) and the
**			practice folders. Run after the surgeon build only in the
**			sense that both read the same SAS tables; neither depends
**			on the other's output.
******************************************************************

******************************************************************
** Paths
set more off
global ROOT_PATH "/home/imc969/files/dua_027710/"
global DATA_SAS "/sas/vrdc/data/dua/dua_027710/files/Users/imc969/libs/"
global DATA_UPLOAD "${ROOT_PATH}data-external/"

global PROJ_PATH "${ROOT_PATH}pcp-referrals/"
global CODE_FILES "${PROJ_PATH}data-code/stata/"
adopath + "${ROOT_PATH}stata-ado"
do "${CODE_FILES}_programs.do"
do "${CODE_FILES}D2_unit-practice.do"	/* the unit of the specialist choice */

global DATA_FINAL "${PROJ_PATH}data/practice/"
global RESULTS_FINAL "${PROJ_PATH}results/practice/"
global LOG_PATH "${PROJ_PATH}logs/practice/"
foreach d in data results logs temp {
	capture mkdir "${PROJ_PATH}`d'/"
	capture mkdir "${PROJ_PATH}`d'/practice/"
}
cd "${PROJ_PATH}temp/practice/"


******************************************************************
** Global variables
global PCP_Visit=2	/* minimum visits for a physician to be assigned as the referring PCP */
global DATA_END=mdy(12,31,2018)	/* last day of claims; stays discharged within 90 days of it are dropped (R0) */


******************************************************************
** Build

** HRR and zip data
do "${CODE_FILES}ZipHRR.do"

** lat/long data
insheet using "${DATA_UPLOAD}zip-latlong-nber.csv", clear
rename zcta5 zip
rename intptlat lat
rename intptlon lon
destring zip, force replace
drop if zip==.
save "${DATA_FINAL}LatLong.dta", replace

** main referral dataset
log using "${LOG_PATH}BuildReferralData_`logdate'.log", replace
do "${CODE_FILES}R0_BuildReferralData.do"
log close

** main choice dataset
log using "${LOG_PATH}BuildChoiceData_`logdate'.log", replace
do "${CODE_FILES}C0_BuildChoiceData.do"
log close

** specialist capacity data
log using "${LOG_PATH}SpecialistCapacity_`logdate'.log", replace
do "${CODE_FILES}S1_SpecialistCapacity.do"
log close
