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
	local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
	matrix data_cleanup_`y' = J(10,12,.)
	do "${CODE_FILES}R1_Operations.do"
	do "${CODE_FILES}R2_Referrals.do"
	do "${CODE_FILES}R3_Patients.do"
	do "${CODE_FILES}R4_Physicians.do"
	do "${CODE_FILES}R5_Hospitals.do"
	do "${CODE_FILES}R6_Outcomes.do"

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
	
	
	** merge PCP characteristics
	if $RFR_Priority==1 {
		/* ** prioritizing the listed referring physician in the claims data (not typically a PCP)
		gen double pcp_npi=RFR_PCP_ID1
		replace pcp_npi=Claim_PCP_ID if pcp_npi==.
		gen pcp_source="Listed RFR" if pcp_npi==RFR_PCP_ID1 & pcp_npi!=Claim_PCP_ID & pcp_npi!=.
		replace pcp_source="Claims" if pcp_npi==Claim_PCP_ID & pcp_npi!=RFR_PCP_ID1 & pcp_npi!=.
		replace pcp_source="Both" if pcp_npi==RFR_PCP_ID1 & pcp_npi==Claim_PCP_ID & pcp_npi!=.
		*/
		
		** prioritizing frequency/recency of visits, but supplementing with referring physician field
		gen double pcp_npi=Claim_PCP_ID
		replace pcp_npi=RFR_PCP_ID1 if pcp_npi==.
		gen pcp_source="Claims" if pcp_npi==Claim_PCP_ID & pcp_npi!=RFR_PCP_ID1 & pcp_npi!=.
		replace pcp_source="Listed RFR" if pcp_npi!=Claim_PCP_ID & pcp_npi==RFR_PCP_ID1 & pcp_npi!=.
		replace pcp_source="Both" if pcp_npi==RFR_PCP_ID1 & pcp_npi==Claim_PCP_ID & pcp_npi!=.

	}
	
	else if $RFR_Priority==0 {
		gen double pcp_npi=Claim_PCP_ID
		gen pcp_source="Claims" if pcp_npi==Claim_PCP_ID & pcp_npi!=.
	}
	
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
	
	** focus on 65+ eligibles and drop duplicates
	drop op_physn_upin
	gen bene_age=int( (discharge-bene_birthday)/365.25)
	drop if bene_age<65 
	bys bene_id NPINUM admit: gen count=_N
	drop if count>1
	drop count
	matrix data_cleanup_`y'[10,11]=_N
	
	** define Practice_ID and Specialist_ID to use throughout other code...this can be as granular as an NPI or as broad as a practice group
	if $PCP_Only==1 {
		keep if pcp_phy_spec_broad==1
	}
	else if $PCP_Only==0 {
		keep if pcp_npi!=spec_npi
	}
	
	keep if spec_phy_spec_prim_1_name=="Orthopedic Surgery"
	
	if ${PCP_Practice}==1 {

		/* PCP & Specialist at Practice Level 
		gen double Practice_ID=pcp_phy_tin1
		gen double Specialist_ID=spec_phy_tin1
		
		preserve
		bys Practice_ID pcp_npi: gen prac_pcp=_N
		bys pcp_npi: egen max_prac_pcp=max(prac_pcp)
		keep if prac_pcp==max_prac_pcp
		bys Practice_ID pcp_npi: gen prac_pcp_obs=_n
		keep if prac_pcp_obs==1
		rename pcp_npi physician_id
		destring physician_id, replace force
		keep Practice_ID physician_id
		save "${DATA_FINAL}practice_pcp_xwalk_`y'.dta", replace
		restore
		
		preserve
		bys Specialist_ID spec_npi: gen prac_spec=_N
		bys spec_npi: egen max_prac_spec=max(prac_spec)
		keep if prac_spec==max_prac_spec
		bys Specialist_ID spec_npi: gen prac_spec_obs=_n
		keep if prac_spec_obs==1
		rename spec_npi physician_id
		destring physician_id, replace force
		keep Specialist_ID physician_id
		save "${DATA_FINAL}practice_spec_xwalk_`y'.dta", replace
		restore
		
		*/
		
		/* Specialist ONLY at practice level, PCP at physician level */
		gen double Practice_ID=pcp_npi
		gen double Specialist_ID=spec_phy_tin1
		
		preserve
		bys Specialist_ID spec_npi: gen prac_spec=_N
		bys spec_npi: egen max_prac_spec=max(prac_spec)
		keep if prac_spec==max_prac_spec
		bys Specialist_ID spec_npi: gen prac_spec_obs=_n
		keep if prac_spec_obs==1
		rename spec_npi physician_id
		destring physician_id, replace force
		keep Specialist_ID physician_id
		save "${DATA_FINAL}practice_spec_xwalk_`y'.dta", replace
		restore		

	}
	else if ${PCP_Practice}==0 {
		gen double Practice_ID=pcp_npi
		gen double Specialist_ID=spec_npi
	}
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
	do "${CODE_FILES}R7_Saliency.do"	
	
	** collect failure events and form running failure variables
	do "${CODE_FILES}R8_FailureEvents.do"	
	
	** combine referrals with failures and saliency
	use temp_referrals_`y', clear
	merge m:1 Practice_ID Specialist_ID admit using "${DATA_FINAL}Running_Pair_`y'.dta", nogenerate keep(master match)
	merge m:1 Practice_ID admit using "${DATA_FINAL}Running_PCP_`y'.dta", nogenerate keep(master match)
	merge m:1 Specialist_ID admit using "${DATA_FINAL}Running_Spec_`y'.dta", nogenerate keep(master match)
	merge m:1 Practice_ID bene_id admit using "${DATA_FINAL}fwup_visits_`y'.dta", nogenerate keep(master match)	
	save "${DATA_FINAL}Referrals_`y'_`r_type'.dta", replace
}

