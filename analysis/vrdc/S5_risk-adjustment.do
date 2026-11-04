set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}S5_RiskAdj_`logdate'.log", replace

******************************************************************
**	Title:		Risk-adjusted specialist quality
**	Author:		Ian McCarthy
**	Date Created:	5/18/2026
**	Notes:		Patient-level LPM of failure on age, sex, race, DRG, and the
**			Charlson index (9_patient_cci.sas, read with sasload), indirect
**			standardization to a risk-adjusted specialist quality, and two
**			MNL sensitivities (DRG 470 only; risk-adjusted quality as the
**			prior; risk score by surgeon quality) through a variant of
**			run_mnl_specs; a within-surgeon LPM of failure on experience and
**			quarterly volume. Surgeon level only. Writes DRG_Distribution.csv,
**			SpecQualAdj.csv, SpecQualAdj.png, VolumeOutcome.csv, MNL_Specs5/6/9.dta,
**			MNL_Specs_Adj.tex, and temp_spec_quarterly for S6.
******************************************************************



******************************************************************
** run_mnl_specs (_programs.do) with three options: Drg(numlist) keeps the
** listed DRGs; Adjust swaps the risk-adjusted spec_qual into the prior;
** Interact adds the patient's risk score times the surgeon's running quality.
capture program drop run_mnl_specs_rev
program define run_mnl_specs_rev
	syntax , Regressors(string) [Fwup] [Drg(numlist)] [Adjust] [Interact]

	forvalues i=1/457 {
		capture confirm file "${DATA_FINAL}ChoiceData_HRR`i'.dta"
		if _rc==0 {
			use "${DATA_FINAL}ChoiceData_HRR`i'.dta", clear

			** optional DRG filter (case-mix sensitivity)
			if "`drg'" != "" {
				gen byte _drg_keep=0
				foreach d of numlist `drg' {
					replace _drg_keep=1 if clm_drg_cd==`d'
				}
				keep if _drg_keep==1
				drop _drg_keep
				qui count
				if r(N)==0 continue
			}

			do "${CODE_FILES}_clean-analysis.do"

			** optional risk-adjusted spec_qual swap
			if "`adjust'" != "" {
				merge m:1 Specialist_ID using temp_spec_qual_adj, ///
					keep(master match) nogenerate
				replace spec_qual=spec_qual_adj if !missing(spec_qual_adj)
				drop spec_qual_adj
			}
			local extra
			if "`interact'" != "" {
				merge m:1 bene_id admit using temp_patient_risk, keep(master match) nogenerate
				gen risk_x_qual=phat*(1-prop_spec_failures_run)
				local extra risk_x_qual
			}

			** prepare for cmclogit syntax
			egen referral=group(bene_id admit)
			keep Practice_ID Specialist_ID choice referral case_obs casevar common_ref prop_failures_run prop_patients_run ///
				pair_success_run spec_qual pair_patients_run pair_failures_run pair_patients_run_fw pair_failures_run_fw ///
				bene_spec_distance bene_distance diff_dist prac_vi pair_new ///
				fmly_np_* Year pcp_phy_tin1 pcp_phy_tin2 `extra'
			sum fmly_np_*
			drop fmly_np_0
			local step=0
			foreach x of varlist pcp_phy_tin1 pcp_phy_tin2 {
				local step=`step'+1
				bys `x': egen practice_patients_`step'=sum(pair_patients_run)
				replace practice_patients_`step'=practice_patients_`step'-pair_patients_run
				bys `x': egen practice_failures_`step'=sum(pair_failures_run)
				replace practice_failures_`step'=practice_failures_`step'-pair_failures_run
				gen practice_info_`step'=(practice_patients_`step'-practice_failures_`step')/practice_patients_`step'
			}

			cmset Practice_ID referral case_obs
			qui sum spec_qual
			local rho=r(mean)
			if "`fwup'" != "" {
				gen pair_success_run_fw=pair_patients_run_fw-pair_failures_run_fw
				replace pair_success_run_fw=0 if pair_success_run_fw==. | pair_success_run_fw<0
				replace pair_patients_run_fw=0 if pair_patients_run_fw==.
				gen m=(`rho' + pair_success_run_fw)/(1 + pair_patients_run_fw)
			}
			else {
				gen m=(`rho' + pair_success_run)/(1 + pair_patients_run)
			}

			** estimate and save results
			gsort casevar -common_ref
			capture cmclogit choice m `regressors', noconstant iterate(100)

			if _rc==0 {
				gen belief_s=.
				local iter=0
				local lna_old=1
				local lna_new=ln(max(_b[m],0.01))
				while (abs( exp(`lna_new') - exp(`lna_old') ) > 0.005 & `iter'<10) {
					local iter=`iter' + 1
					local lna_old = `lna_new'
					qui replace belief_s = exp(`lna_old')*m
					qui cmclogit choice belief_s `regressors', noconstant iterate(100)
					local lna_new = `lna_old' + _b[belief_s]-1
				}
				est store cmclogit_est
				matrix b1=get(_b)
				mat b1[1,1]=exp(`lna_new')
				matrix var_cov=e(V)
				matrix var_diag=vecdiag(var_cov)
				matrix c1=(`i', e(converged), e(ll), b1)'
				matrix var1=(`i', e(converged), e(ll), var_diag)'
				svmat double c1, name(coef_`i')
				svmat double var1, name(coef_se_`i')
				gen coef_names_`i'=""
				replace coef_names_`i'="hrr" if _n==1
				replace coef_names_`i'="converged" if _n==2
				replace coef_names_`i'="log_like" if _n==3
				local cov_list=rowsof(c1)
				local names : rownames c1
				forvalues l=4/`cov_list' {
					local name : word `l' of `names'
					replace coef_names_`i'="`name'" if _n==`l'
				}

				keep if coef_`i'!=.
				keep coef_`i' coef_se_`i' coef_names_`i'
				replace coef_se_`i'=sqrt(coef_se_`i')
				save coef_data_`i', replace
			}
		}
	}

	forvalues i=1/457 {
		capture confirm file "coef_data_`i'.dta"
		if _rc==0 {
			use coef_data_`i', clear
			rename coef_`i'1 coef_val
			rename coef_se_`i'1 coef_se
			rename coef_names_`i' coef_name
			save coef_data_`i', replace
		}
	}

	local step=0
	forvalues i=1/457 {
		capture confirm file "coef_data_`i'.dta"
		if _rc==0 {
			local step=`step'+1
			if `step'==1 {
				use coef_data_`i', clear
			}
			else {
				append using coef_data_`i', force
			}
		}
		capture erase "coef_data_`i'.dta"
	}
