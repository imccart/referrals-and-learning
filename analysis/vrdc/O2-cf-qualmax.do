set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}CF_QualMax_${MODEL_TYPE}_`logdate'.log", replace

******************************************************************
**	Title:		Counterfactual — Quality Maximization
**	Author:		Ian McCarthy
**	Date Created:	4/15/2026
**	Notes:		Requires base_hrr files from O2-baseline.do.
**			m = spec_qual, xi_j = 0, fmly_agg = 0 (converge).
**			Three alpha scenarios:
**			  a1     = alpha numeraire (1)
**			  amatch = alpha matches max(distance, congestion)
**			  ahigh  = 2x amatch
**			No familiarity dynamics — uses converge (static).
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

** alpha scenario labels
local alpha_labels "a1 amatch ahigh"

** clean up any leftover temp files
foreach alabel in `alpha_labels' {
	forvalues i=1/500 {
		foreach eta in 1 5 {
			capture erase "cf_qualmax_`alabel'_hrr`i'_eta`eta'.dta"
			capture erase "cf_qualmax_`alabel'_summary_hrr`i'_eta`eta'.dta"
			capture erase "cf_qualmax_`alabel'_spec_hrr`i'_eta`eta'.dta"
		}
	}
}

** determine dynamic HRR count from baseline files
local hrr_agg = 0
foreach eta in 1 5 {
	forvalues i=1/500 {
		capture confirm file "base_hrr`i'_eta`eta'.dta"
		if _rc==0 & `i'>`hrr_agg' local hrr_agg = `i'
	}
}

