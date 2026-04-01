set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Baseline_${MODEL_TYPE}_`logdate'.log", replace

******************************************************************
**	Title:		Baseline Predictions and Partial Effects
**	Author:		Ian McCarthy
**	Date Created:	3/30/2026
**	Notes:		Parameterized by global MODEL_TYPE (Myopic or FWD).
**			Saves base_hrr files for counterfactual scripts.
******************************************************************

** Derive locals from globals
if "${MODEL_TYPE}" == "Myopic" {
	local coef_prefix "StructureMyopic"
}
else if "${MODEL_TYPE}" == "FWD" {
	local coef_prefix "StructureForward"
}
else {
	display as error "MODEL_TYPE must be Myopic or FWD"
	exit 198
}
local model "${MODEL_TYPE}"
local r_type "${PCP_First}_${PCP_Only}_${RFR_Priority}"


** Load IV scalars from O1-coef-tables.do
use "${RESULTS_FINAL}iv_scalars_`model'.dta", clear
foreach eta_val in 1 5 {
	qui sum iv_pat if eta == `eta_val'
	local iv_pat_`eta_val' = r(mean)
	qui sum iv_time if eta == `eta_val'
	local iv_time_`eta_val' = r(mean)
	qui sum iv_shift if eta == `eta_val'
	local iv_shift_`eta_val' = r(mean)
}


******************************************************************
** Baseline predictions and partial effects

** clean up any leftover temp files from prior runs
forvalues i=1/500 {
	foreach eta in 1 5 {
		capture erase "base_hrr`i'_eta`eta'.dta"
	}
}

use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
sort Practice_ID Specialist_ID referral
by Practice_ID Specialist_ID: gen obs=_n
keep if obs==1
keep Practice_ID Specialist_ID pair_patients_run
rename pair_patients_run start_patients_run
save temp_base_patients, replace

foreach eta in 1 5 {

	use "${RESULTS_FINAL}`coef_prefix'HRR_Spec_FEs_`r_type'_rhobar.dta", clear
	keep if eta==`eta'
	save spec_fe, replace

	use "${RESULTS_FINAL}`coef_prefix'HRR_MainCoeff_`r_type'_rhobar.dta", clear
	keep if eta==`eta'
	save coeff_notfe, replace

	use "${RESULTS_FINAL}`coef_prefix'HRR_FmlyCoeff_`r_type'_rhobar.dta", clear
	keep if eta==`eta'
	keep coef_val fmly_level hrr
	rename coef_val fmly_agg
	save fmly_effect, replace
	rename fmly_agg fmly_agg_a
	rename fmly_level fmly_level_a
	save fmly_effect_a, replace

	use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
	egen fmly_level=cut(pair_patients_run), at(0,1,2,3,4,5,6,8,11,16,10000)
	replace fmly_level=7 if fmly_level==6
	replace fmly_level=10 if fmly_level==8
	replace fmly_level=15 if fmly_level==11
	replace fmly_level=20 if fmly_level==16

	merge m:1 Practice_ID Specialist_ID using temp_base_patients, keep(master match) nogenerate
	gen iv_pat = `iv_pat_`eta''
	gen iv_time = `iv_time_`eta''
	gen iv_shift = `iv_shift_`eta''

	* loop over HRRs
	egen hrr_group=group(hrr)
	qui sum hrr_group
	local hrr_count=r(max)
	forvalues h=1/`hrr_count' {
		preserve
		keep if hrr_group==`h'

		** merge coefficients
		merge m:1 hrr Specialist_ID time_period using spec_fe, keep(match) nogenerate
		merge m:1 hrr using coeff_notfe, keep(match) nogenerate
		merge m:1 hrr fmly_level using fmly_effect, keep(master match) nogenerate
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

			** calculate "current" specialist quality and fill in if missing
			gen spec_success_run=spec_patients_run - spec_failures_run
			gen spec_qual_run=spec_success_run/spec_patients_run
			replace spec_qual_run=spec_qual_fill if spec_qual_run==.

			** generate variables for remaining analysis
			bys Specialist_ID time_period: gen spec_obs=_n
			gen xi_j=coef_val - iv_pat*tot_patients

			** calculate marginal effect
			gen m=(rho*`eta' + pair_success_run)/(`eta' + pair_patients_run)
			gen exp_uij=exp(coef_dist*diff_dist + coef_m*m + fmly_agg + coef_val)
			bys casevar: egen sum_exp_uij=sum(exp_uij)
			gen pr_j=exp_uij/sum_exp_uij
			gen mfx_m=pr_j*(1-pr_j)*coef_m/(`eta'+pair_success_run)
			gen m_orig=m
			drop m exp_uij sum_exp_uij

			** calculate aggregate effect of familiarity
			gen exp_uij_0=exp(coef_dist*diff_dist + coef_m*m_orig + coef_val)
			bys casevar: egen sum_exp_uij_0=sum(exp_uij_0)
			gen pr_j_0=exp_uij_0/sum_exp_uij_0
			drop exp_uij_0 sum_exp_uij_0
			gen pfx_fam=pr_j-pr_j_0

			** calculate aggregate effect of patient outcomes
			gen exp_uij_0=exp(coef_dist*diff_dist + fmly_agg + coef_val)
			bys casevar: egen sum_exp_uij_0=sum(exp_uij_0)
			gen pr_j_m0=exp_uij_0/sum_exp_uij_0
			drop exp_uij_0 sum_exp_uij_0
			gen pfx_m0=pr_j-pr_j_m0

			** calculate partial effect
			gen m=(rho*`eta' + pair_success_run)/(`eta' + pair_patients_run+1)
			gen exp_uij=exp(coef_dist*diff_dist + coef_m*m + fmly_agg + coef_val)
			gen exp_uij_orig=exp(coef_dist*diff_dist + coef_m*m_orig + fmly_agg + coef_val)
			bys casevar: egen sum_exp_uij=sum(exp_uij_orig)
			replace sum_exp_uij=sum_exp_uij-exp_uij_orig+exp_uij
			gen pr_j_alt=exp_uij/sum_exp_uij
			drop m exp_uij sum_exp_uij exp_uij_orig
			gen pfx_m=pr_j_alt-pr_j

			save base_hrr`h'_eta`eta', replace
		}
		restore
	}
}


