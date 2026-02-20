******************************************************************
**	Title:		Assignment_Alg
**			Investigate share of procedures lost under different algorithms for assigning referring physicians
**	Author:		Ian McCarthy
**	Date Created:	1/30/2023
**	Date Updated:	2/2/2023
******************************************************************
forvalues y=2013/2018 {


	insheet using "${DATA_SAS}MDPPAS_V24_`y'.tab", tab clear
	destring npi, force replace
	rename npi physician_id
	bys physician_id: gen obs=_n
	drop if obs>1
	drop obs
	keep if spec_broad==1
	keep physician_id
	save temp_pcps, replace


	insheet using "${DATA_SAS}REFERRALSCARRIER_`y'.tab", tab clear
	keep if rfr_physn_npi !=.
	rename prf_physn_npi spec_npi
	rename rfr_physn_npi physician_id
	keep spec_npi physician_id bene_id clm_from_dt clm_thru_dt

	rename physician_id RFR_PCP_ID
	bys spec_npi bene_id RFR_PCP_ID clm_from_dt clm_thru_dt: gen dup=_n
	drop if dup>1
	drop dup

	bys spec_npi bene_id clm_from_dt clm_thru_dt: gen rfr_obs=_n
	reshape wide RFR_PCP_ID, i(bene_id spec_npi clm_from_dt clm_thru_dt) j(rfr_obs)
	destring spec_npi, replace

	save temp_listed, replace
	
	
	
	insheet using "${DATA_SAS}PRESURGERY_PHYSICIANS_`y'.tab", tab clear
	destring physician_id, force replace

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


	use temp_max, clear
	append using temp_max_recent
	rename physician_id Claim_PCP_ID
	rename source pcp_source_claim
	destring Claim_PCP_ID, replace
	gen admit=date(date,"DMY")
	drop date

	sort bene_id admit
	save temp_claims, replace
	


	
	
	insheet using "${DATA_SAS}PRESURGERY_PHYSICIANS_`y'.tab", tab clear
	destring physician_id, force replace
	merge m:1 physician_id using temp_pcps, nogenerate keep(match)	

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


	use temp_max, clear
	append using temp_max_recent
	rename physician_id Claim_PCP_ID2
	rename source pcp_source_claim2
	rename pcp_visits pcp_visits2
	destring Claim_PCP_ID2, replace
	gen admit=date(date,"DMY")
	drop date

	sort bene_id admit
	keep bene_id admit Claim_PCP_ID2 pcp_source_claim2 pcp_visits2
	save temp_claims_pcp, replace


	
	

	use "${DATA_FINAL}OrthoStays_`y'.dta", clear
	
	** merge referring PCP ID from carrier claim frequency/recency
	merge m:1 bene_id admit using temp_claims, keep(master match) generate(EM_RFR)
	
	** merge referring PCP ID from carrier claim frequency/recency (limited to PCPs only)
	merge m:1 bene_id admit using temp_claims_pcp, keep(master match) generate(EM_RFR2)
	
	** merge referring PCP ID from claims listing
	merge m:1 bene_id spec_npi clm_from_dt clm_thru_dt using temp_listed, keep(master match) generate(Listed_RFR)
	keep bene_id spec_npi clm_id Year Claim_PCP_ID* pcp_visits* pcp_source_claim EM_RFR EM_RFR2 RFR_PCP_ID* Listed_RFR
	
	gen double physician_npi=Claim_PCP_ID
	merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) keepusing(phy_spec_broad phy_spec_prim_1 phy_spec_prim_1_name) nogenerate
	foreach x of varlist phy_spec_broad phy_spec_prim_1 phy_spec_prim_1_name {
		rename `x' claim_`x'
	}
	drop physician_npi

	gen double physician_npi=Claim_PCP_ID2
	merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) keepusing(phy_spec_broad phy_spec_prim_1 phy_spec_prim_1_name) nogenerate
	foreach x of varlist phy_spec_broad phy_spec_prim_1 phy_spec_prim_1_name {
		rename `x' claim2_`x'
	}
	drop physician_npi
	
	
	gen double physician_npi=RFR_PCP_ID1
	merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) keepusing(phy_spec_broad phy_spec_prim_1 phy_spec_prim_1_name phy_tin1) nogenerate
	foreach x of varlist phy_spec_broad phy_spec_prim_1 phy_spec_prim_1_name phy_tin1 {
		rename `x' rfr_`x'
	}
	drop physician_npi
	
	gen double physician_npi=spec_npi
	merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) keepusing(phy_tin1) nogenerate
	rename phy_tin1 op_phy_tin1
	drop physician_npi
	
	save temp_alg_check_`y', replace
}

use temp_alg_check_2013, clear
forvalues y=2014/2018 {
	append using temp_alg_check_`y'
}

