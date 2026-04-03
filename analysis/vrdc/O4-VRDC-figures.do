set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Figures_${MODEL_TYPE}_`logdate'.log", replace

******************************************************************
**	Title:		Structural Figures (VRDC)
**	Author:		Ian McCarthy
**	Date Created:	2/25/2026
**	Date Updated:	3/30/2026
**	Notes:		Parameterized by global MODEL_TYPE (Myopic or FWD).
**			Loads per-counterfactual summary/spec files from
**			O2-cf-*.do scripts.
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


******************************************************************
** Alpha and distance histograms (across HRRs)

use "${RESULTS_FINAL}`coef_prefix'_SummaryHRR.dta", replace
foreach eta in 1 5 {
	preserve
	keep if eta==`eta'
	sum coef_m, detail
	hist coef_m [weight=patients], fraction color(gray) width(0.3) ///
		ylabel(0(.1).7) ///
		ytitle("Relative Frequency") xtitle("Estimates for {&alpha} with {&eta}= `eta'") legend(off)
	graph save "${RESULTS_FINAL}alpha_`model'_eta`eta'_rhobar_`r_type'", replace
	graph export "${RESULTS_FINAL}alpha_`model'_eta`eta'_rhobar_`r_type'.png", as(png) replace
	hist coef_dist [weight=patients], fraction color(gray) width(0.01) ///
		ylabel(0(.05).2) ///
		ytitle("Relative Frequency") xtitle("Estimates for diff. distance with {&eta}= `eta'") legend(off)
	graph save "${RESULTS_FINAL}dist_`model'_eta`eta'_rhobar_`r_type'", replace
	graph export "${RESULTS_FINAL}dist_`model'_eta`eta'_rhobar_`r_type'.png", as(png) replace
	restore
}


******************************************************************
** Partial effect histograms

foreach eta in 1 5 {
	use "${RESULTS_FINAL}MarginalEffects_`model'`eta'.dta", clear
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)
	sum mfx_mean mfx_10 mfx_25 mfx_50 mfx_75 mfx_90 mfx_sd [aweight=mfx_count]
	sum pfx_mean pfx_10 pfx_25 pfx_50 pfx_75 pfx_90 pfx_sd [aweight=patients]

	gen rel_mean=pfx_mean/pr_mean
	replace pfx_mean=-0.02 if pfx_mean< -0.02
	hist pfx_mean [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1)0.5) xscale(range(-0.02 0)) xlabel(-0.02 "<-0.02" -0.015(0.005)0, add) //////
		ytitle("Relative Frequency") xtitle("Mean Partial Effect of One Failure, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Partial_FX_Failure_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Partial_FX_Failure_`model'_eta`eta'.png", as(png) replace
}


******************************************************************
** Counterfactual histograms

