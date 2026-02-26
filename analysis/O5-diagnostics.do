set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Diagnostics_`logdate'.log", replace

******************************************************************
**	Title:		Diagnostics — FE comparison, convergence checks
**	Author:		Ian McCarthy
**	Date Created:	2/25/2026
**	Notes:		Runs once after both model types complete.
**			Extracted from O2-structural-summary.do and _main.do.
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


******************************************************************
** MLE convergence cross-tabs

* Myopic
use "${RESULTS_FINAL}StructureMyopicHRR_CoefFull_`r_type'_rhobar.dta", clear

gen eta_val=coef_val if coef_name=="eta"
gen hrr_val=coef_val if coef_name=="hrr"
gen conv_val=coef_val if coef_name=="converged"
gen ll_val=coef_val if coef_name=="log_like"
destring coef_name, gen(test_numeric) force
gen group_id=sum(coef_val==0 & coef_se==0 & test_numeric!=.)
bys group_id: egen hrr=min(hrr_val)
bys group_id: egen eta=min(eta_val)
bys group_id: egen converged=min(conv_val)
bys group_id: egen log_like=min(ll_val)
drop eta_val hrr_val conv_val ll_val group_id test_numeric

keep if coef_name=="belief_s" | coef_name=="o.belief_s"
rename coef_val coef_m
replace coef_m=0 if coef_m==.

bys hrr eta: gen est_obs=_n
keep if est_obs==1
keep eta hrr log_like converged coef_m
bys eta: tab converged
keep hrr eta coef_m
rename coef_m alpha_myopic
save temp_myopic_alpha, replace


* Forward-looking
use "${RESULTS_FINAL}StructureForwardHRR_CoefFull_`r_type'_rhobar.dta", clear

gen eta_val=coef_val if coef_name=="eta"
gen hrr_val=coef_val if coef_name=="hrr"
gen conv_val=coef_val if coef_name=="converged"
gen ll_val=coef_val if coef_name=="log_like"
destring coef_name, gen(test_numeric) force
gen group_id=sum(coef_val==0 & coef_se==0 & test_numeric!=.)
bys group_id: egen hrr=min(hrr_val)
bys group_id: egen eta=min(eta_val)
bys group_id: egen converged=min(conv_val)
bys group_id: egen log_like=min(ll_val)
drop eta_val hrr_val conv_val ll_val group_id test_numeric

keep if coef_name=="belief_s" | coef_name=="o.belief_s"
rename coef_val coef_m
replace coef_m=0 if coef_m==.

bys hrr eta: gen est_obs=_n
keep if est_obs==1
keep eta hrr log_like converged coef_m
bys eta: tab converged
keep hrr eta coef_m
rename coef_m alpha_fwd
save temp_fwd_alpha, replace


******************************************************************
** Counterfactual iteration convergence

* Myopic eta=5
use "${RESULTS_FINAL}CounterFactuals_Myopic5.dta", clear
merge m:1 hrr eta using temp_myopic_alpha, nogenerate keep(master match)
gen alpha_0=(alpha_myopic==0)
tab no_equil_full alpha_0
collapse (sum) pr_j, by(alpha_0 no_equil_full)

use "${RESULTS_FINAL}CounterFactuals_Myopic5.dta", clear
merge m:1 hrr eta using temp_myopic_alpha, nogenerate keep(master match)
gen alpha_0=(alpha_myopic==0)
collapse (sum) pr_j alpha_0 no_equil_full, by(hrr)
replace alpha_0=(alpha_0>0)
replace no_equil_full=(no_equil_full>0)
collapse (sum) pr_j, by(alpha_0 no_equil_full)


* Forward-looking eta=5
use "${RESULTS_FINAL}CounterFactuals_FWD5.dta", clear
merge m:1 hrr eta using temp_myopic_alpha, nogenerate keep(master match)
gen alpha_0=(alpha_myopic==0)
tab no_equil_full alpha_0
collapse (sum) pr_j, by(alpha_0 no_equil_full)

use "${RESULTS_FINAL}CounterFactuals_FWD5.dta", clear
merge m:1 hrr eta using temp_myopic_alpha, nogenerate keep(master match)
gen alpha_0=(alpha_myopic==0)
collapse (sum) pr_j alpha_0 no_equil_full, by(hrr)
replace alpha_0=(alpha_0>0)
replace no_equil_full=(no_equil_full>0)
collapse (sum) pr_j, by(alpha_0 no_equil_full)


log close
