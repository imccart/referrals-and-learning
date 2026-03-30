set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Counterfactuals_${MODEL_TYPE}_`logdate'.log", replace

******************************************************************
**	Title:		Partial Effects and Counterfactual Simulations
**	Author:		Ian McCarthy
**	Date Created:	2/25/2026
**	Notes:		Parameterized by global MODEL_TYPE (Myopic or FWD).
**			Extracted from O2-structural-summary.do Section B.
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
** Partial effects and counterfactual calculations

** clear progress tracker from any prior run
capture erase "${RESULTS_FINAL}cf_progress_`model'.dta"
capture erase "${RESULTS_FINAL}cf_progress_`model'.csv"

** clean up any leftover temp files from prior runs
forvalues i=1/500 {
	foreach eta in 1 5 {
		capture erase "cf_hrr`i'_eta`eta'.dta"
		capture erase "cf_summary_hrr`i'_eta`eta'.dta"
		capture erase "fx_top_hrr`i'_eta`eta'.dta"
		capture erase "fx_any_hrr`i'_eta`eta'.dta"
		capture erase "cf_sum_hrr`i'_eta`eta'.dta"
		capture erase "cf_spec_hrr`i'_eta`eta'.dta"
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

			** simulate counterfactual - full quality information with no initial familiarity
			gen m=spec_qual
			gen fmly_agg_orig=fmly_agg
			gen base_patients=0

			gen pred_equil=tot_patients
			converge_dyn pred_equil
			rename pij pij_full
			rename no_equil no_equil_full
			replace fmly_agg=fmly_agg_orig
			drop m pred_iter_new pred_iter_old exp_uij sum_exp_uij pred_equil fmly_agg_orig base_patients conv_crit

			** simulate counterfactual - full quality information with baseline familiarity
			gen m=spec_qual
			gen base_patients=start_patients_run
			replace base_patients=0 if base_patients==.

			gen pred_equil=tot_patients
			converge_dyn pred_equil
			rename pij pij_current
			rename no_equil no_equil_current
			drop m pred_iter_new pred_iter_old exp_uij sum_exp_uij pred_equil base_patients	conv_crit

			** simulate counterfactual - full quality information and no familiarity effect
			gen m=spec_qual
			gen pred_equil=tot_patients
			replace fmly_agg=0
			quietly converge pred_equil
			rename pij pij_full_fam
			rename no_equil no_equil_full_fam
			drop m pred_iter_new pred_iter_old exp_uij sum_exp_uij pred_equil

			keep Practice_ID Specialist_ID casevar choice hrr pr_j pr_j_0 pr_j_m0 pr_j_alt pij_full pij_current pij_full_fam mfx_m pfx_m pfx_fam pfx_m0 m_orig spec_qual spec_qual_run ///
				patients tot_patients pair_success_run pair_patients_run spec_patients_run spec_failures_run ///
				pcp_patients_run pcp_failures_run common_ref hrr no_equil* coef_m xi_j
			save cf_hrr`h'_eta`eta', replace

			** HRR-level summary for progress tracking and later analysis

			** Step 1: specialist-level diagnostics (before patient-level collapse)
			** Note: already inside preserve from HRR loop, so use tempfile instead of nested preserve
			tempfile patient_data
			save `patient_data'
			collapse (sum) pred_pat0=pr_j pred_pat_full=pij_full ///
				pred_pat_current=pij_current pred_pat_fullfam=pij_full_fam ///
				(first) xi_j spec_qual coef_m tot_patients, by(Specialist_ID hrr)

			** number of specialists
			qui count
			local n_specs = r(N)

			** FE-quality correlation (guard against too few specialists)
			if `n_specs'>=5 {
				qui corr xi_j spec_qual
				local corr_fe_qual = r(rho)
			}
			else {
				local corr_fe_qual = .
			}

			** FE dispersion
			qui sum xi_j
			local fe_sd = r(sd)
			local fe_range = r(max) - r(min)

			** quality dispersion
			qui sum spec_qual
			local qual_sd = r(sd)

			** reallocation direction: patient-weighted quality change
			gen delta_full = pred_pat_full - pred_pat0
			gen delta_current = pred_pat_current - pred_pat0
			gen delta_fullfam = pred_pat_fullfam - pred_pat0
			if `n_specs'>=5 {
				qui corr delta_full spec_qual
				local corr_realloc_qual_full = r(rho)
				qui corr delta_fullfam spec_qual
				local corr_realloc_qual_fullfam = r(rho)
			}
			else {
				local corr_realloc_qual_full = .
				local corr_realloc_qual_fullfam = .
			}

			** share of reallocation going to above-median quality specialists
			qui sum spec_qual, detail
			local qual_med = r(p50)
			gen highqual = (spec_qual > `qual_med')
			qui sum delta_full if highqual==1
			local realloc_to_highq_full = r(sum)
			qui sum delta_full if highqual==0
			local realloc_to_lowq_full = r(sum)
			qui sum delta_fullfam if highqual==1
			local realloc_to_highq_fullfam = r(sum)
			qui sum delta_fullfam if highqual==0
			local realloc_to_lowq_fullfam = r(sum)

			** mean FE for high vs low quality specialists
			qui sum xi_j if highqual==1
			local fe_mean_highqual = r(mean)
			qui sum xi_j if highqual==0
			local fe_mean_lowqual = r(mean)

			use `patient_data', clear

			** Step 2: patient-level health effects
			gen success_prob0=pr_j*spec_qual
			gen success_prob1_full=pij_full*spec_qual
			gen success_prob1_current=pij_current*spec_qual
			gen success_prob1_fullfam=pij_full_fam*spec_qual
			gen pij_diff_full=abs(pij_full-pr_j)/2
			gen pij_diff_current=abs(pij_current-pr_j)/2
			gen pij_diff_fullfam=abs(pij_full_fam-pr_j)/2
			collapse (first) hrr coef_m (sum) success_prob0 success_prob1_full success_prob1_current success_prob1_fullfam pij_diff_full pij_diff_current pij_diff_fullfam pr_j, by(casevar)
			collapse (mean) coef_m pij_diff_full pij_diff_current pij_diff_fullfam (mean) health_full=success_prob1_full health_current=success_prob1_current health_fullfam=success_prob1_fullfam health_base=success_prob0 (count) n_cases=casevar, by(hrr)
			replace health_full=health_full-health_base
			replace health_current=health_current-health_base
			replace health_fullfam=health_fullfam-health_base

			** Step 3: attach specialist-level diagnostics
			gen corr_fe_qual = `corr_fe_qual'
			gen fe_sd = `fe_sd'
			gen fe_range = `fe_range'
			gen qual_sd = `qual_sd'
			gen corr_realloc_qual_full = `corr_realloc_qual_full'
			gen corr_realloc_qual_fullfam = `corr_realloc_qual_fullfam'
			gen realloc_to_highq_full = `realloc_to_highq_full'
			gen realloc_to_lowq_full = `realloc_to_lowq_full'
			gen realloc_to_highq_fullfam = `realloc_to_highq_fullfam'
			gen realloc_to_lowq_fullfam = `realloc_to_lowq_fullfam'
			gen fe_mean_highqual = `fe_mean_highqual'
			gen fe_mean_lowqual = `fe_mean_lowqual'
			gen n_specs = `n_specs'

			gen eta=`eta'
			save cf_summary_hrr`h'_eta`eta', replace

			** running progress tracker (overwritten each HRR for mid-run monitoring)
			capture confirm file "${RESULTS_FINAL}cf_progress_`model'.dta"
			if _rc==0 {
				append using "${RESULTS_FINAL}cf_progress_`model'.dta"
			}
			save "${RESULTS_FINAL}cf_progress_`model'.dta", replace
			outsheet using "${RESULTS_FINAL}cf_progress_`model'.csv", comma replace
		}
		restore
	}
}