foreach cf_name in full current fullfam fullnofe {

	** set labels for figures
	if "`cf_name'" == "full" local cf_label "Full Info"
	if "`cf_name'" == "current" local cf_label "Current Info"
	if "`cf_name'" == "fullfam" local cf_label "Full Info and No Familiarity"
	if "`cf_name'" == "fullnofe" local cf_label "Full Info, No FEs"

	foreach eta in 1 5 {

		capture confirm file "${RESULTS_FINAL}CounterFactualsSummary_`cf_name'_`model'`eta'.dta"
		if _rc!=0 continue

		use "${RESULTS_FINAL}CounterFactualsSummary_`cf_name'_`model'`eta'.dta", clear
		merge 1:1 hrr using hrr_size, nogenerate keep(master match)

		** all markets: reallocation
		hist pij_diff_cf [weight=patients], fraction color(gray) ///
			ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with `cf_label', {&eta}=`eta'") legend(off)
		graph save "${RESULTS_FINAL}Reallocation_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}Reallocation_`cf_name'_`model'_eta`eta'.png", as(png) replace

		** all markets: health effects
		gen health_cf_t = health_cf
		replace health_cf_t=-0.01 if health_cf_t<-0.01
		replace health_cf_t=0.01 if health_cf_t>0.01
		hist health_cf_t [weight=patients], fraction color(gray) width(0.001) ///
			ylabel(0(.1).5) ///
			xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
			ytitle("Relative Frequency") xtitle("Health Effects of `cf_label', {&eta}=`eta'") legend(off)
		graph save "${RESULTS_FINAL}Mean_Health_FX_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}Mean_Health_FX_`cf_name'_`model'_eta`eta'.png", as(png) replace
		drop health_cf_t

		** alpha>0 markets: reallocation
		preserve
		keep if coef_m>0

		sum pij_diff_cf health_cf [aweight=patients], detail

		hist pij_diff_cf [weight=patients], fraction color(gray) ///
			ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with `cf_label', {&eta}=`eta'") legend(off)
		graph save "${RESULTS_FINAL}ReallocationNC_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}ReallocationNC_`cf_name'_`model'_eta`eta'.png", as(png) replace

		gen health_cf_t = health_cf
		replace health_cf_t=-0.01 if health_cf_t<-0.01
		replace health_cf_t=0.01 if health_cf_t>0.01
		hist health_cf_t [weight=patients], fraction color(gray) width(0.001) ///
			ylabel(0(.1).5) ///
			xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
			ytitle("Relative Frequency") xtitle("Health Effects of `cf_label', {&eta}=`eta'") legend(off)
		graph save "${RESULTS_FINAL}Mean_Health_FXNC_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}Mean_Health_FXNC_`cf_name'_`model'_eta`eta'.png", as(png) replace
		restore

		** gradient plots (alpha>0 only)
		preserve
		keep if coef_m>0
		xtile alpha_bin=coef_m [aweight=patients], nq(20)
		collapse (mean) pij_diff_cf health_cf coef_m [aweight=patients], by(alpha_bin)

		twoway scatter pij_diff_cf coef_m, color(gray) msymbol(circle) ///
			ytitle("Reallocation with `cf_label'") xtitle("{&alpha}, {&eta}=`eta'") legend(off)
		graph save "${RESULTS_FINAL}Gradient_Reallocation_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}Gradient_Reallocation_`cf_name'_`model'_eta`eta'.png", as(png) replace

		twoway scatter health_cf coef_m, color(gray) msymbol(circle) ///
			ytitle("Health Effects of `cf_label'") xtitle("{&alpha}, {&eta}=`eta'") legend(off)
		graph save "${RESULTS_FINAL}Gradient_HealthFX_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}Gradient_HealthFX_`cf_name'_`model'_eta`eta'.png", as(png) replace
		restore

		** health effects by FE-quality correlation (alpha>0 only)
		preserve
		keep if coef_m>0 & corr_fe_qual!=.

		twoway (scatter health_cf corr_fe_qual [aweight=patients], msymbol(circle_hollow) mcolor(gray)) ///
			(lfit health_cf corr_fe_qual [aweight=patients], lcolor(black) lwidth(medthick)), ///
			ytitle("Health Effects of `cf_label'") xtitle("Corr({&xi}, quality), {&eta}=`eta'") legend(off)
		graph save "${RESULTS_FINAL}HealthFX_by_FEQual_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}HealthFX_by_FEQual_`cf_name'_`model'_eta`eta'.png", as(png) replace
		restore
	}
}


******************************************************************
** Specialist volume changes

use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
bys Specialist_ID hrr: gen obs=_n
bys Specialist_ID hrr: egen spec_patients=sum(choice)
replace spec_qual=spec_success_tot/spec_patients_tot
keep if obs==1
keep Specialist_ID hrr spec_qual spec_patients
save spec_temp, replace

foreach cf_name in full current fullfam fullnofe {

	if "`cf_name'" == "full" local cf_label "Full Info"
	if "`cf_name'" == "current" local cf_label "Current Info"
	if "`cf_name'" == "fullfam" local cf_label "Full Info and No Familiarity"
	if "`cf_name'" == "fullnofe" local cf_label "Full Info, No FEs"

	foreach eta in 1 5 {

		capture confirm file "${RESULTS_FINAL}CounterFactualsSpec_`cf_name'_`model'`eta'.dta"
		if _rc!=0 continue

		** all markets
		use "${RESULTS_FINAL}CounterFactualsSpec_`cf_name'_`model'`eta'.dta", clear
		merge 1:1 hrr Specialist_ID hrr using spec_temp, keep(match) nogenerate

		gen diff_cf=pred_patients_cf-pred_patients0
		gen reldiff_cf=diff_cf/pred_patients0
		reg reldiff_cf spec_qual, robust

		hist reldiff_cf if reldiff_cf>-1 & reldiff_cf<1, fraction color(gray) ///
			ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
		graph save "${RESULTS_FINAL}VolumeChange_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}VolumeChange_`cf_name'_`model'_eta`eta'.png", as(png) replace

		** removing non-converging markets
		use "${RESULTS_FINAL}CounterFactualsSpec_`cf_name'_`model'`eta'.dta", clear
		gen share_nc=no_equil_cf/pred_patients0
		merge 1:1 hrr Specialist_ID hrr using spec_temp, keep(match) nogenerate

		drop if share_nc>0.05
		gen diff_cf=pred_patients_cf-pred_patients0
		gen reldiff_cf=diff_cf/pred_patients0
		reg reldiff_cf spec_qual, robust

		hist reldiff_cf if reldiff_cf>-1 & reldiff_cf<1, fraction color(gray) ///
			ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
		graph save "${RESULTS_FINAL}VolumeChangeNC_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}VolumeChangeNC_`cf_name'_`model'_eta`eta'.png", as(png) replace
	}
}


