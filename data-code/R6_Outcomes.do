******************************************************************
**	Title:		R6_Outcomes
**			Incorporating outcome data 
**			(complications, mortality, readmissions)
**	Author:		Ian McCarthy
**	Date Created:	10/20/2019
**	Date Updated:	4/3/2024
******************************************************************

local t=$year

******************************************************************
/* Collect patient data (for mortality indicators) */
******************************************************************
** First import patient data and collect mortality information
if `t' < 2018 {
	insheet using "${DATA_SAS}ORTHOPATIENT_DATA_`t'.tab", tab clear
	save temp_mort1, replace

	local next=`t'+1
	insheet using "${DATA_SAS}ORTHOPATIENT_DATA_`next'.tab", tab clear
	keep bene_id bene_death_dt
	rename bene_death_dt bene_death_dt2
	bys bene_id: gen obs=_n
	keep if obs==1
	drop obs
	save temp_mort2, replace

	use temp_mort1, clear
	merge m:1 bene_id using temp_mort2, nogenerate keep(master match)
	gen death_date=bene_death_dt
	replace death_date=bene_death_dt2 if death_date==""
	bys bene_id: gen obs=_n
	keep if obs==1
	keep bene_id death_date
	save temp_mort, replace
}
else if `t' >= 2018 {
	insheet using "${DATA_SAS}ORTHOPATIENT_DATA_`t'.tab", tab clear
	gen death_date=bene_death_dt

	bys bene_id: gen obs=_n
	keep if obs==1
	keep bene_id death_date
	save temp_mort, replace
}

** Now collect other outcome data and reshape to wide form
insheet using "${DATA_SAS}ORTHOOUTCOMES_`t'.tab", tab clear
bys bene_id initial_id initial_admit initial_discharge: gen obs=_n
qui sum obs
local maxj=r(max)
reshape wide category event_count, i(bene_id initial_id initial_admit initial_discharge) j(obs)
rename initial_id clm_id
gen readmit=0
gen any_comp=0
forvalues j=1/`maxj' {
	replace readmit=1 if category`j'=="Readmit"
	replace any_comp=1 if category`j'!="Readmit"
}
keep bene_id clm_id readmit any_comp
save temp_read_comp, replace
	

use "${DATA_FINAL}OrthoStays_`t'.dta", clear
matrix data_cleanup_`t'[7,2]=_N

merge m:1 bene_id using temp_mort, keep(master match) nogenerate
matrix data_cleanup_`t'[7,3]=_N

merge 1:1 bene_id clm_id using temp_read_comp, keep(master match) nogenerate
replace readmit=0 if readmit==.
replace any_comp=0 if any_comp==.
matrix data_cleanup_`t'[7,4]=_N

gen death=date(death_date, "DMY")
format discharge %td
format death %td
gen mortality_90=( (death-discharge)<=90 & death!=. & discharge!=.)
gen mortality_60=( (death-discharge)<=60 & death!=. & discharge!=.)
gen mortality_30=( (death-discharge)<=30 & death!=. & discharge!=.)

keep bene_id clm_id readmit any_comp mortality_30 mortality_60 mortality_90
save "${DATA_FINAL}Outcomes_`t'.dta", replace
