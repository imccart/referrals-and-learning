******************************************************************
**	Title:		Build Referral Data
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	4/4/2024
******************************************************************

******************************************************************
** Preliminaries

** distance calculation using 
capture program drop finddist 
		program define finddist 
			args lat1 long1 lat2 long2 
			local radius_earth=6.378136e3
			tempvar val 
			gen double `val'=sin(_pi*abs(`lat1')/180)*sin(_pi*abs(`lat2')/180)+cos(_pi*abs(`lat1')/180)*cos(_pi*abs(`lat2')/180)*cos(_pi*abs(`long1')/180-_pi*abs(`long2')/180) 
			qui replace `val'=1 if (`val'>1)&(`val'!=.)
			gen distance=`radius_earth'*acos(`val')
		end 

				
******************************************************************
** Run do-files for each year
forvalues y=2008/2018 {
	global year=`y'
	matrix data_cleanup_`y' = J(10,12,.)
	do "${CODE_FILES}2a_stays.do"
	do "${CODE_FILES}2b_referring-pcp.do"
	do "${CODE_FILES}2c_patients.do"
	do "${CODE_FILES}2d_physicians.do"
	do "${CODE_FILES}2e_hospitals.do"
	do "${CODE_FILES}2f_outcomes.do"

	** begin with surgeries/inpatient stays
	use "${DATA_FINAL}OrthoStays_`y'.dta", clear
	matrix data_cleanup_`y'[10,2]=_N
	
	** merge referring PCP ID from carrier claim frequency/recency
	merge m:1 bene_id admit using "${DATA_FINAL}Referrals_Claims_`y'.dta", keep(master match) generate(EM_RFR)
	qui count if EM_RFR==3
	matrix data_cleanup_`y'[10,3]=r(N)
	
	** merge referring PCP ID from claims listing
	merge m:1 bene_id spec_npi clm_from_dt clm_thru_dt using "${DATA_FINAL}Referrals_Listed_`y'.dta", keep(master match) generate(Listed_RFR)
	qui count if Listed_RFR==3
	matrix data_cleanup_`y'[10,4]=r(N)
	
	qui count if Listed_RFR==3 | EM_RFR==3
	matrix data_cleanup_`y'[10,5]=r(N)
	
	** merge patient characteristics
	merge m:1 bene_id using "${DATA_FINAL}Patient_`y'.dta", keep(master match) generate(Patient_Match)
	qui count if Patient_Match==3
	matrix data_cleanup_`y'[10,6]=r(N)
	
	
	** merge specialist characteristics
	gen double physician_npi=spec_npi
	merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) generate(Specialist_Match)
	foreach x of varlist phy_* claims_* {
		rename `x' spec_`x'
	}
	drop physician_npi
	qui count if Specialist_Match==3
	matrix data_cleanup_`y'[10,7]=r(N)
	
	
	** the referring PCP is the most-visited PCP in the year before surgery (2b_referring-pcp); the referring physician listed on the claim is merged for the match counts only
	gen double pcp_npi=Claim_PCP_ID
	gen pcp_source="Claims" if pcp_npi==Claim_PCP_ID & pcp_npi!=.
	
	drop pcp_visits* pcp_tax_id pcp_max_visit pcp_min_visit pcp_source_claim RFR_PCP_* Listed_RFR EM_RFR Claim_PCP_ID
	gen double physician_npi=pcp_npi
	merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) generate(PCP_Match)
	foreach x of varlist phy_* claims_* {
		rename `x' pcp_`x'
	}
	drop physician_npi
	qui count if PCP_Match==3
	matrix data_cleanup_`y'[10,8]=r(N)
	
	** merge hospital data
	merge m:1 NPINUM using "${DATA_FINAL}Hospital_`y'.dta", keep(master match) generate(Hosp_Match)
	qui count if Hosp_Match==3
	matrix data_cleanup_`y'[10,9]=r(N)
	
	** merge outcomes data
	merge 1:1 bene_id clm_id using "${DATA_FINAL}Outcomes_`y'.dta", keep(master match) generate(Outcomes_Match)
	qui count if Outcomes_Match==3
	matrix data_cleanup_`y'[10,10]=r(N)
	
	** stays without a full 90-day outcome window (discharged within 90 days of the end of the data) are dropped
	drop if window_full==0

	** focus on 65+ eligibles and drop duplicates
	drop op_physn_upin
	gen bene_age=int( (discharge-bene_birthday)/365.25)
	drop if bene_age<65 
	bys bene_id NPINUM admit: gen count=_N
	drop if count>1
	drop count
	matrix data_cleanup_`y'[10,11]=_N
	
	** the referring physician must be a PCP
	keep if pcp_phy_spec_broad==1
	
	keep if spec_phy_spec_prim_1_name=="Orthopedic Surgery"
	
	** the unit of the specialist choice: _unit-surgeon.do or _unit-practice.do, loaded by the driver
	define_unit `y'
	drop if Practice_ID==. | Specialist_ID==.
	matrix data_cleanup_`y'[10,12]=_N
	
	** merge lat/long data and calculate distance
	gen zip=bene_zip
	merge m:1 zip using "${DATA_FINAL}LatLong.dta", nogenerate keep(master match)
	rename lat bene_lat
	rename lon bene_long
	drop zip

	** quality outcomes
	gen any_bad=(any_comp+readmit+mortality_90>0)
	
	local step=0
	foreach x of varlist spec_phy_zip* {
		local step=`step'+1
		gen zip=`x'
		merge m:1 zip using "${DATA_FINAL}LatLong.dta", nogenerate keep(master match)
		rename lat spec_lat`step'
		rename lon spec_long`step'
		drop zip
	}
	local spec_step=`step'

	local step=0
	foreach x of varlist pcp_phy_zip* {
		local step=`step'+1
		gen zip=`x'
		merge m:1 zip using "${DATA_FINAL}LatLong.dta", nogenerate keep(master match)
		rename lat pcp_lat`step'
		rename lon pcp_long`step'
		drop zip
	}
	local pcp_step=`step'

	local step=0
	foreach x of varlist hosp_zip* {
		local step=`step'+1
		gen zip=`x'
		merge m:1 zip using "${DATA_FINAL}LatLong.dta", nogenerate keep(master match)
		rename lat hosp_lat`step'
		rename lon hosp_long`step'
		drop zip
	}
	local hosp_step=`step'

	forvalues i=1/`spec_step' {
		finddist bene_lat bene_long spec_lat`i' spec_long`i'
		gen bene_phy_distance`i'=distance/1.609344
		drop distance
	}

	forvalues i=1/`pcp_step' {
		finddist bene_lat bene_long pcp_lat`i' pcp_long`i'
		gen bene_pcp_distance`i'=distance/1.609344
		drop distance
	}

	forvalues i=1/`hosp_step' {
		finddist bene_lat bene_long hosp_lat`i' hosp_long`i'
		gen bene_hosp_distance`i'=distance/1.609344
		drop distance
	}

	forvalues i=1/`spec_step' {
		forvalues j=1/`pcp_step' {
			finddist spec_lat`i' spec_long`i' pcp_lat`j' pcp_long`j'
			gen spec`i'_pcp`j'_distance=distance/1.609344
			drop distance
		}
	}

	save temp_referrals_`y', replace
	
	rename mortality_90 death
	keep Practice_ID Specialist_ID admit any_bad any_comp death readmit bene_id
	save temp_referrals_small_`y', replace

	** identify admits with follow-up visits to same PCP
	do "${CODE_FILES}2g_followup-visits.do"	
	
	** collect failure events and form running failure variables
	do "${CODE_FILES}2h_running-failures.do"	
	
	** combine referrals with failures and saliency
	use temp_referrals_`y', clear
	merge m:1 Practice_ID Specialist_ID admit using "${DATA_FINAL}Running_Pair_`y'.dta", nogenerate keep(master match)
	merge m:1 Practice_ID admit using "${DATA_FINAL}Running_PCP_`y'.dta", nogenerate keep(master match)
	merge m:1 Specialist_ID admit using "${DATA_FINAL}Running_Spec_`y'.dta", nogenerate keep(master match)
	merge m:1 Practice_ID bene_id admit using "${DATA_FINAL}fwup_visits_`y'.dta", nogenerate keep(master match)	
	save "${DATA_FINAL}Referrals_`y'.dta", replace
}

