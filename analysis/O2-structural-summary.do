set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Structural_${MODEL_TYPE}_`logdate'.log", replace

******************************************************************
**	Title:		Summarize Structural Results (unified Myopic/FWD)
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	2/20/2026
**	Notes:		Parameterized by globals MODEL_TYPE and GRAPHS_ONLY
**			Replaces O2-structural-myopic-summary.do and
**			O3-structural-fwdlooking-summary.do
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


** choice set summaries
use "${DATA_FINAL}ChoiceEstData_Summary.dta", replace

bys casevar hrr: gen choice_set_size=_N
sum choice_set_size

bys Specialist_ID hrr: gen spec_obs=_n
replace spec_obs=0 if spec_obs>1
bys hrr: egen spec_count=sum(spec_obs)
bys hrr: gen hrr_count=_n
sum spec_count if hrr_count==1

** temp choice data for patient counts, etc
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


if ${GRAPHS_ONLY}==0 {
******************************************************************
** Section A: Coefficient Estimates

use "${RESULTS_FINAL}`coef_prefix'HRR_CoefFull_`r_type'_rhobar.dta", clear

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
keep if coef_name=="belief_s" | coef_name=="o.belief_s"
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
save "${RESULTS_FINAL}`coef_prefix'HRR_MainCoeff_`r_type'_rhobar.dta", replace
outsheet using "${RESULTS_FINAL}`coef_prefix'HRR_MainCoeff_`r_type'_rhobar.csv", comma replace


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
save "${RESULTS_FINAL}`coef_prefix'HRR_FmlyCoeff_`r_type'_rhobar.dta", replace
outsheet using "${RESULTS_FINAL}`coef_prefix'HRR_FmlyCoeff_`r_type'_rhobar.csv", comma replace


** specialist FEs
use base_coef, clear
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
save "${RESULTS_FINAL}`coef_prefix'HRR_Spec_FEs_`r_type'_rhobar.dta", replace
outsheet using "${RESULTS_FINAL}`coef_prefix'HRR_Spec_FEs_`r_type'_rhobar.csv", comma replace


******************************************************************
** Assess convergence/available estimates
use base_coef, clear
keep if converged==1
bys hrr eta: gen hrr_eta_obs=_n
replace hrr_eta_obs=0 if hrr_eta_obs>1
bys eta: egen hrr_obs=sum(hrr_eta_obs)
bys eta: sum hrr_obs
keep if hrr_eta_obs==1
keep hrr eta
save est_base, replace

use temp_m, clear
keep if converged==1
gen m_nonmissing=(coef_m!=.)
collapse (count) m_count=coef_m (sum) m_nonmissing, by(hrr eta)
save est_m, replace

use temp_dist, clear
keep if converged==1
gen dist_nonmissing=(coef_dist!=.)
collapse (count) dist_count=coef_dist (sum) dist_nonmissing, by(hrr eta)
save est_dist, replace

use temp_fmly, clear
keep if converged==1
gen fmly_nonmissing=(coef_val!=.)
collapse (count) fmly_count=coef_val (sum) fmly_nonmissing, by(hrr eta)
save est_fmly, replace

use temp_fe, clear
keep if converged==1
gen fe_nonmissing=(coef_val!=.)
collapse (count) fe_count=coef_val (sum) fe_nonmissing, by(hrr eta)
save est_fe, replace

use est_base, clear
merge 1:1 hrr eta using est_m, nogenerate keep(master match)
merge 1:1 hrr eta using est_dist, nogenerate keep(master match)
merge 1:1 hrr eta using est_fmly, nogenerate keep(master match)
merge 1:1 hrr eta using est_fe, nogenerate keep(master match)

foreach x of varlist m_count m_nonmissing dist_count dist_nonmissing fmly_count fmly_nonmissing fe_count fe_nonmissing {
	replace `x'=0 if `x'==.
}
total m_count m_nonmissing if eta==1
total dist_count dist_nonmissing if eta==1
keep if m_count==0

preserve
keep if eta==1
keep hrr
save missing_m_eta1, replace

restore
keep if eta==5
keep hrr
save missing_m_eta5, replace

