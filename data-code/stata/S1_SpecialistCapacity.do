******************************************************************
**	Title:		Specialist Capacity Data
**	Author:		Ian McCarthy
**	Date Created:	5/4/2023
**	Date Updated:	5/4/2023
******************************************************************

				
******************************************************************
** Run do-files for each year
forvalues y=2008/2018 {

	** begin with surgeries/inpatient stays
	use "${DATA_FINAL}OrthoStays_`y'.dta", clear
	merge m:1 bene_id using "${DATA_FINAL}Patient_`y'.dta", nogenerate keep(master match)
	
	preserve
	gen quarter=qofd(admit)
	collapse (count) bene_id, by(spec_npi quarter bene_hrr)
	format quarter %tq
	save temp_spec_quarter_`y', replace
	restore
	
	collapse (count) bene_id, by(spec_npi Year bene_hrr)
	save temp_spec_year_`y', replace
	
}

use temp_spec_quarter_2008, clear
forvalues y=2009/2018 {
	append using temp_spec_quarter_`y'
}
save temp_spec_quarter_all, replace

use temp_spec_year_2008, clear
forvalues y=2009/2018 {
	append using temp_spec_year_`y'
}
save temp_spec_year_all, replace



foreach x of newlist quarter year {
	use temp_spec_`x'_2008, clear
	forvalues y=2009/2018 {
		append using temp_spec_`x'_`y'
	}
	collapse (p90) capacity_p90=bene_id (p75) capacity_p75=bene_id, by(spec_npi)
	save temp_spec_capacity_`x', replace
}


use temp_spec_quarter_all, clear
merge m:1 spec_npi using temp_spec_capacity_quarter, keep(master match) nogenerate
rename bene_id patients
gen cong_90=patients/capacity_p90
gen cong_75=patients/capacity_p75
replace cong_90=1 if cong_90>1
replace cong_75=1 if cong_75>1
save "${DATA_FINAL}SpecialistCapacity_quarter.dta", replace


use temp_spec_year_all, clear
merge m:1 spec_npi using temp_spec_capacity_year, keep(master match) nogenerate
rename bene_id patients
gen cong_90=patients/capacity_p90
gen cong_75=patients/capacity_p75
replace cong_90=1 if cong_90>1
replace cong_75=1 if cong_75>1
save "${DATA_FINAL}SpecialistCapacity_year.dta", replace

