set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Descriptive_`logdate'.log", replace

******************************************************************
**	Title:		Descriptive Analysis
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	7/16/2024
******************************************************************

******************************************************************
** Details of dataset construction and other scalars
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${RESULTS_FINAL}data_build_detail_`r_type'.dta", clear
**keep if year>=2013
format step_* %12.0fc
collapse (sum) step_*, by(code_section)
keep if code_section=="Overall"
rename step_1 total_obs
rename step_2 referral_em
rename step_3 referral_listed
rename step_4 referral_any
rename step_5 patient_chars
rename step_6 specialist_phy_chars
rename step_7 refer_phy_chars
rename step_8 hosp_chars
rename step_9 quality_outcomes
rename step_10 patient_age
rename step_11 pcp_ortho_pair

display "Total Observations: "patient_age
display "Total Matched Referrals: "pcp_ortho_pair


** for some specific numbers using the full data
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
forvalues y=2008/2018 {
	use "${DATA_FINAL}OrthoStays_`y'.dta", clear
	merge m:1 bene_id using "${DATA_FINAL}Patient_`y'.dta", keep(master match) generate(Patient_Match)
	drop op_physn_upin
	gen bene_age=int( (discharge-bene_birthday)/365.25)
	drop if bene_age<65 
	bys bene_id NPINUM admit: gen count=_N
	drop if count>1
	drop count
	
	merge m:1 bene_id admit using "${DATA_FINAL}Referrals_Claims_`y'.dta", keep(master match) generate(EM_RFR)
	gen double physician_npi=spec_npi
	merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) generate(Specialist_Match)
	foreach x of varlist phy_* claims_* {
		rename `x' spec_`x'
	}
	keep physician_npi bene_id admit Claim_PCP_ID spec_* EM_RFR Specialist_Match pcp_*
	save temp_all_data_`y', replace
}

use temp_all_data_2008, clear
forvalues y=2009/2018 {
	append using temp_all_data_`y'
}
count
count if EM_RFR==3 & Claim_PCP_ID!=.
count if spec_phy_spec_prim_1_name=="Orthopedic Surgery"
count if EM_RFR==3 & spec_phy_spec_prim_1_name=="Orthopedic Surgery"


** total counts from 2008 through 2018
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
qui count
qui count if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}
local f1=r(N)
qui count if Year>=2013 & EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}
local f2=r(N)

display "Final Observations: `f1'"
display "Final Observations after 2012: `f2'"



** unique PCPs and specialists
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
**keep if Year>=2013 & EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}

bys Practice_ID: gen obs=_n
qui count if obs==1
local pcps=r(N)
drop obs

bys Specialist_ID: gen obs=_n
qui count if obs==1
local specs=r(N)
drop obs

display "Unique PCPs: `pcps'"
display "Unique Specialists: `specs'"


**egen bene_distance=rowmin(bene_spec_distance*)
**drop if bene_distance==. | bene_distance>=75
bys Specialist_ID bene_hrr Year: gen spec_obs=_n
replace spec_obs=0 if spec_obs>1
bys bene_hrr Year: egen total_specialists=total(spec_obs)
bys bene_hrr Year: gen hrr_obs=_n
sum total_specialists if hrr_obs==1



******************************************************************
** Overall Summary Statistics

** basic descriptive stats table (pre/post/all)
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}

bys Practice_ID Year: gen PCP_obs=_n
replace PCP_obs=0 if PCP_obs>1
bys Specialist_ID Year: gen spec_obs=_n
replace spec_obs=0 if spec_obs>1
bys pcp_phy_tin1 Year: egen tot_pcp_size=total(PCP_obs)
bys spec_phy_tin1 Year: egen tot_spec_size=total(spec_obs)
gen pcp_birthday=date(pcp_phy_birth_dt, "DMY")
gen spec_birthday=date(spec_phy_birth_dt, "DMY")