end


******************************************************************
** Stack patient-event-level data across years
clear
forvalues y=2008/2018 {
	append using "${DATA_FINAL}Referrals_`y'.dta", ///
		keep(bene_id clm_id Practice_ID Specialist_ID admit Year ///
		     bene_age bene_gender bene_race clm_drg_cd any_bad)
}

** merge in Charlson Comorbidity Index from 9_patient_cci.sas
preserve
sasload patientcci_all
keep bene_id clm_id cci_score
duplicates drop bene_id clm_id, force
save temp_cci, replace
restore
merge m:1 bene_id clm_id using temp_cci, keep(master match) nogenerate
gen byte cci_missing=missing(cci_score)
replace cci_score=0 if missing(cci_score)
erase temp_cci.dta

** restrict to specialists meeting the estimation-sample size threshold
bys Specialist_ID: gen spec_n=_N
keep if spec_n>=${SPEC_MIN}
drop spec_n


******************************************************************
** Clean covariates (handle both string and numeric storage)
capture confirm numeric variable bene_gender
if _rc==0 {
	gen byte female=(bene_gender==2)
	replace female=. if !inlist(bene_gender,1,2)
}
else {
	gen byte female=(bene_gender=="2")
	replace female=. if !inlist(bene_gender,"1","2")
}

capture confirm numeric variable bene_race
if _rc==0 {
	gen byte race_cat=1 if bene_race==1
	replace race_cat=2 if bene_race==2
	replace race_cat=3 if !inlist(bene_race,1,2,.) & !missing(bene_race)
}
else {
	gen byte race_cat=1 if bene_race=="1"
	replace race_cat=2 if bene_race=="2"
	replace race_cat=3 if !inlist(bene_race,"1","2","") & !missing(bene_race)
}

capture confirm numeric variable clm_drg_cd
if _rc==0 {
	gen drg=clm_drg_cd
}
else {
	encode clm_drg_cd, gen(drg)
}

gen age=bene_age
gen age2=bene_age^2

drop if missing(any_bad, age, female, race_cat, drg)


******************************************************************
** DRG distribution of the analytic sample
preserve
contract clm_drg_cd, freq(n_events)
egen tot=total(n_events)
gen share=n_events/tot
drop tot
gsort -n_events
replace n_events=. if n_events<=11
replace share=. if missing(n_events)
list, sepby(clm_drg_cd) noobs
export delimited using "${RESULTS_BASE}DRG_Distribution.csv", replace
restore


******************************************************************
** Patient-level LPM for failure: any_bad on patient characteristics.
** age (quadratic) + female + race + DRG + Charlson CCI.
reg any_bad c.age##c.age i.female i.race_cat i.drg c.cci_score i.cci_missing
predict phat_lpm, xb

