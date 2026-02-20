******************************************************************
**	Title:		Construct Choice Sets
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	7/18/2023
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
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"

** unique referrals
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
bys Practice_ID: gen unique_practice=_n
keep if unique_practice==1
keep Practice_ID
save "${DATA_FINAL}UniquePractice_`r_type'.dta", replace

** sample of unique referrals
use "${DATA_FINAL}UniquePractice_`r_type'.dta", clear
sample 50
save "${DATA_FINAL}RandomSample_`r_type'.dta", replace



******************************************************************
** Final choice sets
forvalues y=2013/2018 {
	local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	
	
	** collapse specialist characteristics to specialist practice
	if ${PCP_Practice}==1 {
		use "${DATA_FINAL}Physician_`y'.dta", clear
		rename physician_npi physician_id
		merge m:1 physician_id using "${DATA_FINAL}practice_spec_xwalk_`y'.dta", nogenerate keep(match)
		gen male=(phy_sex=="M") if phy_sex!=""
		bys physician_id: gen spec_obs=_n
		replace spec_obs=0 if spec_obs>1
		gen birth_date=date(phy_birth_dt, "DMY")
		gen age=`y' - year(birth_date)
		bys Specialist_ID: egen mode_state=mode(phy_state)
		bys Specialist_ID: egen mode_cbsa=mode(phy_cbsa_cd)
		bys Specialist_ID: egen mode_tin1=mode(phy_tin1)
		bys Specialist_ID: egen mode_tin2=mode(phy_tin2)
		
		preserve
		keep Specialist_ID phy_zip_perf1
		rename phy_zip_perf1 spec_phy_zip_perf1
		bys Specialist_ID spec_phy_zip_perf1: gen claims_zip=_N
		bys Specialist_ID spec_phy_zip_perf1: gen obs=_n
		keep if obs==1
		gsort Specialist_ID -claims_zip
		drop obs claims_zip
		by Specialist_ID: gen obs=_n
		reshape wide spec_phy_zip_perf1, i(Specialist_ID) j(obs)
		save temp_spec_practice_zip, replace
		restore
		
		collapse (mean) spec_practice_male=male spec_practice_age=age (sum) spec_practice_size=spec_obs ///
			(first) spec_practice_state=mode_state spec_practice_cbsa=mode_cbsa ///
			(first) spec_phy_tin1=mode_tin1 spec_phy_tin2=mode_tin2, by(Specialist_ID)
		merge 1:1 Specialist_ID using temp_spec_practice_zip, nogenerate keep(master match)
		save "${DATA_FINAL}Specialist_Practice_`y'.dta", replace
		
		/*
		use "${DATA_FINAL}Physician_`y'.dta", clear
		rename physician_npi physician_id
		merge m:1 physician_id using "${DATA_FINAL}practice_pcp_xwalk_`y'.dta", nogenerate keep(match)
		gen male=(phy_sex=="M") if phy_sex!=""
		bys physician_id: gen pcp_obs=_n
		replace pcp_obs=0 if pcp_obs>1
		gen birth_date=date(phy_birth_dt, "DMY")
		gen age=`y' - year(birth_date)
		bys Practice_ID: egen mode_state=mode(phy_state)
		bys Practice_ID: egen mode_cbsa=mode(phy_cbsa_cd)
		bys Practice_ID: egen mode_tin1=mode(phy_tin1)
		bys Practice_ID: egen mode_tin2=mode(phy_tin2)
		
		preserve
		keep Practice_ID phy_zip_perf1
		rename phy_zip_perf1 pcp_phy_zip_perf1
		bys Practice_ID pcp_phy_zip_perf1: gen claims_zip=_N
		bys Practice_ID pcp_phy_zip_perf1: gen obs=_n
		keep if obs==1
		gsort Practice_ID -claims_zip
		drop obs claims_zip
		by Practice_ID: gen obs=_n
		reshape wide pcp_phy_zip_perf1, i(Practice_ID) j(obs)
		save temp_pcp_practice_zip, replace
		restore
		
		collapse (mean) pcp_practice_male=male pcp_practice_age=age (sum) pcp_practice_size=pcp_obs ///
			(first) pcp_practice_state=mode_state pcp_practice_cbsa=mode_cbsa ///
			(first) pcp_phy_tin1=mode_tin1 pcp_phy_tin2=mode_tin2, by(Practice_ID)
		merge 1:1 Practice_ID using temp_pcp_practice_zip, nogenerate keep(master match)
		save "${DATA_FINAL}PCP_Practice_`y'.dta", replace
		*/
	}
	
	use "${DATA_FINAL}Referrals_`y'_`r_type'.dta", clear
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
	
	use "${DATA_FINAL}Referrals_`y'_`r_type'.dta", clear	
	keep Practice_ID Specialist_ID pcp_npi spec_npi bene_hrr bene_id clm_id admit bene_lat* bene_long* hosp_lat* hosp_long*
	drop if bene_hrr==.
	qui sum bene_hrr
	display r(max)
	local max_group=r(max)
	save temp_data, replace

	** form set of all specialists in the market (in that year)
	use temp_data, clear
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
	
			** merge characteristics of the specialist and PCP practice
			
			/* For both PCP and Specialist at practice level
			if ${PCP_Practice}==1 {
				merge m:1 Specialist_ID using "${DATA_FINAL}Specialist_Practice_`y'.dta", keep(master match) generate(Specialist_Match)
				merge m:1 Practice_ID using "${DATA_FINAL}PCP_Practice_`y'.dta", keep(master match) generate(PCP_Match)
			}
			else if ${PCP_Practice}==0 {
				gen double physician_npi=Specialist_ID
				merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) generate(Specialist_Match)
				foreach x of varlist phy_* claims_perf* {
					rename `x' spec_`x'
				}
				drop physician_npi
				
				gen double physician_npi=Practice_ID
				merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) generate(PCP_Match)
				foreach x of varlist phy_* claims_perf* {
					rename `x' pcp_`x'
				}
				drop physician_npi	
			}
			*/

			/* For both Specialist at practice level and PCP at individual level */
			if ${PCP_Practice}==1 {
				merge m:1 Specialist_ID using "${DATA_FINAL}Specialist_Practice_`y'.dta", keep(master match) generate(Specialist_Match)
			}
			else if ${PCP_Practice}==0 {
				gen double physician_npi=Specialist_ID
				merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) generate(Specialist_Match)
				foreach x of varlist phy_* claims_perf* {
					rename `x' spec_`x'
				}
				drop physician_npi
			}
			gen double physician_npi=Practice_ID
			merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) generate(PCP_Match)
			foreach x of varlist phy_* claims_perf* {
				rename `x' pcp_`x'
			}
			drop physician_npi	
			
		

			
			** merge remaining practice characteristics
			merge m:1 Specialist_ID admit using "${DATA_FINAL}Running_Spec_`y'.dta", nogenerate keep(master match)
			merge m:1 Specialist_ID using "${DATA_FINAL}Total_Spec_`r_type'.dta", nogenerate keep(master match)
			merge m:1 Practice_ID admit using "${DATA_FINAL}Running_PCP_`y'.dta", nogenerate keep(master match)
			merge m:1 Practice_ID using "${DATA_FINAL}Total_PCP_`r_type'.dta", nogenerate keep(master match)
	
			** merge characteristics of the pcp/specialist pair
			merge m:1 Practice_ID Specialist_ID admit using "${DATA_FINAL}Running_Pair_`y'.dta", nogenerate keep(master match)
			merge m:1 Practice_ID Specialist_ID using "${DATA_FINAL}Total_Pair_`r_type'.dta", nogenerate keep(master match)
	
			** merge outcomes of specific surgery
			merge m:1 bene_id clm_id using "${DATA_FINAL}Outcomes_`y'.dta", keep(master match) nogenerate
		
			** merge hospital lat/long
			merge m:1 Specialist_ID using temp_spec_hosp, nogenerate keep(master match)
			
			** merge established PCP indicator
			
			/* If PCP at practice level
			if ${PCP_Practice}==1 {
				preserve
				use "${DATA_FINAL}EstPractice_`r_type'.dta", clear
				rename pcp_npi physician_id
				merge m:1 physician_id using "${DATA_FINAL}practice_pcp_xwalk_`y'.dta", nogenerate keep(match)
				collapse (max) total_patients maxrun, by(Practice_ID)
				save pcp_practice_maxest, replace
				restore
				
				merge m:1 Practice_ID using pcp_practice_maxest, keep(master match) gen(EstPCPMatch)
		
			}
			else if ${PCP_Practice}==0 {
				merge m:1 pcp_npi using "${DATA_FINAL}EstPractice_`r_type'.dta", keep(master match) gen(EstPCPMatch)
			}
			*/
			merge m:1 pcp_npi using "${DATA_FINAL}EstPractice_`r_type'.dta", keep(master match) gen(EstPCPMatch)
			
			** merge episode spending data
			merge m:1 bene_id clm_id using "${DATA_FINAL}Episode_`y'.dta", keep(master match) nogenerate
			
			** merge follow-up visits (as proxy for saliency)
			merge m:1 Practice_ID bene_id admit using "${DATA_FINAL}fwup_visits_`y'.dta", nogenerate keep(master match)
			
			** subset data
			/* If PCP and Specialist at practice level 
			if ${PCP_Practice}==1 {
				keep Practice_ID Specialist_ID bene_id admit bene_birth_dt bene_lat bene_long spec_hosp_lat* spec_hosp_long* ///
					Year choice clm_drg_cd episode_spend EstPCPMatch fwup* ///
					pair_* ///
					pcp_practice_male pcp_practice_age pcp_practice_size pcp_practice_state pcp_practice_cbsa pcp_phy_zip_perf* ///
					pcp_patients_* pcp_failures_* pcp_death_* pcp_readmit_* pcp_comp* ///
					spec_practice_male spec_practice_age spec_practice_size spec_practice_state spec_practice_cbsa spec_phy_zip_perf* ///
					spec_phy_tin1 spec_phy_tin2 pcp_phy_tin1 pcp_phy_tin2 ///
					spec_patients_* spec_failures_* spec_death_* spec_readmit_* spec_comp*	
			}
			else if ${PCP_Practice}==0 {
				keep Practice_ID Specialist_ID bene_id admit bene_birth_dt bene_lat bene_long spec_hosp_lat* spec_hosp_long* ///
					Year choice clm_drg_cd episode_spend EstPCPMatch fwup* ///
					pair_* ///
					pcp_phy_sex pcp_phy_birth_dt pcp_phy_pos_* pcp_phy_tin1 pcp_phy_tin2 pcp_phy_zip_perf* pcp_claims_perf* ///
					pcp_patients_* pcp_failures_* pcp_death_* pcp_readmit_* pcp_comp* ///
					spec_phy_sex spec_phy_birth_dt spec_phy_spec_prim* spec_phy_pos_* spec_phy_tin1 spec_phy_tin2 spec_phy_zip_perf* spec_claims_perf* ///
					spec_patients_* spec_failures_* spec_death_* spec_readmit_* spec_comp*
			}
			*/
			
			*/ If PCP at individual level and specialist at practice level */
			if ${PCP_Practice}==1 {
				keep Practice_ID Specialist_ID bene_id admit bene_birth_dt bene_lat bene_long spec_hosp_lat* spec_hosp_long* ///
					Year choice clm_drg_cd episode_spend EstPCPMatch fwup* ///
					pair_* ///
					pcp_phy_sex pcp_phy_birth_dt pcp_phy_pos_* pcp_phy_tin1 pcp_phy_tin2 pcp_phy_zip_perf* pcp_claims_perf* ///
					pcp_patients_* pcp_failures_* pcp_death_* pcp_readmit_* pcp_comp* ///
					spec_practice_male spec_practice_age spec_practice_size spec_practice_state spec_practice_cbsa spec_phy_zip_perf* ///
					spec_phy_tin1 spec_phy_tin2 pcp_phy_tin1 pcp_phy_tin2 ///
					spec_patients_* spec_failures_* spec_death_* spec_readmit_* spec_comp*	
			}
			else if ${PCP_Practice}==0 {
				keep Practice_ID Specialist_ID bene_id admit bene_birth_dt bene_lat bene_long spec_hosp_lat* spec_hosp_long* ///
					Year choice clm_drg_cd episode_spend EstPCPMatch fwup* ///
					pair_* ///
					pcp_phy_sex pcp_phy_birth_dt pcp_phy_pos_* pcp_phy_tin1 pcp_phy_tin2 pcp_phy_zip_perf* pcp_claims_perf* ///
					pcp_patients_* pcp_failures_* pcp_death_* pcp_readmit_* pcp_comp* ///
					spec_phy_sex spec_phy_birth_dt spec_phy_spec_prim* spec_phy_pos_* spec_phy_tin1 spec_phy_tin2 spec_phy_zip_perf* spec_claims_perf* ///
					spec_patients_* spec_failures_* spec_death_* spec_readmit_* spec_comp*
			}
			
			save temp_choice_`h'_`y', replace
		}
	}
}


local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
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
		
		** distance from bene to all hospitals where a given specialist operates
		forvalues i=1/6 {
			finddist bene_lat bene_long spec_hosp_lat1`i' spec_hosp_long1`i'
			gen bene_hosp_distance1`i'=distance/1.609344
			drop distance
		
			finddist bene_lat bene_long spec_hosp_lat2`i' spec_hosp_long2`i'
			gen bene_hosp_distance2`i'=distance/1.609344
			drop distance
		}
		
		** distance from bene to specialist offices
		local z_step=0
		foreach x of varlist spec_phy_zip_perf* {
			local z_step=`z_step'+1
			gen zip=`x'
			merge m:1 zip using "${DATA_FINAL}LatLong.dta", nogenerate keep(master match)
			rename lat spec_lat`z_step'
			rename lon spec_long`z_step'
			drop zip
		}

		forvalues i=1/6 {	
			finddist bene_lat bene_long spec_lat`i' spec_long`i'
			gen bene_spec_distance1`i'=distance/1.609344
			drop distance
		}
		drop spec_lat* spec_long* spec_phy_zip_perf*
		save "${DATA_FINAL}ChoiceData_HRR`h'_`r_type'.dta", replace
	}
}

