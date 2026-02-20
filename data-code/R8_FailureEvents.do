******************************************************************
**	Title:		R8_FailureEvents
**			Construct cumulative failure events for PCPs, Specialists, and PCP/specialist pairs
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	2/18/2026
******************************************************************

local t=$year

use temp_referrals_`t', clear
bys Practice_ID admit: gen obs=_n
keep if obs==1
keep Practice_ID admit
save temp_pcp_`t', replace

use temp_referrals_small_2008, clear
if `t'>2008 {
	forvalues c=2009/`t' {	
		append using temp_referrals_small_`c', force
	}
}
save temp_referral_stack, replace

** Stack all follow-up visit files for the lookback window
use "${DATA_FINAL}fwup_visits_2008.dta", clear
if `t'>2008 {
	forvalues c=2009/`t' {
		append using "${DATA_FINAL}fwup_visits_`c'.dta"
	}
}
save temp_fwup_stack, replace

use temp_referral_stack, clear
local date1=date("01JAN`t'","DMY")
local date2=date("31DEC`t'","DMY")
matrix data_cleanup_`t'[9,2]=_N

local step_pair=0
forvalues d=`date1'/`date2' {
	preserve
	keep if admit<`d' & admit>=`d'-365*5
	merge m:1 Practice_ID bene_id admit using temp_fwup_stack, nogenerate keep(master match)
	gen any_comp_fw=any_comp*fwup100
	gen readmit_fw=readmit*fwup100
	gen any_bad_fw=0
	replace any_bad_fw=1 if any_comp==1 & fwup100==1 & death==0
	replace any_bad_fw=1 if readmit==1 & fwup100==1 & death==0
	replace any_bad_fw=1 if death==1
	collapse_16 (count) pair_patients_run=bene_id ///
		(sum) pair_failures_run=any_bad pair_death_run=death pair_readmit_run=readmit pair_comp_run=any_comp ///
		(sum) pair_patients_run_fw=fwup100 pair_failures_run_fw=any_bad_fw pair_readmit_run_fw=readmit_fw pair_comp_run_fw=any_comp_fw, by(Practice_ID Specialist_ID)
	gen admit=`d'
	merge m:1 Practice_ID admit using temp_pcp_`t', nogenerate keep(match)
	qui count
	local dat_cnt=r(N)
	if `dat_cnt'>0 {
		local step_pair=`step_pair'+1
		save temp_reshape_pair_`step_pair', replace
	}
	restore
}
matrix data_cleanup_`t'[9,3]=_N

local step_pcp=0
forvalues d=`date1'/`date2' {
	preserve
	keep if admit<`d' & admit>=`d'-365*5
	merge m:1 Practice_ID bene_id admit using temp_fwup_stack, nogenerate keep(master match)
	gen any_comp_fw=any_comp*fwup100
	gen readmit_fw=readmit*fwup100
	gen any_bad_fw=0
	replace any_bad_fw=1 if any_comp==1 & fwup100==1 & death==0
	replace any_bad_fw=1 if readmit==1 & fwup100==1 & death==0
	replace any_bad_fw=1 if death==1
	collapse_16 (count) pcp_patients_run=bene_id ///
		(sum) pcp_failures_run=any_bad pcp_death_run=death pcp_readmit_run=readmit pcp_comp_run=any_comp ///
		(sum) pcp_patients_run_fw=fwup100 pcp_failures_run_fw=any_bad_fw pcp_readmit_run_fw=readmit_fw pcp_comp_run_fw=any_comp_fw, by(Practice_ID)
	gen admit=`d'
	merge 1:1 Practice_ID admit using temp_pcp_`t', nogenerate keep(match)
	qui count
	local dat_cnt=r(N)
	if `dat_cnt'>0 {
		local step_pcp=`step_pcp'+1
		save temp_reshape_pcp_`step_pcp', replace
	}
	restore
}
matrix data_cleanup_`t'[9,4]=_N

local step_spec=0
forvalues d=`date1'/`date2' {
	preserve
	keep if admit<`d' & admit>=`d'-365*5
	merge m:1 Practice_ID bene_id admit using temp_fwup_stack, nogenerate keep(master match)
	gen any_comp_fw=any_comp*fwup100
	gen readmit_fw=readmit*fwup100
	gen any_bad_fw=0
	replace any_bad_fw=1 if any_comp==1 & fwup100==1 & death==0
	replace any_bad_fw=1 if readmit==1 & fwup100==1 & death==0
	replace any_bad_fw=1 if death==1
	collapse_16 (count) spec_patients_run=bene_id ///
		(sum) spec_failures_run=any_bad spec_death_run=death spec_readmit_run=readmit spec_comp_run=any_comp ///
		(sum) spec_patients_run_fw=fwup100 spec_failures_run_fw=any_bad_fw spec_readmit_run_fw=readmit_fw spec_comp_run_fw=any_comp_fw, by(Specialist_ID)
	gen admit=`d'
	local step_spec=`step_spec'+1
	save temp_reshape_spec_`step_spec', replace
	restore
}
matrix data_cleanup_`t'[9,5]=_N

use temp_reshape_pair_1, clear
forvalues m=2/`step_pair' {
	append using temp_reshape_pair_`m'
}
save "${DATA_FINAL}Running_Pair_`t'.dta", replace
matrix data_cleanup_`t'[9,6]=_N


use temp_reshape_pcp_1
forvalues m=2/`step_pcp' {
	append using temp_reshape_pcp_`m'
}
save "${DATA_FINAL}Running_PCP_`t'.dta", replace
matrix data_cleanup_`t'[9,7]=_N


use temp_reshape_spec_1, clear
forvalues m=2/`step_spec' {
	append using temp_reshape_spec_`m'
}
save "${DATA_FINAL}Running_Spec_`t'.dta", replace
matrix data_cleanup_`t'[9,8]=_N
