******************************************************************
**	Title:		Construct Choice Sets unique to DRG
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	12/7/2022
******************************************************************


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
** Prepare Data for Random Sample

** unique referrals
use "${DATA_FINAL}EstReferrals.dta", clear
bys Practice_ID: gen unique_practice=_n
keep if unique_practice==1
keep Practice_ID
save "${DATA_FINAL}UniquePractice.dta", replace

** sample of unique referrals
use "${DATA_FINAL}UniquePractice.dta", clear
sample 50
save "${DATA_FINAL}RandomSample.dta", replace



******************************************************************
** Identify PCP Movers
use "${DATA_FINAL}EstReferrals.dta", clear
keep Practice_ID bene_id bene_hrr pcp_phy_zip_perf1 pcp_phy_zip_perf2 Year
preserve
bys Practice_ID bene_hrr Year: gen pcp_hrr_patients=_N
bys Practice_ID Year: gen pcp_tot_patients=_N
gen pcp_hrr_share=pcp_hrr_patients/pcp_tot_patients
bys Practice_ID bene_hrr: egen pcp_hrr_min_year=min(Year)
bys Practice_ID bene_hrr: egen pcp_hrr_max_year=max(Year)
bys Practice_ID bene_hrr Year: gen obs=_n
keep if obs==1
keep Practice_ID Year bene_hrr pcp_hrr_patients pcp_hrr_share pcp_hrr_min_year pcp_hrr_max_year
save "${DATA_FINAL}PCP_HRR_Data.dta", replace
restore

preserve
bys Practice_ID pcp_phy_zip_perf1 Year: gen pcp_zip1_patients=_N
bys Practice_ID Year: gen pcp_tot_patients=_N
gen pcp_zip1_share=pcp_zip1_patients/pcp_tot_patients
bys Practice_ID pcp_phy_zip_perf1: egen pcp_zip1_min_year=min(Year)
bys Practice_ID pcp_phy_zip_perf1: egen pcp_zip1_max_year=max(Year)
bys Practice_ID pcp_phy_zip_perf1 Year: gen obs=_n
keep if obs==1
keep Practice_ID Year pcp_phy_zip_perf1 pcp_zip1_patients pcp_zip1_share pcp_zip1_min_year pcp_zip1_max_year
save "${DATA_FINAL}PCP_Zip1_Data.dta", replace
restore

bys Practice_ID pcp_phy_zip_perf2 Year: gen pcp_zip2_patients=_N
bys Practice_ID Year: gen pcp_tot_patients=_N
gen pcp_zip2_share=pcp_zip2_patients/pcp_tot_patients
bys Practice_ID pcp_phy_zip_perf2: egen pcp_zip2_min_year=min(Year)
bys Practice_ID pcp_phy_zip_perf2: egen pcp_zip2_max_year=max(Year)
bys Practice_ID pcp_phy_zip_perf2 Year: gen obs=_n
keep if obs==1
keep Practice_ID Year pcp_phy_zip_perf2 pcp_zip2_patients pcp_zip2_share pcp_zip2_min_year pcp_zip2_max_year
save "${DATA_FINAL}PCP_Zip2_Data.dta", replace