******************************************************************
** assess sample sizes, match quality, etc.
clear
forvalues y=2008/2018 {
	svmat data_cleanup_`y'
	rename data_cleanup_`y'1 code_section
	tostring code_section, replace
	replace code_section="R1_Operations" if _n==1
	replace code_section="R2_Referrals_Listed" if _n==2
	replace code_section="R2_Referrals_EM" if _n==3
	replace code_section="R3_Patients" if _n==4
	replace code_section="R4_Physicians" if _n==5
	replace code_section="R5_Hospitals" if _n==6
	replace code_section="R6_Outcomes" if _n==7
	replace code_section="R7_Saliency" if _n==8
	replace code_section="R8_FailureEvents" if _n==9
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
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${RESULTS_FINAL}build_2008.dta", clear
gen year=2008
forvalues y=2009/2018 {
	append using "${RESULTS_FINAL}build_`y'.dta"
	replace year=`y' if year==.
}
save "${RESULTS_FINAL}data_build_detail_`r_type'.dta", replace


use "${DATA_FINAL}Referrals_2008_`r_type'.dta", clear
forvalues y=2009/2018 {
	append using "${DATA_FINAL}Referrals_`y'_`r_type'.dta", force
}
sort Practice_ID Specialist_ID admit bene_id

save "${DATA_FINAL}FinalReferrals_`r_type'.dta", replace


******************************************************************
** Calculate cumulative runninng variables
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"

** cumulative events by pair
use "${DATA_FINAL}FinalReferrals_`r_type'.dta", clear
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
save "${DATA_FINAL}Cumulative_Pair_`r_type'.dta", replace


** cumulative events by pair with follow-up PCP visits
use "${DATA_FINAL}FinalReferrals_`r_type'.dta", clear
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
save "${DATA_FINAL}Cumulative_Pair_FW_`r_type'.dta", replace



** total events by pair
use "${DATA_FINAL}FinalReferrals_`r_type'.dta", clear
collapse (count) pair_patients_tot=bene_id (sum) pair_death_tot=mortality_90 pair_failures_tot=any_bad ///
	pair_readmit_tot=readmit pair_comp_tot=any_comp, by(Practice_ID Specialist_ID)
save "${DATA_FINAL}Total_Pair_`r_type'.dta", replace



** cumulative events by practice
use "${DATA_FINAL}FinalReferrals_`r_type'.dta", clear
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
save "${DATA_FINAL}Cumulative_PCP_`r_type'.dta", replace


** total events by practice
use "${DATA_FINAL}FinalReferrals_`r_type'.dta", clear
collapse (count) pcp_patients_tot=bene_id (sum) pcp_death_tot=mortality_90 pcp_failures_tot=any_bad ///
	pcp_readmit_tot=readmit pcp_comp_tot=any_comp, by(Practice_ID)
save "${DATA_FINAL}Total_PCP_`r_type'.dta", replace


** cumulative events by specialist
use "${DATA_FINAL}FinalReferrals_`r_type'.dta", clear
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
save "${DATA_FINAL}Cumulative_Spec_`r_type'.dta", replace

** total events by specialist
use "${DATA_FINAL}FinalReferrals_`r_type'.dta", clear
collapse (count) spec_patients_tot=bene_id (sum) spec_death_tot=mortality_90 spec_failures_tot=any_bad ///
	spec_readmit_tot=readmit spec_comp_tot=any_comp, by(Specialist_ID)
save "${DATA_FINAL}Total_Spec_`r_type'.dta", replace


local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
******************************************************************
** Identify established practices
do "${CODE_FILES}R9_EstablishedPCPs.do"

******************************************************************
** Calculate episode spending
do "${CODE_FILES}R10_EpisodeSpend.do"

******************************************************************
** Merge final data
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}FinalReferrals_`r_type'.dta", clear
merge m:1 pcp_npi using "${DATA_FINAL}EstPractice_`r_type'.dta", keep(master match) generate(EstPCPMatch)
merge 1:1 bene_id clm_id using "${DATA_FINAL}Episode_Spending.dta", keep(master match) generate(EpisodeMatch)
merge m:1 Practice_ID Specialist_ID admit using "${DATA_FINAL}Cumulative_Pair_`r_type'.dta", keep(master match) nogenerate
merge m:1 Practice_ID Specialist_ID admit using "${DATA_FINAL}Cumulative_Pair_FW_`r_type'.dta", keep(master match) nogenerate
merge m:1 Practice_ID admit using "${DATA_FINAL}Cumulative_PCP_`r_type'.dta", keep(master match) nogenerate
merge m:1 Specialist_ID admit using "${DATA_FINAL}Cumulative_Spec_`r_type'.dta", keep(master match) nogenerate

save "${DATA_FINAL}EstReferrals_`r_type'.dta", replace
