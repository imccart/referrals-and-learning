******************************************************************
**	Title:			R2_ReferralData
**					Referring physicians (PCPs) merged to specialist
**					and physician data
**	Author:			Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	5/3/2021
******************************************************************

local t=$year

******************************************************************
** Referring physician directly in claim
insheet using "${DATA_SAS}ReferralsCarrier_`t'.tab", tab clear
keep if rfr_physn_npi !=.
rename prf_physn_npi physician_npi
rename rfr_physn_npi RFR_PCP_ID
keep physician_npi RFR_PCP_ID bene_id clm_from_dt clm_thru_dt
bys physician_npi bene_id RFR_PCP_ID clm_from_dt clm_thru_dt: gen dup=_n
drop if dup>1
drop dup

bys physician_npi bene_id clm_from_dt clm_thru_dt: gen rfr_obs=_n
reshape wide RFR_PCP_ID, i(bene_id physician_npi clm_from_dt clm_thru_dt) j(rfr_obs)
destring physician_npi, replace
save temp_referral_listed, replace


******************************************************************
** "Previous Physician" Data (physician IDs from EM visits before surgery)
insheet using "${DATA_SAS}PreSurgery_Physicians_`t'.tab", tab clear
save temp_prephy, replace

******************************************************************
** Identify the PCP for each patient
bys bene_id date: egen max_visits=max(visits)
keep if max_visits==visits
bys bene_id date: gen num_max=_N

** unique most-visited physicians
preserve
	keep if num_max==1
	keep bene_id date physician_id phy_tax_id visits max_visit_date min_visit_date
	gen source="Most Visited"
	save temp_max, replace
restore

** break ties with most recent visit
keep if num_max>1
gen max_visit_date2=date(max_visit_date, "DMY")
bys bene_id date: egen last_date=max(max_visit_date2)
keep if last_date==max_visit_date2
bys bene_id date: gen num_max_recent=_N

preserve
	keep if num_max_recent==1
	keep bene_id date physician_id phy_tax_id visits max_visit_date min_visit_date	
	gen source="Most Visited and Recent"
	save temp_max_recent, replace
restore

** retain the rest
keep if num_max_recent>1
bys bene_id date: gen phy_count=_n
keep physician_id phy_tax_id visits bene_id date phy_count
reshape wide physician_id phy_tax_id visits, i(bene_id date) j(phy_count)
keep bene_id date physician_id* phy_tax_id* visits*
gen source="Who knows"
save temp_unknown, replace


******************************************************************
** Finalize dataset on PCPs
use temp_max, clear
append using temp_max_recent
append using temp_unknown

gen Year=`t'
rename physician_id Claim_PCP_ID
destring Claim_PCP_ID, replace
gen admit=date(date,"DMY")
drop date

sort bene_id admit
save temp_referrals, replace


