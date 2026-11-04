set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}CongestionYearly_`logdate'.log", replace

******************************************************************
**	Title:		Congestion identified within surgeon across years
**	Author:		Ian McCarthy
**	Date Created:	11/4/2026
**	Notes:		In markets with at least ten chosen referrals per
**			specialist-year, the myopic model is re-estimated with
**			specialist-by-year fixed effects (the main model splits
**			2013-15 and 2016-18), and the fixed effects are regressed
**			on yearly volume with the distance-predicted volume as the
**			instrument, as in O1, pooled with year and HRR effects and
**			within surgeon. The two-period estimate on the same markets
**			is reported beside it. Eta = 1 only. Writes Congestion_Yearly.csv.
******************************************************************

local min_per_spec_year 10

capture postclose fe
postfile fe hrr eta double Specialist_ID Year double(coef_val coef_se) converged tot_patients yhat using temp_s7_fe, replace

forvalues i=1/457 {
	capture confirm file "${DATA_FINAL}ChoiceData_HRR`i'.dta"
	if _rc!=0 continue
	use "${DATA_FINAL}ChoiceData_HRR`i'.dta", clear
	do "${CODE_FILES}_clean-analysis.do"

	egen referral=group(bene_id admit)
	keep Practice_ID Specialist_ID choice referral case_obs casevar common_ref pair_success_run spec_qual pair_patients_run diff_dist fmly_np_* Year
	drop fmly_np_0

	** market size: chosen referrals per specialist-year
	qui count if choice==1
	local cases=r(N)
	bys Specialist_ID: gen first_s=(_n==1)
	qui count if first_s==1
	if `cases'/r(N)/6 < `min_per_spec_year' continue
	drop first_s

	** specialist-by-year alternatives; the most frequent specialist is the base in every year
	gen Spec_ID_t=string(Specialist_ID, "%10.0f")+"-"+string(Year)
	bys Specialist_ID Year: egen any_choice=max(choice)
	drop if any_choice==0
	drop any_choice
	bys Specialist_ID: gen spec_freq=_N
	qui sum spec_freq
	local freq_max=r(max)
	preserve
	keep if spec_freq==`freq_max'
	local base_ID=Specialist_ID[1]
	restore
	bys Specialist_ID Year: egen tot_patients_year=sum(choice)
	cmset Practice_ID referral case_obs
	gsort casevar -common_ref

	** distance-predicted volume by specialist-year
	capture cmclogit choice diff_dist, noconstant iterate(100)
	if _rc!=0 | e(converged)==0 continue
	predict yhat_i
	bys Specialist_ID Year: egen yhat=sum(yhat_i)
	drop yhat_i

	** the full logit with specialist-by-year effects
	replace Spec_ID_t=string(Specialist_ID,"%10.0f") if Specialist_ID==`base_ID'
	encode Spec_ID_t, gen(Spec_ID)
	replace Spec_ID=0 if Specialist_ID==`base_ID'
	qui sum spec_qual
	local rho=r(mean)
	gen m=.
	gen belief_s=.
	foreach eta in 1 {
		replace m=(`rho'*`eta' + pair_success_run)/(`eta' + pair_patients_run)
		capture cmclogit choice m diff_dist fmly_np_* ib0.Spec_ID, noconstant iterate(100)
		if _rc!=0 | e(converged)==0 continue
		local iter=0
		local lna_old=1
		local lna_new=ln(max(_b[m],0.01))
		matrix b_start=e(b)
		local fit_ok=1
		while (abs( exp(`lna_new') - exp(`lna_old') ) > 0.005 & `iter'<10) {
			local iter=`iter' + 1
			local lna_old = `lna_new'
			qui replace belief_s = exp(`lna_old')*m
			mat b_start[1,1]=1
			capture qui cmclogit choice belief_s diff_dist fmly_np_* ib0.Spec_ID, noconstant iterate(100) from(b_start, copy)
			if _rc!=0 {
				local fit_ok=0
				continue, break
			}
			local lna_new = `lna_old' + _b[belief_s]-1
			matrix b_start=e(b)
		}
		if `fit_ok'==0 continue
		local conv=e(converged)
		levelsof Spec_ID if Spec_ID>0, local(levels)
		foreach l of local levels {
			local lab : label (Spec_ID) `l'
			local npi=substr("`lab'",1,strpos("`lab'","-")-1)
			local yr=substr("`lab'",strpos("`lab'","-")+1,.)
			qui sum tot_patients_year if Spec_ID==`l'
			local tp=r(mean)
			qui sum yhat if Spec_ID==`l'
			local yh=r(mean)
			post fe (`i') (`eta') (`npi') (`yr') (_b[`l'.Spec_ID]) (_se[`l'.Spec_ID]) (`conv') (`tp') (`yh')
		}
	}
}
postclose fe

