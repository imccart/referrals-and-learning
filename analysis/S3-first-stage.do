set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}FirstStage_`logdate'.log", replace

******************************************************************
**	Title:		First-Stage Diagnostics for Congestion 2SLS
**	Author:		Ian McCarthy
**	Date Created:	3/6/2026
**	Notes:		Appendix diagnostics for the congestion (gamma)
**			first stage. HRR FEs included throughout.
**			Loops over Myopic/FWD. Produces:
**			  - Pooled first-stage table (coef, SE, F-stat, N)
**			  - Histogram of HRR-level F-statistics
**			  - Scatter of actual vs predicted patient counts
**			  - Summary of weak-instrument diagnostics
******************************************************************

local r_type "${PCP_First}_${PCP_Only}_${RFR_Priority}"


******************************************************************
** Capacity data (common across models)
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
keep Specialist_ID tot_patients_time hrr Year
gen time_period=(Year>2015)
bys Specialist_ID hrr time_period: gen obs=_n
keep if obs==1
drop obs
rename tot_patients_time tot_patients
save temp_s3_capacity, replace


******************************************************************
** Loop over model types

foreach model_type in Myopic FWD {
	if "`model_type'" == "Myopic" {
		local coef_prefix "StructureMyopic"
	}
	else {
		local coef_prefix "StructureForward"
	}
	local model "`model_type'"

	** Distance-only predictions (instrument)
	use "${RESULTS_FINAL}Distance_Prediction_Full_`r_type'.dta", clear
	split Spec_ID_t, p("-") generate(spec_id)
	rename spec_id1 Specialist_ID
	gen time_period=0 if spec_id2=="a"
	replace time_period=1 if spec_id2=="b"
	drop Spec_ID_t spec_id2
	gen base_count=yhat if Specialist_ID=="base"
	bys hrr: egen baseline=min(base_count)
	replace yhat=yhat-baseline
	drop if Specialist_ID=="base"
	keep yhat hrr time_period Specialist_ID
	destring Specialist_ID, replace force
	format Specialist_ID %12.0g
	sort hrr Specialist_ID time_period
	save temp_s3_distance, replace


	** Merge FEs with instrument and capacity
	use "${RESULTS_FINAL}`coef_prefix'HRR_Spec_FEs_`r_type'_rhobar.dta", clear
	merge m:1 hrr Specialist_ID time_period using temp_s3_distance, nogenerate keep(match)
	merge m:1 Specialist_ID time_period hrr using temp_s3_capacity, nogenerate keep(match)
	gen reg_weight=1/(coef_se^2)
	keep if converged==1
	save temp_s3_base_`model', replace


	************************************************************
	** A. Pooled first stage with HRR FEs
	************************************************************

	foreach eta in 1 5 {
		use temp_s3_base_`model', clear
		keep if eta==`eta'

		** First stage: tot_patients on yhat, with HRR FEs
		reg tot_patients yhat time_period i.hrr [aweight=reg_weight], cluster(Specialist_ID)

		** Store results
		local fs_coef_`eta' = _b[yhat]
		local fs_se_`eta' = _se[yhat]
		local fs_n_`eta' = e(N)

		** F-stat on excluded instrument
		test yhat
		local fs_f_`eta' = r(F)

		** Scatter: actual vs predicted patients
		predict yhat_resid, residuals
		predict tot_resid, residuals

		** Partial scatter (residualize both on controls + HRR FEs)
		qui reg tot_patients time_period i.hrr [aweight=reg_weight]
		predict tot_hat, residuals
		qui reg yhat time_period i.hrr [aweight=reg_weight]
		predict yhat_hat, residuals

		twoway (scatter tot_hat yhat_hat [aweight=reg_weight], msize(tiny) mcolor(gs10)) ///
			(lfit tot_hat yhat_hat [aweight=reg_weight], lcolor(black) lwidth(medthick)), ///
			ytitle("Actual patients (residualized)") ///
			xtitle("Predicted patients (residualized)") ///
			legend(off) title("`model', {&eta}=`eta'")
		graph save "${RESULTS_FINAL}FirstStage_Scatter_`model'_eta`eta'_`r_type'", replace
		graph export "${RESULTS_FINAL}FirstStage_Scatter_`model'_eta`eta'_`r_type'.png", as(png) replace

		drop yhat_resid tot_resid tot_hat yhat_hat
	}


	************************************************************
	** B. HRR-level first-stage F-statistics
	************************************************************

	** Dynamic HRR count
	use temp_s3_base_`model', clear
	local hrr_max = 0
	forvalues i=1/500 {
		qui count if hrr==`i'
		if r(N)>0 local hrr_max = `i'
	}

	foreach eta in 1 5 {
		use temp_s3_base_`model', clear
		keep if eta==`eta'

		matrix fs_hrr=J(`hrr_max',6,.)
		forvalues i=1/`hrr_max' {
			qui count if hrr==`i' & reg_weight!=.
			if r(N)>5 {
				qui reg tot_patients yhat time_period [aweight=reg_weight] if hrr==`i', cluster(Specialist_ID)
				mat fs_hrr[`i',1]=_b[yhat]
				mat var_mat=e(V)
				mat fs_hrr[`i',2]=sqrt(var_mat[1,1])
				mat fs_hrr[`i',3]=e(df_r)
				mat fs_hrr[`i',4]=`i'
				mat fs_hrr[`i',5]=`eta'
				** F-stat on yhat
				qui test yhat
				mat fs_hrr[`i',6]=r(F)
			}
		}

		clear
		svmat fs_hrr
		rename fs_hrr1 coef_est
		rename fs_hrr2 coef_se
		rename fs_hrr3 df
		rename fs_hrr4 hrr
		rename fs_hrr5 eta
		rename fs_hrr6 f_stat
		drop if hrr==.
		merge 1:1 hrr using hrr_size, nogenerate keep(master match)
		save temp_s3_fs_hrr_`model'_eta`eta', replace

		** Count weak/strong instruments
		qui count if f_stat>=10
		local n_strong = r(N)
		qui count
		local n_total = r(N)
		local pct_strong: di %4.1f 100*`n_strong'/`n_total'
		display "eta=`eta': `n_strong' of `n_total' HRRs have F>=10 (`pct_strong'%)"

		** Patient-weighted version
		qui sum f_stat [aweight=patients] if f_stat>=10
		qui sum patients if f_stat>=10
		local pat_strong = r(sum)
		qui sum patients
		local pat_total = r(sum)
		local pat_pct: di %4.1f 100*`pat_strong'/`pat_total'
		display "eta=`eta': `pat_pct'% of patients in HRRs with F>=10"

		** Histogram of F-stats with line at 10
		hist f_stat [fweight=patients], fraction color(gray) width(5) ///
			xline(10, lcolor(black) lpattern(dash)) ///
			ylabel(0(.1).5) ///
			ytitle("Relative Frequency") ///
			xtitle("First-stage F-statistic, {&eta}=`eta'") ///
			legend(off) title("`model'")
		graph save "${RESULTS_FINAL}FirstStage_Fstat_`model'_eta`eta'_`r_type'", replace
		graph export "${RESULTS_FINAL}FirstStage_Fstat_`model'_eta`eta'_`r_type'.png", as(png) replace
	}


	************************************************************
	** C. Summary table (LaTeX)
	************************************************************

	tempfile fs_table
	postfile fs_table str200 line using "`fs_table'", replace
	post fs_table ("")
	post fs_table ("& Coefficient & SE & F-statistic & N \\")
	post fs_table ("\hline\hline")

	foreach eta in 1 5 {
		post fs_table ("\$\eta=`eta'\$ & `=string(`fs_coef_`eta'', "%9.3f")' & (`=string(`fs_se_`eta'', "%9.3f")') & `=string(`fs_f_`eta'', "%9.1f")' & `=string(`fs_n_`eta'', "%9.0fc")' \\")
	}
	post fs_table ("\hline")
	postclose fs_table

	use "`fs_table'", clear
	outfile line using "${RESULTS_FINAL}FirstStage_Table_`model'.tex", noquote replace
}


log close