******************************************************************
** Final choice sets
forvalues y=2013/2018 {
	use "${DATA_FINAL}Referrals_`y'.dta", clear
	keep if clm_drg_cd==470 | clm_drg_cd==469
	keep Specialist_ID hosp_lat1 hosp_long1 hosp_lat2 hosp_long2
	bys Specialist_ID hosp_lat1 hosp_long1 hosp_lat2 hosp_long2: gen obs=_n
	keep if obs==1
	drop obs
	
	bys Specialist_ID: gen obs=_n
	reshape wide hosp_lat1 hosp_long1 hosp_lat2 hosp_long2, i(Specialist_ID) j(obs)
	foreach x of varlist hosp_long* hosp_lat* {
		rename `x' spec_`x'
	}
	save temp_spec_hosp, replace
	
	use "${DATA_FINAL}Referrals_`y'.dta", clear
	keep if clm_drg_cd==470 | clm_drg_cd==469
	keep Practice_ID Specialist_ID clm_drg_cd bene_hrr bene_id clm_id admit bene_lat* bene_long* hosp_lat* hosp_long*
	drop if bene_hrr==.
	qui sum bene_hrr
	local max_group=r(max)
	save temp_data, replace

	** form set of all specialists in the market (in that year)
	use temp_data, clear
	keep if clm_drg_cd==470 | clm_drg_cd==469
	bys Specialist_ID bene_hrr: gen obs=_n
	keep if obs==1
	drop obs
	rename Specialist_ID Specialist_Option
	save temp_choice_spec, replace	
	
	** merge m:1 Practice_ID using "${DATA_FINAL}RandomSample.dta", nogenerate keep(match)	
	** full join to original data
	forvalues h=1/`max_group' {
		use temp_data, clear
		keep if bene_hrr==`h'
		qui count
		if r(N)>0 {
			joinby bene_hrr using temp_choice_spec
			gen choice=(Specialist_Option==Specialist_ID)
			gen double Specialist_Choice=Specialist_ID
			drop Specialist_ID
			rename Specialist_Option Specialist_ID

			** merge characteristics of the inpatient stay
			merge m:1 bene_id clm_id admit using "${DATA_FINAL}OrthoStays_`y'.dta", nogenerate keep(match)	
	
			** merge characteristics of the patient
			merge m:1 bene_id using "${DATA_FINAL}Patient_`y'.dta", nogenerate keep(master match)
	
			** merge characteristics of the specialist
			gen double physician_npi=Specialist_ID
			merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) generate(Specialist_Match)
			foreach x of varlist phy_* claims_perf* {
				rename `x' spec_`x'
			}
			drop physician_npi
			merge m:1 Specialist_ID admit using "${DATA_FINAL}Running_Spec_`y'.dta", nogenerate keep(master match)
			merge m:1 Specialist_ID using "${DATA_FINAL}Total_Spec.dta", nogenerate keep(master match)
		
			** merge characteritics of the pcp
			gen double physician_npi=Practice_ID
			merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) generate(PCP_Match)
			foreach x of varlist phy_* claims_perf* {
				rename `x' pcp_`x'
			}
			drop physician_npi	
			merge m:1 Practice_ID admit using "${DATA_FINAL}Running_PCP_`y'.dta", nogenerate keep(master match)
			merge m:1 Practice_ID using "${DATA_FINAL}Total_PCP.dta", nogenerate keep(master match)
	
			** merge characteristics of the pcp/specialist pair
			merge m:1 Practice_ID Specialist_ID admit using "${DATA_FINAL}Running_Pair_`y'.dta", nogenerate keep(master match)

			merge m:1 Practice_ID Specialist_ID using "${DATA_FINAL}Total_Pair.dta", nogenerate keep(master match)
	
			** merge outcomes
			merge m:1 bene_id clm_id using "${DATA_FINAL}Outcomes_`y'.dta", keep(master match) nogenerate
		
			** merge hospital lat/long
			merge m:1 Specialist_ID using temp_spec_hosp, nogenerate keep(master match)
			
			** merge established PCP indicator
			merge m:1 Practice_ID using "${DATA_FINAL}EstPractice.dta", keep(master match) gen(EstPCPMatch)
	
			** merge episode spending data
			merge m:1 bene_id clm_id using "${DATA_FINAL}Episode_`y'.dta", keep(master match) nogenerate
			
			** merge follow-up visits (as proxy for saliency)
			merge m:1 Practice_ID bene_id admit using "${DATA_FINAL}fwup_visits_`y'.dta", nogenerate keep(master match)
			
			** subset data
			keep Practice_ID Specialist_ID bene_id admit bene_birth_dt bene_lat bene_long spec_hosp_lat* spec_hosp_long* ///
				Year choice clm_drg_cd episode_spend EstPCPMatch fwup* ///
				pair_* ///
				pcp_phy_sex pcp_phy_birth_dt pcp_phy_pos_* pcp_phy_tin1 pcp_phy_tin2 pcp_phy_zip_perf* pcp_claims_perf* ///
				pcp_patients_* pcp_failures_* pcp_death_* pcp_readmit_* ///
				spec_phy_sex spec_phy_birth_dt spec_phy_spec_prim* spec_phy_pos_* spec_phy_tin1 spec_phy_tin2 spec_phy_zip_perf* spec_claims_perf* ///
				spec_patients_* spec_failures_* spec_death_* spec_readmit_*
			save temp_choice_`h'_`y', replace
		}
	}
}


forvalues h=1/457 {
	local step=0
	forvalues y=2013/2018 {
		capture confirm file "temp_choice_`h'_`y'.dta"
		if _rc==0 {
			local step=`step'+1
			if `step'==1 {
				use temp_choice_`h'_`y', clear
			}
			else {
				append using temp_choice_`h'_`y', force
			}
		}
	}
	
	if `step'>0 {
		egen casevar=group(bene_id admit Practice_ID)
		bys Practice_ID Specialist_ID: egen total_referrals=total(choice)
		bys casevar: egen max_recent=max(total_referrals)
		gen common_ref=(max_recent==total_referrals)
		gsort casevar -common_ref
		by casevar: gen case_obs=_n
		by casevar: egen max_choice=max(choice)

		drop if max_choice==0
		drop total_referrals max_recent max_choice
		
		forvalues i=1/7 {
			finddist bene_lat bene_long spec_hosp_lat1`i' spec_hosp_long1`i'
			gen bene_hosp_distance1`i'=distance/1.609344
			drop distance
		
			finddist bene_lat bene_long spec_hosp_lat2`i' spec_hosp_long2`i'
			gen bene_hosp_distance2`i'=distance/1.609344
			drop distance
		}
		save "${DATA_FINAL}ChoiceData_HRR_DRG`h'.dta", replace
	}
}