gen pcp_age=int( (admit-pcp_birthday)/365.25 )
gen spec_age=int( (admit-spec_birthday)/365.25 )
gen bene_black=(bene_race==2)
gen bene_white=(bene_race==1)
gen bene_other=(inlist(bene_race, 1, 2)==0)
gen bene_male=(bene_gender==1)
gen pcp_male=(pcp_phy_sex=="M")
gen spec_male=(spec_phy_sex=="M")
egen pcp_distance=rowmin(bene_pcp_distance*)
egen spec_distance=rowmin(bene_phy_distance*)
egen hosp_distance=rowmin(bene_hosp_distance*)

label variable bene_age "Age"
label variable bene_white "White"
label variable bene_black "Black"
label variable bene_other "Other"
label variable bene_male "Male"
label variable tot_pcp_size "Practice Size"
label variable pcp_male "Male"
label variable tot_spec_size "Practice Size"
label variable spec_male "Male"
label variable pcp_distance "  to PCP"
label variable spec_distance "  to Specialist"
label variable hosp_distance "  to Hospital"
label variable readmit "90-day Readmission"
label variable mortality_90 "90-day Mortality"
label variable any_comp "90-day Complication"
label variable any_bad "Failure"

estpost sum bene_age bene_white bene_black bene_male ///
	tot_pcp_size pcp_male tot_spec_size spec_male pcp_distance hosp_distance readmit mortality_90 any_comp any_bad if Year<2013
est store sum_all_pre

estpost sum bene_age bene_white bene_black bene_male ///
	tot_pcp_size pcp_male tot_spec_size spec_male pcp_distance hosp_distance readmit mortality_90 any_comp any_bad if Year>=2013
est store sum_all_post

estpost sum bene_age bene_white bene_black bene_male ///
	tot_pcp_size pcp_male tot_spec_size spec_male pcp_distance hosp_distance readmit mortality_90 any_comp any_bad
est store sum_all

esttab sum_all_pre sum_all_post sum_all using "${RESULTS_FINAL}sum-stats-all_`r_type'.tex", replace ///
	refcat (bene_age "\emph{Patient Characteristics}" tot_pcp_size "\emph{PCP Characteristics}" tot_spec_size "\emph{Specialist Characteristics}" pcp_distance "\emph{Distance}" readmit_90 "\emph{Quality Outcomes}", nolabel) ///
	stats(N, fmt(%9.0fc) labels("\midrule Observations")) ///
	mtitle("2008-2012" "2013-2018" "Overall") ///
	cells(mean(fmt(3)) sd(par)) label booktabs nonum collabels(none) gaps f noobs


** referral graphs (combining all post-period years)
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear	
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if Year>=2013 & EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}
collapse (count) patients=bene_id (sum) readmit mortality_30 mortality_60 mortality_90 any_comp any_bad, by(Practice_ID Specialist_ID)
bys Practice_ID: gen practice_count=_n
bys Practice_ID: egen practice_patients=sum(patients)
bys Practice_ID: egen practice_failures=sum(any_bad)
bys Practice_ID: gen specialist_per_pcp=_N
bys Specialist_ID: gen specialist_count=_n
bys Specialist_ID: egen specialist_patients=sum(patients)
bys Specialist_ID: egen specialist_failures=sum(any_bad)
bys Specialist_ID: gen pcp_per_specialist=_N
gen pcp_specialist_share=patients/practice_patients
gen pcp_specialist_readmit=readmit/patients
gen pcp_specialist_mortality=mortality_90/patients
gen pcp_specialist_comp=any_comp/patients
gen pcp_specialist_bad=any_bad/patients
gen other_specialist_bad=(specialist_failures-any_bad)/(specialist_patients-patients)
save temp_full_data, replace


** description of networks (across all time periods)
use temp_full_data, clear
count if practice_count==1  				/* unique number of practices */
sum practice_patients if practice_count==1, detail	/* number of patients per practice */
count if specialist_count==1				/* unique number of specialists */
sum specialist_patients if specialist_count==1, detail  /* number of patients per specialist */
count							/* unique number of pairs */
sum patients, detail					/* number of patients per pair */
sum specialist_per_pcp if practice_count==1, detail	/* number of specialists per PCP */
sum pcp_per_specialist if specialist_count==1, detail 	/* number of PCPs per specialist */
sum pcp_specialist_share, detail			/* share of patients to each specialist */
sum specialist_patients if specialist_count==1, detail
sum readmit mortality_90 any_comp any_bad, detail	/* count of negative outcomes per pair */
bys Practice_ID: egen max_share=max(pcp_specialist_share)
sum max_share if practice_count==1, detail

