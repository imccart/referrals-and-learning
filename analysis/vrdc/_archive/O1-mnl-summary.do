set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}MNL_Results_`logdate'.log", replace

******************************************************************
**	Title:		Summarize MNL (Reduced Form) Estimation
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	9/28/2023
******************************************************************


******************************************************************		
** means for interpretation of estimates

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
keep if EstPCPMatch==3

replace pair_patients_run=0 if pair_patients_run==.
replace pair_failures_run=0 if pair_failures_run==.
gen failure_rate=pair_failures_run/pair_patients_run
replace failure_rate=0 if failure_rate==.
gen pair_patients_extra=pair_patients_run+1
gen pair_failures_extra=pair_failures_run+1
gen failure_rate_extra=pair_failures_extra/pair_patients_extra
sum failure_rate failure_rate_extra if Year>=2013


******************************************************************		
** MFXs from MNL Myopic Model

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${RESULTS_FINAL}MyopicHRR_mfxFull_`r_type'.dta", clear
gen hrr=mfx_val if mfx_name=="hrr"
replace hrr=hrr[_n-1] if hrr==.

bys hrr: gen var=_n
reshape wide mfx_val mfx_name, i(hrr) j(var)
rename mfx_val2 mfx_failures
rename mfx_val3 mfx_patients
rename mfx_val4 mfx_failures_se
rename mfx_val5 mfx_patients_se
drop mfx_name* mfx_val1

merge 1:1 hrr using hrr_size, nogenerate keep(master match)
save "${RESULTS_FINAL}MyopicHRR_mfxFull_final_`r_type'.dta", replace
outsheet using "${RESULTS_FINAL}MyopicHRR_mfxFull_final_`r_type'.csv", comma replace


******************************************************************
** Coefficient Estimates from MNL Myopic Model

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${RESULTS_FINAL}MyopicHRR_CoefFull_`r_type'.dta", clear
gen hrr=coef_val if coef_name=="hrr"
replace hrr=hrr[_n-1] if hrr==.

bys hrr: gen var=_n-1
reshape wide coef_val coef_se coef_name, i(hrr) j(var)
rename coef_val2 coef_failures
rename coef_se2 coef_failures_se
rename coef_val3 coef_patients
rename coef_se3 coef_patients_se
rename coef_val4 coef_failures_patients
rename coef_se4 coef_failures_patients_se
rename coef_val5 coef_distance
rename coef_se5 coef_distance_se
drop coef_name0 coef_name1 coef_name2 coef_name3 coef_name4 coef_name5 coef_val0 coef_val1 coef_se0 coef_se1

merge 1:1 hrr using hrr_size, nogenerate keep(master match)
save "${RESULTS_FINAL}MyopicHRR_CoefFull_final_`r_type'.dta", replace
outsheet using "${RESULTS_FINAL}MyopicHRR_CoefFull_final_`r_type'.csv", comma replace

** keep alpha and distance coefficients
use "${RESULTS_FINAL}MyopicHRR_CoefFull_final_1_1_0.dta", clear
keep hrr coef_dist* coef_failures* coef_patients*
save "${RESULTS_FINAL}MNL_Coeff_notFEs.dta", replace

** keep only specialist FEs
use "${RESULTS_FINAL}MyopicHRR_CoefFull_final_1_1_0.dta", clear
drop coef_failures* coef_patients* coef_distance*
drop patients pcp_total spec_total mean_choice_size mean_spec_failures mean_pair_failures mean_pcp_failures spec_hhi mean_vi

