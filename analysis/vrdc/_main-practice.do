set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )

******************************************************************
**	Title:		Analysis, practice as the unit of choice
**	Author:		Ian McCarthy
**	Date Created:	11/2/2026
**	Notes:		_main-surgeon.do with the practice unit (D2) and the
**			practice folders. Runs the scripts that are defined for a
**			practice: the intermediate data, the re-referral analysis,
**			the congestion instrument, the structural estimation, and
**			the counterfactuals. The descriptive statistics (A1), the
**			MNL sensitivities (A3), the paper numbers (O3), and the
**			supplemental scripts (S1-S6) describe surgeons and do not run.
******************************************************************

******************************************************************
** Paths
set more off
global ROOT_PATH "/home/imc969/files/dua_027710/"
global DATA_SAS "/sas/vrdc/data/dua/dua_027710/files/Users/imc969/libs/"
global DATA_UPLOAD "${ROOT_PATH}data-external/"

global PROJ_PATH "${ROOT_PATH}pcp-referrals/"
global CODE_FILES "${PROJ_PATH}analysis/"
adopath + "${ROOT_PATH}stata-ado"
do "${PROJ_PATH}data-code/stata/_programs.do"		/* sasload */
do "${PROJ_PATH}data-code/stata/D2_unit-practice.do"	/* the unit of the specialist choice */

global DATA_FINAL "${PROJ_PATH}data/practice/"
global RESULTS_FINAL "${PROJ_PATH}results/practice/"
global RESULTS_BASE "${RESULTS_FINAL}"
global LOG_PATH "${PROJ_PATH}logs/practice/"
foreach d in results logs temp {
	capture mkdir "${PROJ_PATH}`d'/"
	capture mkdir "${PROJ_PATH}`d'/practice/"
}
cd "${PROJ_PATH}temp/practice/"


******************************************************************
** Global variables
global SPEC_MIN=20	/* minimum yearly operations for a practice's busiest surgeon, for the practice to enter a choice set */
global OUTSIDE_OPTION=0	/* no outside option in the choice set; A4, A5, and _clean-analysis branch on this */


******************************************************************
** Programs
do "${CODE_FILES}A0-programs.do"


******************************************************************
** Intermediate data and reduced form
do "${CODE_FILES}A0-intermediate-data.do"	/* temporary datasets used throughout */
do "${CODE_FILES}A2-rereferral.do"		/* re-referral after failure vs success: level and referral-order event study */
do "${CODE_FILES}A4-mnl-distance.do"		/* congestion instrument */


******************************************************************
** Structural estimation and output, by model
foreach model in Myopic FWD {
	global MODEL_TYPE "`model'"
	do "${CODE_FILES}A5-structural-estimation.do"
	do "${CODE_FILES}O1-coef-tables.do"
	do "${CODE_FILES}O2-baseline.do"
	do "${CODE_FILES}O5-model-diagnostics.do"
	foreach cf in current full fullfam fullnofe {
		global CF_NAME "`cf'"
		do "${CODE_FILES}O2-counterfactuals.do"
	}
	do "${CODE_FILES}O2-counterfactuals-qualmax.do"
	do "${CODE_FILES}O4-VRDC-figures.do"
}
