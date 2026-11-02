******************************************************************
**	Title:		1_geography
**			Clean and merge HRR data
**	Author:		Ian McCarthy
**	Date Created:	1/18/2022
**	Date Updated:	1/18/2022
******************************************************************

local step=0
forvalues y=8/17 {
	local step=`step'+1
	local t=string(`y',"%02.0f")
	import excel using "${DATA_UPLOAD}ZipHsaHrr`t'.xls", firstrow clear
	if `y'<17 {
		rename zipcode`t' zip
	}
	else if `y'==17 {
		rename zipcode2017 zip
	}
	gen Year=`t'+2000
	save temp_hrr_`step', replace
}

local step=`step'+1
insheet using "${DATA_UPLOAD}ZipHsaHrr18.csv", clear
rename zipcode18 zip
gen Year=2018
save temp_hrr_`step', replace

use temp_hrr_1
forvalues s=1/`step' {
	append using temp_hrr_`s'
}

bys zip Year hrrnum: gen obs=_n
keep if obs==1
drop obs

save "${DATA_FINAL}ZipHRR.dta", replace

** zip to coordinates
insheet using "${DATA_UPLOAD}zip-latlong-nber.csv", clear
rename zcta5 zip
rename intptlat lat
rename intptlon lon
destring zip, force replace
drop if zip==.
save "${DATA_FINAL}LatLong.dta", replace
