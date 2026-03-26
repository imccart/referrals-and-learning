set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}CoefTables_${MODEL_TYPE}_`logdate'.log", replace

******************************************************************
**	Title:		Coefficient Extraction, IV, and LaTeX Tables
**	Author:		Ian McCarthy
**	Date Created:	2/25/2026
**	Notes:		Parameterized by global MODEL_TYPE (Myopic or FWD).
**			Extracted from O2-structural-summary.do.
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
drop fmly_level1 fmly_level2 coef_name
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

split coef_name, p("-") generate(spec_id)
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
	reg coef_val yhat time_period big_coef i.hrr [aweight=reg_weight], robust
	ivreg2 coef_val time_period big_coef i.hrr (tot_patients=yhat) [aweight=reg_weight], robust
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
post table_tex ("\hline\hline")

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
post table_tex ("\\[-0.5ex]")
post table_tex ("")
post table_tex ("\multicolumn{8}{l}{\$\pi\$ (utility weight on distance)} \\")

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

post table_tex ("\\[-0.5ex]")
post table_tex ("")
post table_tex ("\multicolumn{8}{l}{\$\rho\$ (prior mean)} \\")
post table_tex ("\ \ (all \$\eta\$) & `=string(r(mean), "%9.4f")' & (`=string(r(sd), "%9.4f")') & `=string(r(p10), "%9.4f")'  & `=string(r(p25), "%9.4f")'  & `=string(r(p50), "%9.4f")'  & `=string(r(p75), "%9.4f")'  & `=string(r(p90), "%9.4f")' \\")

** congestion/capacity
post table_tex ("\\[-0.5ex]")
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
post table_tex ("\\[-0.5ex]")
post table_tex ("")
post table_tex ("\multicolumn{2}{l}{\$\kappa_{b}\$ (familiarity)} & \multicolumn{5}{c}{Range of \$e_{ijt}\$} \\")
post table_tex ("\cline{2-8}")
post table_tex ("\ \  & 1  & 2  & 3  & 4  & 5  & [6,7]  & [8,10] \\")
post table_tex ("\hline\hline")

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
** Save IV scalars for O2-counterfactuals.do
clear
set obs 2
gen eta = .
gen iv_pat = .
gen iv_time = .
gen iv_shift = .
local e = 0
foreach eta_val in 1 5 {
	local e = `e' + 1
	est restore iv_`eta_val'
	replace eta = `eta_val' in `e'
	replace iv_pat = e(b)[1,1] in `e'
	replace iv_time = e(b)[1,2] in `e'
	replace iv_shift = e(b)[1,3] in `e'
}
save "${RESULTS_FINAL}iv_scalars_`model'.dta", replace


log close