use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
bys hrr: egen hrr_patients=sum(choice)
bys hrr Specialist_ID: egen spec_hrr_patients=sum(choice)
gen mkt_share=spec_hrr_patients/hrr_patients
gen mkt_share2=mkt_share^2
bys hrr Specialist_ID: gen spec_obs=_n
replace mkt_share2=0 if spec_obs>1
replace spec_obs=0 if spec_obs>1
bys hrr Practice_ID: gen pcp_obs=_n
replace pcp_obs=0 if pcp_obs>1
collapse (sd) m_git_eta1 m_git_eta5 diff_dist fmly (mean) mean_dist=diff_dist mean_fmly=fmly (sum) choice spec_hhi=mkt_share2 spec_obs pcp_obs, by(hrr)
save temp_assess, replace

use temp_assess, clear
merge 1:1 hrr using missing_m_eta1, keep(master match) generate(eta1)
gen missing=(eta1==3)
reg missing m_git_eta1 diff_dist fmly mean_dist mean_fmly choice spec_hhi spec_obs pcp_obs

use temp_assess, clear
merge 1:1 hrr using missing_m_eta5, keep(master match) generate(eta5)
gen missing=(eta5==3)
reg missing m_git_eta5 diff_dist fmly mean_dist mean_fmly choice spec_hhi spec_obs pcp_obs

use temp_choice_data, clear
merge 1:1 hrr using missing_m_eta1, keep(master match) generate(eta1)
gen missing=(eta1==3)
qui sum patients
local all_patients=r(sum)
qui sum patients if missing==1
local lost_patients=r(sum)
qui sum missing
local mean_missing=r(mean)
display "lost patients, `lost_patients', out of `all_patients'"
display "lost share is `=string(`lost_patients'/`all_patients', "%6.2f")' of patients and `mean_missing' of markets "


******************************************************************
** Compare Specialist FEs over time periods
use "${RESULTS_FINAL}`coef_prefix'HRR_Spec_FEs_`r_type'_rhobar.dta", replace
preserve
keep if time_period==0
keep coef_val coef_se hrr eta Specialist_ID
foreach x of varlist coef_val coef_se {
	rename `x' `x'_0
}
save fe_t0, replace
restore

keep if time_period==1
keep coef_val coef_se hrr eta Specialist_ID
foreach x of varlist coef_val coef_se {
	rename `x' `x'_1
}
save fe_t1, replace

use fe_t0, clear
merge 1:1 Specialist_ID hrr eta using fe_t1, nogenerate
twoway scatter coef_val_0 coef_val_1 if eta==1 & abs(coef_val_0)<4 & abs(coef_val_1)<4, ///
	ytitle("Period One") xtitle("Period Two") color(gray)
graph save "${RESULTS_FINAL}FE_Compare_`model'_eta1_rhobar_`r_type'", replace
graph export "${RESULTS_FINAL}FE_Compare_`model'_eta1_rhobar_`r_type'.png", as(png) replace

twoway scatter coef_val_0 coef_val_1 if eta==5 & abs(coef_val_0)<4 & abs(coef_val_1)<4, ///
	ytitle("Period One") xtitle("Period Two") color(gray)
graph save "${RESULTS_FINAL}FE_Compare_`model'_eta5_rhobar_`r_type'", replace
graph export "${RESULTS_FINAL}FE_Compare_`model'_eta5_rhobar_`r_type'.png", as(png) replace


******************************************************************
** Summarize coefficients across HRRs

use "${RESULTS_FINAL}`coef_prefix'HRR_MainCoeff_`r_type'_rhobar.dta", clear
save temp_coeff_rho, replace

use temp_coeff_rho, clear
merge m:1 hrr using temp_choice_data, nogenerate
save "${RESULTS_FINAL}`coef_prefix'_SummaryHRR.dta", replace
outsheet using "${RESULTS_FINAL}`coef_prefix'_SummaryHRR.csv", comma replace

collapse (p50) like=log_like (mean) tot_spec tot_pcp patients rho ///
	(mean) mean_alpha=coef_m mean_dist=coef_dist ///
	(mean) se_alpha=coef_m_se se_dist=coef_dist_se ///
	(p10) p10_alpha=coef_m p10_dist=coef_dist ///
	(p25) p25_alpha=coef_m p25_dist=coef_dist ///
	(p50) p50_alpha=coef_m p50_dist=coef_dist ///
	(p75) p75_alpha=coef_m p75_dist=coef_dist ///
	(p90) p90_alpha=coef_m p90_dist=coef_dist, by(eta)