******************************************************************
** assess sample sizes, match quality, etc.
clear
forvalues y=2008/2018 {
	svmat data_cleanup_`y'
	rename data_cleanup_`y'1 code_section
	tostring code_section, replace
	replace code_section="2a_stays" if _n==1
	replace code_section="2b_referring-pcp_Listed" if _n==2
	replace code_section="2b_referring-pcp_EM" if _n==3
	replace code_section="2c_patients" if _n==4
	replace code_section="2d_physicians" if _n==5
	replace code_section="2e_hospitals" if _n==6
	replace code_section="2f_outcomes" if _n==7
	replace code_section="2g_followup-visits" if _n==8
	replace code_section="2h_running-failures" if _n==9
	replace code_section="Overall" if _n==10
	forvalues i=2/12 {
		local j=`i'-1
		rename data_cleanup_`y'`i' step_`j'
	}
	save "${RESULTS_FINAL}build_`y'.dta", replace
	clear
}

******************************************************************
** Append yearly data into one
use "${RESULTS_FINAL}build_2008.dta", clear
gen year=2008
forvalues y=2009/2018 {
	append using "${RESULTS_FINAL}build_`y'.dta"
	replace year=`y' if year==.
}
save "${RESULTS_FINAL}data_build_detail.dta", replace


use "${DATA_FINAL}Referrals_2008.dta", clear
forvalues y=2009/2018 {
	append using "${DATA_FINAL}Referrals_`y'.dta", force
}
sort Practice_ID Specialist_ID admit bene_id

save "${DATA_FINAL}FinalReferrals.dta", replace


******************************************************************
** Calculate cumulative runninng variables

** cumulative events by pair
use "${DATA_FINAL}FinalReferrals.dta", clear
sort Practice_ID Specialist_ID admit
by Practice_ID Specialist_ID: gen pair_death_cuml=sum(mortality_90)
by Practice_ID Specialist_ID: gen pair_failures_cuml=sum(any_bad)
by Practice_ID Specialist_ID: gen pair_patients_cuml=_n
by Practice_ID Specialist_ID: gen pair_readmit_cuml=sum(readmit)
by Practice_ID Specialist_ID: gen pair_comp_cuml=sum(any_comp)
by Practice_ID Specialist_ID admit: egen pair_death_today=total(mortality_90)
by Practice_ID Specialist_ID admit: egen pair_failures_today=total(any_bad)
by Practice_ID Specialist_ID admit: gen pair_patients_today=_N
by Practice_ID Specialist_ID admit: egen pair_readmit_today=total(readmit)
by Practice_ID Specialist_ID admit: egen pair_comp_today=total(any_comp)
foreach x of varlist pair_death_today pair_failures_today pair_patients_today pair_readmit_today pair_comp_today {
	replace `x'=0 if `x'==.
}
replace pair_death_cuml = pair_death_cuml-pair_death_today
replace pair_failures_cuml = pair_failures_cuml-pair_failures_today
replace pair_patients_cuml = pair_patients_cuml-pair_patients_today
replace pair_readmit_cuml = pair_readmit_cuml-pair_readmit_today
replace pair_comp_cuml = pair_comp_cuml - pair_comp_today
drop pair_death_today pair_failures_today pair_patients_today pair_readmit_today pair_comp_today

keep Practice_ID Specialist_ID admit pair_death_cuml pair_failures_cuml pair_readmit_cuml pair_patients_cuml pair_comp_cuml
bys Practice_ID Specialist_ID admit: gen obs=_n
keep if obs==1
drop obs
save "${DATA_FINAL}Cumulative_Pair.dta", replace


** cumulative events by pair with follow-up PCP visits
use "${DATA_FINAL}FinalReferrals.dta", clear
gen any_comp_fw=any_comp*fwup100
gen readmit_fw=readmit*fwup100
gen any_bad_fw=0
replace any_bad_fw=1 if any_comp==1 & fwup100==1 & mortality_90==0
replace any_bad_fw=1 if readmit==1 & fwup100==1 & mortality_90==0
replace any_bad_fw=1 if mortality_90==1

sort Practice_ID Specialist_ID admit
by Practice_ID Specialist_ID: gen pair_failures_cuml_fw=sum(any_bad_fw)
by Practice_ID Specialist_ID: gen pair_patients_cuml_fw=sum(fwup100)
by Practice_ID Specialist_ID: gen pair_readmit_cuml_fw=sum(readmit_fw)
by Practice_ID Specialist_ID: gen pair_comp_cuml_fw=sum(any_comp_fw)
by Practice_ID Specialist_ID admit: egen pair_failures_today=total(any_bad_fw)
by Practice_ID Specialist_ID admit: egen pair_patients_today=total(fwup100)
by Practice_ID Specialist_ID admit: egen pair_readmit_today=total(readmit_fw)
by Practice_ID Specialist_ID admit: egen pair_comp_today=total(any_comp_fw)

foreach x of varlist pair_failures_today pair_patients_today pair_readmit_today pair_comp_today {
	replace `x'=0 if `x'==.
}
replace pair_failures_cuml_fw = pair_failures_cuml_fw-pair_failures_today
replace pair_patients_cuml_fw = pair_patients_cuml_fw-pair_patients_today
replace pair_readmit_cuml_fw = pair_readmit_cuml_fw-pair_readmit_today
replace pair_comp_cuml_fw = pair_comp_cuml_fw-pair_comp_today

drop pair_failures_today pair_patients_today pair_readmit_today pair_comp_today

keep Practice_ID Specialist_ID admit pair_failures_cuml_fw pair_readmit_cuml_fw pair_patients_cuml_fw pair_comp_cuml_fw
bys Practice_ID Specialist_ID admit: gen obs=_n
keep if obs==1
drop obs
save "${DATA_FINAL}Cumulative_Pair_FW.dta", replace



** total events by pair
use "${DATA_FINAL}FinalReferrals.dta", clear
collapse (count) pair_patients_tot=bene_id (sum) pair_death_tot=mortality_90 pair_failures_tot=any_bad ///
	pair_readmit_tot=readmit pair_comp_tot=any_comp, by(Practice_ID Specialist_ID)
save "${DATA_FINAL}Total_Pair.dta", replace



** cumulative events by practice
use "${DATA_FINAL}FinalReferrals.dta", clear
collapse (count) patients=bene_id (sum) mortality_90 any_bad readmit any_comp, by(Practice_ID admit)

sort Practice_ID admit
by Practice_ID: gen pcp_death_cuml=sum(mortality_90)
by Practice_ID: gen pcp_failures_cuml=sum(any_bad)
by Practice_ID: gen pcp_patients_cuml=sum(patients)
by Practice_ID: gen pcp_readmit_cuml=sum(readmit)
by Practice_ID: gen pcp_comp_cuml=sum(any_comp)
by Practice_ID admit: egen pcp_death_today=total(mortality_90)
by Practice_ID admit: egen pcp_failures_today=total(any_bad)
by Practice_ID admit: egen pcp_patients_today=total(patients)
by Practice_ID admit: egen pcp_readmit_today=total(readmit)
by Practice_ID admit: egen pcp_comp_today=total(any_comp)
foreach x of varlist pcp_death_today pcp_failures_today pcp_patients_today pcp_readmit_today pcp_comp_today {
	replace `x'=0 if `x'==.
}
replace pcp_death_cuml = pcp_death_cuml-pcp_death_today
replace pcp_failures_cuml = pcp_failures_cuml-pcp_failures_today
replace pcp_patients_cuml = pcp_patients_cuml-pcp_patients_today
replace pcp_readmit_cuml = pcp_readmit_cuml-pcp_readmit_today
replace pcp_comp_cuml = pcp_comp_cuml-pcp_comp_today
drop pcp_death_today pcp_failures_today pcp_patients_today pcp_readmit_today pcp_comp_today

keep Practice_ID admit pcp_death_cuml pcp_failures_cuml pcp_readmit_cuml pcp_patients_cuml pcp_comp_cuml
bys Practice_ID admit: gen obs=_n
keep if obs==1
drop obs
save "${DATA_FINAL}Cumulative_PCP.dta", replace


** total events by practice
use "${DATA_FINAL}FinalReferrals.dta", clear
collapse (count) pcp_patients_tot=bene_id (sum) pcp_death_tot=mortality_90 pcp_failures_tot=any_bad ///
	pcp_readmit_tot=readmit pcp_comp_tot=any_comp, by(Practice_ID)
save "${DATA_FINAL}Total_PCP.dta", replace


** cumulative events by specialist
use "${DATA_FINAL}FinalReferrals.dta", clear
collapse (count) patients=bene_id (sum) mortality_90 any_bad readmit any_comp, by(Specialist_ID admit)

sort Specialist_ID admit
by Specialist_ID: gen spec_death_cuml=sum(mortality_90)
by Specialist_ID: gen spec_failures_cuml=sum(any_bad)
by Specialist_ID: gen spec_patients_cuml=sum(patients)
by Specialist_ID: gen spec_readmit_cuml=sum(readmit)
by Specialist_ID: gen spec_comp_cuml=sum(any_comp)
by Specialist_ID admit: egen spec_death_today=total(mortality_90)
by Specialist_ID admit: egen spec_failures_today=total(any_bad)
by Specialist_ID admit: egen spec_patients_today=total(patients)
by Specialist_ID admit: egen spec_readmit_today=total(readmit)
by Specialist_ID admit: egen spec_comp_today=total(any_comp)
foreach x of varlist spec_death_today spec_failures_today spec_patients_today spec_readmit_today spec_comp_today {
	replace `x'=0 if `x'==.
}
replace spec_death_cuml = spec_death_cuml-spec_death_today
replace spec_failures_cuml = spec_failures_cuml-spec_failures_today
replace spec_patients_cuml = spec_patients_cuml-spec_patients_today
replace spec_readmit_cuml = spec_readmit_cuml-spec_readmit_today
replace spec_comp_cuml = spec_comp_cuml-spec_comp_today
drop spec_death_today spec_failures_today spec_patients_today spec_readmit_today spec_comp_today

keep Specialist_ID admit spec_death_cuml spec_failures_cuml spec_readmit_cuml spec_patients_cuml spec_comp_cuml
bys Specialist_ID admit: gen obs=_n
keep if obs==1
drop obs
save "${DATA_FINAL}Cumulative_Spec.dta", replace

** total events by specialist
use "${DATA_FINAL}FinalReferrals.dta", clear
collapse (count) spec_patients_tot=bene_id (sum) spec_death_tot=mortality_90 spec_failures_tot=any_bad ///
	spec_readmit_tot=readmit spec_comp_tot=any_comp, by(Specialist_ID)
save "${DATA_FINAL}Total_Spec.dta", replace


******************************************************************
** Identify established practices
do "${CODE_FILES}2i_established-pcps.do"

******************************************************************
** Calculate episode spending
do "${CODE_FILES}2j_episode-spending.do"

******************************************************************
** Merge final data
use "${DATA_FINAL}FinalReferrals.dta", clear
merge m:1 pcp_npi using "${DATA_FINAL}EstPractice.dta", keep(master match) generate(EstPCPMatch)
merge 1:1 bene_id clm_id using "${DATA_FINAL}Episode_Spending.dta", keep(master match) generate(EpisodeMatch)
merge m:1 Practice_ID Specialist_ID admit using "${DATA_FINAL}Cumulative_Pair.dta", keep(master match) nogenerate
merge m:1 Practice_ID Specialist_ID admit using "${DATA_FINAL}Cumulative_Pair_FW.dta", keep(master match) nogenerate
merge m:1 Practice_ID admit using "${DATA_FINAL}Cumulative_PCP.dta", keep(master match) nogenerate
merge m:1 Specialist_ID admit using "${DATA_FINAL}Cumulative_Spec.dta", keep(master match) nogenerate

save "${DATA_FINAL}EstReferrals.dta", replace
