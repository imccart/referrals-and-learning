******************************************************************
**	Title:			R1_Patients_Physicians
**					Extract patient and physician data
**	Author:			Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	3/1/2021
******************************************************************

local t=$year

******************************************************************
/* Collect basic physician characteristics */
******************************************************************
insheet using "${DATA_SAS}OrthoPhysician_Data_`t'.tab", tab clear
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

save temp_physician_raw, replace


if `t'<2018 {
	insheet using "${DATA_SAS}MDPPAS_V23_`t'.tab", tab clear
} 
else if `t'==2018 {
	insheet using "${DATA_SAS}MDPPAS_V23_2017.tab", tab clear
}

destring npi, force replace
rename npi physician_npi
foreach x of varlist name_last name_first name_middle sex birth_dt spec_broad spec_prim_1 spec_prim_1_name spec_prim_2_name ///
	spec_prim_2 spec_source spec_source_hosp pos_office pos_inpat pos_opd pos_er pos_nursing pos_asc pos_resid pos_other ///
	state state_multi cbsa_type cbsa_cd cbsa_name cbsa_multi npi_srvc_lines npi_allowed_amt npi_unq_benes tin1 tin1_legal_name ///
	tin1_srvc_month tin1_srvc_lines tin1_allowed_amt tin1_unq_benes tin2 tin2_legal_name tin2_srvc_month tin2_srvc_lines tin2_allowed_amt tin2_unq_benes {
		rename `x' phy_`x'
	}
bys physician_npi: gen obs=_n
drop if obs>1
drop obs
	
save temp_physician_mdpps, replace

use temp_physician_raw, clear
merge 1:1 physician_npi using temp_physician_mdpps, nogenerate keep(master match)
save temp_physician_data, replace



******************************************************************
/* Collect basic patient characteristics */
******************************************************************
insheet using "${DATA_SAS}OrthoPatient_Data_`t'.tab", tab clear
save temp_patient, replace


******************************************************************
/* Collect ortho inpatient stays and */
******************************************************************
insheet using "${DATA_SAS}MajorJoint_`t'.tab", tab clear
rename org_npi_num NPINUM
rename op_physn_npi physician_npi
merge m:1 bene_id using temp_patient, nogenerate keep(master match)
merge m:1 physician_npi using temp_physician_data, nogenerate keep(master match)

** clean variables
foreach x of varlist prvdr_num icd_prcdr_cd1 icd_prcdr_cd2 icd_prcdr_cd3 icd_prcdr_cd4 icd_prcdr_cd5 ///
 icd_prcdr_cd6 icd_prcdr_cd7 icd_prcdr_cd8 icd_prcdr_cd9 icd_prcdr_cd10 {
 tostring `x', replace
}

** Create variables
gen birthday=date(bene_birth_dt, "DMY")
gen discharge=date(nch_bene_dschrg_dt, "DMY")
replace discharge=date(clm_thru_dt, "DMY") if discharge==.
gen admit=date(clm_from_dt,"DMY")
format birthday %td
format discharge %td
gen age=int( (discharge-birthday)/365.25)
gen los=discharge-admit+1

** Clean data for analysis
drop if age<65 
qui tab race, gen(race_)
qui tab gender, gen(gender_)

bys bene_id NPINUM admit: gen count=_N
drop if count>1
drop count

gen Year=`t'
save temp_ortho, replace
