******************************************************************
**	Title:		R5_HospitalData
**	Description:	Collect hospital characteristics
**	Author:		Ian McCarthy
**	Date Created:	10/9/16
**	Date Updated:	10/11/2022
******************************************************************

local t=$year

if `t'==2008 {
	insheet using "${DATA_SAS}HOSPITAL_LOCATION_2009.tab", tab clear
} 
else {
	insheet using "${DATA_SAS}HOSPITAL_LOCATION_`t'.tab", tab clear
}

matrix data_cleanup_`t'[6,2]=_N

gsort hosp_npi -claim_count
by hosp_npi: egen max_claims=max(claim_count)
by hosp_npi: egen total_claims=sum(claim_count)
gen perc_claims=claim_count/total_claims
drop if perc_claims<0.10

replace hosp_zip=hosp_zip_pos if hosp_zip==.
by hosp_npi: gen obs=_n
keep hosp_zip hosp_npi claim_count obs
rename hosp_npi NPINUM
rename claim_count hosp_claim_count
reshape wide hosp_zip hosp_claim_count, i(NPINUM) j(obs)

matrix data_cleanup_`t'[6,3]=_N
save "${DATA_FINAL}Hospital_`t'.dta", replace