count if practice_patients<=2 & practice_count==1
count if specialist_patients<=2 & specialist_count==1
count if patients<=2

count if practice_failures==0 & practice_count==1
count if practice_failures>0 & practice_failures<=2 & practice_count==1

count if specialist_failures==0 & specialist_count==1
count if specialist_failures>0 & specialist_failures<=2 & specialist_count==1


** specialist failure rate
gen spec_failure_rate=specialist_failures/specialist_patients
sum spec_failure_rate if specialist_count==1, detail


** practice-level figures
keep if practice_count==1

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
set scheme uncluttered
hist max_share, frequency color(gray) ///
	ylabel(0(1000)5000) ///
	ytitle("Frequency") xtitle("Share of Most Common Referral") legend(off)
graph save "${RESULTS_FINAL}HighestShare_`r_type'", replace
graph export "${RESULTS_FINAL}HighestShare_`r_type'.png", as(png) replace		

set scheme uncluttered
hist max_share if max_share>0.01 [fweight=practice_patients], frequency color(gray) ///
	ylabel(0 25000 "25" 50000 "50" 75000 "75" 100000 "100") ///
	ytitle("Frequency (1000s)") xtitle("Share of Most Common Referral") legend(off)
graph save "${RESULTS_FINAL}HighestShareWeighted_`r_type'", replace
graph export "${RESULTS_FINAL}HighestShareWeighted_`r_type'.png", as(png) replace		

set scheme uncluttered
bys specialist_per_pcp: gen freq=_N
graph twoway scatter freq specialist_per_pcp, color(gray) xscale(log) yscale(log) ///
	xlabel(1 "10^0" 10 "10^1" 100 "10^2" 1000 "10^3") ///
	ylabel(1 "10^0" 10 "10^1" 100 "10^2" 1000 "10^3" 10000 "10^4") ///
	ytitle("Frequency") xtitle("Network Size") legend(off)
graph save "${RESULTS_FINAL}LLNetworkSize_`r_type'", replace
graph export "${RESULTS_FINAL}LLNetworkSize_`r_type'.png", as(png) replace		

preserve
graph use "${RESULTS_FINAL}LLNetworkSize_`r_type'"
serset dir
serset use, clear
gen ln_freq=log(freq)
gen ln_size=log(specialist_per_pcp)
reg ln_freq ln_size if specialist_per_pcp>=11
restore

set scheme uncluttered	
hist specialist_per_pcp if specialist_per_pcp<50, frequency color(gray) discrete ///
	ylabel(0(1000)6000) ///
	ytitle("Frequency") xtitle("Unique Specialists") legend(off)
graph save "${RESULTS_FINAL}NetworkSize_`r_type'", replace
graph export "${RESULTS_FINAL}NetworkSize_`r_type'.png", as(png) replace		

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
set scheme uncluttered
hist practice_patients if practice_patients<100, frequency color(gray) discrete ///
	ylabel(0(500)2500) ///
	ytitle("Frequency") xtitle("Total Patients Referred") legend(off)
graph save "${RESULTS_FINAL}TotalReferrals_`r_type'", replace
graph export "${RESULTS_FINAL}TotalReferrals_`r_type'.png", as(png) replace		



******************************************************************
** Description of Networks Over Time
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}
gen same_practice=0
replace same_practice=1 if pcp_phy_tin1==spec_phy_tin1 & pcp_phy_tin1!=. & spec_phy_tin1!=.
replace same_practice=1 if pcp_phy_tin1==spec_phy_tin2 & pcp_phy_tin1!=. & spec_phy_tin2!=. 
replace same_practice=1 if pcp_phy_tin2==spec_phy_tin1 & pcp_phy_tin2!=. & spec_phy_tin1!=. 
replace same_practice=1 if pcp_phy_tin2==spec_phy_tin2 & pcp_phy_tin2!=. & spec_phy_tin2!=.