******************************************************************
** Quality consumption and spending distributions (baseline vs counterfactual)

** Build specialist-level mean episode cost from A1 temp file
use spec_quality_distribution, clear
collapse (mean) mean_episode [aweight=spec_patients_year], by(Specialist_ID bene_hrr)
rename bene_hrr hrr
save temp_spec_cost, replace

foreach cf_name in full current fullfam fullnofe {

	if "`cf_name'" == "full" local cf_label "Full Info"
	if "`cf_name'" == "current" local cf_label "Current Info"
	if "`cf_name'" == "fullfam" local cf_label "Full Info and No Familiarity"
	if "`cf_name'" == "fullnofe" local cf_label "Full Info, No FEs"

	foreach eta in 1 5 {

		capture confirm file "${RESULTS_FINAL}CounterFactualsSpec_`cf_name'_`model'`eta'.dta"
		if _rc!=0 continue

		use "${RESULTS_FINAL}CounterFactualsSpec_`cf_name'_`model'`eta'.dta", clear
		merge 1:1 hrr Specialist_ID using temp_spec_cost, keep(master match) nogenerate

		** quality consumption density: all markets
		twoway (kdensity spec_qual [aweight=pred_patients0], lcolor(gs8) lwidth(medthick)) ///
			(kdensity spec_qual [aweight=pred_patients_cf], lcolor(cranberry) lwidth(medthick) lpattern(dash)), ///
			xtitle("Specialist Quality (Success Rate)") ytitle("Density") ///
			legend(order(1 "Baseline" 2 "`cf_label'") position(6) rows(1))
		graph save "${RESULTS_FINAL}QualDist_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}QualDist_`cf_name'_`model'_eta`eta'.png", as(png) replace

		** quality consumption density: alpha>0 markets
		preserve
		keep if coef_m>0
		twoway (kdensity spec_qual [aweight=pred_patients0], lcolor(gs8) lwidth(medthick)) ///
			(kdensity spec_qual [aweight=pred_patients_cf], lcolor(cranberry) lwidth(medthick) lpattern(dash)), ///
			xtitle("Specialist Quality (Success Rate)") ytitle("Density") ///
			legend(order(1 "Baseline" 2 "`cf_label'") position(6) rows(1))
		graph save "${RESULTS_FINAL}QualDistNC_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}QualDistNC_`cf_name'_`model'_eta`eta'.png", as(png) replace
		restore

		** spending density: all markets
		twoway (kdensity mean_episode [aweight=pred_patients0], lcolor(gs8) lwidth(medthick)) ///
			(kdensity mean_episode [aweight=pred_patients_cf], lcolor(cranberry) lwidth(medthick) lpattern(dash)), ///
			xtitle("Mean Episode Spending ($)") ytitle("Density") ///
			legend(order(1 "Baseline" 2 "`cf_label'") position(6) rows(1))
		graph save "${RESULTS_FINAL}SpendDist_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}SpendDist_`cf_name'_`model'_eta`eta'.png", as(png) replace

		** spending density: alpha>0 markets
		preserve
		keep if coef_m>0
		twoway (kdensity mean_episode [aweight=pred_patients0], lcolor(gs8) lwidth(medthick)) ///
			(kdensity mean_episode [aweight=pred_patients_cf], lcolor(cranberry) lwidth(medthick) lpattern(dash)), ///
			xtitle("Mean Episode Spending ($)") ytitle("Density") ///
			legend(order(1 "Baseline" 2 "`cf_label'") position(6) rows(1))
		graph save "${RESULTS_FINAL}SpendDistNC_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}SpendDistNC_`cf_name'_`model'_eta`eta'.png", as(png) replace
		restore
	}
}


log close
