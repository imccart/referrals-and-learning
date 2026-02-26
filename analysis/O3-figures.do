set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Figures_${MODEL_TYPE}_`logdate'.log", replace

******************************************************************
**	Title:		Structural Figures
**	Author:		Ian McCarthy
**	Date Created:	2/25/2026
**	Notes:		Parameterized by global MODEL_TYPE (Myopic or FWD).
**			Extracted from O2-structural-summary.do Sections C/D
**			plus alpha/distance histograms.
******************************************************************

** Derive locals from globals
if "${MODEL_TYPE}" == "Myopic" {
	local coef_prefix "StructureMyopic"
}
else if "${MODEL_TYPE}" == "FWD" {
	local coef_prefix "StructureForward"
}
else {
	display as error "MODEL_TYPE must be Myopic or FWD"
	exit 198
}
local model "${MODEL_TYPE}"
local r_type "${PCP_First}_${PCP_Only}_${RFR_Priority}"


******************************************************************
** Alpha and distance histograms (across HRRs)

use "${RESULTS_FINAL}`coef_prefix'_SummaryHRR.dta", replace
foreach eta in 1 5 {
	preserve
	keep if eta==`eta'
	sum coef_m, detail
	hist coef_m [weight=patients], fraction color(gray) width(0.3) ///
		ylabel(0(.1).7) ///
		ytitle("Relative Frequency") xtitle("Estimates for {&alpha} with {&eta}= `eta'") legend(off)
	graph save "${RESULTS_FINAL}alpha_`model'_eta`eta'_rhobar_`r_type'", replace
	graph export "${RESULTS_FINAL}alpha_`model'_eta`eta'_rhobar_`r_type'.png", as(png) replace
	hist coef_dist [weight=patients], fraction color(gray) width(0.01) ///
		ylabel(0(.05).2) ///
		ytitle("Relative Frequency") xtitle("Estimates for diff. distance with {&eta}= `eta'") legend(off)
	graph save "${RESULTS_FINAL}dist_`model'_eta`eta'_rhobar_`r_type'", replace
	graph export "${RESULTS_FINAL}dist_`model'_eta`eta'_rhobar_`r_type'.png", as(png) replace
	restore
}


******************************************************************
** Paper figures: partial effects and counterfactual histograms

foreach eta in 1 5 {
	use "${RESULTS_FINAL}MarginalEffects_`model'`eta'.dta", clear
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)
	sum mfx_mean mfx_10 mfx_25 mfx_50 mfx_75 mfx_90 mfx_sd [aweight=mfx_count]
	sum pfx_mean pfx_10 pfx_25 pfx_50 pfx_75 pfx_90 pfx_sd [aweight=patients]

	gen rel_mean=pfx_mean/pr_mean
	replace pfx_mean=-0.02 if pfx_mean< -0.02
	hist pfx_mean [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1)0.5) xscale(range(-0.02 0)) xlabel(-0.02 "<-0.02" -0.015(0.005)0, add) //////
		ytitle("Relative Frequency") xtitle("Mean Partial Effect of One Failure, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Partial_FX_Failure_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Partial_FX_Failure_`model'_eta`eta'.png", as(png) replace
}

** Summarize counterfactuals: effects on reallocation and ex ante patient health

