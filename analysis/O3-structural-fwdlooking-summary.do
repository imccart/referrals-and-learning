set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Structural_FWDLooking_Summary_`logdate'.log", replace

******************************************************************
**	Title:		Summarize Structural (Forward Looking) Results
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	4/10/2025
******************************************************************

/* exploratory summaries and graphs */
/*
use "${DATA_FINAL}ChoiceEstData_Summary.dta", replace

hist m_git_eta1, fraction color(gray) width(0.03) ///
	ylabel(0(.1).7) ///
	ytitle("Relative Frequency") xtitle("Index m for {&eta}=1") legend(off)
graph save "${RESULTS_FINAL}Hist_m_eta1_rhobar_1_1_0", replace
graph export "${RESULTS_FINAL}Hist_m_eta1_rhobar_1_1_0.png", as(png) replace

hist m_git_eta1 if m_git_eta1<0.89, fraction color(gray) width(0.03) ///
	ylabel(0(.1).7) ///
	ytitle("Relative Frequency") xtitle("Index m for {&eta}=1") legend(off)
graph save "${RESULTS_FINAL}Hist_mlow_eta1_rhobar_1_1_0", replace
graph export "${RESULTS_FINAL}Hist_mlow_eta1_rhobar_1_1_0.png", as(png) replace

hist pair_patients_run if pair_patients_run<10, fraction color(gray) width(1) ///
	ylabel(0(.2)1) ///
	ytitle("Relative Frequency") xtitle("Index e") legend(off)
graph save "${RESULTS_FINAL}Hist_e_rhobar_1_1_0", replace
graph export "${RESULTS_FINAL}Hist_e_rhobar_1_1_0.png", as(png) replace

graph twoway scatter gittins_eta1 pair_patients_run if m_git_eta1>=0.95 & m_git_eta1<1, ///
	ytitle("Gittins Index") xtitle("Familiarity (e)") legend(off)
graph save "${RESULTS_FINAL}Gittins_scatter_m1_rhobar_1_1_0", replace
graph export "${RESULTS_FINAL}Gittins_scatter_m1_rhobar_1_1_0.png", as(png) replace

graph twoway scatter gittins_eta1 pair_patients_run if m_git_eta1>=0.90 & m_git_eta1<.95, ///
	ytitle("Gittins Index") xtitle("Familiarity (e)") legend(off)
graph save "${RESULTS_FINAL}Gittins_scatter_m2_rhobar_1_1_0", replace
graph export "${RESULTS_FINAL}Gittins_scatter_m2_rhobar_1_1_0.png", as(png) replace

graph twoway scatter gittins_eta1 pair_patients_run if m_git_eta1>=0.85 & m_git_eta1<.90, ///
	ytitle("Gittins Index") xtitle("Familiarity (e)") legend(off)
graph save "${RESULTS_FINAL}Gittins_scatter_m3_rhobar_1_1_0", replace
graph export "${RESULTS_FINAL}Gittins_scatter_m3_rhobar_1_1_0.png", as(png) replace


graph twoway scatter gittins_eta1 pair_patients_run if m_git_eta1>=0.95 & m_git_eta1<1 & pair_patients_run<5, ///
	ytitle("Gittins Index") xtitle("Familiarity (e)") legend(off)


graph twoway scatter gittins_eta1 m_git_eta1 if pair_patients_run==0, ///
	ytitle("Gittins Index") xtitle("m, for e=0") legend(off)
graph save "${RESULTS_FINAL}Gittins_scatter_bye0_rhobar_1_1_0", replace
graph export "${RESULTS_FINAL}Gittins_scatter_bye0_rhobar_1_1_0.png", as(png) replace


graph twoway scatter gittins_eta1 m_git_eta1 if pair_patients_run==1 ///
	|| scatter gittins_eta1 m_git_eta1 if pair_patients_run==2 ///
	|| scatter gittins_eta1 m_git_eta1 if pair_patients_run==3 ///
	|| scatter gittins_eta1 m_git_eta1 if pair_patients_run==4 ///
	|| scatter gittins_eta1 m_git_eta1 if pair_patients_run==5, ///
	ytitle("Gittins Index") xtitle("m") legend(order(1 "e=1" 2 "e=2" 3 "e=3" 4 "e=4" 5 "e=5"))
graph save "${RESULTS_FINAL}Gittins_scatter_bye15_rhobar_1_1_0", replace
graph export "${RESULTS_FINAL}Gittins_scatter_bye15_rhobar_1_1_0.png", as(png) replace
	
graph twoway scatter gittins_eta1 m_git_eta1 if pair_patients_run>=5 & pair_patients_run<10 ///
	|| scatter gittins_eta1 m_git_eta1 if pair_patients_run>=10 & pair_patients_run<15 ///
	|| scatter gittins_eta1 m_git_eta1 if pair_patients_run>=15 & pair_patients_run<20 ///
	|| scatter gittins_eta1 m_git_eta1 if pair_patients_run>=20 & pair_patients_run<25 ///
	|| scatter gittins_eta1 m_git_eta1 if pair_patients_run>=25 & pair_patients_run<30, ///
	ytitle("Gittins Index") xtitle("m") legend(order(1 "e=5-10" 2 "e=10-15" 3 "e=15-20" 4 "e=20-25" 5 "e=25-30"))
graph save "${RESULTS_FINAL}Gittins_scatter_bye30_rhobar_1_1_0", replace
graph export "${RESULTS_FINAL}Gittins_scatter_bye30_rhobar_1_1_0.png", as(png) replace
*/
	

** choice set summaries
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear

bys casevar hrr: gen choice_set_size=_N
sum choice_set_size

bys Specialist_ID hrr: gen spec_obs=_n
replace spec_obs=0 if spec_obs>1
bys hrr: egen spec_count=sum(spec_obs)
bys hrr: gen hrr_count=_n
sum spec_count if hrr_count==1

** temp choice data for patient counts, etc.
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
bys hrr: gen obs=_n
bys hrr: egen patients=sum(choice)
bys hrr Specialist_ID: gen spec_obs=_n
replace spec_obs=0 if spec_obs>1
bys hrr: egen tot_spec=sum(spec_obs)
bys hrr Practice_ID: gen pcp_obs=_n
replace pcp_obs=0 if pcp_obs>1
bys hrr: egen tot_pcp=sum(pcp_obs)
keep if obs==1
keep hrr patients tot_spec tot_pcp rho
save temp_choice_data, replace


******************************************************************
** Coefficient Estimates

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
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
drop if hrr==.
save base_coef, replace

** primary coefficients
use base_coef, clear
keep if coef_name=="belief_s" | coef_name=="o.belief"
rename coef_val coef_m
gen coef_m_se=coef_m*coef_se
replace coef_m=0 if coef_m==.
drop coef_name coef_se
save temp_m, replace

use base_coef, clear
keep if coef_name=="diff_dist"
rename coef_val coef_dist
rename coef_se coef_dist_se
drop coef_name
save temp_dist, replace

use temp_dist, clear
merge 1:1 hrr eta using temp_m, nogenerate
merge m:1 hrr using hrr_size, nogenerate keep(master match)
keep if converged==1
save "${RESULTS_FINAL}StructureForwardHRR_MainCoeff_`r_type'_rhobar.dta", replace
outsheet using "${RESULTS_FINAL}StructureForwardHRR_MainCoeff_`r_type'_rhobar.csv", comma replace

