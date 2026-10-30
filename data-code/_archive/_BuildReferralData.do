set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "S:\IMC969\Logs\PCP Referrals\BuildReferralData_`logdate'.log", replace

******************************************************************
**	Title:			Build Referral Data
**	Author:			Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	9/27/2021
******************************************************************

******************************************************************
** Preliminaries
set more off
cd "S:\IMC969\Temp and ado files\"
global DATA_SAS "S:\IMC969\SAS Data v2\"
global DATA_DARTMOUTH "S:\IMC969\Stata Uploaded Data\"
global DATA_AHA "S:\IMC969\Stata Uploaded Data\AHA Data\"
global DATA_ACS "S:\IMC969\Stata Uploaded Data\ACS Data\"
global DATA_COMPARE "S:\IMC969\Stata Uploaded Data\Hospital Compare\"
global DATA_HCRIS "S:\IMC969\Stata Uploaded Data\Hospital Cost Reports\"
global DATA_IPPS "S:\IMC969\Stata Uploaded Data\Inpatient PPS\"
global DATA_FINAL "S:\IMC969\Final Data\PCP Referrals\"
global CODE_FILES "S:\IMC969\Stata Code Files\PCP Referrals\"
global RESULTS_FINAL "S:\IMC969\Results\PCP Referrals\"


******************************************************************
** Run do-files for each year
forvalues y=2008/2018 {
	global year=`y'
	do "${CODE_FILES}R1_Patients_Physicians.do"
	do "${CODE_FILES}R2_ReferralData.do"
	do "${CODE_FILES}R3_Outcomes.do"	
	
	use temp_ortho, clear
	merge m:1 bene_id admit using temp_referrals, keep(master match) generate(EM_RFR)
	merge m:1 bene_id physician_npi clm_from_dt clm_thru_dt using temp_referral_listed, keep(master match) generate(Listed_RFR)
	
	merge 1:1 bene_id clm_id using temp_outcomes_all, keep(master match) nogenerate
	save "${DATA_FINAL}Referrals_`y'.dta", replace
}


******************************************************************
** Combine Data
forvalues t=2008/2018 {
	use "${DATA_FINAL}Referrals_`t'.dta", clear
	drop op_physn_upin
	
	gen double PCP_ID=RFR_PCP_ID1
	replace PCP_ID=Claim_PCP_ID if PCP_ID==.
	gen PCP_source="Listed RFR" if PCP_ID==RFR_PCP_ID1 & PCP_ID!=Claim_PCP_ID & PCP_ID!=.
	replace PCP_source="Claims" if PCP_ID==Claim_PCP_ID & PCP_ID!=RFR_PCP_ID1 & PCP_ID!=.
	replace PCP_source="Both" if PCP_ID==RFR_PCP_ID1 & PCP_ID==Claim_PCP_ID & PCP_ID!=.
	rename phy_tax_id PCP_taxid_claim
	rename phy_tax_id2 PCP_taxid_claim2
	rename visits pcp_visits_claim
	rename max_visit_date pcp_maxdate_claim
	rename min_visit_date pcp_mindate_claim
	rename source pcp_source_claim
	
	drop physician_id* phy_tax_id* visits*
	save temp_final, replace
	
	
	if `t'<2018 {
		insheet using "${DATA_SAS}MDPPAS_V23_`t'.tab", tab clear
	} 
	else if `t'==2018 {
		insheet using "${DATA_SAS}MDPPAS_V23_2017.tab", tab clear
	}

	destring npi, force replace
	rename npi PCP_ID
	foreach x of varlist name_last name_first name_middle sex birth_dt spec_broad spec_prim_1 spec_prim_1_name spec_prim_2_name ///
		spec_prim_2 spec_source spec_source_hosp pos_office pos_inpat pos_opd pos_er pos_nursing pos_asc pos_resid pos_other ///
		state state_multi cbsa_type cbsa_cd cbsa_name cbsa_multi npi_srvc_lines npi_allowed_amt npi_unq_benes tin1 tin1_legal_name ///
		tin1_srvc_month tin1_srvc_lines tin1_allowed_amt tin1_unq_benes tin2 tin2_legal_name tin2_srvc_month tin2_srvc_lines tin2_allowed_amt tin2_unq_benes {
			rename `x' pcp_`x'
		}
	bys PCP_ID: gen obs=_n
	drop if obs>1
	drop obs
	save temp_pcp_data, replace
	
	use temp_final, clear
	merge m:1 PCP_ID using temp_pcp_data, nogenerate keep(master match)
	
	save "${DATA_FINAL}FinalReferrals_`t'.dta", replace
}

use "${DATA_FINAL}FinalReferrals_2008.dta", clear
forvalues t=2009/2018 {
	append using "${DATA_FINAL}FinalReferrals_`t'.dta", force
}

keep if pcp_spec_broad==1 & phy_spec_prim_1_name=="Orthopedic Surgery"
**egen Practice_ID=group(pcp_tin1 pcp_cbsa_cd)
**egen Specialist_ID=group(phy_tin1 phy_cbsa_cd)
set type double
gen Practice_ID=PCP_ID
gen Specialist_ID=physician_npi
drop if Practice_ID==. | Specialist_ID==.
save "${DATA_FINAL}FinalReferrals.dta", replace


log close