******************************************************************
** Aggregate marginal/partial effects across HRRs

** determine dynamic HRR count
local hrr_agg = 0
foreach eta in 1 5 {
	forvalues i=1/500 {
		capture confirm file "base_hrr`i'_eta`eta'.dta"
		if _rc==0 & `i'>`hrr_agg' local hrr_agg = `i'
	}
}

foreach eta in 1 5 {
	local step=0
	forvalues i=1/`hrr_agg' {
		capture confirm file "base_hrr`i'_eta`eta'.dta"
		if _rc==0 {
			use base_hrr`i'_eta`eta', clear
			keep if common_ref==1
			collapse (first) hrr ///
				(p10) mfx_10=mfx_m pfx_10=pfx_m pfx_fam_10=pfx_fam pfx_m0_10=pfx_m0 ///
				(p25) mfx_25=mfx_m pfx_25=pfx_m pfx_fam_25=pfx_fam pfx_m0_25=pfx_m0 ///
				(p50) mfx_50=mfx_m pfx_50=pfx_m pfx_fam_50=pfx_fam pfx_m0_50=pfx_m0 ///
				(p75) mfx_75=mfx_m pfx_75=pfx_m pfx_fam_75=pfx_fam pfx_m0_75=pfx_m0 ///
				(p90) mfx_90=mfx_m pfx_90=pfx_m pfx_fam_90=pfx_fam pfx_m0_90=pfx_m0 ///
				(mean) mfx_mean=mfx_m pfx_mean=pfx_m pr_mean=pr_j pr_obs=choice pfx_fam_mean=pfx_fam pfx_m0_mean=pfx_m0 ///
				(sd) mfx_sd=mfx_m pfx_sd=pfx_m pfx_fam_sd=pfx_fam pfx_m0_sd=pfx_m0 (count) mfx_count=mfx_m pfx_count=pfx_m
			gen hrr_group=`i'
			gen eta=`eta'
			local step=`step'+1
			if `step'==1 {
				save fx_top`eta', replace
			}
			else {
				append using fx_top`eta'
				save fx_top`eta', replace
			}

			use base_hrr`i'_eta`eta', clear
			keep if pair_patients_run>0 & pair_patients_run!=.
			collapse (first) hrr ///
				(p10) mfx_10=mfx_m pfx_10=pfx_m pfx_fam_10=pfx_fam pfx_m0_10=pfx_m0 ///
				(p25) mfx_25=mfx_m pfx_25=pfx_m pfx_fam_25=pfx_fam pfx_m0_25=pfx_m0 ///
				(p50) mfx_50=mfx_m pfx_50=pfx_m pfx_fam_50=pfx_fam pfx_m0_50=pfx_m0 ///
				(p75) mfx_75=mfx_m pfx_75=pfx_m pfx_fam_75=pfx_fam pfx_m0_75=pfx_m0 ///
				(p90) mfx_90=mfx_m pfx_90=pfx_m pfx_fam_90=pfx_fam pfx_m0_90=pfx_m0 ///
				(mean) mfx_mean=mfx_m pfx_mean=pfx_m pr_mean=pr_j pr_obs=choice pfx_fam_mean=pfx_fam pfx_m0_mean=pfx_m0 ///
				(sd) mfx_sd=mfx_m pfx_sd=pfx_m pfx_fam_sd=pfx_fam pfx_m0_sd=pfx_m0 (count) mfx_count=mfx_m pfx_count=pfx_m
			gen hrr_group=`i'
			gen eta=`eta'
			if `step'==1 {
				save fx_any`eta', replace
			}
			else {
				append using fx_any`eta'
				save fx_any`eta', replace
			}
		}
	}
}

foreach eta in 1 5 {
	use fx_any`eta', clear
	save "${RESULTS_FINAL}MarginalEffects_`model'`eta'.dta", replace
	** mask small cell sizes for export
	replace mfx_count=. if mfx_count<=11
	replace pfx_count=. if pfx_count<=11
	outsheet using "${RESULTS_FINAL}MarginalEffects_`model'`eta'.csv", comma replace
	erase fx_any`eta'.dta
}


log close