foreach eta in 1 5 {
	use "${RESULTS_FINAL}CounterFactuals_`model'`eta'.dta", clear
	gen success_diff_full=success_prob1_full-success_prob0
	gen success_diff_current=success_prob1_current-success_prob0
	gen success_diff_fullfam=success_prob1_fullfam-success_prob0

	collapse (mean) success_prob0 success_diff_full success_diff_current success_diff_fullfam pij_diff_full pij_diff_current pij_diff_fullfam, by(hrr)
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)

	sum pij_diff_full pij_diff_current pij_diff_fullfam success_diff_full success_diff_current success_diff_fullfam [aweight=patients], detail

	hist pij_diff_full [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Full Info., {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Reallocation_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Reallocation_Full_`model'_eta`eta'.png", as(png) replace

	hist pij_diff_current [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Current Info., {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Reallocation_Current_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Reallocation_Current_`model'_eta`eta'.png", as(png) replace

	hist pij_diff_fullfam [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Full Info and No Familiarity, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Reallocation_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Reallocation_FullFam_`model'_eta`eta'.png", as(png) replace

	replace success_diff_full=-0.01 if success_diff_full<-0.01
	replace success_diff_full=0.01 if success_diff_full>0.01
	hist success_diff_full [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Full Info, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FX_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FX_Full_`model'_eta`eta'.png", as(png) replace

	replace success_diff_current=-0.01 if success_diff_current<-0.01
	replace success_diff_current=0.01 if success_diff_current>0.01
	hist success_diff_current [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Current Info, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FX_Current_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FX_Current_`model'_eta`eta'.png", as(png) replace

	replace success_diff_fullfam=-0.01 if success_diff_fullfam<-0.01
	replace success_diff_fullfam=0.01 if success_diff_fullfam>0.01
	hist success_diff_fullfam [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Full Info and No Familiarity, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FX_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FX_FullFam_`model'_eta`eta'.png", as(png) replace

}


******************************************************************
** Diagnostic figures: NC variants and volume changes

** Summarize counterfactuals dropping non-converging markets

foreach eta in 1 5 {
	use "${RESULTS_FINAL}CounterFactuals_`model'`eta'.dta", clear
	gen success_diff_full=success_prob1_full-success_prob0
	gen success_diff_current=success_prob1_current-success_prob0
	gen success_diff_fullfam=success_prob1_fullfam-success_prob0

	drop if no_equil_full==1
	collapse (mean) success_prob0 success_diff_full success_diff_current success_diff_fullfam pij_diff_full pij_diff_current pij_diff_fullfam, by(hrr)
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)

	sum pij_diff_full pij_diff_current pij_diff_fullfam success_diff_full success_diff_current success_diff_fullfam [aweight=patients], detail

	hist pij_diff_full [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Full Info., {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}ReallocationNC_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}ReallocationNC_Full_`model'_eta`eta'.png", as(png) replace

	hist pij_diff_current [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Current Info., {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}ReallocationNC_Current_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}ReallocationNC_Current_`model'_eta`eta'.png", as(png) replace

	hist pij_diff_fullfam [weight=patients], fraction color(gray) ///
		ytitle("Relative Frequency") xscale(range(0 1)) xlabel(0(0.1)1) xtitle("Reallocation with Full Info and No Familiarity, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}ReallocationNC_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}ReallocationNC_FullFam_`model'_eta`eta'.png", as(png) replace

	replace success_diff_full=-0.01 if success_diff_full<-0.01
	replace success_diff_full=0.01 if success_diff_full>0.01
	hist success_diff_full [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Full Info, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FXNC_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FXNC_Full_`model'_eta`eta'.png", as(png) replace

	replace success_diff_current=-0.01 if success_diff_current<-0.01
	replace success_diff_current=0.01 if success_diff_current>0.01
	hist success_diff_current [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Current Info, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FXNC_Current_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FXNC_Current_`model'_eta`eta'.png", as(png) replace

	replace success_diff_fullfam=-0.01 if success_diff_fullfam<-0.01
	replace success_diff_fullfam=0.01 if success_diff_fullfam>0.01
	hist success_diff_fullfam [weight=patients], fraction color(gray) width(0.001) ///
		ylabel(0(.1).5) ///
		xlabel(-0.01(0.005)0.01 0.01 ">0.01" -0.01 "<-0.01", add) ///
		ytitle("Relative Frequency") xtitle("Health Effects of Full Info and No Familiarity, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}Mean_Health_FXNC_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}Mean_Health_FXNC_FullFam_`model'_eta`eta'.png", as(png) replace

}


** examine changes in specialist volume
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
bys Specialist_ID hrr: gen obs=_n
bys Specialist_ID hrr: egen spec_patients=sum(choice)
replace spec_qual=spec_success_tot/spec_patients_tot
keep if obs==1
keep Specialist_ID hrr spec_qual spec_patients
save spec_temp, replace

foreach eta in 1 5 {

	use "${RESULTS_FINAL}CounterFactualsSpec_`model'`eta'.dta", clear
	merge 1:1 hrr Specialist_ID hrr using spec_temp, keep(match) nogenerate

	foreach x of newlist full fullfam current {
		gen diff_`x'=pred_patients_`x'-pred_patients0
		gen reldiff_`x'=diff_`x'/pred_patients0
	}
	reg reldiff_full spec_qual, robust
	reg reldiff_fullfam spec_qual, robust

	hist reldiff_full if reldiff_full>-1 & reldiff_full<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChange_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChange_Full_`model'_eta`eta'.png", as(png) replace

	hist reldiff_fullfam if reldiff_fullfam>-1 & reldiff_fullfam<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChange_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChange_FullFam_`model'_eta`eta'.png", as(png) replace

	sum diff_full, detail
	replace diff_full=-100 if diff_full<-100
	replace diff_full=100 if diff_full>100
	hist diff_full if reldiff_full>-1 & reldiff_full<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Absolute Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeABS_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeABS_Full_`model'_eta`eta'.png", as(png) replace

	sum diff_fullfam, detail
	replace diff_fullfam=-100 if diff_fullfam<-100
	replace diff_fullfam=100 if diff_fullfam>100
	hist diff_fullfam if reldiff_fullfam>-1 & reldiff_fullfam<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Absolute Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeABS_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeABS_FullFam_`model'_eta`eta'.png", as(png) replace

}

** examine changes in specialist volume, removing non-converging markets
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
bys Specialist_ID hrr: gen obs=_n
bys Specialist_ID hrr: egen spec_patients=sum(choice)
replace spec_qual=spec_success_tot/spec_patients_tot
keep if obs==1
keep Specialist_ID hrr spec_qual spec_patients
save spec_temp, replace

foreach eta in 1 5 {

	use "${RESULTS_FINAL}CounterFactualsSpec_`model'`eta'.dta", clear
	gen share_nc=no_equil_full/pred_patients0
	merge 1:1 hrr Specialist_ID hrr using spec_temp, keep(match) nogenerate

	drop if share_nc>0.05
	foreach x of newlist full fullfam current {
		gen diff_`x'=pred_patients_`x'-pred_patients0
		gen reldiff_`x'=diff_`x'/pred_patients0
	}
	reg reldiff_full spec_qual, robust
	reg reldiff_fullfam spec_qual, robust

	hist reldiff_full if reldiff_full>-1 & reldiff_full<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeNC_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeNC_Full_`model'_eta`eta'.png", as(png) replace

	hist reldiff_fullfam if reldiff_fullfam>-1 & reldiff_fullfam<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Relative Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeNC_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeNC_FullFam_`model'_eta`eta'.png", as(png) replace


	sum diff_full, detail
	replace diff_full=-100 if diff_full<-100
	replace diff_full=100 if diff_full>100
	hist diff_full if reldiff_full>-1 & reldiff_full<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Absolute Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeABS_NC_Full_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeABS_NC_Full_`model'_eta`eta'.png", as(png) replace

	sum diff_fullfam, detail
	replace diff_fullfam=-100 if diff_fullfam<-100
	replace diff_fullfam=100 if diff_fullfam>100
	hist diff_fullfam if reldiff_fullfam>-1 & reldiff_fullfam<1, fraction color(gray) ///
		ytitle("Relative Frequency") xtitle("Absolute Change in Patient Volume, {&eta}=`eta'") legend(off)
	graph save "${RESULTS_FINAL}VolumeChangeABS_NC_FullFam_`model'_eta`eta'", replace
	graph export "${RESULTS_FINAL}VolumeChangeABS_NC_FullFam_`model'_eta`eta'.png", as(png) replace

}


log close
