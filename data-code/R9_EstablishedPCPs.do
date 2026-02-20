******************************************************************
** Title:		R9_EstablishedPCPs
**			Identify "established" PCPs to limit final analysis
** Author:		Ian McCarthy
** Date Created:	1/18/2022
** Date Updated:	10/14/2022
** Notes:		"Established" defined as a PCP with at least
**			 20 referrals total and nonzero referrals over
**			 a three year period.
******************************************************************

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
******************************************************************
** Established PCPs
use "${DATA_FINAL}FinalReferrals_`r_type'.dta", clear
sort pcp_npi spec_npi Year
by pcp_npi spec_npi : gen pair_count=_n
by pcp_npi spec_npi : egen first_year=min(Year)
gen new_pair=(pair_count==1 & first_year==Year)

bys pcp_npi pcp_phy_tin1 Year: gen pair_pcp=_n
replace pair_pcp=0 if pair_pcp>1
collapse (count) patients=bene_id (sum) unique_spec=new_pair practice_size=pair_pcp, by(pcp_npi Year)
reshape wide patients practice_size unique_spec, i(pcp_npi) j(Year)
foreach x of varlist patients* unique_spec* practice_size* {
	replace `x'=0 if `x'==.
}

reshape long patients unique_spec practice_size, i(pcp_npi) j(Year)
sort pcp_npi Year
by pcp_npi: gen cumulative_spec=sum(unique_spec)
save "${DATA_FINAL}PracticeYears_`r_type'.dta", replace


use "${DATA_FINAL}PracticeYears_`r_type'.dta", clear
keep if patients>0
by pcp_npi: egen total_patients=total(patients)
keep pcp_npi Year total_patients

tsset pcp_npi Year
gen run = .
by pcp_npi: replace run = cond(L.run == ., 1, L.run + 1)
by pcp_npi: egen maxrun = max(run)
keep if maxrun>=3 & total_patients>=20

bys pcp_npi: gen obs=_n
keep if obs==1
drop obs
keep pcp_npi total_patients maxrun
save "${DATA_FINAL}EstPractice_`r_type'.dta", replace