gen pair_failure_rate=pair_failures_cuml/pair_patients_cuml
qui sum pair_patients_cuml
local mean_cuml_pat=r(mean)
local std_cuml_pat=r(sd)
qui sum pair_failure_rate
local mean_cuml_rate=r(mean)
local std_cuml_rate=r(sd)

collapse (count) patients=bene_id (sum) readmit mortality_30 mortality_60 mortality_90 any_comp any_bad same_practice, by(Practice_ID Specialist_ID Year)
bys Practice_ID Year: gen practice_count=_n
bys Practice_ID Year: egen practice_patients=sum(patients)
bys Practice_ID Year: gen specialist_per_pcp=_N
bys Practice_ID Year: egen practice_failures=sum(any_bad)
bys Specialist_ID Year: gen specialist_count=_n
bys Specialist_ID Year: egen specialist_patients=sum(patients)
bys Specialist_ID Year: egen specialist_failures=sum(any_bad)
gen pcp_specialist_share=patients/practice_patients
gen pcp_specialist_readmit=readmit/patients
gen pcp_specialist_mortality=mortality_90/patients
gen pcp_specialist_comp=any_comp/patients
gen pcp_specialist_failure=any_bad/patients
gen other_specialist_failure=(specialist_failures-any_bad)/(specialist_patients-patients)
bys Practice_ID Year: egen max_share=max(pcp_specialist_share)
save temp_networks_yearly, replace

** summary stats tables
replace practice_patients=. if practice_count>1
replace specialist_per_pcp=. if practice_count>1
replace practice_failures=. if practice_count>1
label variable practice_patients "Total Referrals"
label variable specialist_per_pcp "Network Size"
label variable patients "Referrals per Specialist"
label variable pcp_specialist_share "Referral Share"
label variable practice_failures "Total Failures"
label variable pcp_specialist_failure "Failure Rate"

estpost sum practice_patients specialist_per_pcp practice_failures patients pcp_specialist_failure if Year<2013
est store sum_all_pre

estpost sum practice_patients specialist_per_pcp practice_failures patients pcp_specialist_failure if Year>=2013
estadd scalar running_patients_mean=`mean_cuml_pat'
estadd scalar running_patients_sd=`std_cuml_pat'
estadd scalar running_failure_mean=`mean_cuml_rate'
estadd scalar running_failure_sd=`std_cuml_rate'
est store sum_all_post

estpost sum practice_patients specialist_per_pcp practice_failures patients pcp_specialist_failure
est store sum_all

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
esttab sum_all_pre sum_all_post sum_all using "${RESULTS_FINAL}sum-stats-pairs_`r_type'.tex", replace ///
	stats(running_patients_mean running_patients_sd running_failure_mean running_failure_sd N, ///
	fmt(%9.3fc %9.3fc %9.3fc %9.3fc %9.0fc) ///
	labels("Running Referrals" " " "Running Failure Rate" " " "\midrule Observations")) ///
	mtitle("2008-2012" "2013-2018" "Overall") ///
	cells(mean(fmt(3)) sd(par)) label booktabs nonum collabels(none) gaps f noobs


** figures
use temp_networks_yearly, clear
collapse (mean) patients, by(Year)
set scheme uncluttered
graph twoway connected patients Year, xtitle("Year") ytitle("Referrals per Specialist") ///
	legend(off) ylabel(0(1)2) xlabel(2008(1)2018)
graph save "${RESULTS_FINAL}Referrals_per_Spec_Yearly_`r_type'", replace
graph export "${RESULTS_FINAL}Referrals_per_Spec_Yearly_`r_type'.png", as(png) replace		

use temp_networks_yearly, clear
keep if practice_count==1
set scheme uncluttered
graph box max_share [fweight=practice_patients], over(Year) ytitle("Shares of Most Common Referral by PCP") ///
	legend(off) ylabel(0(.1)1) nooutsides note("")
graph save "${RESULTS_FINAL}WeightedMaxShare_Box_Yearly_`r_type'", replace
graph export "${RESULTS_FINAL}WeightedMaxShare_Box_Yearly_`r_type'.png", as(png) replace		

set scheme uncluttered
graph box specialist_per_pcp if specialist_per_pcp<100, over(Year) ///
	ytitle("Network Size") legend(off) nooutsides note("") 
