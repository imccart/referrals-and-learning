set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Uniqueness_`logdate'.log", replace

******************************************************************
**	Title:		S4 — Equilibrium Uniqueness Check
**	Author:		Ian McCarthy
**	Date Created:	3/20/2026
**	Notes:		Runs converge_dyn from two starting values (0 and
**			tot_patients) for a sample of HRRs. Compares resulting
**			counterfactual shares to assess uniqueness.
******************************************************************

local model "Myopic"
local coef_prefix "StructureMyopic"
local r_type "${PCP_First}_${PCP_Only}_${RFR_Priority}"


** Load IV scalars
use "${RESULTS_FINAL}iv_scalars_`model'.dta", clear
qui sum iv_pat if eta == 1
local iv_pat_1 = r(mean)


** Prepare base patients
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
sort Practice_ID Specialist_ID referral
by Practice_ID Specialist_ID: gen obs=_n
keep if obs==1
keep Practice_ID Specialist_ID pair_patients_run
rename pair_patients_run start_patients_run
save temp_base_patients_s4, replace


** Load coefficients for eta=1
use "${RESULTS_FINAL}`coef_prefix'HRR_Spec_FEs_`r_type'_rhobar.dta", clear
keep if eta==1
save spec_fe_s4, replace

use "${RESULTS_FINAL}`coef_prefix'HRR_MainCoeff_`r_type'_rhobar.dta", clear
keep if eta==1
save coeff_notfe_s4, replace

use "${RESULTS_FINAL}`coef_prefix'HRR_FmlyCoeff_`r_type'_rhobar.dta", clear
keep if eta==1
keep coef_val fmly_level hrr
rename coef_val fmly_agg
save fmly_effect_s4, replace
rename fmly_agg fmly_agg_a
rename fmly_level fmly_level_a
save fmly_effect_a, replace


** Prepare main data
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
egen fmly_level=cut(pair_patients_run), at(0,1,2,3,4,5,6,8,11,16,10000)
replace fmly_level=7 if fmly_level==6
replace fmly_level=10 if fmly_level==8
replace fmly_level=15 if fmly_level==11
replace fmly_level=20 if fmly_level==16

merge m:1 Practice_ID Specialist_ID using temp_base_patients_s4, keep(master match) nogenerate
gen iv_pat = `iv_pat_1'

egen hrr_group=group(hrr)
qui sum hrr_group
local hrr_count=r(max)

** Pick test HRRs: small, medium, large by patient count, with alpha>0
preserve
merge m:1 hrr using coeff_notfe_s4, keep(match) nogenerate keepusing(coef_m)
keep if coef_m>0
collapse (count) n_obs=casevar, by(hrr hrr_group)
qui sum n_obs, detail
gen size_group = cond(n_obs<=r(p25), 1, cond(n_obs<=r(p75), 2, 3))
set seed 20260320
gen rand=runiform()
sort size_group rand
by size_group: gen pick=_n
keep if pick<=2
local test_hrrs ""
forvalues j=1/`=_N' {
	local test_hrrs "`test_hrrs' `=hrr_group[`j']'"
}
dis "Testing HRR groups: `test_hrrs'"
restore


** Run counterfactual from two starting values for each test HRR
local test_num=0
foreach h of local test_hrrs {
	local test_num=`test_num'+1

	foreach start in 0 1 {
		preserve
		keep if hrr_group==`h'

		** merge coefficients
		merge m:1 hrr Specialist_ID time_period using spec_fe_s4, keep(match) nogenerate
		merge m:1 hrr using coeff_notfe_s4, keep(match) nogenerate
		merge m:1 hrr fmly_level using fmly_effect_s4, keep(master match) nogenerate
		merge m:1 Specialist_ID time_period hrr using mean_capacity, keep(match) nogenerate
		replace fmly_agg=0 if fmly_agg==.

		qui count
		local robs=r(N)
		if `robs'>0 {

			** drop FE outliers
			qui sum coef_val, detail
			keep if inrange(coef_val, r(p1), r(p99))

			** fill in missing specialist quality
			bys Specialist_ID: egen spec_qual_fill=mean(spec_qual)
			replace spec_qual=spec_qual_fill if spec_qual==.

			** generate variables
			bys Specialist_ID time_period: gen spec_obs=_n
			gen xi_j=coef_val - iv_pat*tot_patients

			** set m to full info
			gen m=spec_qual
			gen base_patients=0

			** set starting value
			if `start'==0 {
				gen pred_equil=0
				dis "HRR group `h': starting from 0"
			}
			else {
				gen pred_equil=tot_patients
				dis "HRR group `h': starting from tot_patients"
			}

			converge_dyn pred_equil

			** save specialist-level predicted volumes
			keep Specialist_ID time_period hrr pij tot_patients spec_qual
			bys Specialist_ID time_period: egen pred_vol=sum(pij)
			bys Specialist_ID time_period: keep if _n==1
			gen start_type=`start'
			gen test_hrr=`test_num'
			save temp_uniq_`test_num'_`start', replace
		}
		restore
	}
}


** Combine and compare
clear
local first=1
forvalues t=1/`test_num' {
	foreach s in 0 1 {
		capture confirm file "temp_uniq_`t'_`s'.dta"
		if _rc==0 {
			if `first'==1 {
				use temp_uniq_`t'_`s', clear
				local first=0
			}
			else {
				append using temp_uniq_`t'_`s'
			}
		}
	}
}

** reshape to compare starting values side by side
reshape wide pij pred_vol, i(test_hrr Specialist_ID time_period) j(start_type)
gen diff_pij=abs(pij1-pij0)
gen diff_vol=abs(pred_vol1-pred_vol0)

dis "============================================"
dis "Equilibrium Uniqueness Summary"
dis "============================================"
tabstat diff_pij diff_vol, by(test_hrr) stat(mean max p50 p90) format(%9.6f)
sum diff_pij diff_vol, detail

save "${RESULTS_FINAL}uniqueness_check.dta", replace
outsheet using "${RESULTS_FINAL}uniqueness_check.csv", comma replace

log close
