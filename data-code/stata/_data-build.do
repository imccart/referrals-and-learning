set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )

******************************************************************
**	Title:		Main file to build the analytic data
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	10/30/2026
**	Notes:		Reads the SAS tables straight from the library folder
**			(no exports). Builds the referral panel and the choice
**			sets at the surgeon level (pcp-level) and at the
**			practice level (pcp-practice-level), each into its own
**			data folder, with the working directory set to the
**			level's temp folder so temp files land there.
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


******************************************************************
** Global variables
global PCP_Visit=2	/* minimum visits for a physician to be assigned as the referring PCP */
global DATA_END=mdy(12,31,2018)	/* last day of claims; outcomes for stays discharged within 90 days of it are right-censored (R6) */


******************************************************************
** Build by level of the specialist choice: surgeon NPI (pcp-level)
** and surgeon practice TIN (pcp-practice-level)

foreach level in pcp-level pcp-practice-level {

	if "`level'"=="pcp-level" {
		global PCP_Practice=0
	}
	else {
		global PCP_Practice=1
	}
	global DATA_FINAL "${PROJ_PATH}data/`level'/"
	global RESULTS_FINAL "${PROJ_PATH}results/`level'/"
	global LOG_PATH "${PROJ_PATH}logs/`level'/"
	capture mkdir "${PROJ_PATH}data/"
	capture mkdir "${DATA_FINAL}"
	capture mkdir "${PROJ_PATH}results/"
	capture mkdir "${RESULTS_FINAL}"
	capture mkdir "${PROJ_PATH}logs/"
	capture mkdir "${LOG_PATH}"
	capture mkdir "${PROJ_PATH}temp/"
	capture mkdir "${PROJ_PATH}temp/`level'/"
	cd "${PROJ_PATH}temp/`level'/"

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
}
