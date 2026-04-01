set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}CF_FullFam_${MODEL_TYPE}_`logdate'.log", replace

******************************************************************
**	Title:		Counterfactual — Full Info, No Familiarity
**	Author:		Ian McCarthy
**	Date Created:	3/30/2026
**	Notes:		Requires base_hrr files from O2-baseline.do.
**			m = spec_qual, fmly_agg = 0 (converge, not converge_dyn).
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
local cf_name "fullfam"

** clean up any leftover temp files
forvalues i=1/500 {
	foreach eta in 1 5 {
		capture erase "cf_`cf_name'_hrr`i'_eta`eta'.dta"
		capture erase "cf_`cf_name'_summary_hrr`i'_eta`eta'.dta"
		capture erase "cf_`cf_name'_spec_hrr`i'_eta`eta'.dta"
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

	** recreate eta-specific coefficient files for converge/converge_dyn
	use "${RESULTS_FINAL}`coef_prefix'HRR_FmlyCoeff_`r_type'_rhobar.dta", clear
	keep if eta==`eta'
	keep coef_val fmly_level hrr
	rename coef_val fmly_agg
	save fmly_effect, replace
	rename fmly_agg fmly_agg_a
	rename fmly_level fmly_level_a
	save fmly_effect_a, replace

	forvalues h=1/`hrr_agg' {
		capture confirm file "base_hrr`h'_eta`eta'.dta"
		if _rc==0 {
			use base_hrr`h'_eta`eta', clear

			** simulate counterfactual
			gen m=spec_qual
			gen pred_equil=tot_patients
			replace fmly_agg=0
			quietly converge pred_equil
			rename pij pij_cf
			rename no_equil no_equil_cf
			drop m pred_iter_new pred_iter_old exp_uij sum_exp_uij pred_equil

			save cf_`cf_name'_hrr`h'_eta`eta', replace

			** HRR-level summary
			tempfile patient_data
			save `patient_data'

			** Step 1: specialist-level diagnostics
			collapse (sum) pred_pat0=pr_j pred_pat_cf=pij_cf ///
				(first) xi_j spec_qual coef_m tot_patients, by(Specialist_ID hrr)

			qui count
			local n_specs = r(N)

			if `n_specs'>=5 {
				qui corr xi_j spec_qual
				local corr_fe_qual = r(rho)
			}
			else {
				local corr_fe_qual = .
			}

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

			qui sum xi_j if highqual==1
			local fe_mean_highqual = r(mean)
			qui sum xi_j if highqual==0
			local fe_mean_lowqual = r(mean)

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
			gen eta=`eta'
			save cf_`cf_name'_summary_hrr`h'_eta`eta', replace

			** specialist-level output
			use cf_`cf_name'_hrr`h'_eta`eta', clear
			collapse (sum) pred_patients0=pr_j pred_patients_cf=pij_cf no_equil_* ///
				(first) xi_j spec_qual coef_m tot_patients, by(Specialist_ID hrr)
			gen hrr_group=`h'
			gen eta=`eta'
			save cf_`cf_name'_spec_hrr`h'_eta`eta', replace
		}
	}
}


******************************************************************
** Aggregate across HRRs

foreach eta in 1 5 {
	local step=0
	foreach x of newlist cf_`cf_name'_summary cf_`cf_name'_spec {
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
	use cf_`cf_name'_summary`eta', clear
	save "${RESULTS_FINAL}CounterFactualsSummary_`cf_name'_`model'`eta'.dta", replace
	** mask small cell sizes for export
	replace n_specs=. if n_specs<=11
	replace n_cases=. if n_cases<=11
	outsheet using "${RESULTS_FINAL}CounterFactualsSummary_`cf_name'_`model'`eta'.csv", comma replace
	erase cf_`cf_name'_summary`eta'.dta

	use cf_`cf_name'_spec`eta', clear
	save "${RESULTS_FINAL}CounterFactualsSpec_`cf_name'_`model'`eta'.dta", replace
	outsheet using "${RESULTS_FINAL}CounterFactualsSpec_`cf_name'_`model'`eta'.csv", comma replace
	erase cf_`cf_name'_spec`eta'.dta
}


log close