graph save "${RESULTS_FINAL}Network_Box_Yearly_`r_type'", replace
graph export "${RESULTS_FINAL}Network_Box_Yearly_`r_type'.png", as(png) replace		


use temp_networks_yearly, clear
keep if practice_count==1
collapse (mean) specialist_per_pcp, by(Year)
set scheme uncluttered
graph twoway connected specialist_per_pcp Year, xtitle("Year") ytitle("Network Size") ///
	legend(off) ylabel(0(1)5) xlabel(2008(1)2018)
graph save "${RESULTS_FINAL}Network_Mean_Yearly_`r_type'", replace
graph export "${RESULTS_FINAL}Network_Mean_Yearly_`r_type'.png", as(png) replace		

use temp_networks_yearly, clear
keep if practice_count==1
collapse (mean) practice_patients, by(Year)
set scheme uncluttered
graph twoway connected practice_patients Year, xtitle("Year") ytitle("Total Referrals") ///
	legend(off) ylabel(0(1)5) xlabel(2008(1)2018)
graph save "${RESULTS_FINAL}Referrals_Yearly_`r_type'", replace
graph export "${RESULTS_FINAL}Referrals_Yearly_`r_type'.png", as(png) replace		

use temp_networks_yearly, clear
keep if practice_count==1
replace specialist_per_pcp=. if specialist_per_pcp>1000
collapse (mean) max_share specialist_per_pcp, by(Year)
graph twoway connected max_share Year, xtitle("Year") ytitle("Mean Shares of Most Common Referral") ///
	legend(off) ylabel(0(.1)1) xlabel(2008(1)2018)
graph save "${RESULTS_FINAL}MaxShare_Mean_Yearly_`r_type'", replace
graph export "${RESULTS_FINAL}MaxShare_Mean_Yearly_`r_type'.png", as(png) replace		


******************************************************************
** Describe range of quality and spending outcomes
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}
rename readmit readmit_90 

preserve
gen period=(Year>=2013)
bys period: sum episode_spend
sum episode_spend
restore

keep if Year>=2013 
bys Specialist_ID bene_hrr Year: egen mean_episode=mean(episode_spend)
bys Specialist_ID bene_hrr Year: gen spec_patients_year=_N
bys Specialist_ID bene_hrr Year: egen max_date=max(admit)
keep if max_date==admit
bys Specialist_ID bene_hrr Year: gen obs=_n
keep if obs==1
foreach x of newlist failures death readmit comp {
	gen prop_`x'=spec_`x'_run/spec_patients_run
	bys bene_hrr Year: egen p25_`x'=pctile(prop_`x'), p(25)
	bys bene_hrr Year: egen p50_`x'=pctile(prop_`x'), p(50)	
	bys bene_hrr Year: egen p75_`x'=pctile(prop_`x'), p(75)
	
	gen patients_75_`x'=(prop_`x'>=p75_`x')	
	gen patients_50_`x'=(prop_`x'>=p50_`x')		
}

keep Specialist_ID bene_hrr Year prop_* spec_patients_run spec_patients_year patients_75_* patients_50_* p25_* p50_* p75_* mean_episode
save spec_quality_distribution, replace

** identify top performing specialists 
preserve
keep if prop_failures<p25_failures
keep Specialist_ID bene_hrr Year spec_patients_year
save top_specialists_failure, replace
restore

** count of patients hypothetically reallocated by market/year
preserve
keep if prop_failures>p75_failures
collapse (sum) spec_patients_year, by(bene_hrr Year)
rename spec_patients_year hypo_reallocate
save hypo_reallocate, replace
restore

** iqr graphs
collapse (mean) mort_mean=prop_death readmit_mean=prop_readmit any_mean=prop_failures comp_mean=prop_comp ///
	(sum) patients_75_failures patients_75_death patients_75_readmit patients_75_comp ///
	(sum) patients_50_failures patients_50_death patients_50_readmit patients_50_comp ///
	(sum) patients=spec_patients_year ///
	(p25) mort_p25=prop_death readmit_p25=prop_readmit any_p25=prop_failures comp_p25=prop_comp pay_p25=mean_episode ///
	(p75) mort_p75=prop_death readmit_p75=prop_readmit any_p75=prop_failures comp_p75=prop_comp pay_p75=mean_episode ///
	(p50) mort_p50=prop_death readmit_p50=prop_readmit any_p50=prop_failures comp_p50=prop_comp, by(bene_hrr Year)