** familiarity coefficients
use base_coef, clear
keep if strpos(coef_name,"fmly_np_")==1
split coef_name, p("_") generate(fmly_level)
drop fmly_level1 fmly_level2 coef_name`i'
rename fmly_level3 fmly_level
destring fmly_level, replace force
keep if converged==1
save temp_fmly, replace

use temp_fmly, clear
drop if fmly_level==.
merge m:1 hrr using hrr_size, nogenerate keep(master match)
save "${RESULTS_FINAL}StructureForwardHRR_FmlyCoeff_`r_type'_rhobar.dta", replace
outsheet using "${RESULTS_FINAL}StructureForwardHRR_FmlyCoeff_`r_type'_rhobar.csv", comma replace

** specialist FEs
use base_coef, clear
**drop if strpos(coef_name,"fmly_np_")==1 | strpos(coef_name,"diff_dist")==1 | strpos(coef_name,"belief_s")==1 
**drop if strpos(coef_name,"converged")==1 | strpos(coef_name,"log_like")==1 | strpos(coef_name,"hrr")==1 | strpos(coef_name,"eta")==1
keep if substr(coef_name, -2, .)=="-a" | substr(coef_name, -2, .)=="-b"

split coef_name`i', p("-") generate(spec_id)
rename spec_id1 Specialist_ID
gen time_period=0 if spec_id2=="a"
replace time_period=1 if spec_id2=="b"
drop coef_name spec_id2
destring Specialist_ID, replace force
format Specialist_ID %12.0g
			
replace coef_se=. if coef_se==0
bys hrr eta: egen mean_se=mean(coef_se)
replace coef_se=mean_se if coef_se==.
drop mean_se
keep if converged==1
save temp_fe, replace

use temp_fe, clear			
merge m:1 hrr using hrr_size, nogenerate keep(master match)
save "${RESULTS_FINAL}StructureForwardHRR_Spec_FEs_`r_type'_rhobar.dta", replace
outsheet using "${RESULTS_FINAL}StructureForwardHRR_Spec_FEs_`r_type'_rhobar.csv", comma replace


