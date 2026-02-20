******************************************************************
**	Title:		R4_Physicians
**			Extract patient and specialist data
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	10/11/2022
******************************************************************

local t=$year

** characteristics from the carrier files and nppes
insheet using "${DATA_SAS}ORTHOPHYSICIAN_DATA_`t'.tab", tab clear
matrix data_cleanup_`t'[5,2]=_N

replace primary_taxid=. if primary_taxid==0
replace secondary_taxid=. if secondary_taxid==0
bys primary_taxid: gen practice_size=_N
replace practice_size=. if primary_taxid==.
rename practice_size phy_prac_size_carrier
rename primary_specialty phy_specialty_carrier
rename nppes_hptc phy_hptc_nppes
rename nppes_update phy_update_nppes
keep physician_npi phy_prac_size_carrier phy_specialty_carrier phy_hptc_nppes phy_update_nppes

destring physician_npi, force replace
bys physician_npi: gen obs=_n
drop if obs>1
drop obs
matrix data_cleanup_`t'[5,3]=_N
save temp_physician_raw, replace

** characteristics from md-ppas
insheet using "${DATA_SAS}MDPPAS_V24_`t'.tab", tab clear
destring npi, force replace
rename npi physician_npi
bys physician_npi: gen obs=_n
drop if obs>1
drop obs
save temp_physician_mdpps, replace


** zip code information from the carrier files (already aggregated in SAS)
if `t'==2008 {
	insheet using "${DATA_SAS}PHYLOCATION_2009.tab", tab clear
}
else if `t'>2008 {
	insheet using "${DATA_SAS}PHYLOCATION_`t'.tab", tab clear
}
destring physician_npi, force replace
drop if physician_npi==.

preserve
keep physician_npi phy_zip_perf claims_perf
bys physician_npi phy_zip_perf: gen obs=_n
keep if obs==1
drop obs
gsort physician_npi -claims_perf
by physician_npi: egen max_claims=max(claims_perf)
by physician_npi: egen total_claims=sum(claims_perf)
gen perc_claims=claims_perf/total_claims
drop if perc_claims<0.10
by physician_npi: gen obs=_n
keep phy_zip_perf physician_npi claims_perf obs
reshape wide phy_zip_perf claims_perf, i(physician_npi) j(obs)
save temp_location_perf, replace
restore

preserve
keep physician_npi phy_zip_pos claims_pos
bys physician_npi phy_zip_pos: gen obs=_n
keep if obs==1
drop obs
gsort physician_npi -claims_pos
by physician_npi: egen max_claims=max(claims_pos)
by physician_npi: egen total_claims=sum(claims_pos)
gen perc_claims=claims_pos/total_claims
drop if perc_claims<0.10
by physician_npi: gen obs=_n
keep phy_zip_pos physician_npi claims_pos obs
reshape wide phy_zip_pos claims_pos, i(physician_npi) j(obs)
save temp_location_pos, replace
restore

bys physician_npi: gen obs=_n
keep if obs==1
keep physician_npi
merge 1:1 physician_npi using temp_location_perf, nogenerate
merge 1:1 physician_npi using temp_location_pos, nogenerate
save temp_location_data, replace


** merge specialist characteristics from all sources
use temp_physician_raw, clear
merge 1:1 physician_npi using temp_physician_mdpps, nogenerate keep(master match)
merge 1:1 physician_npi using temp_location_data, nogenerate keep(master match)


foreach x of varlist name_last name_first name_middle sex birth_dt spec_broad spec_prim_1 spec_prim_1_name ///
	spec_prim_2_name spec_prim_2 spec_source spec_source_hosp pos_office pos_inpat pos_opd pos_er ///
	pos_nursing pos_asc pos_resid pos_other state state_multi cbsa_type cbsa_cd cbsa_name cbsa_multi ///
	npi_srvc_lines npi_allowed_amt npi_unq_benes tin1 tin1_legal_name tin1_srvc_month tin1_srvc_lines ///
	tin1_allowed_amt tin1_unq_benes tin2 tin2_legal_name tin2_srvc_month tin2_srvc_lines tin2_allowed_amt tin2_unq_benes {
		rename `x' phy_`x'
	}

matrix data_cleanup_`t'[5,4]=_N	
save "${DATA_FINAL}Physician_`t'.dta", replace

