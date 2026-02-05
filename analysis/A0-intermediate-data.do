******************************************************************
**	Title:		Create intermediate datasets
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	8/29/2023
******************************************************************


******************************************************************
** Total specialist operations per year
forvalues y=2008/2018 {
	use "${DATA_FINAL}OrthoStays_`y'.dta", clear
	collapse (count) yearly_ops=bene_id, by(spec_npi)
	
	if ${PCP_Practice}==1 {
		rename spec_npi physician_id
		merge m:1 physician_id using "${DATA_FINAL}practice_spec_xwalk_`y'.dta", nogenerate keep(match)
		
		collapse (max) yearly_ops, by(Specialist_ID)
	}
	else if ${PCP_Practice}==0 {
		rename spec_npi Specialist_ID
	}
	
	gen Year=`y'
	save temp_ops_`y', replace
}
use temp_ops_2008, clear
forvalues y=2009/2018 {
	append using temp_ops_`y'
}
total yearly_ops if yearly_ops>=${SPEC_MIN}
local num=e(b)[1,1]
total yearly_ops
local denom=e(b)[1,1]
local coverage=round((`num'/`denom/')*100,.01)
display "still keeps `coverage'% of operations"

save temp_spec_yearly, replace


******************************************************************		
** HRR weights

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
keep if EstPCPMatch==3
keep if Year>=2013
gen prac_vi=0
replace prac_vi=1 if pcp_phy_tin1==spec_phy_tin1 & pcp_phy_tin1!=. & spec_phy_tin1!=.
replace prac_vi=1 if pcp_phy_tin1==spec_phy_tin2 & pcp_phy_tin1!=. & spec_phy_tin2!=. 
replace prac_vi=1 if pcp_phy_tin2==spec_phy_tin1 & pcp_phy_tin2!=. & spec_phy_tin1!=. 
replace prac_vi=1 if pcp_phy_tin2==spec_phy_tin2 & pcp_phy_tin2!=. & spec_phy_tin2!=.
keep bene_hrr Practice_ID Specialist_ID spec_failures_run pair_failures_run pcp_failures_run prac_vi spec_phy_tin1 spec_phy_tin2
bys bene_hrr: gen patients=_N

bys bene_hrr spec_phy_tin1: gen spec_practice_patients=_N
gen spec_share_sq=(spec_practice_patients/patients)^2
bys bene_hrr spec_phy_tin1: gen spec_prac_obs=_n
replace spec_share_sq=0 if spec_prac_obs>1

bys Practice_ID bene_hrr: gen pcp_obs=_n
replace pcp_obs=0 if pcp_obs>1
bys bene_hrr: egen pcp_total=total(pcp_obs)

bys Specialist_ID bene_hrr: gen spec_obs=_n
replace spec_obs=0 if spec_obs>1
bys bene_hrr: egen spec_total=total(spec_obs)

bys Specialist_ID Practice_ID bene_hrr: gen pair=_n
replace pair=0 if pair>1
bys Practice_ID bene_hrr: egen choice_size=total(pair)
bys bene_hrr: egen mean_choice_size=mean(choice_size)

bys bene_hrr: egen mean_spec_failures=mean(spec_failures_run)
bys bene_hrr: egen mean_pair_failures=mean(pair_failures_run)
bys bene_hrr: egen mean_pcp_failures=mean(pcp_failures_run)
bys bene_hrr: egen spec_hhi=total(spec_share_sq)
bys bene_hrr: egen mean_vi=mean(prac_vi)


bys bene_hrr: gen obs=_n
keep if obs==1
drop obs
rename bene_hrr hrr
keep hrr patients pcp_total spec_total mean_spec_failures mean_pair_failures mean_pcp_failures mean_choice_size spec_hhi mean_vi
save hrr_size, replace