******************************************************************
** Summarize coefficients across HRRs

use "${RESULTS_FINAL}StructureForwardHRR_MainCoeff_1_1_0_rhobar.dta", clear
save temp_coeff_rho, replace

use temp_coeff_rho, clear
merge m:1 hrr using temp_choice_data, nogenerate
save "${RESULTS_FINAL}StructureForward_SummaryHRR.dta", replace
outsheet using "${RESULTS_FINAL}StructureForward_SummaryHRR.csv", comma replace

collapse (p50) like=log_like (mean) tot_spec tot_pcp patients rho ///
	(mean) mean_alpha=coef_m mean_dist=coef_dist ///
	(mean) se_alpha=coef_m_se se_dist=coef_dist_se ///
	(p10) p10_alpha=coef_m p10_dist=coef_dist ///
	(p25) p25_alpha=coef_m p25_dist=coef_dist ///
	(p50) p50_alpha=coef_m p50_dist=coef_dist ///
	(p75) p75_alpha=coef_m p75_dist=coef_dist ///
	(p90) p90_alpha=coef_m p90_dist=coef_dist, by(eta)
save "${RESULTS_FINAL}StructureForward_Summary.dta", replace
outsheet using "${RESULTS_FINAL}StructureForward_Summary.csv", comma replace


** histograms of alpha (across HRRs) for given rho and eta
use "${RESULTS_FINAL}StructureForward_SummaryHRR.dta", replace
foreach eta in 1 5 {
	preserve
	keep if eta==`eta'
	sum coef_m, detail
	hist coef_m [weight=patients], fraction color(gray) width(0.3) ///
		ylabel(0(.1).7) ///
		ytitle("Relative Frequency") xtitle("Estimates for {&alpha} with {&eta}= `eta'") legend(off)
	graph save "${RESULTS_FINAL}alpha_fwd_eta`eta'_rhobar_1_1_0", replace
	graph export "${RESULTS_FINAL}alpha_fwd_eta`eta'_rhobar_1_1_0.png", as(png) replace		
	hist coef_dist [weight=patients], fraction color(gray) width(0.01) ///
		ylabel(0(.05).2) ///
		ytitle("Relative Frequency") xtitle("Estimates for diff. distance with {&eta}= `eta'") legend(off)
	graph save "${RESULTS_FINAL}dist_fwd_eta`eta'_rhobar_1_1_0", replace
	graph export "${RESULTS_FINAL}dist_fwd_eta`eta'_rhobar_1_1_0.png", as(png) replace		
	restore
}

** summary of rho (prior mean of specialist quality)
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
bys hrr: gen obs=_n
keep if obs==1
sum rho, detail

