set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}R2_RiskAdj_`logdate'.log", replace

******************************************************************
**	Title:		R2 — Risk-Adjusted Specialist Quality (VRDC)
**	Author:		Ian McCarthy
**	Date Created:	5/18/2026
**	Notes:		Revision script. Strips patient case-mix from the
**			failure outcome and aggregates to the specialist
**			level, then compares to the unadjusted measure
**			(spec_qual_raw) used in the structural model.
**
**			Risk-adjusters are *patient* characteristics only:
**			age (quadratic), female, race, DRG dummies, and
**			Charlson Comorbidity Index (cci_score). No year,
**			HRR, or specialist effects on the right-hand side
**			— those would absorb specialist heterogeneity,
**			which is the thing we want to keep.
**
**			Charlson Comorbidity Index (CCI):
**			built separately by data-code/P1-patient-cci.sas
**			(Quan 2005 ICD-9 + ICD-10 across dx1-25 on the
**			index admission, with Charlson hierarchies). User
**			exports patient_cci.csv from SAS Enterprise Guide
**			and drops it into ${DATA_FINAL}patient_cci.csv on
**			the R side before running this script.
**
**			Outputs (per Goal 1: risk-adjusted vs raw quality):
**			  - DRG_Distribution_<r_type>.csv (supports the
**			    DRG 470 concentration point for the A3 MNL
**			    extensions, Goal 2)
**			  - SpecQualAdj_<r_type>.csv: specialist-level
**			    raw + risk-adjusted quality + ranks
**			  - SpecQualAdj_<r_type>.png: raw vs adj scatter
**
**			Self-contained: stacks Referrals_<y>_<r_type>.dta
**			directly; no dependence on A0/A1 temp files.
******************************************************************

local r_type "${PCP_First}_${PCP_Only}_${RFR_Priority}"


******************************************************************
** Stack patient-event-level data across years
clear
forvalues y=2008/2018 {
	append using "${DATA_FINAL}Referrals_`y'_`r_type'.dta", ///
		keep(bene_id clm_id Practice_ID Specialist_ID admit Year ///
		     bene_age bene_gender bene_race clm_drg_cd any_bad)
}

** merge in Charlson Comorbidity Index from P1-patient-cci.sas
preserve
import delimited using "${DATA_FINAL}patient_cci.csv", clear varnames(1)
keep bene_id clm_id cci_score
duplicates drop bene_id clm_id, force
save temp_cci, replace
restore
merge m:1 bene_id clm_id using temp_cci, keep(master match) nogenerate
gen byte cci_missing=missing(cci_score)
replace cci_score=0 if missing(cci_score)
erase temp_cci.dta

** restrict to specialists meeting the estimation-sample size threshold
bys Specialist_ID: gen spec_n=_N
keep if spec_n>=${SPEC_MIN}
drop spec_n


******************************************************************
** Clean covariates (handle both string and numeric storage)
capture confirm numeric variable bene_gender
if _rc==0 {
	gen byte female=(bene_gender==2)
	replace female=. if !inlist(bene_gender,1,2)
}
else {
	gen byte female=(bene_gender=="2")
	replace female=. if !inlist(bene_gender,"1","2")
}

capture confirm numeric variable bene_race
if _rc==0 {
	gen byte race_cat=1 if bene_race==1
	replace race_cat=2 if bene_race==2
	replace race_cat=3 if !inlist(bene_race,1,2,.) & !missing(bene_race)
}
else {
	gen byte race_cat=1 if bene_race=="1"
	replace race_cat=2 if bene_race=="2"
	replace race_cat=3 if !inlist(bene_race,"1","2","") & !missing(bene_race)
}

capture confirm numeric variable clm_drg_cd
if _rc==0 {
	gen drg=clm_drg_cd
}
else {
	encode clm_drg_cd, gen(drg)
}

gen age=bene_age
gen age2=bene_age^2

drop if missing(any_bad, age, female, race_cat, drg)


******************************************************************
** DRG distribution of the analytic sample
preserve
contract clm_drg_cd, freq(n_events)
egen tot=total(n_events)
gen share=n_events/tot
drop tot
gsort -n_events
replace n_events=. if n_events<=11
replace share=. if missing(n_events)
list, sepby(clm_drg_cd) noobs
export delimited using "${RESULTS_BASE}DRG_Distribution_`r_type'.csv", replace
restore


******************************************************************
** Patient-level LPM for failure: any_bad on patient characteristics.
** age (quadratic) + female + race + DRG + Charlson CCI.
reg any_bad c.age##c.age i.female i.race_cat i.drg c.cci_score i.cci_missing
predict phat_lpm, xb

** trim predictions to [0,1] for indirect-standardization aggregation
gen phat=phat_lpm
replace phat=0 if phat<0
replace phat=1 if phat>1

sum any_bad
local mean_fail=r(mean)


******************************************************************
** Specialist-level aggregation
** Risk-adjusted failure = (observed - expected) + overall-mean failure
** Risk-adjusted quality = 1 - risk-adjusted failure
preserve
collapse (count) n_pat=any_bad (mean) obs_fail=any_bad exp_fail=phat, by(Specialist_ID)
gen adj_fail=obs_fail - exp_fail + `mean_fail'
gen spec_qual_raw=1 - obs_fail
gen spec_qual_adj=1 - adj_fail

** summary + raw-vs-adjusted correlation
sum spec_qual_raw spec_qual_adj
corr spec_qual_raw spec_qual_adj
spearman spec_qual_raw spec_qual_adj

** rank changes
egen rank_raw=rank(spec_qual_raw)
egen rank_adj=rank(spec_qual_adj)
gen rank_diff=rank_adj - rank_raw
sum rank_diff, detail

** cell-size masking before export
foreach v of varlist obs_fail exp_fail adj_fail spec_qual_raw spec_qual_adj rank_raw rank_adj rank_diff {
	replace `v'=. if n_pat<=11
}
replace n_pat=. if n_pat<=11

export delimited using "${RESULTS_BASE}SpecQualAdj_`r_type'.csv", replace
restore


******************************************************************
** Scatter of raw vs risk-adjusted quality at specialist level
preserve
collapse (count) n_pat=any_bad (mean) obs_fail=any_bad exp_fail=phat, by(Specialist_ID)
keep if n_pat>=${SPEC_MIN}
gen adj_fail=obs_fail - exp_fail + `mean_fail'
gen spec_qual_raw=1 - obs_fail
gen spec_qual_adj=1 - adj_fail

twoway (scatter spec_qual_adj spec_qual_raw, mcolor(gs6%40) msize(small)) ///
	(function y=x, range(spec_qual_raw) lcolor(black) lpattern(dash)), ///
	xtitle("Raw Specialist Quality (Success Rate)") ///
	ytitle("Risk-Adjusted Specialist Quality") ///
	legend(off)
graph save "${RESULTS_BASE}SpecQualAdj_`r_type'", replace
graph export "${RESULTS_BASE}SpecQualAdj_`r_type'.png", as(png) replace
restore


log close
