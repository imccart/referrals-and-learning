set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Diagnostics_`logdate'.log", replace

******************************************************************
**	Title:		Specialist FE Stability Across Time Periods
**	Author:		Ian McCarthy
**	Date Created:	2/25/2026
**	Date Updated:	2/27/2026
**	Notes:		Runs once after both model types complete.
**			Produces scatter plots comparing specialist FEs
**			between estimation periods (2013-2015 vs 2016-2018).
******************************************************************

local r_type "${PCP_First}_${PCP_Only}_${RFR_Priority}"


******************************************************************
** Compare Specialist FEs over time periods (both model types)

foreach model_type in Myopic FWD {
	if "`model_type'" == "Myopic" {
		local coef_prefix "StructureMyopic"
	}
	else {
		local coef_prefix "StructureForward"
	}
	local model "`model_type'"

	use "${RESULTS_FINAL}`coef_prefix'HRR_Spec_FEs_`r_type'_rhobar.dta", replace
	preserve
	keep if time_period==0
	keep coef_val coef_se hrr eta Specialist_ID
	foreach x of varlist coef_val coef_se {
		rename `x' `x'_0
	}
	save fe_t0, replace
	restore

	keep if time_period==1
	keep coef_val coef_se hrr eta Specialist_ID
	foreach x of varlist coef_val coef_se {
		rename `x' `x'_1
	}
	save fe_t1, replace

	use fe_t0, clear
	merge 1:1 Specialist_ID hrr eta using fe_t1, nogenerate
	twoway scatter coef_val_0 coef_val_1 if eta==1 & abs(coef_val_0)<4 & abs(coef_val_1)<4, ///
		ytitle("Period One") xtitle("Period Two") color(gray)
	graph save "${RESULTS_FINAL}FE_Compare_`model'_eta1_rhobar_`r_type'", replace
	graph export "${RESULTS_FINAL}FE_Compare_`model'_eta1_rhobar_`r_type'.png", as(png) replace

	twoway scatter coef_val_0 coef_val_1 if eta==5 & abs(coef_val_0)<4 & abs(coef_val_1)<4, ///
		ytitle("Period One") xtitle("Period Two") color(gray)
	graph save "${RESULTS_FINAL}FE_Compare_`model'_eta5_rhobar_`r_type'", replace
	graph export "${RESULTS_FINAL}FE_Compare_`model'_eta5_rhobar_`r_type'.png", as(png) replace
}


log close