save "${RESULTS_FINAL}`coef_prefix'_Summary.dta", replace
outsheet using "${RESULTS_FINAL}`coef_prefix'_Summary.csv", comma replace


** histograms of alpha (across HRRs) for given rho and eta
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
save fe_distance, replace


** summarize first stage results (regression of total patients on predicted patients)
use "${RESULTS_FINAL}`coef_prefix'HRR_Spec_FEs_`r_type'_rhobar.dta", clear
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

** dynamic HRR count for aggregation loops
local hrr_max = 0
forvalues i=1/500 {
	qui count if hrr==`i'
	if r(N)>0 local hrr_max = `i'
}

foreach eta in 1 5 {
	preserve
	keep if eta==`eta'
	matrix fs_results=J(`hrr_max',5,.)
	forvalues i=1/`hrr_max' {
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
	graph save "${RESULTS_FINAL}`coef_prefix'_2SLSFirstStage_eta`eta'_rhobar_`r_type'", replace
	graph export "${RESULTS_FINAL}`coef_prefix'_2SLSFirstStage_eta`eta'_rhobar_`r_type'.png", as(png) replace
	restore
}

** summarize IV results (regression of FE on total patients, with predicted patients as instrument)
use "${RESULTS_FINAL}`coef_prefix'HRR_Spec_FEs_`r_type'_rhobar.dta", clear
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
	matrix tsls_results=J(`hrr_max',6,.)
	forvalues i=1/`hrr_max' {
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
	graph save "${RESULTS_FINAL}`coef_prefix'_2SLSEstimate_eta`eta'_rhobar_`r_type'", replace
	graph export "${RESULTS_FINAL}`coef_prefix'_2SLSEstimate_eta`eta'_rhobar_`r_type'.png", as(png) replace
	restore
}

******************************************************************
** Summary of coefficients overall
tempfile table_tex
postfile table_tex str200 line using "`table_tex'", replace
post table_tex ("")
post table_tex ("& & & \multicolumn{5}{c}{Percentile} \\")
post table_tex ("\cline{4-8}")
post table_tex ("Parameter & Mean & (SD/SE) & 10th & 25th & 50th & 75th & 90th \\")
post table_tex ("\hline")

** first alpha (index coefficient)
post table_tex ("")
post table_tex ("\multicolumn{8}{l}{\$\alpha\$ (utility weight on outcome)} \\")

use "${RESULTS_FINAL}`coef_prefix'_Summary.dta", clear
foreach eta in 1 5 {
	preserve
	keep if eta == `eta'
	local ma = mean_alpha[1]
	local sa = se_alpha[1]

	post table_tex ("\ \ (\$\eta=`eta'\$) & `=string(`ma', "%9.4f")' & (`=string(`sa', "%9.4f")') & `=string(p10_alpha[1], "%9.4f")'  & `=string(p25_alpha[1], "%9.4f")'  & `=string(p50_alpha[1], "%9.4f")'  & `=string(p75_alpha[1], "%9.4f")'  & `=string(p90_alpha[1], "%9.4f")' \\")
	restore
}

** then pi (distance coefficient)
post table_tex ("")
post table_tex ("\multicolumn{8}{l}{\$\pi\$ (utility weight on outcome)} \\")

use "${RESULTS_FINAL}`coef_prefix'_Summary.dta", clear
foreach eta in 1 5 {
	preserve
	keep if eta == `eta'
	local mp = mean_dist[1]
	local sp = se_dist[1]

	post table_tex ("\ \ (\$\eta=`eta'\$) & `=string(`mp', "%9.4f")' & (`=string(`sp', "%9.4f")') & `=string(p10_dist[1], "%9.4f")'  & `=string(p25_dist[1], "%9.4f")'  & `=string(p50_dist[1], "%9.4f")'  & `=string(p75_dist[1], "%9.4f")'  & `=string(p90_dist[1], "%9.4f")' \\")
	restore
}


** next rho
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
bys hrr: gen obs=_n
keep if obs==1
qui sum rho, detail

post table_tex ("")
post table_tex ("\multicolumn{8}{l}{\$\rho\$ (prior mean)} \\")
post table_tex ("\ \ (all \$\eta\$) & `=string(r(mean), "%9.4f")' & (`=string(r(sd), "%9.4f")') & `=string(r(p10), "%9.4f")'  & `=string(r(p25), "%9.4f")'  & `=string(r(p50), "%9.4f")'  & `=string(r(p75), "%9.4f")'  & `=string(r(p90), "%9.4f")' \\")