******************************************************************
** Bene HRR
use "${DATA_FINAL}Patient_2013.dta", clear
gen Year=2013
forvalues y=2014/2018 {
	append using "${DATA_FINAL}Patient_`y'.dta"
	replace Year=`y' if Year==.
}
keep bene_id bene_hrr Year
save temp_bene_hrr, replace


******************************************************************
** Identify PCP Movers
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
keep Practice_ID bene_id bene_hrr pcp_phy_zip_perf1 pcp_phy_zip_perf2 Year
preserve
bys Practice_ID bene_hrr Year: gen pcp_hrr_patients=_N
bys Practice_ID Year: gen pcp_tot_patients=_N
gen pcp_hrr_share=pcp_hrr_patients/pcp_tot_patients
bys Practice_ID bene_hrr: egen pcp_hrr_min_year=min(Year)
bys Practice_ID bene_hrr: egen pcp_hrr_max_year=max(Year)
bys Practice_ID bene_hrr Year: gen obs=_n
keep if obs==1
keep Practice_ID Year bene_hrr pcp_hrr_patients pcp_hrr_share pcp_hrr_min_year pcp_hrr_max_year
save "${DATA_FINAL}PCP_HRR_Data_`r_type'.dta", replace
restore

preserve
bys Practice_ID pcp_phy_zip_perf1 Year: gen pcp_zip1_patients=_N
bys Practice_ID Year: gen pcp_tot_patients=_N
gen pcp_zip1_share=pcp_zip1_patients/pcp_tot_patients
bys Practice_ID pcp_phy_zip_perf1: egen pcp_zip1_min_year=min(Year)
bys Practice_ID pcp_phy_zip_perf1: egen pcp_zip1_max_year=max(Year)
bys Practice_ID pcp_phy_zip_perf1 Year: gen obs=_n
keep if obs==1
keep Practice_ID Year pcp_phy_zip_perf1 pcp_zip1_patients pcp_zip1_share pcp_zip1_min_year pcp_zip1_max_year
save "${DATA_FINAL}PCP_Zip1_Data_`r_type'.dta", replace
restore

bys Practice_ID pcp_phy_zip_perf2 Year: gen pcp_zip2_patients=_N
bys Practice_ID Year: gen pcp_tot_patients=_N
gen pcp_zip2_share=pcp_zip2_patients/pcp_tot_patients
bys Practice_ID pcp_phy_zip_perf2: egen pcp_zip2_min_year=min(Year)
bys Practice_ID pcp_phy_zip_perf2: egen pcp_zip2_max_year=max(Year)
bys Practice_ID pcp_phy_zip_perf2 Year: gen obs=_n
keep if obs==1
keep Practice_ID Year pcp_phy_zip_perf2 pcp_zip2_patients pcp_zip2_share pcp_zip2_min_year pcp_zip2_max_year
save "${DATA_FINAL}PCP_Zip2_Data_`r_type'.dta", replace


local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}PCP_HRR_Data_`r_type'.dta", clear
drop if Practice_ID==. | bene_hrr==.

preserve
collapse (min) min_hrr_year=Year, by(Practice_ID bene_hrr)
bys Practice_ID: egen first_year=min(min_hrr_year)
save pcp_hrr_year, replace
restore

forvalues y=2009/2017 {
	preserve
	keep if Year<`y'
	collapse (sum) hrr_patients_pre=pcp_hrr_patients, by(Practice_ID bene_hrr)
	save temp_hrr_pre`y', replace
	restore
	
	preserve
	keep if Year>`y'
	collapse (sum) hrr_patients_post=pcp_hrr_patients, by(Practice_ID bene_hrr)
	save temp_hrr_post`y', replace
	restore
}

forvalues y=2009/2017 {
	preserve
	keep if Year<`y'
	collapse (sum) total_patients_pre=pcp_hrr_patients, by(Practice_ID)
	save temp_all_pre`y', replace
	restore
	
	preserve
	keep if Year>`y'
	collapse (sum) total_patients_post=pcp_hrr_patients, by(Practice_ID)
	save temp_all_post`y', replace
	restore
}

forvalues y=2009/2017 {
	use temp_hrr_pre`y', clear
	merge 1:1 Practice_ID bene_hrr using temp_hrr_post`y', generate(pre_post)
	merge m:1 Practice_ID using temp_all_post`y', nogenerate
	merge m:1 Practice_ID using temp_all_pre`y', nogenerate
	gen overlap=(pre_post==3)
	bys Practice_ID: egen any_overlap=max(overlap)
	keep if hrr_patients_post!=. & hrr_patients_pre==. & any_overlap==0 & total_patients_pre>10 & total_patients_pre!=.
	save movers`y', replace
}

