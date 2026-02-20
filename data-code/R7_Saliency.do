******************************************************************
**	Title:		R7_Saliency
**			Identifying follow-up visits to same PCPs
**	Author:		Ian McCarthy
**	Date Created:	7/28/2022
**	Date Updated:	10/11/2022
******************************************************************
local t=$year

******************************************************************
** Total E&M visits by physician, bene, and year
insheet using "${DATA_SAS}PCPCARRIER_`t'.tab", tab clear
destring physician_id, replace force

gen double Practice_ID=physician_id
/* If allowing PCP at practice level too
if ${PCP_Practice}==1 {
	merge m:1 physician_id using "${DATA_FINAL}practice_pcp_xwalk_`t'.dta", nogenerate keep(master match)
}
else if ${PCP_Practice}==0 {
	gen double Practice_ID=physician_id
}
*/
gen pcp_visit_date=date(visit_date,"DMY")
format pcp_visit_date %td
keep Practice_ID bene_id pcp_visit_date
save temp_saliency0, replace

if `t'<2018 {
	local t_plus=`t'+1
	insheet using "${DATA_SAS}PCPCARRIER_`t_plus'.tab", tab clear
	destring physician_id, replace force
	gen double Practice_ID=physician_id	
	/*
	if ${PCP_Practice}==1 {
		merge m:1 physician_id using "${DATA_FINAL}practice_pcp_xwalk_`t'.dta", nogenerate keep(master match)
	}
	else if ${PCP_Practice}==0 {
		gen double Practice_ID=physician_id
	}
	*/
	gen pcp_visit_date=date(visit_date,"DMY")
	format pcp_visit_date %td
	drop if pcp_visit_date>d(01apr`t_plus')
	keep Practice_ID bene_id pcp_visit_date
	save temp_saliency1, replace
	
	use temp_saliency0, clear
	append using temp_saliency1	
}
else if `t'>=2018 {
	use temp_saliency0, clear
}
save temp_saliency, replace

******************************************************************
** Bene/visit information for each referral
use temp_referrals_small_`t', clear
keep Practice_ID bene_id admit
format admit %td
bys Practice_ID bene_id: gen obs=_n
qui sum obs
local max_wide=r(max)
reshape wide admit, i(Practice_ID bene_id) j(obs)
save temp_referral_wide_`t', replace

******************************************************************
** Merge surgery referrals and PCP visits
use temp_saliency, clear
merge m:1 Practice_ID bene_id using temp_referral_wide_`t', keep(match) nogenerate
matrix data_cleanup_`t'[8,2]=_N
gen drop_fwup=1

** identify f-u visits within 1, 2, 3, 6, and 12 months (allowing for a 10 day window)
forvalues j=1/`max_wide' {
	foreach i in 40 70 100 190 375 {
		gen fwup`i'_`j'=(pcp_visit_date>admit`j' & pcp_visit_date<=(admit`j'+`i') & admit`j'!=.)
		replace drop_fwup=0 if fwup`i'_`j'!=0 & drop_fwup==1
	}
}
drop if drop_fwup==1
matrix data_cleanup_`t'[8,3]=_N
drop drop_fwup pcp_visit_date

forvalues m=1/`max_wide' {
	preserve
	keep fwup40_`m' fwup70_`m' fwup100_`m' fwup190_`m' fwup375_`m' admit`m' Practice_ID bene_id
	rename admit`m' admit
	rename fwup40_`m' fwup40
	rename fwup70_`m' fwup70
	rename fwup100_`m' fwup100
	rename fwup190_`m' fwup190
	rename fwup375_`m' fwup375
	keep if admit!=.
	if _N>0 {
		collapse (max) fwup40 fwup70 fwup100 fwup190 fwup375, by(Practice_ID bene_id admit)
		gen Year=`t'
	}
	save temp_fwup`m', replace emptyok
	restore
}

use temp_fwup1, clear
forvalues m=2/`max_wide' {
	append using temp_fwup`m'
}

bys Practice_ID bene_id admit: gen obs=_n
keep if obs==1
drop obs
save "${DATA_FINAL}fwup_visits_`t'.dta", replace
