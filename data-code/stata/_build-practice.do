set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )

******************************************************************
**	Title:		Build the analytic data, practice as the unit of choice
**	Author:		Ian McCarthy
**	Date Updated:	11/2/2026
**	Notes:		_build-surgeon.do with _unit-practice.do and the practice
**			folders.
******************************************************************

set more off
global ROOT_PATH "/home/imc969/files/dua_027710/"
global DATA_SAS "/sas/vrdc/data/dua/dua_027710/files/Users/imc969/libs/"
global DATA_UPLOAD "${ROOT_PATH}data-external/"
global PROJ_PATH "${ROOT_PATH}pcp-referrals/"
global CODE_FILES "${PROJ_PATH}data-code/stata/"
adopath + "${ROOT_PATH}stata-ado"
do "${CODE_FILES}_programs.do"
do "${CODE_FILES}_unit-practice.do"

global DATA_FINAL "${PROJ_PATH}data/practice/"
global RESULTS_FINAL "${PROJ_PATH}results/practice/"
global LOG_PATH "${PROJ_PATH}logs/practice/"
cd "${PROJ_PATH}temp/practice/"

global PCP_Visit=2	/* minimum visits to be assigned as the referring PCP */
global DATA_END=mdy(12,31,2018)	/* last day of claims; stays without a full 90-day window are dropped */

do "${CODE_FILES}1_geography.do"

log using "${LOG_PATH}ReferralPanel_`logdate'.log", replace
do "${CODE_FILES}2_referral-panel.do"
log close

log using "${LOG_PATH}ChoiceSets_`logdate'.log", replace
do "${CODE_FILES}3_choice-sets.do"
log close

log using "${LOG_PATH}Capacity_`logdate'.log", replace
do "${CODE_FILES}4_capacity.do"
log close
