set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )

******************************************************************
**	Title:		Analysis, practice as the unit of choice
**	Author:		Ian McCarthy
**	Date Updated:	11/2/2026
**	Notes:		_main-surgeon.do with _unit-practice.do and the practice
**			folders. A2, A4, O7, and S1-S6 describe surgeons and do not run.
******************************************************************

set more off
global ROOT_PATH "/home/imc969/files/dua_027710/"
global DATA_SAS "/sas/vrdc/data/dua/dua_027710/files/Users/imc969/libs/"
global DATA_UPLOAD "${ROOT_PATH}data-external/"
global PROJ_PATH "${ROOT_PATH}pcp-referrals/"
global CODE_FILES "${PROJ_PATH}analysis/"
adopath + "${ROOT_PATH}stata-ado"
do "${PROJ_PATH}data-code/stata/_programs.do"
do "${PROJ_PATH}data-code/stata/_unit-practice.do"
do "${CODE_FILES}_programs.do"

global DATA_FINAL "${PROJ_PATH}data/practice/"
global RESULTS_FINAL "${PROJ_PATH}results/practice/"
global RESULTS_BASE "${RESULTS_FINAL}"
global LOG_PATH "${PROJ_PATH}logs/practice/"
cd "${PROJ_PATH}temp/practice/"

global SPEC_MIN=20	/* minimum yearly operations of the practice's busiest surgeon to enter a choice set */
global OUTSIDE_OPTION=0

** A: analysis
do "${CODE_FILES}A1_intermediate-data.do"
do "${CODE_FILES}A3_rereferral.do"
do "${CODE_FILES}A5_congestion-instrument.do"
foreach model in Myopic FWD {
	global MODEL_TYPE "`model'"
	do "${CODE_FILES}A6_structural-estimation.do"

	** O: output, by model
	do "${CODE_FILES}O1_coef-tables.do"
	do "${CODE_FILES}O2_baseline.do"
	do "${CODE_FILES}O3_model-diagnostics.do"
	foreach cf in current full fullfam fullnofe {
		global CF_NAME "`cf'"
		do "${CODE_FILES}O4_counterfactuals.do"
	}
	do "${CODE_FILES}O5_counterfactuals-qualmax.do"
	do "${CODE_FILES}O6_figures.do"
}