** determine dynamic HRR count for aggregation
local hrr_agg = 0
foreach eta in 1 5 {
	forvalues i=1/500 {
		capture confirm file "cf_hrr`i'_eta`eta'.dta"
		if _rc==0 & `i'>`hrr_agg' local hrr_agg = `i'
	}
}

foreach eta in 1 5 {
	forvalues i=1/`hrr_agg' {
		capture confirm file "cf_hrr`i'_eta`eta'.dta"
		if _rc==0 {
			** marginal and partial effects for top-choice specialist
			use cf_hrr`i'_eta`eta', clear
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
			save fx_top_hrr`i'_eta`eta', replace

			** marginal and partial effects for any non-zero specialist
			use cf_hrr`i'_eta`eta', clear
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
			save fx_any_hrr`i'_eta`eta', replace

			** ex ante probability of success
			use cf_hrr`i'_eta`eta', clear
			gen success_prob0=pr_j*spec_qual
			gen success_prob1_full=pij_full*spec_qual
			gen success_prob1_current=pij_current*spec_qual
			gen success_prob1_fullfam=pij_full_fam*spec_qual
			gen pij_diff_full=abs(pij_full-pr_j)/2
			gen pij_diff_current=abs(pij_current-pr_j)/2
			gen pij_diff_fullfam=abs(pij_full_fam-pr_j)/2

			** patient level summary
			preserve
			collapse (first) hrr no_equil_* (sum) success_prob0 success_prob1_full success_prob1_current success_prob1_fullfam ///
				pij_diff_full pij_diff_current pij_diff_fullfam pr_j, by(casevar)
			gen hrr_group=`i'
			gen eta=`eta'
			save cf_sum_hrr`i'_eta`eta', replace
			restore

			** specialist level summary
			collapse (sum) pred_patients0=pr_j pred_patients_full=pij_full no_equil_* ///
				pred_patients_current=pij_current pred_patients_fullfam=pij_full_fam ///
				(first) xi_j spec_qual coef_m tot_patients, by(Specialist_ID hrr)
			gen hrr_group=`i'
			gen eta=`eta'
			save cf_spec_hrr`i'_eta`eta', replace

		}
	}
}



