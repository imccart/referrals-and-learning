set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )

******************************************************************
**	Title:		Analysis, surgeon as the unit of choice
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	11/2/2026
**	Notes:		Reads data/surgeon/ (from _build-surgeon.do) and writes
**			results/surgeon/. The unit of the specialist choice is set
**			by the D script loaded below and by nothing else. The
**			working directory is temp/surgeon/, where temp files saved
**			with relative paths land. _main-practice.do is the practice
**			counterpart and runs the subset of scripts that are defined
**			for practices.
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
do "${PROJ_PATH}data-code/stata/D1_unit-surgeon.do"	/* the unit of the specialist choice */

global DATA_FINAL "${PROJ_PATH}data/surgeon/"
global RESULTS_FINAL "${PROJ_PATH}results/surgeon/"
global RESULTS_BASE "${RESULTS_FINAL}"
global LOG_PATH "${PROJ_PATH}logs/surgeon/"
foreach d in results logs temp {
	capture mkdir "${PROJ_PATH}`d'/"
	capture mkdir "${PROJ_PATH}`d'/surgeon/"
}
cd "${PROJ_PATH}temp/surgeon/"


******************************************************************
** Global variables
global SPEC_MIN=20	/* minimum yearly operations for a specialist to enter a choice set */
global OUTSIDE_OPTION=0	/* no outside option in the choice set; A4, A5, and _clean-analysis branch on this */


******************************************************************
** Programs
do "${CODE_FILES}A0-programs.do"


******************************************************************
** Intermediate data and reduced form
do "${CODE_FILES}A0-intermediate-data.do"	/* temporary datasets used throughout */
do "${CODE_FILES}A1-desc-stats.do"
do "${CODE_FILES}A2-rereferral.do"		/* re-referral after failure vs success: level and referral-order event study */
do "${CODE_FILES}A3-mnl-myopic.do"		/* MNL sensitivities (appendix) */
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
do "${CODE_FILES}O3-paper-numbers.do"	/* loops over both models */


******************************************************************
** Supplemental diagnostics, risk adjustment, and sample descriptives
do "${CODE_FILES}S1-diagnostics.do"
do "${CODE_FILES}S2-pcp-assignment.do"
do "${CODE_FILES}S3-first-stage.do"
do "${CODE_FILES}S4-uniqueness.do"
do "${CODE_FILES}S5-risk-adjustment.do"
do "${CODE_FILES}S6-sample-descriptives.do"	/* patient mix by specialist, billing groups, established vs all PCPs, referral endpoint */