forvalues i=6/266 {
	split coef_name`i', p(".") generate(spec_id)
	drop spec_id2 coef_name`i'
	rename spec_id1 spec_id`i'
}
reshape long coef_val coef_se spec_id, i(hrr) j(count) string
replace spec_id=subinstr(spec_id, "b","",.)
drop count
destring spec_id, replace force
drop if spec_id==.
rename spec_id Specialist_ID

replace coef_se=. if coef_se==0
bys hrr: egen mean_se=mean(coef_se)
replace coef_se=mean_se if coef_se==.
save "${RESULTS_FINAL}MNL_Specialist_FEs.dta", replace



use "${RESULTS_FINAL}MyopicHRR_CoefFull_final_1_1_0.dta", clear
sum coef_failures [aw=patients], detail
sum coef_patients [aw=patients], detail
sum coef_failures_patients [aw=patients], detail
sum coef_distance [aw=patients], detail

sum coef_failures_se coef_patients_se coef_failures_patients_se coef_distance_se [aw=patients]


******************************************************************		
** Market-level analysis

use "${RESULTS_FINAL}MyopicHRR_mfxFull_final_1_1_0.dta", clear

sum mfx_patients [aw=patients], detail
sum mfx_failures [aw=patients], detail
sum mfx_patients_se mfx_failures_se [aw=patients]

** Transformations: patients in 1000s, doctors in 100s
gen pat1000=patients/1000
gen pcp100=pcp_total/100
gen spec100=spec_total/100

** Ratios
gen spec_pcp_ratio = spec_total/pcp_total
gen spec_pat_ratio = spec_total/patients
gen failure_ratio=mean_pair_failures/mean_spec_failures

** Signs of MFX estimates
gen negative=(mfx_failures+2*mfx_failures_se<0)
gen negative_null=(mfx_failures<0 & (mfx_failures+2*mfx_failures_se>0))
gen positive_null=(mfx_failures>0 & (mfx_failures-2*mfx_failures_se<0))

** Summaries
sum patients pcp_total spec_total spec_hhi mean_vi mfx_failures [aw=patients], detail
sum *_ratio [aw=patients], detail
hist mfx_failures if mfx_failures<.5 & mfx_failures>-.5 [weight=patients], fraction color(gray) width(0.03) ///
	ylabel(0(.05).3) ///
	ytitle("Relative Frequency") xtitle("Marginal Effects of Failure Rate") legend(off)
graph save "${RESULTS_FINAL}MFX_HRR_1_1_0", replace
graph export "${RESULTS_FINAL}MFX_HRR_1_1_0.png", as(png) replace		

cor patients pcp_total spec_total spec_hhi mean_vi spec_pcp_ratio spec_pat_ratio [aw=patients]


** Regressions
gen temp = 1/mfx_failures_se
sum temp mfx_failures_se, detail
drop temp
gen reg_weight=1/mfx_failures_se^2

local ind_vars1 "pat1000"
local ind_vars2 "spec100"
local ind_vars3 "pat1000 spec100"
local ind_vars4 "pcp100"
local ind_vars5 "pcp100 pat1000"
local ind_vars6 "spec100 pcp100 pat1000"
local ind_vars7 "spec_pat_ratio"
local ind_vars8 "spec_pat_ratio pat1000"
local ind_vars9 "spec_pcp_ratio"
local ind_vars10 "spec_pcp_ratio pat1000"
local ind_vars11 "spec_hhi"
local ind_vars12 "spec_hhi pat1000"
local ind_vars13 "spec_hhi spec100"
local ind_vars14 "spec_hhi spec100 pat1000"
local ind_vars15 "spec_hhi spec100 pcp100 pat1000"
local ind_vars16 "mean_vi"
local ind_vars17 "mean_vi pat1000"

local step=0
forvalues i=1/17 {
	local step=`step'+1
	
	reg mfx_failures `ind_vars`i'' [aw=reg_weight]
	if `step'==1 {
		outreg2 using "${RESULTS_FINAL}MFX-market-level.tex", replace se bdec(4) sdec(4) noaster
	}
	else {
		outreg2 using "${RESULTS_FINAL}MFX-market-level.tex", append se bdec(4) sdec(4) noaster
	}
	
}

lpoly mfx_failures spec_hhi if spec_hhi < 0.5 [aw=reg_weight], degree(1) ci noscatter title("") xtitle("Specialist HHI") ytitle("MFX of Failures")
graph export "${RESULTS_FINAL}lpoly_hhi.png", width(1100) height(800) replace		

lpoly mfx_patients spec_hhi if spec_hhi < 0.5 [aw=reg_weight], degree(1) ci noscatter title("") xtitle("Specialist HHI") ytitle("MFX of Prior Patients")
graph export "${RESULTS_FINAL}lpoly_inertia_hhi.png", width(1100) height(800) replace		

	
******************************************************************		
** IV estimates for congestion/capacity constraints

use "${DATA_FINAL}SpecialistCapacity_year.dta", clear
keep if Year>=2013
rename bene_hrr hrr
collapse (mean) mean_patients=patients capacity_* cong_* (p75) cong_p75=cong_75 (sum) tot_patients=patients, by(spec_npi hrr)
rename spec_npi Specialist_ID
save mean_capacity, replace

use "${RESULTS_FINAL}MNL_Specialist_FEs.dta", clear
merge 1:1 hrr Specialist_ID using "${RESULTS_FINAL}Distance_Prediction_Full_1_1_0.dta", nogenerate keep(match)
merge 1:1 Specialist_ID hrr using mean_capacity, nogenerate keep(match)
gen reg_weight=1/(coef_se^2)
reg tot_patients yhat [aweight=reg_weight] 

matrix fs_results=J(457,4,.)
forvalues i=1/457 {
	count if hrr==`i' & reg_weight!=.
	if r(N)>5 {
		reg tot_patients yhat [aweight=reg_weight] if hrr==`i'
		mat fs_results[`i',1]=_b[yhat]
		mat var_mat=e(V)
		mat fs_results[`i',2]=sqrt(var_mat[1,1])
		mat fs_results[`i',3]=e(df_r)
		mat fs_results[`i',4]=`i'
	}
}
clear
svmat fs_results
rename fs_results1 coef_est
rename fs_results2 coef_se
rename fs_results3 df
rename fs_results4 hrr
drop if hrr==.
gen t_stat=coef_est/coef_se
gen f_stat=t_stat^2
sum f_stat, detail

gen p_val=2*ttail(df, abs(t_stat))
hist p_val

merge 1:1 hrr using hrr_size, nogenerate keep(master match)
hist coef_est [weight=patients], fraction color(gray) width(0.5) ///
	ylabel(0(.05).25) ///
	ytitle("Relative Frequency") xtitle("First-stage estimates") legend(off)
graph save "${RESULTS_FINAL}2SLSFirstStage_1_1_0", replace
graph export "${RESULTS_FINAL}2SLSFirstStage_1_1_0.png", as(png) replace		




use "${RESULTS_FINAL}MNL_Specialist_FEs.dta", clear
merge 1:1 hrr Specialist_ID using "${RESULTS_FINAL}Distance_Prediction_Full_1_1_0.dta", nogenerate keep(match)
merge 1:1 Specialist_ID hrr using mean_capacity, nogenerate keep(match)
gen reg_weight=1/(coef_se^2)

sum coef_val, detail
keep if inrange(coef_val, r(p1), r(p99))
twoway scatter coef_val yhat [aweight=reg_weight]

** total patients and predicted patients
reg tot_patients yhat [aweight=reg_weight]
reg coef_val yhat [aweight=reg_weight]
sum yhat, detail
ivreg2 coef_val (tot_patients=yhat) [aweight=reg_weight]

** with hrr FE
reg tot_patients yhat i.hrr [aweight=reg_weight]
reg coef_val yhat i.hrr [aweight=reg_weight]
ivreg2 coef_val i.hrr (tot_patients=yhat) [aweight=reg_weight]

** adding 2nd order polynomials
gen tot_pat2=tot_patients^2
gen yhat2=yhat^2
reg tot_patients yhat [aweight=reg_weight]
reg tot_pat2 yhat2 [aweight=reg_weight]
ivreg coef_val (tot_patients=yhat yhat2) [aweight=reg_weight]
ivreg coef_val (tot_patients tot_pat2=yhat yhat2) [aweight=reg_weight]

** congestion instead of patients counts
gen pred_cong=yhat/capacity_p90
reg cong_90 pred_cong [aweight=reg_weight]
reg coef_val pred_cong [aweight=reg_weight]
ivreg coef_val (cong_90=pred_cong) [aweight=reg_weight], first
graph twoway scatter coef_val pred_cong|| fpfit coef_val pred_cong

** "high" congestion...dummy for capacity contrained
gen high_cong=(cong_90>0.99)
gen pred_high_cong=(pred_cong>.9)
reg cong_90 pred_high_cong [aweight=reg_weight]
reg coef_val pred_high_cong [aweight=reg_weight]
ivreg coef_val (cong_90=pred_high_cong) [aweight=reg_weight], first

matrix tsls_results=J(457,4,.)
forvalues i=1/457 {
	count if hrr==`i' & reg_weight!=.
	if r(N)>5 {
		ivreg coef_val (tot_patients=yhat) [aweight=reg_weight] if hrr==`i'
		mat fs_results[`i',1]=_b[tot_patients]
		mat var_mat=e(V)
		mat fs_results[`i',2]=sqrt(var_mat[1,1])
		mat fs_results[`i',3]=e(df_r)
		mat fs_results[`i',4]=`i'
	}
}
clear
svmat fs_results
rename fs_results1 coef_est
rename fs_results2 coef_se
rename fs_results3 df
rename fs_results4 hrr
drop if hrr==.
gen t_stat=coef_est/coef_se
gen p_val=2*ttail(df, abs(t_stat))
hist p_val

merge 1:1 hrr using hrr_size, nogenerate keep(master match)
hist coef_est if coef_est>-0.05 & coef_est<0.05 [weight=patients], fraction color(gray) width(0.0005) ///
	ylabel(0(.05).2) ///
	ytitle("Relative Frequency") xtitle("2SLS estimates") legend(off)
graph save "${RESULTS_FINAL}2SLSEstimate_1_1_0", replace
graph export "${RESULTS_FINAL}2SLSEstimate_1_1_0.png", as(png) replace		


log close