foreach eta in 1 5 {

	forvalues h=1/`hrr_agg' {
		capture confirm file "base_hrr`h'_eta`eta'.dta"
		if _rc==0 {

			** load once to compute alpha_match for this HRR
			use base_hrr`h'_eta`eta', clear

			** SD of distance (patient-specialist level)
			qui sum diff_dist
			local sd_dist = r(sd)

			** SD of quality and volume (specialist level)
			qui sum spec_qual if spec_obs==1
			local sd_qual = r(sd)
			qui sum tot_patients if spec_obs==1
			local sd_vol = r(sd)

			** coefficient values (constant within HRR)
			qui sum coef_dist if spec_obs==1
			local abs_coef_dist = abs(r(mean))
			qui sum iv_pat if spec_obs==1
			local abs_iv_pat = abs(r(mean))

			** compute alpha_match: quality matches the stronger constraint
			if `sd_qual' > 0.001 {
				local alpha_dist = `abs_coef_dist' * `sd_dist' / `sd_qual'
				local alpha_cong = `abs_iv_pat' * `sd_vol' / `sd_qual'
				local alpha_match_val = max(`alpha_dist', `alpha_cong')
			}
			else {
				** no quality variation — fall back to estimated alpha
				qui sum coef_m if spec_obs==1
				local alpha_match_val = r(mean)
			}

			** three scenarios
			local alpha_a1 = 1
			local alpha_amatch = `alpha_match_val'
			local alpha_ahigh = 2 * `alpha_match_val'

			dis "HRR `h', eta `eta': a1=`alpha_a1', amatch=`alpha_amatch', ahigh=`alpha_ahigh'"
			dis "  (dist component=`alpha_dist', cong component=`alpha_cong')"

			foreach alabel in `alpha_labels' {

				use base_hrr`h'_eta`eta', clear

				** simulate counterfactual
				replace xi_j = 0
				replace fmly_agg = 0
				gen m = spec_qual
				replace coef_m = `alpha_`alabel''
				gen pred_equil = tot_patients
				quietly converge pred_equil
				rename pij pij_cf
				rename no_equil no_equil_cf
				drop m pred_iter_new pred_iter_old exp_uij sum_exp_uij pred_equil conv_crit

				save cf_qualmax_`alabel'_hrr`h'_eta`eta', replace

				** HRR-level summary
				tempfile patient_data
				save `patient_data'

				** Step 1: specialist-level diagnostics
				collapse (sum) pred_pat0=pr_j pred_pat_cf=pij_cf ///
					(first) xi_j spec_qual coef_m tot_patients, by(Specialist_ID hrr)

				qui count
				local n_specs = r(N)

				** xi_j is 0 everywhere so corr is undefined — store missing
				local corr_fe_qual = .

				qui sum xi_j
				local fe_sd = r(sd)
				local fe_range = r(max) - r(min)

				qui sum spec_qual
				local qual_sd = r(sd)

				gen delta_cf = pred_pat_cf - pred_pat0
				if `n_specs'>=5 {
					qui corr delta_cf spec_qual
					local corr_realloc_qual = r(rho)
				}
				else {
					local corr_realloc_qual = .
				}

				qui sum spec_qual, detail
				local qual_med = r(p50)
				gen highqual = (spec_qual > `qual_med')
				qui sum delta_cf if highqual==1
				local realloc_to_highq = r(sum)
				qui sum delta_cf if highqual==0
				local realloc_to_lowq = r(sum)

				** xi_j = 0 so these are all 0
				local fe_mean_highqual = 0
				local fe_mean_lowqual = 0

				use `patient_data', clear

				** Step 2: patient-level health effects
				gen success_prob0=pr_j*spec_qual
				gen success_prob1_cf=pij_cf*spec_qual
				gen pij_diff_cf=abs(pij_cf-pr_j)/2
				collapse (first) hrr coef_m (sum) success_prob0 success_prob1_cf pij_diff_cf pr_j, by(casevar)
				collapse (mean) coef_m pij_diff_cf (mean) health_cf=success_prob1_cf health_base=success_prob0 (count) n_cases=casevar, by(hrr)
				replace health_cf=health_cf-health_base

				** Step 3: attach diagnostics
				gen corr_fe_qual = `corr_fe_qual'
				gen fe_sd = `fe_sd'
				gen fe_range = `fe_range'
				gen qual_sd = `qual_sd'
				gen corr_realloc_qual = `corr_realloc_qual'
				gen realloc_to_highq = `realloc_to_highq'
				gen realloc_to_lowq = `realloc_to_lowq'
				gen fe_mean_highqual = `fe_mean_highqual'
				gen fe_mean_lowqual = `fe_mean_lowqual'
				gen n_specs = `n_specs'
				gen alpha_used = `alpha_`alabel''
				gen eta=`eta'
				save cf_qualmax_`alabel'_summary_hrr`h'_eta`eta', replace

				** specialist-level output
				use cf_qualmax_`alabel'_hrr`h'_eta`eta', clear
				collapse (sum) pred_patients0=pr_j pred_patients_cf=pij_cf no_equil_* ///
					(first) xi_j spec_qual coef_m tot_patients, by(Specialist_ID hrr)
				gen hrr_group=`h'
				gen alpha_used = `alpha_`alabel''
				gen eta=`eta'
				save cf_qualmax_`alabel'_spec_hrr`h'_eta`eta', replace
			}
		}
	}
}


******************************************************************
** Aggregate across HRRs

foreach alabel in `alpha_labels' {
	foreach eta in 1 5 {
		local step=0
		foreach x of newlist cf_qualmax_`alabel'_summary cf_qualmax_`alabel'_spec {
			forvalues i=1/`hrr_agg' {
				capture confirm file "base_hrr`i'_eta`eta'.dta"
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
		use cf_qualmax_`alabel'_summary`eta', clear
		save "${RESULTS_FINAL}CounterFactualsSummary_qualmax_`alabel'_`model'`eta'.dta", replace
		** mask small cell sizes for export
		replace n_specs=. if n_specs<=11
		replace n_cases=. if n_cases<=11
		outsheet using "${RESULTS_FINAL}CounterFactualsSummary_qualmax_`alabel'_`model'`eta'.csv", comma replace
		erase cf_qualmax_`alabel'_summary`eta'.dta

		use cf_qualmax_`alabel'_spec`eta', clear
		save "${RESULTS_FINAL}CounterFactualsSpec_qualmax_`alabel'_`model'`eta'.dta", replace
		outsheet using "${RESULTS_FINAL}CounterFactualsSpec_qualmax_`alabel'_`model'`eta'.csv", comma replace
		erase cf_qualmax_`alabel'_spec`eta'.dta
	}
}


log close