gen iqr_mort=mort_p75-mort_p25
replace iqr_mort=iqr_mort*100

gen iqr_failure=any_p75 - any_p25
replace iqr_failure=iqr_failure*100

gen iqr_comp=comp_p75 - comp_p25
replace iqr_comp=iqr_comp*100


gen iqr_payment=pay_p75 - pay_p25
replace iqr_payment=iqr_payment/1000

gen iqr_failure_ratio=any_p75/any_p25
gen iqr_payment_ratio=pay_p75/pay_p25

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
set scheme uncluttered
hist iqr_mort if iqr_mort<5 & patients>100, frequency color(gray) ///
	ylabel(0(50)300) ///
	ytitle("Frequency") xtitle("Interquartile Range of Mortality Rate (per 100)") legend(off)
graph save "${RESULTS_FINAL}Mortality_IQR_`r_type'", replace
graph export "${RESULTS_FINAL}Mortality_IQR_`r_type'.png", as(png) replace		

hist iqr_failure if iqr_failure<20 & patients>100, frequency color(gray) ///
	ylabel(0(50)250) ///
	ytitle("Frequency") xtitle("Interquartile Range of Failure Rate (per 100)") legend(off)
graph save "${RESULTS_FINAL}Failure_IQR_`r_type'", replace
graph export "${RESULTS_FINAL}Failure_IQR_`r_type'.png", as(png) replace		

hist iqr_payment if iqr_payment<50, frequency color(gray) ///
	ylabel(0(50)200) ///
	ytitle("Frequency") xtitle("Interquartile Range of Episode Payments ($1,000s)") legend(off)
graph save "${RESULTS_FINAL}Payment_IQR_`r_type'", replace
graph export "${RESULTS_FINAL}Payment_IQR_`r_type'.png", as(png) replace		


** lives saved
gen lives_saved=iqr_mort*patients_75_death/100
total lives_saved

** bad events saved
gen events_saved=iqr_failure*patients_75_failures/100
total events_saved

******************************************************************
** Correlation between low performing specialists and patient characteristics

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}
rename readmit readmit_90 
keep if Year>=2013 


******************************************************************
** Describe feasiblity of reallocation
use "${DATA_FINAL}SpecialistCapacity_year.dta", clear
drop if patients>365
rename spec_npi Specialist_ID
merge m:1 Specialist_ID bene_hrr Year using top_specialists_failure, keep(match) nogenerate
merge m:1 bene_hrr Year using hypo_reallocate, keep(match) nogenerate

gen excess_capacity=capacity_p75 - patients
replace excess_capacity=0 if excess_capacity<0

** potential excess capacity
collapse (first) hypo_reallocate (sum) excess_capacity, by(bene_hrr Year)
set scheme uncluttered
gen capacity_cap=min(excess_capacity, 500)
hist capacity_cap, frequency color(gray) ///
	ylabel(0(100)500) ///
	bin(16) xscale(range(0 600)) xlabel(0(100)500 500 ">500", add) ///	
	ytitle("Frequency") xtitle("Estimated Excess Annual Capacity") legend(off)
graph save "${RESULTS_FINAL}Excess_Capacity", replace
graph export "${RESULTS_FINAL}Excess_Capacity.png", as(png) replace		

** patients hypothetically reallocated by market
gen hypo_cap=min(hypo_reallocate, 1000)
set scheme uncluttered
hist hypo_cap, frequency color(gray) ///
	ylabel(0(100)500) ///
	bin(21) xscale(range(0 1100)) xlabel(0(100)900 1000 ">1000", add) ///
	ytitle("Frequency") xtitle("Hypothetically Reallocated Patients") legend(off)
graph save "${RESULTS_FINAL}Hypo_Reallocate", replace
graph export "${RESULTS_FINAL}Hypo_Reallocate.png", as(png) replace		

** summarize excess capacity relative to reallocation
gen relative_reallocate=hypo_reallocate/excess_capacity



log close