** summary of familiarity
insheet using "${RESULTS_FINAL}StructureMyopicHRR_FmlyCoeff_1_1_0_rhobar.csv", clear
bys eta fmly_level: sum coef_val coef_se


******************************************************************		
** IV estimates for congestion/capacity constraints
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
keep Specialist_ID tot_patients hrr
bys Specialist_ID hrr: gen obs=_n
keep if obs==1
drop obs
save mean_capacity_full, replace

use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
keep Specialist_ID tot_patients_time hrr Year
gen time_period=(Year>2015)
bys Specialist_ID hrr time_period: gen obs=_n
keep if obs==1
drop obs
rename tot_patients_time tot_patients
save mean_capacity, replace

** organize distance-only regression
use "${RESULTS_FINAL}Distance_Prediction_Full_1_1_0.dta", clear
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
save fe_distance, replace


** summarize first stage results (regression of total patients on predicted patients)
use "${RESULTS_FINAL}StructureForwardHRR_Spec_FEs_1_1_0_rhobar.dta", clear
merge m:1 hrr Specialist_ID time_period using fe_distance, nogenerate keep(match)
merge m:1 Specialist_ID time_period hrr using mean_capacity, nogenerate keep(match)
gen reg_weight=1/(coef_se^2)

foreach eta in 1 5 {
	preserve
	keep if eta==`eta'
	reg tot_patients yhat time_period [aweight=reg_weight], cluster(Specialist_ID)
	restore
}

_pctile coef_val [aweight=reg_weight], percentiles(1 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 99)

foreach eta in 1 5 {
	preserve
	keep if eta==`eta'
	matrix fs_results=J(457,5,.)
	forvalues i=1/457 {
		count if hrr==`i' & reg_weight!=.
		if r(N)>5 {
			reg tot_patients yhat time_period [aweight=reg_weight] if hrr==`i', cluster(Specialist_ID)
			mat fs_results[`i',1]=_b[yhat]
			mat var_mat=e(V)
			mat fs_results[`i',2]=sqrt(var_mat[1,1])
			mat fs_results[`i',3]=e(df_r)
			mat fs_results[`i',4]=`i'
			mat fs_results[`i',5]=`eta'
		}
	}

	clear
	svmat fs_results
	rename fs_results1 coef_est
	rename fs_results2 coef_se
	rename fs_results3 df
	rename fs_results4 hrr
	rename fs_results5 eta
	drop if hrr==.
	gen t_stat=coef_est/coef_se
	gen f_stat=t_stat^2
	sum f_stat, detail

	gen p_val=2*ttail(df, abs(t_stat))
	hist p_val

	merge 1:1 hrr using hrr_size, nogenerate keep(master match)
	hist coef_est [weight=patients], fraction color(gray) width(0.5) ///
		ylabel(0(.1).7) ///
		ytitle("Relative Frequency") xtitle("First-stage estimates for {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}StructureFWD_2SLSFirstStage_eta`eta'_rhobar_1_1_0", replace
	graph export "${RESULTS_FINAL}StructureFWD_2SLSFirstStage_eta`eta'_rhobar_1_1_0.png", as(png) replace
	restore
}

** summarize IV results (regression of FE on total patients, with predicted patients as instrument)
use "${RESULTS_FINAL}StructureForwardHRR_Spec_FEs_1_1_0_rhobar.dta", clear
merge m:1 hrr Specialist_ID time_period using fe_distance, nogenerate keep(match)
merge m:1 Specialist_ID time_period hrr using mean_capacity, nogenerate keep(match)
gen reg_weight=1/(coef_se^2)

qui sum coef_val, detail
keep if inrange(coef_val, r(p1), r(p99))
twoway scatter coef_val yhat [aweight=reg_weight]
gen big_coef=(abs(coef_val)>6)

** overall effect (all markets combined)	
foreach eta in 1 5 {
	preserve
	keep if eta==`eta' & converged==1
	reg coef_val yhat time_period big_coef [aweight=reg_weight], robust
	ivreg2 coef_val time_period big_coef (tot_patients=yhat) [aweight=reg_weight], robust
	est store iv_`eta'
	restore
}

** separately by market
foreach eta in 1 5 {
	preserve
	keep if eta==`eta'
	matrix tsls_results=J(457,6,.)
	forvalues i=1/457 {
		count if hrr==`i' & reg_weight!=. & converged==1
		if r(N)>5 {
			ivreg coef_val time_period big_coef (tot_patients=yhat) [aweight=reg_weight] if hrr==`i', robust
			mat tsls_results[`i',1]=_b[tot_patients]
			mat var_mat=e(V)
			mat tsls_results[`i',2]=sqrt(var_mat[1,1])
			mat tsls_results[`i',3]=e(df_r)
			mat tsls_results[`i',4]=`i'
			mat tsls_results[`i',5]=`eta'
		}
	}

	clear
	svmat tsls_results
	rename tsls_results1 coef_est
	rename tsls_results2 coef_se
	rename tsls_results3 df
	rename tsls_results4 hrr
	rename tsls_results5 eta
	drop if hrr==.
	gen t_stat=coef_est/coef_se
	gen p_val=2*ttail(df, abs(t_stat))
	** hist p_val
	save temp_2sls_eta`eta'_rhobar, replace
		
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)
	hist coef_est if coef_est>-0.1 [weight=patients], fraction color(gray) width(0.0005) ///
		ylabel(0(.05).2) ///
		ytitle("Relative Frequency") xtitle("2SLS estimates for {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}StructureFWD_2SLSEstimate_eta`eta'_rhobar_1_1_0", replace
	graph export "${RESULTS_FINAL}StructureFWD_2SLSEstimate_eta`eta'_rhobar_1_1_0.png", as(png) replace
	restore
}


	
******************************************************************
** Partial effects and counterfactual calculations

foreach eta in 1 5 {
	use "${RESULTS_FINAL}StructureForwardHRR_Spec_FEs_1_1_0_rhobar.dta", clear
	keep if eta==`eta'
	save spec_fe, replace
		
	use "${RESULTS_FINAL}StructureForwardHRR_MainCoeff_1_1_0_rhobar.dta", clear
	keep if eta==`eta'
	save coeff_notfe, replace
	
	use "${RESULTS_FINAL}StructureForwardHRR_FmlyCoeff_1_1_0_rhobar.dta", clear
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
**	drop if fmly_level==0
			
	est restore iv_`eta'
	gen iv_pat=e(b)[1,1]
	gen iv_time=e(b)[1,2]
	gen iv_shift=e(b)[1,3]
		
	* loop over HRRs
	egen hrr_group=group(hrr)
	qui sum hrr_group
	local hrr_count=r(max)
		
	forvalues h=1/`hrr_count' {
		preserve
		keep if hrr_group==`h'
		
		** merge datasets
		merge m:1 hrr Specialist_ID time_period using spec_fe, keep(match) nogenerate
		merge m:1 hrr using coeff_notfe, keep(match) nogenerate
		merge m:1 hrr fmly_level using fmly_effect, keep(master match) nogenerate
		merge m:1 hrr Specialist_ID time_period using mean_capacity, keep(match) nogenerate
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
			gen cs_base=log(sum_exp_uij)
			drop m exp_uij sum_exp_uij
			
			** calculate aggregate effect of familiarity
			gen exp_uij_0=exp(coef_dist*diff_dist + coef_m*m_orig + coef_val)
			bys casevar: egen sum_exp_uij_0=sum(exp_uij_0)
			gen pr_j_0=exp_uij_0/sum_exp_uij_0
			gen cs_fam=log(sum_exp_uij_0)
			drop exp_uij_0 sum_exp_uij_0
			gen pfx_fam=pr_j-pr_j_0
			
			** calculate aggregate effect of patient outcomes
			gen exp_uij_0=exp(coef_dist*diff_dist + fmly_agg + coef_val)
			bys casevar: egen sum_exp_uij_0=sum(exp_uij_0)
			gen pr_j_m0=exp_uij_0/sum_exp_uij_0
			gen cs_m0=log(sum_exp_uij_0)
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
			gen pfx_m=pr_j-pr_j_alt
				
			** simulate counterfactual - full quality information
			gen m=spec_qual
			gen fmly_agg_orig=fmly_agg

			gen pred_equil=pair_patients_run
			converge_dyn pred_equil
			rename pij pij_full
			rename no_equil no_equil_full
			replace fmly_agg=fmly_agg_orig
			drop m pred_iter_new pred_iter_old exp_uij sum_exp_uij pred_equil fmly_agg_orig

			** simulate counterfactual - available quality information
			gen m=spec_qual_run
			gen pred_equil=0
			quietly converge pred_equil
			rename pij pij_current
			rename no_equil no_equil_current
			drop m pred_iter_new pred_iter_old exp_uij sum_exp_uij pred_equil		
			
			** simulate counterfactual - full quality information and no familiarity
			gen m=spec_qual
			gen pred_equil=0
			replace fmly_agg=0
			quietly converge pred_equil
			rename pij pij_full_fam
			rename no_equil no_equil_full_fam
			drop m pred_iter_new pred_iter_old exp_uij sum_exp_uij pred_equil
			
			keep Practice_ID Specialist_ID casevar choice hrr pr_j pr_j_0 pr_j_m0 pr_j_alt pij_full pij_current pij_full_fam mfx_m pfx_m pfx_fam pfx_m0 m_orig spec_qual spec_qual_run ///
				patients tot_patients pair_success_run pair_patients_run spec_patients_run spec_failures_run ///
				pcp_patients_run pcp_failures_run common_ref hrr cs_base cs_fam cs_m0 no_equil* coef_m
			save cf_hrr`h'_eta`eta', replace
		}
		restore
	}
}

foreach eta in 1 5 {
	forvalues i=1/457 {
		capture confirm file "cf_hrr`i'_eta`eta'.dta"
		if _rc==0 {
			** marginal and partial effects for top-choice specialist
			use cf_hrr`i'_eta`eta', clear			
			keep if common_ref==1
			collapse (first) hrr (sum) cs_base cs_fam cs_m0 ///
				(p10) mfx_10=mfx_m pfx_10=pfx_m pfx_fam_10=pfx_fam pfx_m0_10=pfx_m0 ///
				(p25) mfx_25=mfx_m pfx_25=pfx_m pfx_fam_25=pfx_fam pfx_m0_25=pfx_m0 ///
				(p50) mfx_50=mfx_m pfx_50=pfx_m pfx_fam_50=pfx_fam pfx_m0_50=pfx_m0 ///
				(p75) mfx_75=mfx_m pfx_75=pfx_m pfx_fam_75=pfx_fam pfx_m0_75=pfx_m0 ///
				(p90) mfx_90=mfx_m pfx_90=pfx_m pfx_fam_90=pfx_fam pfx_m0_90=pfx_m0 ///
				(mean) mfx_mean=mfx_m pfx_mean=pfx_m pr_mean=pr_j pr_obs=choice pfx_fam_mean=pfx_fam pfx_m0_mean=pfx_m0 ///
					cs_base_mean=cs_base cs_fam_mean=cs_fam cs_m0_mean=cs_m0 ///
				(sd) mfx_sd=mfx_m pfx_sd=pfx_m pfx_fam_sd=pfx_fam pfx_m0_sd=pfx_m0 (count) mfx_count=mfx_m pfx_count=pfx_m
			gen hrr_group=`i'
			gen eta=`eta'
			save fx_top_hrr`i'_eta`eta', replace
			
			** marginal and partial effects for any non-zero specialist
			use cf_hrr`i'_eta`eta', clear
			keep if pair_patients_run>0 & pair_patients_run!=.
			collapse (first) hrr (sum) cs_base cs_fam cs_m0 ///
				(p10) mfx_10=mfx_m pfx_10=pfx_m pfx_fam_10=pfx_fam pfx_m0_10=pfx_m0 ///
				(p25) mfx_25=mfx_m pfx_25=pfx_m pfx_fam_25=pfx_fam pfx_m0_25=pfx_m0 ///
				(p50) mfx_50=mfx_m pfx_50=pfx_m pfx_fam_50=pfx_fam pfx_m0_50=pfx_m0 ///
				(p75) mfx_75=mfx_m pfx_75=pfx_m pfx_fam_75=pfx_fam pfx_m0_75=pfx_m0 ///
				(p90) mfx_90=mfx_m pfx_90=pfx_m pfx_fam_90=pfx_fam pfx_m0_90=pfx_m0 ///
				(mean) mfx_mean=mfx_m pfx_mean=pfx_m pr_mean=pr_j pr_obs=choice pfx_fam_mean=pfx_fam pfx_m0_mean=pfx_m0 ///
					cs_base_mean=cs_base cs_fam_mean=cs_fam cs_m0_mean=cs_m0 ///				
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
			**gen pij_diff_full=(pij_full-pr_j)/pr_j
			gen pij_diff_full=abs(pij_full-pr_j)/2
			gen pij_diff_current=abs(pij_current-pr_j)/2
			gen pij_diff_fullfam=abs(pij_full_fam-pr_j)/2

			** patient/referral level summary
			preserve
			collapse (first) hrr no_equil_* (sum) success_prob0 success_prob1_full success_prob1_current success_prob1_fullfam ///
				pij_diff_full pij_diff_current pij_diff_fullfam pr_j, by(casevar)
			gen hrr_group=`i'
			gen eta=`eta'
			save cf_sum_hrr`i'_eta`eta', replace
			restore
			
			** specialist level summary
			collapse (sum) pred_patients0=pr_j pred_patients_full=pij_full no_equil_* ///
				pred_patients_current=pij_current pred_patients_fullfam=pij_full_fam, by(Specialist_ID hrr)
			gen hrr_group=`i'
			gen eta=`eta'
			save cf_spec_hrr`i'_eta`eta', replace
			
		}
	}
}



foreach eta in 1 5 {
	local step=0
	foreach x of newlist fx_top fx_any cf_sum cf_spec {
		forvalues i=1/457 {
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
	save "${RESULTS_FINAL}MarginalEffects_FWD`eta'.dta", replace
	erase fx_any`eta'.dta

	use cf_sum`eta', clear
	save "${RESULTS_FINAL}CounterFactuals_FWD`eta'.dta", replace
	erase cf_sum`eta'.dta

	use cf_spec`eta', clear
	save "${RESULTS_FINAL}CounterFactualsSpec_FWD`eta'.dta", replace
	erase cf_spec`eta'.dta

}

foreach eta in 1 5 {
	use "${RESULTS_FINAL}MarginalEffects_FWD`eta'.dta", clear
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)
	sum mfx_mean mfx_10 mfx_25 mfx_50 mfx_75 mfx_90 mfx_sd [aweight=mfx_count]
	sum pfx_mean pfx_10 pfx_25 pfx_50 pfx_75 pfx_90 pfx_sd [aweight=patients]

	gen rel_mean=pfx_mean/pr_mean
	replace pfx_mean=0.05 if pfx_mean>0.05
	hist pfx_mean [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1)0.5) xscale(range(0 0.05)) xlabel(0(0.01)0.05 0.05 ">0.05", add) //////
		ytitle("Relative Frequency") xtitle("Mean Partial Effect of One Failure, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Partial_Effect_Failure_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Partial_Effect_Failure_FWD_eta`eta'.png", as(png) replace
		
	gen rel_75=pfx_75/pr_mean
	replace pfx_75=0.05 if pfx_75>0.05
	hist pfx_75 [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1)0.5) xscale(range(0 0.05)) xlabel(0(0.01)0.05 0.05 ">0.05", add) //////
		ytitle("Relative Frequency") xtitle("Mean 75th% Partial Effect of One Failure, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Ptile75_Partial_Effect_Failure_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}Ptile75_Partial_Effect_Failure_FWD_eta`eta'.png", as(png) replace
	
	gen rel_cs_m=(cs_base-cs_m0)/cs_m0
	hist rel_cs_m if cs_m0>0 [weight=patients], fraction color(gray) width(0.05) ///
		ylabel(0(.1).5) ///
		ytitle("Relative Frequency") xtitle("Relative Gain in Consumer Surplus from Learning, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}CS_Learning_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}CS_Learning_FWD_eta`eta'.png", as(png) replace

	gen rel_cs_fam=(cs_base-cs_fam)/cs_fam
	hist rel_cs_fam if cs_fam>0 [weight=patients], fraction color(gray) width(0.1) ///
		ylabel(0(.05).11) ///
		ytitle("Relative Frequency") xtitle("Relative Gain in Consumer Surplus from Familiarity, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}CS_Familiarity_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}CS_Familiarity_FWD_eta`eta'.png", as(png) replace
}

** Summarize counterfactuals: effects on reallocation and ex ante patient health

foreach eta in 1 5 {
	use "${RESULTS_FINAL}CounterFactuals_FWD`eta'.dta", clear
	gen success_diff_full=success_prob1_full-success_prob0
	gen success_diff_current=success_prob1_current-success_prob0
	gen success_diff_fullfam=success_prob1_fullfam-success_prob0	
	
	collapse (mean) success_prob0 success_diff_full success_diff_current success_diff_fullfam pij_diff_full pij_diff_current pij_diff_fullfam, by(hrr)
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)

	sum pij_diff_full pij_diff_current pij_diff_fullfam success_diff_full success_diff_current success_diff_fullfam [aweight=patients], detail
	
	hist pij_diff_full [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Full Info., {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Reallocation_Full_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}Reallocation_Full_FWD_eta`eta'.png", as(png) replace

	hist pij_diff_current [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Current Info., {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Reallocation_Current_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}Reallocation_Current_FWD_eta`eta'.png", as(png) replace
	
	hist pij_diff_fullfam [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Full Info and No Familiarity, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Reallocation_FullFam_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}Reallocation_FullFam_FWD_eta`eta'.png", as(png) replace
	
	replace success_diff_full=-0.01 if success_diff_full<-0.01
	replace success_diff_full=0.01 if success_diff_full>0.01
	hist success_diff_full [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Full Info, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_Effect_Full_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_Effect_Full_FWD_eta`eta'.png", as(png) replace

	replace success_diff_current=-0.01 if success_diff_current<-0.01
	replace success_diff_current=0.01 if success_diff_current>0.01
	hist success_diff_current [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Current Info, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_Effect_Current_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_Effect_Current_FWD_eta`eta'.png", as(png) replace
	
	replace success_diff_fullfam=-0.01 if success_diff_fullfam<-0.01
	replace success_diff_fullfam=0.01 if success_diff_fullfam>0.01
	hist success_diff_fullfam [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Full Info and No Familiarity, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_Effect_FullFam_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_Effect_FullFam_FWD_eta`eta'.png", as(png) replace
	
}

** examine changes in specialist volume
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
bys Specialist_ID hrr: gen obs=_n
bys Specialist_ID hrr: egen spec_patients=sum(choice)
keep if obs==1
keep Specialist_ID hrr spec_qual spec_patients
save spec_temp, replace

foreach eta in 1 5 {

	use "${RESULTS_FINAL}CounterFactualsSpec_FWD`eta'.dta", clear
	merge 1:1 hrr Specialist_ID hrr using spec_temp, keep(match) nogenerate
	
	foreach x of newlist full fullfam current {
		gen diff_`x'=pred_patients_`x'-pred_patients0
		gen reldiff_`x'=diff_`x'/pred_patients0
	}
	reg reldiff_full spec_qual, robust
	reg reldiff_fullfam spec_qual, robust
	
	hist reldiff_full if reldiff_full>-1 & reldiff_full<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChange_Full_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChange_Full_FWD_eta`eta'.png", as(png) replace

	hist reldiff_fullfam if reldiff_fullfam>-1 & reldiff_fullfam<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChange_FullFam_FWD_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChange_FullFam_FWD_eta`eta'.png", as(png) replace

}


** look at distribution of alpha relative to familiarity
** stack mean and 75th percentile in single graph
** scatterplot of referal probability change and specialist quality

log close