** what is the distribution of specialties by source of referral?
table claim_phy_spec_broad Year if EM_RFR==3
table claim2_phy_spec_broad Year if EM_RFR2==3
table rfr_phy_spec_broad Year if Listed_RFR==3
table rfr_phy_spec_prim_1_name Year if rfr_phy_spec_broad==3 & Listed_RFR==3

** how many observations do we lose with different assignments?
count if EM_RFR==3
count if EM_RFR==3 & claim_phy_spec_broad==1
count if EM_RFR2==3
count if Listed_RFR==3
count if Listed_RFR==3 & rfr_phy_spec_broad==1
count if EM_RFR==3 | Listed_RFR==3
count if (rfr_phy_spec_broad==1 & Listed_RFR==3) | (claim_phy_spec_broad==1 & EM_RFR==3)
count if (rfr_phy_spec_broad==1 & Listed_RFR==3) | EM_RFR2==3
 
 
 
** how do visit counts change between any physician vs pcp only?
sum pcp_visits if EM_RFR==3, detail
sum pcp_visits if EM_RFR==3 & claim_phy_spec_broad==1, detail
sum pcp_visits2 if EM_RFR2==3, detail

gen diff_pcp_visits=pcp_visits-pcp_visits2
sum diff_pcp_visits if Claim_PCP_ID!=Claim_PCP_ID2, detail
sum diff_pcp_visits if Claim_PCP_ID!=Claim_PCP_ID2 & EM_RFR==3 & EM_RFR2==3, detail
tab claim_phy_spec_broad Year if Claim_PCP_ID!=Claim_PCP_ID2 & EM_RFR==3 & EM_RFR2==3
tab claim_phy_spec_broad Year if EM_RFR==3 & EM_RFR2!=3

tab claim_phy_spec_prim_1_name Year if claim_phy_spec_broad==2 & EM_RFR==3 & EM_RFR2!=3


** does the referring physician in the claim match the frequency/recency physician
gen match1=(Claim_PCP_ID==RFR_PCP_ID1) if Claim_PCP_ID!=. & RFR_PCP_ID1!=.
gen match2=(Claim_PCP_ID2==RFR_PCP_ID1) if Claim_PCP_ID2!=. & RFR_PCP_ID1!=.
gen match3=(Claim_PCP_ID==RFR_PCP_ID1) if Claim_PCP_ID!=. & claim_phy_spec_broad==1 & RFR_PCP_ID1!=.

** is referring physician in the same practice as operating physician
gen same_practice=(rfr_phy_tin1==op_phy_tin1) if rfr_phy_tin1!=. & op_phy_tin1!=.
gen same_physician=(RFR_PCP_ID1==spec_npi) if RFR_PCP_ID1!=. & spec_npi!=. & Listed_RFR==3
tab same_practice if rfr_phy_spec_broad==3 & Listed_RFR==3
tab same_physician Year if rfr_phy_spec_broad==3 & Listed_RFR==3
tab same_physician Year if Listed_RFR==3
