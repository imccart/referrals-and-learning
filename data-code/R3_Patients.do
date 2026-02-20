******************************************************************
**	Title:		R3_Patients
**			Extract patient data
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	10/11/2022
******************************************************************

local t=$year

insheet using "${DATA_SAS}ORTHOPATIENT_DATA_`t'.tab", tab clear
matrix data_cleanup_`t'[4,2]=_N

rename state_code bene_state
rename zip_cd bene_zip
rename gender bene_gender
rename race bene_race
gen bene_birthday=date(bene_birth_dt, "DMY")
format bene_birthday %td

gen zip=bene_zip
gen Year=`t'
merge m:1 zip Year using "${DATA_FINAL}ZipHRR.dta", nogenerate keep(master match)

rename hrrnum bene_hrr
drop zip hsanum hsacity hsastate hrrcity hrrstate Year
matrix data_cleanup_`t'[4,3]=_N
save "${DATA_FINAL}Patient_`t'.dta", replace