******************************************************************
** IV of the fixed effects on volume, yearly against two-period, on the same markets
use temp_s7_fe, clear
gen reg_weight=1/(coef_se^2)
qui sum coef_val, detail
keep if inrange(coef_val, r(p1), r(p99))
gen big_coef=(abs(coef_val)>6)
save temp_s7_fe, replace
levelsof hrr, local(big_hrrs)

file open fy using "${RESULTS_BASE}Congestion_Yearly.csv", write replace
file write fy "spec,eta,coef,se,n_obs,n_hrr" _n

foreach eta in 1 {
	use temp_s7_fe, clear
	keep if eta==`eta'
	qui tab hrr
	local nh=r(r)

	** pooled: year and HRR effects, as in O1 with years in place of the period
	ivreg2 coef_val i.Year big_coef i.hrr (tot_patients=yhat) [aweight=reg_weight], robust
	file write fy "yearly_pooled,`eta',`=_b[tot_patients]',`=_se[tot_patients]',`=e(N)',`nh'" _n

	** within surgeon: residualize on specialist effects, then IV on the residuals
	foreach v in coef_val tot_patients yhat big_coef {
		qui reghdfe `v' [aweight=reg_weight], absorb(Specialist_ID) resid(r_`v')
	}
	qui tab Year, gen(yr_)
	foreach v of varlist yr_* {
		qui reghdfe `v' [aweight=reg_weight], absorb(Specialist_ID) resid(r_`v')
	}
	ivreg2 r_coef_val r_yr_2 r_yr_3 r_yr_4 r_yr_5 r_yr_6 r_big_coef (r_tot_patients=r_yhat) [aweight=reg_weight], robust noconstant
	file write fy "yearly_within,`eta',`=_b[r_tot_patients]',`=_se[r_tot_patients]',`=e(N)',`nh'" _n

	** the main two-period estimate, all markets and the same large markets, from the O1 inputs
	use "${RESULTS_FINAL}StructureMyopicHRR_Spec_FEs_rhobar.dta", clear
	merge m:1 hrr Specialist_ID time_period using fe_distance, nogenerate keep(match)
	merge m:1 Specialist_ID time_period hrr using mean_capacity, nogenerate keep(match)
	gen reg_weight=1/(coef_se^2)
	qui sum coef_val, detail
	keep if inrange(coef_val, r(p1), r(p99))
	gen big_coef=(abs(coef_val)>6)
	keep if eta==`eta' & converged==1
	ivreg2 coef_val time_period big_coef i.hrr (tot_patients=yhat) [aweight=reg_weight], robust
	qui tab hrr
	file write fy "twoperiod_all,`eta',`=_b[tot_patients]',`=_se[tot_patients]',`=e(N)',`=r(r)'" _n
	gen big_hrr=0
	foreach h of local big_hrrs {
		replace big_hrr=1 if hrr==`h'
	}
	keep if big_hrr==1
	ivreg2 coef_val time_period big_coef i.hrr (tot_patients=yhat) [aweight=reg_weight], robust
	qui tab hrr
	file write fy "twoperiod_large,`eta',`=_b[tot_patients]',`=_se[tot_patients]',`=e(N)',`=r(r)'" _n
}
file close fy

use temp_s7_fe, clear
export delimited using "${RESULTS_BASE}Congestion_Yearly_FE.csv", replace
erase temp_s7_fe.dta

log close
