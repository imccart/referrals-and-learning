set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )

******************************************************************
**	Title:		Main file to call analysis files, etc.
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	2/25/2026
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
global PCP_Practice=1   /* 0 denotes decision between physician and physician, 1 denotes decision at physician to practice */

** file paths based on global values
if ${PCP_Practice}==1 {
	global DATA_FINAL "${PROJ_PATH}data/pcp-practice-level/"
	global RESULTS_BASE "${PROJ_PATH}results/pcp-practice-level/"
}
else if ${PCP_Practice}==0 {
	global DATA_FINAL "${PROJ_PATH}data/pcp-level/"
	global RESULTS_BASE "${PROJ_PATH}results/pcp-level/"
}


** choice sets and sizes
global OUTSIDE_OPTION=0
global SPEC_MIN=20

** time-varying congestion
global CONG_t=1
if ${CONG_t}==1 {
	global RESULTS_FINAL "${RESULTS_BASE}time_vary/"
}
else if ${CONG_t}==0 {
	global RESULTS_FINAL "${RESULTS_BASE}time_constant/"
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

global MODEL_TYPE "Myopic"
do "${CODE_FILES}A5-structural-estimation.do"

global MODEL_TYPE "FWD"
do "${CODE_FILES}A5-structural-estimation.do"

******************************************************************
** Structural output — Myopic

global MODEL_TYPE "Myopic"
do "${CODE_FILES}O1-coef-tables.do"
do "${CODE_FILES}O2-counterfactuals.do"
do "${CODE_FILES}O3-figures.do"

** Structural output — Forward-looking

global MODEL_TYPE "FWD"
do "${CODE_FILES}O1-coef-tables.do"
do "${CODE_FILES}O2-counterfactuals.do"
do "${CODE_FILES}O3-figures.do"

******************************************************************
** Paper numbers and supplemental diagnostics

do "${CODE_FILES}O4-paper-numbers.do"
do "${CODE_FILES}S1-diagnostics.do"
do "${CODE_FILES}S2-pcp-assignment.do"
do "${CODE_FILES}S3-first-stage.do"
