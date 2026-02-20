******************************************************************
**	Title:		R1_Operations
**			Initial set of major joint replacements
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	10/11/2022
******************************************************************

local t=$year
insheet using "${DATA_SAS}MAJORJOINT_`t'.tab", tab clear
matrix data_cleanup_`t'[1,2]=_N

rename org_npi_num NPINUM
rename op_physn_npi spec_npi

** Clean ICD procedure codes
foreach x of varlist prvdr_num icd_prcdr_cd1 icd_prcdr_cd2 icd_prcdr_cd3 icd_prcdr_cd4 icd_prcdr_cd5 ///
 icd_prcdr_cd6 icd_prcdr_cd7 icd_prcdr_cd8 icd_prcdr_cd9 icd_prcdr_cd10 {
 tostring `x', replace
}

** New variables
gen discharge=date(nch_bene_dschrg_dt, "DMY")
replace discharge=date(clm_thru_dt, "DMY") if discharge==.
gen admit=date(clm_from_dt,"DMY")
format discharge %td
gen los=discharge-admit+1
gen Year=`t'
save "${DATA_FINAL}OrthoStays_`t'.dta", replace

matrix data_cleanup_`t'[1,3]=_N