foreach eta in 1 5 {
	local step=0
	foreach x of newlist fx_top fx_any cf_sum cf_spec cf_summary {
		forvalues i=1/`hrr_agg' {
			capture confirm file "cf_hrr`i'_eta`eta'.dta"
			if _rc==0 {
				local step=`step'+1
				if `step'==1 {
					use `x'_hrr`i'_eta`eta', clear
				}
				else {
					append using `x'_hrr`i'_eta`eta'
				}
			}
		}
		save "`x'`eta'", replace
		clear
	}
}

foreach eta in 1 5 {
	use fx_any`eta', clear
	save "${RESULTS_FINAL}MarginalEffects_`model'`eta'.dta", replace
	erase fx_any`eta'.dta

	use cf_sum`eta', clear
	save "${RESULTS_FINAL}CounterFactuals_`model'`eta'.dta", replace
	erase cf_sum`eta'.dta

	use cf_spec`eta', clear
	save "${RESULTS_FINAL}CounterFactualsSpec_`model'`eta'.dta", replace
	outsheet using "${RESULTS_FINAL}CounterFactualsSpec_`model'`eta'.csv", comma replace
	erase cf_spec`eta'.dta

	use cf_summary`eta', clear
	save "${RESULTS_FINAL}CounterFactualsSummary_`model'`eta'.dta", replace
	outsheet using "${RESULTS_FINAL}CounterFactualsSummary_`model'`eta'.csv", comma replace
	erase cf_summary`eta'.dta
}


log close