** trim predictions to [0,1] for indirect-standardization aggregation
gen phat=phat_lpm
replace phat=0 if phat<0
replace phat=1 if phat>1

sum any_bad
local mean_fail=r(mean)

preserve
keep bene_id admit phat
duplicates drop bene_id admit, force
save temp_patient_risk, replace
restore


******************************************************************
** Surgeon volume and outcomes, within surgeon: stays before the admission
** quarter (experience) and stays in it (congestion), from every stay 2008-2018
preserve
clear
forvalues y=2008/2018 {
	append using "${DATA_FINAL}OrthoStays_`y'.dta", keep(spec_npi admit)
}
gen quarter=qofd(admit)
collapse (count) vol_q=admit, by(spec_npi quarter)
rename spec_npi Specialist_ID
sort Specialist_ID quarter
by Specialist_ID: gen vol_cum=sum(vol_q)-vol_q
save temp_spec_quarterly, replace
restore

gen quarter=qofd(admit)
merge m:1 Specialist_ID quarter using temp_spec_quarterly, keep(master match) nogenerate
gen log_exp=log(1+vol_cum)
reghdfe any_bad c.age##c.age i.female i.race_cat i.drg c.cci_score i.cci_missing log_exp vol_q, ///
	absorb(Specialist_ID Year) vce(cluster Specialist_ID)
file open fv using "${RESULTS_BASE}VolumeOutcome.csv", write replace
file write fv "variable,coef,se,n" _n
file write fv "log_experience,`=_b[log_exp]',`=_se[log_exp]',`=e(N)'" _n
file write fv "quarter_volume,`=_b[vol_q]',`=_se[vol_q]',`=e(N)'" _n
file close fv
drop quarter vol_q vol_cum log_exp


******************************************************************
** Specialist-level aggregation
** Risk-adjusted failure = (observed - expected) + overall-mean failure
** Risk-adjusted quality = 1 - risk-adjusted failure
preserve
collapse (count) n_pat=any_bad (mean) obs_fail=any_bad exp_fail=phat, by(Specialist_ID)
gen adj_fail=obs_fail - exp_fail + `mean_fail'
gen spec_qual_raw=1 - obs_fail
gen spec_qual_adj=1 - adj_fail

** summary + raw-vs-adjusted correlation
sum spec_qual_raw spec_qual_adj
corr spec_qual_raw spec_qual_adj
spearman spec_qual_raw spec_qual_adj

** rank changes
egen rank_raw=rank(spec_qual_raw)
egen rank_adj=rank(spec_qual_adj)
gen rank_diff=rank_adj - rank_raw
sum rank_diff, detail

** cell-size masking before export
foreach v of varlist obs_fail exp_fail adj_fail spec_qual_raw spec_qual_adj rank_raw rank_adj rank_diff {
	replace `v'=. if n_pat<=11
}
replace n_pat=. if n_pat<=11

export delimited using "${RESULTS_BASE}SpecQualAdj.csv", replace
restore


******************************************************************
** Scatter of raw vs risk-adjusted quality at specialist level
preserve
collapse (count) n_pat=any_bad (mean) obs_fail=any_bad exp_fail=phat, by(Specialist_ID)
keep if n_pat>=${SPEC_MIN}
gen adj_fail=obs_fail - exp_fail + `mean_fail'
gen spec_qual_raw=1 - obs_fail
gen spec_qual_adj=1 - adj_fail

twoway (scatter spec_qual_adj spec_qual_raw, mcolor(gs6%40) msize(small)) ///
	(function y=x, range(spec_qual_raw) lcolor(black) lpattern(dash)), ///
	xtitle("Raw Specialist Quality (Success Rate)") ///
	ytitle("Risk-Adjusted Specialist Quality") ///
	legend(off)
graph save "${RESULTS_BASE}SpecQualAdj", replace
graph export "${RESULTS_BASE}SpecQualAdj.png", as(png) replace
restore


******************************************************************
** Specialist-level risk-adjusted quality, saved for MNL_Specs6 merge
preserve
collapse (count) n_pat=any_bad (mean) obs_fail=any_bad exp_fail=phat, by(Specialist_ID)
keep if n_pat>=${SPEC_MIN}
gen adj_fail=obs_fail - exp_fail + `mean_fail'
gen spec_qual_adj=1 - adj_fail
keep Specialist_ID spec_qual_adj
save temp_spec_qual_adj, replace
restore


******************************************************************
** MNL_Specs5: baseline regressors, restricted to DRG 470
run_mnl_specs_rev, regressors(diff_dist fmly_np_1 fmly_np_2 fmly_np_3 fmly_np_4 fmly_np_5 fmly_np_7 fmly_np_10 fmly_np_15 fmly_np_20 ib(freq).Specialist_ID) drg(470)
save "${RESULTS_BASE}MNL_Specs5.dta", replace


