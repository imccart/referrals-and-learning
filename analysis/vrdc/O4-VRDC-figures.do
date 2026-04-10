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
		ytitle("Share of Markets") xtitle("Estimated {&alpha}") legend(off)
	graph save "${RESULTS_FINAL}alpha_`model'_eta`eta'_rhobar_`r_type'", replace
	graph export "${RESULTS_FINAL}alpha_`model'_eta`eta'_rhobar_`r_type'.png", as(png) replace
	hist coef_dist [weight=patients], fraction color(gray) width(0.01) ///
		ylabel(0(.05).2) ///
		ytitle("Share of Markets") xtitle("Estimated Distance Coefficient") legend(off)
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
		ylabel(0(.1)0.5) xscale(range(-0.02 0)) xlabel(-0.02 "<-0.02" -0.015(0.005)0, add) ///
		ytitle("Share of Markets") xtitle("Mean Partial Effect of One Failure") legend(off)
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
			ytitle("Share of Markets") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Share of Patients Reallocated") legend(off)
		graph save "${RESULTS_FINAL}Reallocation_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}Reallocation_`cf_name'_`model'_eta`eta'.png", as(png) replace

		** all markets: health effects
		gen health_cf_t = health_cf
		replace health_cf_t=-0.01 if health_cf_t<-0.01
		replace health_cf_t=0.01 if health_cf_t>0.01
		hist health_cf_t [weight=patients], fraction color(gray) width(0.001) ///
			ylabel(0(.1).5) ///
			xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
			ytitle("Share of Markets") xtitle("Change in Mean Failure Rate") legend(off)
		graph save "${RESULTS_FINAL}Mean_Health_FX_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}Mean_Health_FX_`cf_name'_`model'_eta`eta'.png", as(png) replace
		drop health_cf_t

		** alpha>0 markets: reallocation
		preserve
		keep if coef_m>0

		sum pij_diff_cf health_cf [aweight=patients], detail

		hist pij_diff_cf [weight=patients], fraction color(gray) ///
			ytitle("Share of Markets") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Share of Patients Reallocated") legend(off)
		graph save "${RESULTS_FINAL}ReallocationNC_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}ReallocationNC_`cf_name'_`model'_eta`eta'.png", as(png) replace

		gen health_cf_t = health_cf
		replace health_cf_t=-0.01 if health_cf_t<-0.01
		replace health_cf_t=0.01 if health_cf_t>0.01
		hist health_cf_t [weight=patients], fraction color(gray) width(0.001) ///
			ylabel(0(.1).5) ///
			xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
			ytitle("Share of Markets") xtitle("Change in Mean Failure Rate") legend(off)
		graph save "${RESULTS_FINAL}Mean_Health_FXNC_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}Mean_Health_FXNC_`cf_name'_`model'_eta`eta'.png", as(png) replace
		restore

		** gradient plots (alpha>0 only)
		preserve
		keep if coef_m>0
		xtile alpha_bin=coef_m [aweight=patients], nq(20)
		collapse (mean) pij_diff_cf health_cf coef_m [aweight=patients], by(alpha_bin)

		twoway scatter pij_diff_cf coef_m, color(gray) msymbol(circle) ///
			ytitle("Share of Patients Reallocated") xtitle("Estimated {&alpha}") legend(off)
		graph save "${RESULTS_FINAL}Gradient_Reallocation_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}Gradient_Reallocation_`cf_name'_`model'_eta`eta'.png", as(png) replace

		twoway scatter health_cf coef_m, color(gray) msymbol(circle) ///
			ytitle("Change in Mean Failure Rate") xtitle("Estimated {&alpha}") legend(off)
		graph save "${RESULTS_FINAL}Gradient_HealthFX_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}Gradient_HealthFX_`cf_name'_`model'_eta`eta'.png", as(png) replace
		restore

		** health effects by FE-quality correlation (alpha>0 only, skip fullnofe)
		if "`cf_name'" != "fullnofe" {
		preserve
		keep if coef_m>0 & corr_fe_qual!=.

		twoway (scatter health_cf corr_fe_qual [aweight=patients], msymbol(circle_hollow) mcolor(gray)) ///
			(lfit health_cf corr_fe_qual [aweight=patients], lcolor(black) lwidth(medthick)), ///
			ytitle("Change in Mean Failure Rate") xtitle("Correlation Between Fixed Effects and Quality") legend(off)
		graph save "${RESULTS_FINAL}HealthFX_by_FEQual_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}HealthFX_by_FEQual_`cf_name'_`model'_eta`eta'.png", as(png) replace
		restore
		}
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
			ytitle("Share of Specialists") xtitle("Relative Change in Patient Volume") legend(off)
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
			ytitle("Share of Specialists") xtitle("Relative Change in Patient Volume") legend(off)
		graph save "${RESULTS_FINAL}VolumeChangeNC_`cf_name'_`model'_eta`eta'", replace
		graph export "${RESULTS_FINAL}VolumeChangeNC_`cf_name'_`model'_eta`eta'.png", as(png) replace
	}
}


