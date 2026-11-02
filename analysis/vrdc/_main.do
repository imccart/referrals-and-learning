set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )

******************************************************************
**	Title:		Main file to call analysis files
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	10/30/2026
**	Notes:		Runs the analysis at the surgeon level (pcp-level) and
**			at the practice level (pcp-practice-level). Each level
**			has its own data, results, log, and temp folders, and
**			the working directory is the level's temp folder, so
**			temp files saved with relative paths land there.
**			Model-specific output runs for Myopic and FWD.
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
do "${PROJ_PATH}data-code/stata/_programs.do"	/* sasload: reads SAS tables from the library folder */


******************************************************************
** Global variables
global SPEC_MIN=20	/* minimum yearly operations for a specialist to enter a choice set */
global OUTSIDE_OPTION=0	/* no outside option in the choice set; A4, A5, and _clean-analysis branch on this */


******************************************************************
** Programs
do "${CODE_FILES}A0-programs.do"


******************************************************************
** Analysis by level of the specialist choice: surgeon NPI (pcp-level)
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
	global RESULTS_BASE "${RESULTS_FINAL}"	/* level-wide and model-specific output share one folder; model-specific files carry the model in the name */
	global LOG_PATH "${PROJ_PATH}logs/`level'/"
	capture mkdir "${PROJ_PATH}results/"
	capture mkdir "${RESULTS_FINAL}"
	capture mkdir "${PROJ_PATH}logs/"
	capture mkdir "${LOG_PATH}"
	capture mkdir "${PROJ_PATH}temp/"
	capture mkdir "${PROJ_PATH}temp/`level'/"
	cd "${PROJ_PATH}temp/`level'/"

	** intermediate data and reduced form
	do "${CODE_FILES}A0-intermediate-data.do"	/* temporary datasets used throughout */
	do "${CODE_FILES}A1-desc-stats.do"
	do "${CODE_FILES}A2-rereferral.do"		/* re-referral after failure vs success: level and referral-order event study */
	do "${CODE_FILES}A4-mnl-distance.do"		/* congestion instrument */
	if "`level'"=="pcp-level" {
		do "${CODE_FILES}A3-mnl-myopic.do"	/* MNL sensitivities (appendix) */
	}

	** structural estimation and output, by model
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

	** supplemental diagnostics and risk adjustment (surgeon level only)
	if "`level'"=="pcp-level" {
		do "${CODE_FILES}S1-diagnostics.do"
		do "${CODE_FILES}S2-pcp-assignment.do"
		do "${CODE_FILES}S3-first-stage.do"
		do "${CODE_FILES}S4-uniqueness.do"
		do "${CODE_FILES}S5-risk-adjustment.do"
		do "${CODE_FILES}S6-sample-descriptives.do"	/* patient mix by specialist, billing groups, established vs all PCPs */
	}
}
