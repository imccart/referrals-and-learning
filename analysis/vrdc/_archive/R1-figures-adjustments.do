set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}R1_Figures_`logdate'.log", replace

******************************************************************
**	Title:		R1 — Revision Figures (VRDC)
**	Author:		Ian McCarthy
**	Date Created:	5/11/2026
**	Date Updated:	5/18/2026 (renamed from O6 to R1; revision script)
**	Notes:		Supplementary figures that adjust or augment the
**			main O4 output. Self-contained: loads only files
**			that always live in ${DATA_FINAL} and does not
**			depend on A0/A1 temp files. Safe to run on its own.
******************************************************************

local r_type "${PCP_First}_${PCP_Only}_${RFR_Priority}"


******************************************************************
** Familiarity-quality (patient-count version)
** Counterpart to the local years-based Familiarity_Quality figure.
** Uses pair-level total patient count (cumulative across years)
** instead of years of relationship.

** pair-level total patient count (one row per Practice_ID-Specialist_ID)
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
keep if EstPCPMatch==3
collapse (count) pair_patients=bene_id, by(Practice_ID Specialist_ID)
save temp_pair_patients, replace

** specialist quality (success rate across all patients)
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
replace spec_qual=spec_success_tot/spec_patients_tot
bys Specialist_ID: keep if _n==1
keep Specialist_ID spec_qual
save temp_spec_qual_unique, replace

** merge and bin by patient count (bins match structural model boundaries)
use temp_pair_patients, clear
merge m:1 Specialist_ID using temp_spec_qual_unique, keep(match) nogenerate
egen fam_bin=cut(pair_patients), at(1,2,4,6,11,1000000) icodes
label define famlbl 0 "1" 1 "2-3" 2 "4-5" 3 "6-10" 4 "11+"
label values fam_bin famlbl

** bin-level means + SE for bar chart
preserve
collapse (mean) mean_qual=spec_qual (sd) sd_qual=spec_qual ///
	(count) n_pairs=spec_qual, by(fam_bin)
gen se_qual=sd_qual/sqrt(n_pairs)
gen ub=mean_qual + 1.96*se_qual
gen lb=mean_qual - 1.96*se_qual

twoway (bar mean_qual fam_bin, color(gray) barwidth(0.6)) ///
	(rcap lb ub fam_bin, color(black)), ///
	xlabel(0 "1" 1 "2-3" 2 "4-5" 3 "6-10" 4 "11+") ///
	ytitle("Mean Specialist Quality (Success Rate)") ///
	xtitle("Patients in Referral Relationship") ///
	legend(off)
graph save "${RESULTS_BASE}Familiarity_Quality_Patients_`r_type'", replace
graph export "${RESULTS_BASE}Familiarity_Quality_Patients_`r_type'.png", as(png) replace
restore

capture erase temp_pair_patients.dta
capture erase temp_spec_qual_unique.dta


log close
