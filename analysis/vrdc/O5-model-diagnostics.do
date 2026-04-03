set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}ModelDiagnostics_${MODEL_TYPE}_`logdate'.log", replace

******************************************************************
**	Title:		Model Diagnostics
**	Author:		Ian McCarthy
**	Date Created:	4/1/2026
**	Notes:		Parameterized by global MODEL_TYPE (Myopic or FWD).
**			Loads base_hrr files from O2-baseline.do.
**			Produces diagnostic graphs and summary CSV.
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

** determine dynamic HRR count from baseline files
local hrr_agg = 0
foreach eta in 1 5 {
	forvalues i=1/500 {
		capture confirm file "base_hrr`i'_eta`eta'.dta"
		if _rc==0 & `i'>`hrr_agg' local hrr_agg = `i'
	}
}


******************************************************************
** Build specialist-level and HRR-level diagnostics from base_hrr files

foreach eta in 1 5 {
	local step=0
	forvalues h=1/`hrr_agg' {
		capture confirm file "base_hrr`h'_eta`eta'.dta"
		if _rc==0 {
			use base_hrr`h'_eta`eta', clear

			** collapse to specialist level within HRR
			collapse (sum) pred_patients=pr_j observed_patients=choice ///
				(first) xi_j spec_qual coef_m tot_patients m_orig hrr, ///
				by(Specialist_ID)

			** specialist-level mean belief
			** m_orig is patient-level; after collapse with (first) it's just one value
			** need to reload and compute properly
			drop m_orig
			save _temp_spec, replace

			use base_hrr`h'_eta`eta', clear
			collapse (mean) m_mean=m_orig, by(Specialist_ID)
			merge 1:1 Specialist_ID using _temp_spec, nogenerate

			gen hrr_group=`h'
			gen eta=`eta'

			local step=`step'+1
			if `step'==1 {
				save _diag_spec`eta', replace
			}
			else {
				append using _diag_spec`eta'
				save _diag_spec`eta', replace
			}
		}
	}
}


******************************************************************
** Diagnostic graphs

foreach eta in 1 5 {
	use _diag_spec`eta', clear

	** 1. FE vs quality (specialist level)
	twoway (scatter xi_j spec_qual, msymbol(circle_hollow) mcolor(gray%30) msize(tiny)) ///
		(lfit xi_j spec_qual, lcolor(black) lwidth(medthick)), ///
		ytitle("Specialist FE ({&xi})") xtitle("True Quality") ///
		title("FE vs Quality, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}_est-diag-fe-quality_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}_est-diag-fe-quality_`model'_eta`eta'.png", as(png) replace

	** 2. Running beliefs vs true quality (specialist level)
	twoway (scatter m_mean spec_qual, msymbol(circle_hollow) mcolor(gray%30) msize(tiny)) ///
		(function y=x, range(0.5 1) lcolor(red) lwidth(thin)), ///
		ytitle("Mean Running Belief (m)") xtitle("True Quality") ///
		title("Beliefs vs Quality, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}_est-diag-beliefs-quality_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}_est-diag-beliefs-quality_`model'_eta`eta'.png", as(png) replace

	** 3. Volume vs quality (specialist level)
	twoway (scatter tot_patients spec_qual, msymbol(circle_hollow) mcolor(gray%30) msize(tiny)) ///
		(lfit tot_patients spec_qual, lcolor(black) lwidth(medthick)), ///
		ytitle("Total Patients") xtitle("True Quality") ///
		title("Volume vs Quality, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}_est-diag-volume-quality_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}_est-diag-volume-quality_`model'_eta`eta'.png", as(png) replace

	** 4. Predicted vs observed market shares (specialist level)
	** use sum(pred_patients) as denominator = total casevars in HRR
	** (sum(observed_patients) undercounts due to FE-trimmed casevars with no choice)
	bys hrr: egen hrr_total_patients = sum(pred_patients)
	gen pred_share = pred_patients / hrr_total_patients
	gen obs_share = observed_patients / hrr_total_patients
	drop hrr_total_patients
	twoway (scatter pred_share obs_share, msymbol(circle_hollow) mcolor(gray%30) msize(tiny)) ///
		(function y=x, range(0 1) lcolor(red) lwidth(thin)), ///
		ytitle("Predicted Share (pr_j)") xtitle("Observed Share") ///
		title("Model Fit: Market Shares, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}_est-diag-fit-shares_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}_est-diag-fit-shares_`model'_eta`eta'.png", as(png) replace

	** 5. Predicted vs observed health (HRR level)
	preserve
	use base_hrr1_eta`eta', clear
	forvalues h=2/`hrr_agg' {
		capture append using base_hrr`h'_eta`eta'
	}
	** drop casevars whose chosen specialist was trimmed (FE outlier)
	** casevar is only unique within HRR, so must group by both
	bys hrr casevar: egen has_choice = max(choice)
	drop if has_choice == 0
	drop has_choice
	gen pred_health = pr_j * spec_qual
	gen obs_health = choice * spec_qual
	collapse (sum) pred_health obs_health, by(casevar hrr)
	collapse (mean) pred_health obs_health, by(hrr)
	twoway (scatter pred_health obs_health, msymbol(circle_hollow) mcolor(gray)) ///
		(function y=x, range(0.5 1) lcolor(red) lwidth(thin)), ///
		ytitle("Predicted E[Success]") xtitle("Observed E[Success]") ///
		title("Model Fit: Health Outcomes, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}_est-diag-fit-health_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}_est-diag-fit-health_`model'_eta`eta'.png", as(png) replace
	restore


	** HRR-level summary for CSV export
	use _diag_spec`eta', clear
	bys hrr: egen n_specs = count(Specialist_ID)

	** correlations per HRR
	levelsof hrr, local(hrrs)
	tempfile hrr_diag
	local first=1
	foreach h of local hrrs {
		preserve
		keep if hrr==`h'
		qui count
		local ns = r(N)

		local corr_fe_qual = .
		local corr_m_qual = .
		local corr_vol_qual = .
		local corr_pred_obs = .
		if `ns'>=5 {
			qui corr xi_j spec_qual
			local corr_fe_qual = r(rho)
			qui corr m_mean spec_qual
			local corr_m_qual = r(rho)
			qui corr tot_patients spec_qual
			local corr_vol_qual = r(rho)
			qui corr pred_patients observed_patients
			local corr_pred_obs = r(rho)
		}

		qui sum spec_qual
		local mean_qual = r(mean)
		local sd_qual = r(sd)
		qui sum m_mean
		local mean_m = r(mean)
		qui sum xi_j
		local mean_fe = r(mean)
		local sd_fe = r(sd)

		clear
		set obs 1
		gen hrr = `h'
		gen eta = `eta'
		gen n_specs = `ns'
		gen corr_fe_qual = `corr_fe_qual'
		gen corr_m_qual = `corr_m_qual'
		gen corr_vol_qual = `corr_vol_qual'
		gen corr_pred_obs = `corr_pred_obs'
		gen mean_qual = `mean_qual'
		gen sd_qual = `sd_qual'
		gen mean_m = `mean_m'
		gen mean_fe = `mean_fe'
		gen sd_fe = `sd_fe'

		if `first'==1 {
			save `hrr_diag', replace
			local first=0
		}
		else {
			append using `hrr_diag'
			save `hrr_diag', replace
		}
		restore
	}

	use `hrr_diag', clear
	save "${RESULTS_FINAL}ModelDiagnostics_`model'`eta'.dta", replace
	replace n_specs=. if n_specs<=11
	outsheet using "${RESULTS_FINAL}ModelDiagnostics_`model'`eta'.csv", comma replace
}

** clean up
foreach eta in 1 5 {
	capture erase _diag_spec`eta'.dta
}
capture erase _temp_spec.dta


log close
