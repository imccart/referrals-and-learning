******************************************************************
**	Title:		R2_Referrals
**			Identifying referring PCP from claims
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	10/11/2022
******************************************************************

local t=$year

******************************************************************
** Identify PCPs from MDPPAS Data

insheet using "${DATA_SAS}MDPPAS_V24_`t'.tab", tab clear
destring npi, force replace
rename npi physician_id
bys physician_id: gen obs=_n
drop if obs>1
drop obs
keep if spec_broad==1
keep physician_id
save temp_pcps, replace


******************************************************************
** Referring physician directly in claim
insheet using "${DATA_SAS}REFERRALSCARRIER_`t'.tab", tab clear
keep if rfr_physn_npi !=.
rename prf_physn_npi spec_npi
rename rfr_physn_npi physician_id
keep spec_npi physician_id bene_id clm_from_dt clm_thru_dt
matrix data_cleanup_`t'[2,2]=_N

if ${PCP_First}==1 {
	** merge to MDPPAS info and keep only the PCPs	
	merge m:1 physician_id using temp_pcps, nogenerate keep(match)
	matrix data_cleanup_`t'[2,3]=_N	
}
rename physician_id RFR_PCP_ID
bys spec_npi bene_id RFR_PCP_ID clm_from_dt clm_thru_dt: gen dup=_n
drop if dup>1
drop dup

matrix data_cleanup_`t'[2,4]=_N
bys spec_npi bene_id clm_from_dt clm_thru_dt: gen rfr_obs=_n
reshape wide RFR_PCP_ID, i(bene_id spec_npi clm_from_dt clm_thru_dt) j(rfr_obs)
destring spec_npi, replace

matrix data_cleanup_`t'[2,5]=_N
save "${DATA_FINAL}Referrals_Listed_`t'.dta", replace


******************************************************************
** "Previous Physician" Data (physician IDs from EM visits before surgery)
insheet using "${DATA_SAS}PRESURGERY_PHYSICIANS_`t'.tab", tab clear
destring physician_id, force replace

matrix data_cleanup_`t'[3,2]=_N

if ${PCP_First}==1 {
	** merge MDPPAS and keep only the PCPs
	merge m:1 physician_id using temp_pcps, nogenerate keep(match)
	matrix data_cleanup_`t'[3,3]=_N
}

bys bene_id date: egen max_visits=max(visits)
keep if max_visits==visits
bys bene_id date: gen num_max=_N
rename phy_tax_id pcp_tax_id
rename visits pcp_visits
rename max_visit_date pcp_max_visit
rename min_visit_date pcp_min_visit

** unique most-visited physicians
preserve
	keep if num_max==1
	keep bene_id date physician_id pcp_tax_id pcp_visits pcp_max_visit pcp_min_visit
	gen source="Most Visited"
	save temp_max, replace
restore

** break ties with most recent visit
keep if num_max>1
gen pcp_max_visit2=date(pcp_max_visit, "DMY")
bys bene_id date: egen pcp_last_date=max(pcp_max_visit2)
keep if pcp_last_date==pcp_max_visit2
bys bene_id date: gen num_max_recent=_N

preserve
	keep if num_max_recent==1
	keep bene_id date physician_id pcp_tax_id pcp_visits pcp_max_visit pcp_min_visit	
	gen source="Most Visited and Recent"
	save temp_max_recent, replace
restore

** retain the rest
keep if num_max_recent>1
bys bene_id date: gen phy_count=_n
keep physician_id pcp_tax_id pcp_visits bene_id date phy_count
reshape wide physician_id pcp_tax_id pcp_visits, i(bene_id date) j(phy_count)
keep bene_id date physician_id* pcp_tax_id* pcp_visits*
gen source="Who knows"
save temp_unknown, replace


******************************************************************
** Finalize dataset on PCPs
use temp_max, clear
append using temp_max_recent
**append using temp_unknown
matrix data_cleanup_`t'[3,4]=_N

rename physician_id Claim_PCP_ID
rename source pcp_source_claim
destring Claim_PCP_ID, replace
gen admit=date(date,"DMY")
drop date

sort bene_id admit
keep if pcp_visits >= ${PCP_Visit}
save "${DATA_FINAL}Referrals_Claims_`t'.dta", replace