******************************************************************
** MNL_Specs6: baseline regressors, with risk-adjusted spec_qual
run_mnl_specs_rev, regressors(diff_dist fmly_np_1 fmly_np_2 fmly_np_3 fmly_np_4 fmly_np_5 fmly_np_7 fmly_np_10 fmly_np_15 fmly_np_20 ib(freq).Specialist_ID) adjust
save "${RESULTS_BASE}MNL_Specs6.dta", replace


******************************************************************
** MNL_Specs9: baseline regressors plus the patient's risk score times the surgeon's running quality
run_mnl_specs_rev, regressors(diff_dist risk_x_qual fmly_np_1 fmly_np_2 fmly_np_3 fmly_np_4 fmly_np_5 fmly_np_7 fmly_np_10 fmly_np_15 fmly_np_20 ib(freq).Specialist_ID) interact
save "${RESULTS_BASE}MNL_Specs9.dta", replace

erase temp_spec_qual_adj.dta
erase temp_patient_risk.dta


******************************************************************
** Organize Specs5, Specs6, and Specs9 into a supplementary table
foreach n of numlist 5 6 9 {
	use "${RESULTS_BASE}MNL_Specs`n'.dta", clear
	gen hrr=coef_val if coef_name=="hrr"
	replace hrr=hrr[_n-1] if hrr==.

	replace coef_name="belief_s" if coef_name=="o.belief_s"
	keep if inlist(coef_name, "belief_s", "converged", "log_like", "diff_dist", "risk_x_qual") | ///
		inlist(coef_name, "fmly_np_1", "fmly_np_2", "fmly_np_3", "fmly_np_4", "fmly_np_5", "fmly_np_7", "fmly_np_10", "fmly_np_15", "fmly_np_20")

	rename coef_val est_
	rename coef_se se_
	reshape wide est_ se_, i(hrr) j(coef_name) string

	foreach x of newlist converged log_like {
		rename est_`x' `x'
		drop se_`x'
	}
	order hrr converged log_like
	drop if converged==0

	drop est_fmly_np* se_fmly_np* converged
	replace se_belief_s=est_belief_s*se_belief_s
	if `n'==5 gen spec="drg470"
	if `n'==6 gen spec="riskadj"
	if `n'==9 gen spec="riskint"
	save temp_specs`n', replace
}

use temp_specs5, clear
append using temp_specs6
append using temp_specs9

tempfile table_tex
postfile table_tex str200 line using "`table_tex'", replace
post table_tex ("")
post table_tex ("& & \multicolumn{5}{c}{Percentile} \\")
post table_tex ("\cline{3-7}")
post table_tex ("Parameter & Mean & 10th & 25th & 50th & 75th & 90th \\")
post table_tex ("\hline\hline")

qui sum est_belief_s if spec=="drg470", detail
post table_tex (" DRG 470 only & `=string(r(mean), "%9.4f")' & `=string(r(p10), "%9.4f")'  & `=string(r(p25), "%9.4f")'  & `=string(r(p50), "%9.4f")'  & `=string(r(p75), "%9.4f")'  & `=string(r(p90), "%9.4f")' \\")

qui sum est_belief_s if spec=="riskadj", detail
post table_tex (" Risk-Adjusted Quality & `=string(r(mean), "%9.4f")' & `=string(r(p10), "%9.4f")'  & `=string(r(p25), "%9.4f")'  & `=string(r(p50), "%9.4f")'  & `=string(r(p75), "%9.4f")'  & `=string(r(p90), "%9.4f")' \\")

qui sum est_belief_s if spec=="riskint", detail
post table_tex (" With Risk $\times$ Quality & `=string(r(mean), "%9.4f")' & `=string(r(p10), "%9.4f")'  & `=string(r(p25), "%9.4f")'  & `=string(r(p50), "%9.4f")'  & `=string(r(p75), "%9.4f")'  & `=string(r(p90), "%9.4f")' \\")

qui sum est_risk_x_qual if spec=="riskint", detail
post table_tex (" \quad Risk $\times$ Quality & `=string(r(mean), "%9.4f")' & `=string(r(p10), "%9.4f")'  & `=string(r(p25), "%9.4f")'  & `=string(r(p50), "%9.4f")'  & `=string(r(p75), "%9.4f")'  & `=string(r(p90), "%9.4f")' \\")
post table_tex ("\hline\hline")
postclose table_tex

use "`table_tex'", clear
outfile line using "${RESULTS_BASE}MNL_Specs_Adj.tex", noquote replace


log close