use movers2009, clear
forvalues y=2010/2017 {
	append using movers`y'
	if _N>0 {
		bys Practice_ID bene_hrr: gen obs=_n
		keep if obs==1
		drop obs
	}
}
merge 1:1 Practice_ID bene_hrr using pcp_hrr_year, nogenerate keep(master match)
drop if first_year==min_hrr_year
keep Practice_ID bene_hrr min_hrr_year hrr_patients_post hrr_patients_pre
save temp_pcp_mover, replace


** Recreate small version of final choice set data
local step=0
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
forvalues i=1/457 {
	capture confirm file "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta"
	if _rc==0 {
		local step=`step'+1
		use "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta", clear
		do "${CODE_FILES}_clean-analysis.do"

		** prepare for cmclogit syntax
		egen referral=group(bene_id admit)
		keep Practice_ID Specialist_ID choice referral case_obs casevar common_ref ///
			pair_patients_run pair_failures_run pair_success_run ///
			pcp_patients_run pcp_failures_run ///
			spec_patients_run spec_failures_run ///
			spec_patients_tot spec_success_tot ///
			diff_dist spec_qual prac_vi pair_new fmly_np_* Year admit
		gen hrr=`i'
		egen rho=mean(spec_qual)
		foreach eta in 1 5 {
			gen m_git_eta`eta'=(rho*`eta' + pair_success_run)/(`eta' + pair_patients_run)
			local beta=0.95
			gen v_git_eta`eta' = m_git_eta`eta'*(1-m_git_eta`eta')/(pair_patients_run+1)
			gen s_git_eta`eta' = -(log(`beta')*(pair_patients_run+1))^(-1)
			gen psi_git_eta`eta'=sqrt(s_git_eta`eta'/2)
			replace psi_git_eta`eta'=0.49 - 0.11*(1/sqrt(s_git_eta`eta')) if s_git_eta`eta'>0.2 & s_git_eta`eta' <=1
			replace psi_git_eta`eta'=0.63 - 0.26*(1/sqrt(s_git_eta`eta')) if s_git_eta`eta'>1   & s_git_eta`eta'<=5
			replace psi_git_eta`eta'=0.77 - 0.58*(1/sqrt(s_git_eta`eta')) if s_git_eta`eta'>5   & s_git_eta`eta'<=15
			replace psi_git_eta`eta'=sqrt(2*log(s_git_eta`eta') - log(log(s_git_eta`eta')) - log(16*_pi)) if s_git_eta`eta'>15
			gen gittins_eta`eta'=m_git_eta`eta' + sqrt(v_git_eta`eta')*psi_git_eta`eta'
		}

		gen fmly=log(1+pair_patients_run)
		if ${CONG_t}==1 {
			gen time_period=(Year>2015)
			bys Specialist_ID time_period: egen tot_patients_time=sum(choice)
		} 
		bys Specialist_ID: egen tot_patients=sum(choice)
		
				
		save temp_est_data1, replace
		if `step'==1 {
			save temp_est_data, replace
		}
		else if `step'>1 {
			use temp_est_data, clear
			append using temp_est_data1
			save temp_est_data, replace
		}
	}
}
save "${DATA_FINAL}ChoiceEstData_Summary.dta", replace