******************************************************************
** Quality and spending distributions (baseline vs counterfactual)
** Mean change histograms + quantile scatters per HRR

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

		** compute within-HRR quantiles and means (volume-weighted)
		** quality
		foreach stat in mean p10 p25 p75 p90 {
			gen wt_qual_base_`stat' = .
			gen wt_qual_cf_`stat' = .
		}
		gen wt_spend_base_mean = .
		gen wt_spend_cf_mean = .
		foreach stat in p10 p25 p75 p90 {
			gen wt_spend_base_`stat' = .
			gen wt_spend_cf_`stat' = .
		}

		levelsof hrr, local(hrrs)
		foreach h of local hrrs {
			** baseline quality (require >0 weight and >=5 specialists)
			qui count if hrr==`h' & pred_patients0>0 & spec_qual!=.
			if r(N)>=5 {
				qui sum spec_qual if hrr==`h' & pred_patients0>0 [aweight=pred_patients0]
				qui replace wt_qual_base_mean = r(mean) if hrr==`h'
				qui _pctile spec_qual if hrr==`h' & pred_patients0>0 [pweight=pred_patients0], p(10 25 75 90)
				qui replace wt_qual_base_p10 = r(r1) if hrr==`h'
				qui replace wt_qual_base_p25 = r(r2) if hrr==`h'
				qui replace wt_qual_base_p75 = r(r3) if hrr==`h'
				qui replace wt_qual_base_p90 = r(r4) if hrr==`h'
			}

			** cf quality
			qui count if hrr==`h' & pred_patients_cf>0 & spec_qual!=.
			if r(N)>=5 {
				qui sum spec_qual if hrr==`h' & pred_patients_cf>0 [aweight=pred_patients_cf]
				qui replace wt_qual_cf_mean = r(mean) if hrr==`h'
				qui _pctile spec_qual if hrr==`h' & pred_patients_cf>0 [pweight=pred_patients_cf], p(10 25 75 90)
				qui replace wt_qual_cf_p10 = r(r1) if hrr==`h'
				qui replace wt_qual_cf_p25 = r(r2) if hrr==`h'
				qui replace wt_qual_cf_p75 = r(r3) if hrr==`h'
				qui replace wt_qual_cf_p90 = r(r4) if hrr==`h'
			}

			** baseline spending
			qui count if hrr==`h' & mean_episode!=. & pred_patients0>0
			if r(N)>=5 {
				qui sum mean_episode if hrr==`h' & mean_episode!=. & pred_patients0>0 [aweight=pred_patients0]
				qui replace wt_spend_base_mean = r(mean) if hrr==`h'
				qui _pctile mean_episode if hrr==`h' & mean_episode!=. & pred_patients0>0 [pweight=pred_patients0], p(10 25 75 90)
				qui replace wt_spend_base_p10 = r(r1) if hrr==`h'
				qui replace wt_spend_base_p25 = r(r2) if hrr==`h'
				qui replace wt_spend_base_p75 = r(r3) if hrr==`h'
				qui replace wt_spend_base_p90 = r(r4) if hrr==`h'
			}

			** cf spending
			qui count if hrr==`h' & mean_episode!=. & pred_patients_cf>0
			if r(N)>=5 {
				qui sum mean_episode if hrr==`h' & mean_episode!=. & pred_patients_cf>0 [aweight=pred_patients_cf]
				qui replace wt_spend_cf_mean = r(mean) if hrr==`h'
				qui _pctile mean_episode if hrr==`h' & mean_episode!=. & pred_patients_cf>0 [pweight=pred_patients_cf], p(10 25 75 90)
				qui replace wt_spend_cf_p10 = r(r1) if hrr==`h'
				qui replace wt_spend_cf_p25 = r(r2) if hrr==`h'
				qui replace wt_spend_cf_p75 = r(r3) if hrr==`h'
				qui replace wt_spend_cf_p90 = r(r4) if hrr==`h'
			}
		}

		** collapse to HRR level
		collapse (first) wt_qual_* wt_spend_* coef_m ///
			(sum) tot_patients=pred_patients0, by(hrr)

		** derived variables
		gen qual_change = wt_qual_cf_mean - wt_qual_base_mean
		gen spend_change = wt_spend_cf_mean - wt_spend_base_mean
		gen qual_above = (wt_qual_cf_mean > wt_qual_base_mean) if qual_change!=.
		gen spend_below = (wt_spend_cf_mean < wt_spend_base_mean) if spend_change!=.

		** summary statistics
		qui count if qual_change!=.
		local n_qual = r(N)
		qui count if qual_change!=. & qual_above==1
		local n_qual_improve = r(N)
		qui sum tot_patients if qual_change!=. & qual_above==1
		local pat_qual_improve = r(sum)
		qui sum tot_patients if qual_change!=.
		local pat_qual_total = r(sum)

		qui count if spend_change!=.
		local n_spend = r(N)
		qui count if spend_change!=. & spend_below==1
		local n_spend_improve = r(N)
		qui sum tot_patients if spend_change!=. & spend_below==1
		local pat_spend_improve = r(sum)
		qui sum tot_patients if spend_change!=.
		local pat_spend_total = r(sum)

		foreach pct in 10 25 75 90 {
			gen qual_above_p`pct' = (wt_qual_cf_p`pct' > wt_qual_base_p`pct') ///
				if wt_qual_base_p`pct'!=. & wt_qual_cf_p`pct'!=.
			gen spend_below_p`pct' = (wt_spend_cf_p`pct' < wt_spend_base_p`pct') ///
				if wt_spend_base_p`pct'!=. & wt_spend_cf_p`pct'!=.
		}

		** save summary stats CSV
		preserve
		gen cf_type = "`cf_name'"
		gen eta = `eta'
		gen n_hrrs_qual = `n_qual'
		gen n_improve_qual = `n_qual_improve'
		gen pct_improve_qual = `n_qual_improve'/`n_qual' * 100 if `n_qual'>0
		gen pat_pct_improve_qual = `pat_qual_improve'/`pat_qual_total' * 100 if `pat_qual_total'>0
		gen n_hrrs_spend = `n_spend'
		gen n_improve_spend = `n_spend_improve'
		gen pct_improve_spend = `n_spend_improve'/`n_spend' * 100 if `n_spend'>0
		gen pat_pct_improve_spend = `pat_spend_improve'/`pat_spend_total' * 100 if `pat_spend_total'>0
		outsheet hrr cf_type eta tot_patients qual_change spend_change ///
			wt_qual_base_* wt_qual_cf_* wt_spend_base_* wt_spend_cf_* ///
			using "${RESULTS_FINAL}DistSummary_`cf_name'_`model'`eta'.csv", comma replace
		restore

		** ---------- mean quality change histogram ----------
		qui count if qual_change!=.
		if r(N)>=5 {
			hist qual_change if qual_change!=., fraction color(gray) ///
				xtitle("Change in Volume-Weighted Mean Quality") ///
				ytitle("Share of Markets") ///
				xline(0, lcolor(gs10) lpattern(dash)) legend(off)
			graph save "${RESULTS_FINAL}Mean_Qual_FX_`cf_name'_`model'_eta`eta'", replace
			graph export "${RESULTS_FINAL}Mean_Qual_FX_`cf_name'_`model'_eta`eta'.png", as(png) replace
		}

		** ---------- quality quantile scatters ----------
		foreach pct in 10 25 75 90 {
			if `pct'==10 local pct_label "10th Percentile"
			if `pct'==25 local pct_label "25th Percentile"
			if `pct'==75 local pct_label "75th Percentile"
			if `pct'==90 local pct_label "90th Percentile"

			qui count if wt_qual_base_p`pct'!=. & wt_qual_cf_p`pct'!=.
			if r(N)>=5 {
				** share above line (annotation)
				qui count if qual_above_p`pct'==1
				local n_above = r(N)
				qui count if qual_above_p`pct'!=.
				local n_total = r(N)
				local pct_above: di %4.1f (`n_above'/`n_total'*100)
				qui sum tot_patients if qual_above_p`pct'==1
				local pat_above = r(sum)
				qui sum tot_patients if qual_above_p`pct'!=.
				local pat_total = r(sum)
				local pat_pct_above: di %4.1f (`pat_above'/`pat_total'*100)

				qui sum wt_qual_base_p`pct'
				local qmin = r(min)
				local qmax = r(max)
				twoway (scatter wt_qual_cf_p`pct' wt_qual_base_p`pct' if qual_above_p`pct'==1 ///
						[aweight=tot_patients], msymbol(circle) mcolor(midblue%40)) ///
					(scatter wt_qual_cf_p`pct' wt_qual_base_p`pct' if qual_above_p`pct'==0 ///
						[aweight=tot_patients], msymbol(circle) mcolor(cranberry%40)) ///
					(function y=x, range(`qmin' `qmax') lcolor(black) lwidth(thin) lpattern(dash)), ///
					xtitle("Baseline `pct_label' Quality") ///
					ytitle("Counterfactual `pct_label' Quality") ///
					legend(off) ///
					note("`pct_above'% of markets above 45{&degree} (`pat_pct_above'% of patients)", ///
						size(small) position(5) ring(0))
				graph save "${RESULTS_FINAL}QualP`pct'_`cf_name'_`model'_eta`eta'", replace
				graph export "${RESULTS_FINAL}QualP`pct'_`cf_name'_`model'_eta`eta'.png", as(png) replace
			}
		}

		** ---------- mean spending change histogram ----------
		qui count if spend_change!=.
		if r(N)>=5 {
			hist spend_change if spend_change!=., fraction color(gray) ///
				xtitle("Change in Volume-Weighted Mean Episode Spending ($)") ///
				ytitle("Share of Markets") ///
				xline(0, lcolor(gs10) lpattern(dash)) legend(off) ///
				xlabel(, format(%9.0fc))
			graph save "${RESULTS_FINAL}Mean_Spend_FX_`cf_name'_`model'_eta`eta'", replace
			graph export "${RESULTS_FINAL}Mean_Spend_FX_`cf_name'_`model'_eta`eta'.png", as(png) replace
		}

		** ---------- spending quantile scatters ----------
		foreach pct in 10 25 75 90 {
			if `pct'==10 local pct_label "10th Percentile"
			if `pct'==25 local pct_label "25th Percentile"
			if `pct'==75 local pct_label "75th Percentile"
			if `pct'==90 local pct_label "90th Percentile"

			qui count if wt_spend_base_p`pct'!=. & wt_spend_cf_p`pct'!=.
			if r(N)>=5 {
				** share below line = spending decreased (annotation)
				qui count if spend_below_p`pct'==1
				local n_below = r(N)
				qui count if spend_below_p`pct'!=.
				local n_total = r(N)
				local pct_below: di %4.1f (`n_below'/`n_total'*100)
				qui sum tot_patients if spend_below_p`pct'==1
				local pat_below = r(sum)
				qui sum tot_patients if spend_below_p`pct'!=.
				local pat_total = r(sum)
				local pat_pct_below: di %4.1f (`pat_below'/`pat_total'*100)

				qui sum wt_spend_base_p`pct'
				local smin = r(min)
				local smax = r(max)
				twoway (scatter wt_spend_cf_p`pct' wt_spend_base_p`pct' if spend_below_p`pct'==1 ///
						[aweight=tot_patients], msymbol(circle) mcolor(midblue%40)) ///
					(scatter wt_spend_cf_p`pct' wt_spend_base_p`pct' if spend_below_p`pct'==0 ///
						[aweight=tot_patients], msymbol(circle) mcolor(cranberry%40)) ///
					(function y=x, range(`smin' `smax') lcolor(black) lwidth(thin) lpattern(dash)), ///
					xtitle("Baseline `pct_label' Spending ($)") ///
					ytitle("Counterfactual `pct_label' Spending ($)") ///
					legend(off) ///
					xlabel(, format(%9.0fc)) ylabel(, format(%9.0fc)) ///
					note("`pct_below'% of markets below 45{&degree} (`pat_pct_below'% of patients)", ///
						size(small) position(5) ring(0))
				graph save "${RESULTS_FINAL}SpendP`pct'_`cf_name'_`model'_eta`eta'", replace
				graph export "${RESULTS_FINAL}SpendP`pct'_`cf_name'_`model'_eta`eta'.png", as(png) replace
			}
		}
	}
}
capture erase temp_spec_cost.dta


log close
