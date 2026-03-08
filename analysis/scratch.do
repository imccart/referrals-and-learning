******************************************************************
**	Title:		Scratch — MLE and counterfactual convergence checks
**	Author:		Ian McCarthy
**	Date Created:	2/27/2026
**	Notes:		Ad-hoc diagnostics moved from S1-diagnostics.do.
**			Not called by _main.do. Run interactively as needed.
******************************************************************

local r_type "${PCP_First}_${PCP_Only}_${RFR_Priority}"


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