** congestion/capacity
post table_tex ("")
post table_tex ("\multicolumn{8}{l}{\$\gamma\$ (congestion effect, per 100 patients)} \\")

foreach eta in 1 5 {
	est restore iv_`eta'
	matrix b = e(b)
	matrix V = e(V)
	scalar g = b[1, "tot_patients"]*100
	scalar se = sqrt(V["tot_patients", "tot_patients"])*100
	post table_tex ("\ \ (\$\eta=`eta'\$) & `=string(g, "%9.4f")' & (`=string(se, "%9.4f")') \\")
}

** familiarity
post table_tex ("")
post table_tex ("\multicolumn{2}{l}{\$\kappa_{b}\$ (familiarity)} & \multicolumn{5}{c}{Range of \$e_{ijt}\$} \\")
post table_tex ("\cline{2-8}")
post table_tex ("\ \  & 1  & 2  & 3  & 4  & 5  & [6,7]  & [8,10] \\")
post table_tex ("\cline{2-8}")

import delimited "${RESULTS_FINAL}`coef_prefix'HRR_FmlyCoeff_`r_type'_rhobar.csv", clear
gen str8 bin = cond(inrange(fmly_level,6,7), "[6,7]", cond(inrange(fmly_level,8,10), "[8,10]", string(fmly_level)))
keep if inlist(bin, "1","2","3","4","5","[6,7]","[8,10]")

collapse (mean) coef_val coef_se, by(eta bin)
levelsof bin, local(bins)

foreach eta in 1 5 {
	local row1 "\ \ (\$\eta=`eta'\$)"
	local row2 "                    "
	foreach b in 1 2 3 4 5 "[6,7]" "[8,10]" {
		su coef_val if eta==`eta' & bin=="`b'", meanonly
		local row1 "`row1' & `=string(r(mean), "%9.4f")'"
		su coef_se if eta==`eta' & bin=="`b'", meanonly
		local row2 "`row2' & (`=string(r(mean), "%9.4f")')"
	}
	post table_tex ("`row1' \\")
	post table_tex ("`row2' \\")
}
post table_tex ("")
post table_tex ("\hline")
postclose table_tex

use "`table_tex'", clear
outfile line using "${RESULTS_FINAL}`model'Coefficient_Table.tex", noquote replace


******************************************************************
** Section B: Partial effects and counterfactual calculations

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

		** merge coefficients
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
			gen pred_equil=0
			replace fmly_agg=0
			quietly converge pred_equil
			rename pij pij_full_fam
			rename no_equil no_equil_full_fam
			drop m pred_iter_new pred_iter_old exp_uij sum_exp_uij pred_equil

			keep Practice_ID Specialist_ID casevar choice hrr pr_j pr_j_0 pr_j_m0 pr_j_alt pij_full pij_current pij_full_fam mfx_m pfx_m pfx_fam pfx_m0 m_orig spec_qual spec_qual_run ///
				patients tot_patients pair_success_run pair_patients_run spec_patients_run spec_failures_run ///
				pcp_patients_run pcp_failures_run common_ref hrr no_equil* coef_m
			save cf_hrr`h'_eta`eta', replace
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
	erase cf_spec`eta'.dta
}

} /* end if GRAPHS_ONLY==0 */


******************************************************************
** Section C: Paper figures (always runs)

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

** Summarize counterfactuals: effects on reallocation and ex ante patient health

foreach eta in 1 5 {
	use "${RESULTS_FINAL}CounterFactuals_`model'`eta'.dta", clear
	gen success_diff_full=success_prob1_full-success_prob0
	gen success_diff_current=success_prob1_current-success_prob0
	gen success_diff_fullfam=success_prob1_fullfam-success_prob0

	collapse (mean) success_prob0 success_diff_full success_diff_current success_diff_fullfam pij_diff_full pij_diff_current pij_diff_fullfam, by(hrr)
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)

	sum pij_diff_full pij_diff_current pij_diff_fullfam success_diff_full success_diff_current success_diff_fullfam [aweight=patients], detail

	hist pij_diff_full [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Full Info., {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Reallocation_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Reallocation_Full_`model'_eta`eta'.png", as(png) replace

	hist pij_diff_current [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Current Info., {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Reallocation_Current_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Reallocation_Current_`model'_eta`eta'.png", as(png) replace

	hist pij_diff_fullfam [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Full Info and No Familiarity, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Reallocation_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Reallocation_FullFam_`model'_eta`eta'.png", as(png) replace

	replace success_diff_full=-0.01 if success_diff_full<-0.01
	replace success_diff_full=0.01 if success_diff_full>0.01
	hist success_diff_full [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Full Info, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FX_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FX_Full_`model'_eta`eta'.png", as(png) replace

	replace success_diff_current=-0.01 if success_diff_current<-0.01
	replace success_diff_current=0.01 if success_diff_current>0.01
	hist success_diff_current [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Current Info, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FX_Current_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FX_Current_`model'_eta`eta'.png", as(png) replace

	replace success_diff_fullfam=-0.01 if success_diff_fullfam<-0.01
	replace success_diff_fullfam=0.01 if success_diff_fullfam>0.01
	hist success_diff_fullfam [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Full Info and No Familiarity, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FX_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FX_FullFam_`model'_eta`eta'.png", as(png) replace

}


******************************************************************
** Section D: Diagnostic figures (NC variants, volume changes)

** Summarize counterfactuals dropping non-converging markets

foreach eta in 1 5 {
	use "${RESULTS_FINAL}CounterFactuals_`model'`eta'.dta", clear
	gen success_diff_full=success_prob1_full-success_prob0
	gen success_diff_current=success_prob1_current-success_prob0
	gen success_diff_fullfam=success_prob1_fullfam-success_prob0

	drop if no_equil_full==1
	collapse (mean) success_prob0 success_diff_full success_diff_current success_diff_fullfam pij_diff_full pij_diff_current pij_diff_fullfam, by(hrr)
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)

	sum pij_diff_full pij_diff_current pij_diff_fullfam success_diff_full success_diff_current success_diff_fullfam [aweight=patients], detail

	hist pij_diff_full [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Full Info., {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}ReallocationNC_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}ReallocationNC_Full_`model'_eta`eta'.png", as(png) replace

	hist pij_diff_current [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Current Info., {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}ReallocationNC_Current_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}ReallocationNC_Current_`model'_eta`eta'.png", as(png) replace

	hist pij_diff_fullfam [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Full Info and No Familiarity, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}ReallocationNC_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}ReallocationNC_FullFam_`model'_eta`eta'.png", as(png) replace

	replace success_diff_full=-0.01 if success_diff_full<-0.01
	replace success_diff_full=0.01 if success_diff_full>0.01
	hist success_diff_full [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Full Info, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FXNC_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FXNC_Full_`model'_eta`eta'.png", as(png) replace

	replace success_diff_current=-0.01 if success_diff_current<-0.01
	replace success_diff_current=0.01 if success_diff_current>0.01
	hist success_diff_current [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Current Info, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FXNC_Current_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FXNC_Current_`model'_eta`eta'.png", as(png) replace

	replace success_diff_fullfam=-0.01 if success_diff_fullfam<-0.01
	replace success_diff_fullfam=0.01 if success_diff_fullfam>0.01
	hist success_diff_fullfam [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Full Info and No Familiarity, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FXNC_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FXNC_FullFam_`model'_eta`eta'.png", as(png) replace

}


** examine changes in specialist volume
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
bys Specialist_ID hrr: gen obs=_n
bys Specialist_ID hrr: egen spec_patients=sum(choice)
replace spec_qual=spec_success_tot/spec_patients_tot
keep if obs==1
keep Specialist_ID hrr spec_qual spec_patients
save spec_temp, replace

foreach eta in 1 5 {

	use "${RESULTS_FINAL}CounterFactualsSpec_`model'`eta'.dta", clear
	merge 1:1 hrr Specialist_ID hrr using spec_temp, keep(match) nogenerate

	foreach x of newlist full fullfam current {
		gen diff_`x'=pred_patients_`x'-pred_patients0
		gen reldiff_`x'=diff_`x'/pred_patients0
	}
	reg reldiff_full spec_qual, robust
	reg reldiff_fullfam spec_qual, robust

	hist reldiff_full if reldiff_full>-1 & reldiff_full<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChange_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChange_Full_`model'_eta`eta'.png", as(png) replace

	hist reldiff_fullfam if reldiff_fullfam>-1 & reldiff_fullfam<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChange_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChange_FullFam_`model'_eta`eta'.png", as(png) replace

	sum diff_full, detail
	replace diff_full=-100 if diff_full<-100
	replace diff_full=100 if diff_full>100
	hist diff_full if reldiff_full>-1 & reldiff_full<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Absolute Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeABS_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeABS_Full_`model'_eta`eta'.png", as(png) replace

	sum diff_fullfam, detail
	replace diff_fullfam=-100 if diff_fullfam<-100
	replace diff_fullfam=100 if diff_fullfam>100
	hist diff_fullfam if reldiff_fullfam>-1 & reldiff_fullfam<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Absolute Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeABS_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeABS_FullFam_`model'_eta`eta'.png", as(png) replace

}

** examine changes in specialist volume, removing non-converging markets
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
bys Specialist_ID hrr: gen obs=_n
bys Specialist_ID hrr: egen spec_patients=sum(choice)
replace spec_qual=spec_success_tot/spec_patients_tot
keep if obs==1
keep Specialist_ID hrr spec_qual spec_patients
save spec_temp, replace

foreach eta in 1 5 {

	use "${RESULTS_FINAL}CounterFactualsSpec_`model'`eta'.dta", clear
	gen share_nc=no_equil_full/pred_patients0
	merge 1:1 hrr Specialist_ID hrr using spec_temp, keep(match) nogenerate

	drop if share_nc>0.05
	foreach x of newlist full fullfam current {
		gen diff_`x'=pred_patients_`x'-pred_patients0
		gen reldiff_`x'=diff_`x'/pred_patients0
	}
	reg reldiff_full spec_qual, robust
	reg reldiff_fullfam spec_qual, robust

	hist reldiff_full if reldiff_full>-1 & reldiff_full<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeNC_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeNC_Full_`model'_eta`eta'.png", as(png) replace

	hist reldiff_fullfam if reldiff_fullfam>-1 & reldiff_fullfam<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeNC_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeNC_FullFam_`model'_eta`eta'.png", as(png) replace


	sum diff_full, detail
	replace diff_full=-100 if diff_full<-100
	replace diff_full=100 if diff_full>100
	hist diff_full if reldiff_full>-1 & reldiff_full<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Absolute Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeABS_NC_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeABS_NC_Full_`model'_eta`eta'.png", as(png) replace

	sum diff_fullfam, detail
	replace diff_fullfam=-100 if diff_fullfam<-100
	replace diff_fullfam=100 if diff_fullfam>100
	hist diff_fullfam if reldiff_fullfam>-1 & reldiff_fullfam<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Absolute Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeABS_NC_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeABS_NC_FullFam_`model'_eta`eta'.png", as(png) replace

}


******************************************************************
** Section E: Scalar output (append to paper-numbers-structural.tex)

local numfile "${RESULTS_FINAL}paper-numbers-structural.tex"

** count HRRs and alpha=0 HRRs
use "${RESULTS_FINAL}`coef_prefix'_SummaryHRR.dta", clear
keep if eta==1
qui count
local n_hrrs = r(N)
qui count if coef_m==0
local n_alpha0 = r(N)

** alpha/distance ratio
qui sum coef_m if eta==1
local mean_alpha = r(mean)
qui sum coef_dist if eta==1
local mean_pi = abs(r(mean))
local alpha_dist: di %3.1f `mean_alpha'/`mean_pi'

** mean reallocation
use "${RESULTS_FINAL}CounterFactuals_`model'5.dta", clear
gen success_diff_full=success_prob1_full-success_prob0
collapse (mean) pij_diff_full success_diff_full, by(hrr)
merge 1:1 hrr using hrr_size, nogenerate keep(master match)
qui sum pij_diff_full [aweight=patients]
local realloc_mean: di %5.3f r(mean)
qui sum success_diff_full [aweight=patients]
local health_mean: di %7.5f r(mean)

file open numfh using "`numfile'", write append
file write numfh "\newcommand{\reallocationMean`model'}{`realloc_mean'}" _n
file write numfh "\newcommand{\healthFXMean`model'}{`health_mean'}" _n
file write numfh "\newcommand{\nHRRs`model'}{`n_hrrs'}" _n
file write numfh "\newcommand{\nAlphaZero`model'}{`n_alpha0'}" _n
file write numfh "\newcommand{\alphaDistRatio`model'}{`alpha_dist'}" _n
file close numfh



log close
