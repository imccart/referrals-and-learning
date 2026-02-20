set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}ReducedForm_`logdate'.log", replace

******************************************************************
**	Title:		Reduced-form evidence on response to failures
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	7/16/2024
******************************************************************

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
bys Specialist_ID: egen max_yearly_ops=max(yearly_ops)
keep if max_yearly_ops>=${SPEC_MIN}
keep if EstPCPMatch==3
save temp_base_data, replace

******************************************************************
** Create balanced data of quarterly referrals
use temp_base_data, clear
gen quarter=qofd(admit)
format quarter %tq

** collapse to pair/quarter level
collapse (count) patients=bene_id (sum) readmit mortality_30 mortality_60 mortality_90 any_comp any_bad, by(Practice_ID Specialist_ID quarter)
egen pair=group(Practice_ID Specialist_ID)
drop if quarter<quarterly("2008q1","YQ") | quarter==.

by Practice_ID Specialist_ID: gen pair_count=_n
by Practice_ID Specialist_ID: egen first_quarter=min(quarter)
gen new_spec=(pair_count==1 & first_quarter==quarter)
save temp_new_specs, replace

** form complete data (balanced across quarters for each pair)
keep patients readmit* mortality* any_comp any_bad pair Practice_ID Specialist_ID quarter
reshape wide patients readmit* mortality* any_comp any_bad, i(pair Practice_ID Specialist_ID) j(quarter)
foreach x of varlist patients* readmit* mortality* any_comp* any_bad* {
	replace `x'=0 if `x'==.
}
reshape long patients readmit mortality_30 mortality_60 mortality_90 any_comp any_bad, i(pair Practice_ID Specialist_ID) j(quarter)
bys pair: egen total_pair_patients=total(patients)
save "${DATA_FINAL}QuarterlyReferralPanel.dta", replace



******************************************************************
** Create balanced data of quarterly referrals at practice level
use temp_base_data, clear
gen quarter=qofd(admit)
format quarter %tq
merge m:1 Practice_ID Specialist_ID quarter using temp_new_specs, nogenerate keep(master match)

** count unique number of specialists and new specialists
bys Practice_ID Specialist_ID quarter: gen spec_count=_n
replace spec_count=0 if spec_count>1

** collapse to pair/quarter level
collapse (count) patients=bene_id (sum) total_specialists=spec_count new_specialists=new_spec ///
	readmit mortality_30 mortality_60 mortality_90 any_comp any_bad, by(Practice_ID quarter)
drop if quarter<quarterly("2008q1","YQ") | quarter==.

** form complete data (balanced across quarters for each PCP)
reshape wide patients total_specialists new_specialists readmit* mortality* any_comp any_bad, i(Practice_ID) j(quarter)
foreach x of varlist patients* readmit* mortality* any_comp* any_bad* total_specialists* new_specialists* {
	replace `x'=0 if `x'==.
}
reshape long patients total_specialists new_specialists readmit mortality_30 mortality_60 mortality_90 any_comp any_bad, i(Practice_ID) j(quarter)
save "${DATA_FINAL}QuarterlyPCPPanel.dta", replace




******************************************************************
** Create balanced data of yearly referrals
use temp_base_data, clear

** collapse to pair/year level
collapse (count) patients=bene_id (sum) readmit mortality_30 mortality_60 mortality_90 any_comp any_bad, by(Practice_ID Specialist_ID Year)
egen pair=group(Practice_ID Specialist_ID)

** form complete data (balanced across quarters for each pair)
reshape wide patients readmit* mortality* any_comp any_bad, i(pair Practice_ID Specialist_ID) j(Year)
foreach x of varlist patients* readmit* mortality* any_comp* any_bad* {
	replace `x'=0 if `x'==.
}
reshape long patients readmit mortality_30 mortality_60 mortality_90 any_comp any_bad, i(pair Practice_ID Specialist_ID) j(Year)
bys pair: egen total_pair_patients=total(patients)
save "${DATA_FINAL}YearlyReferralPanel.dta", replace


******************************************************************
** Specialist and pcp failures by quarter
use temp_base_data, clear
gen quarter=qofd(admit)
format quarter %tq
drop if quarter==.

collapse (count) patients=bene_id (sum) any_bad, by(Specialist_ID quarter)
reshape wide patients any_bad, i(Specialist_ID) j(quarter)
foreach x of varlist patients* any_bad* {
	replace `x'=0 if `x'==.
}
reshape long patients any_bad, i(Specialist_ID) j(quarter)
sort Specialist_ID quarter
by Specialist_ID: gen spec_cumul_failure=sum(any_bad)-any_bad
by Specialist_ID: gen spec_cumul_patients=sum(patients)-patients
gen spec_failure_rate=spec_cumul_failure/spec_cumul_patients
save spec_failure_quarter, replace


use temp_base_data, clear
gen quarter=qofd(admit)
format quarter %tq
drop if quarter==.
merge m:1 Practice_ID Specialist_ID quarter using temp_new_specs, nogenerate keep(master match)
drop if new_spec==1

collapse (sum) any_bad, by(Practice_ID quarter)
reshape wide any_bad, i(Practice_ID) j(quarter)
foreach x of varlist any_bad* {
	replace `x'=0 if `x'==.
}
reshape long any_bad, i(Practice_ID) j(quarter)
sort Practice_ID quarter
by Practice_ID: gen pcp_cumul_failure=sum(any_bad)-any_bad
save pcp_failure_quarter, replace


******************************************************************
** Quarters of specialist and pcp failures
use temp_base_data, clear
gen quarter=qofd(admit)
format quarter %tq
drop if quarter==.
keep if quarter>=quarterly("2013q1","YQ")

collapse (sum) any_bad, by(Specialist_ID quarter)
keep if any_bad>0
drop any_bad
sort Specialist_ID quarter
by Specialist_ID: gen obs=_n
reshape wide quarter, i(Specialist_ID) j(obs)
save spec_quarter_of_failures, replace


use temp_base_data, clear
gen quarter=qofd(admit)
format quarter %tq
drop if quarter==.
keep if quarter>=quarterly("2013q1","YQ")

collapse (sum) any_bad, by(Practice_ID quarter)
keep if any_bad>0
drop any_bad
sort Practice_ID quarter
by Practice_ID: gen obs=_n
reshape wide quarter, i(Practice_ID) j(obs)
save pcp_quarter_of_failures, replace


******************************************************************
** Initial analysis (just showing where referrals are coming from and correlation between failures and referrals)
use "${DATA_FINAL}QuarterlyReferralPanel.dta", clear
sort pair quarter
by pair: gen cumul_patients=sum(patients)-patients
by pair: gen cumul_failures=sum(any_bad)-any_bad

** drop specialists with only one PCPs
bys pair: gen obs=_n
replace obs=0 if obs>1
bys Specialist_ID: egen pcp_per_spec=total(obs)
keep if pcp_per_spec>1
drop obs

** drop pairs with no history
drop if cumul_patients==0 & patients==0
keep if quarter>=quarterly("2013q1","YQ")
save temp_reduced_form, replace


** regression analysis
use temp_reduced_form, clear
merge m:1 Specialist_ID quarter using spec_failure_quarter, nogenerate keep(master match)
** find pairs that have and have not seen failures from same specialists
gen failure_diff=spec_cumul_failure-cumul_failures
** drop specialists with no failure ever
bys Specialist_ID: egen max_failure=max(spec_cumul_failure)
drop if max_failure==0

xtset pair quarter
gen share_obs=cumul_failures/spec_cumul_failure
gen any_obs=cumul_failures>0
xtreg patients any_obs share_obs cumul_patients L.patients i.quarter, fe
xtreg patients cumul_failures cumul_patients L.patients i.quarter, fe

** mean difference by observed vs total failure rate
collapse (sum) patients, by(Specialist_ID cumul_failures spec_cumul_failure quarter)
sort Specialist_ID quarter spec_cumul_failure cumul_failures

collapse (mean) patients, by(cumul_failures spec_cumul_failure quarter)
format quarter %tq

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
graph twoway (connected patients quarter if spec_cumul_failure==1 & cumul_failures==0, color(black) lpattern(solid)) ///
	     (connected patients quarter if spec_cumul_failure==1 & cumul_failures==1, color(black) lpattern(dash)), ///
	      xtitle("Quarter") ytitle("Patients") ylabel(0(1)5) ///
	      text(0.3 2013 "With Failures", place(e)) text(3.4 2013 "Without Failures", place(e))
graph save "${RESULTS_FINAL}MeanPatients_Fail1_`r_type'", replace
graph export "${RESULTS_FINAL}MeanPatients_Fail1_`r_type'.png", as(png) replace			

graph twoway (connected patients quarter if spec_cumul_failure==2 & cumul_failures==0, color(black) lpattern(solid)) ///
	     (connected patients quarter if spec_cumul_failure==2 & cumul_failures==1, color(gs10) lpattern(dot)) ///
	     (connected patients quarter if spec_cumul_failure==2 & cumul_failures==2, color(black) lpattern(dash)), ///
	      xtitle("Year") ytitle("Patients") ylabel(0(1)6) ///
	      text(0.7 2013 "With Failures", place(e)) text(5.1 2013 "Without Failures", place(e))
graph save "${RESULTS_FINAL}MeanPatients_Fail2_`r_type'", replace
graph export "${RESULTS_FINAL}MeanPatients_Fail2_`r_type'.png", as(png) replace			


graph twoway (connected patients quarter if spec_cumul_failure==3 & cumul_failures==0, color(black) lpattern(solid)) ///
	     (connected patients quarter if spec_cumul_failure==3 & cumul_failures==1, color(gs10) lpattern(dot)) ///
	     (connected patients quarter if spec_cumul_failure==3 & cumul_failures==2, color(gs10) lpattern(dot))  ///
	     (connected patients quarter if spec_cumul_failure==3 & cumul_failures==3, color(black) lpattern(dash)), ///
	      xtitle("Year") ytitle("Patients") ylabel(0(1)7) ///
	      text(0.7 2013 "With Failures", place(e)) text(6.1 2013 "Without Failures", place(e))
graph save "${RESULTS_FINAL}MeanPatients_Fail3_`r_type'", replace
graph export "${RESULTS_FINAL}MeanPatients_Fail3_`r_type'.png", as(png) replace			
	     
use temp_reduced_form, clear
merge m:1 Specialist_ID quarter using spec_failure_quarter, nogenerate keep(master match)
keep if quarter>=quarterly("2013q1","YQ") & quarter<quarterly("2018q4","YQ")

keep if spec_cumul_patients>=100
gen fail_quantile=.
forvalues q=212/234 {
	capture drop xq
	xtile xq=spec_failure_rate if quarter==`q', nq(4)
	replace fail_quantile=xq if quarter==`q'
}
collapse (mean) patients, by(quarter fail_quantile)

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	     
format quarter %tq
graph twoway (connected patients quarter if fail_quantile==1, color(black) lpattern(solid)) ///
	(connected patients quarter if fail_quantile==4, color(gs10) lpattern(solid)), ///
	legend(off) ytitle("Referrals Received") ylabel(0(.05).2) xtitle("Quarter") ///
	xlabel(212(4)232) text(0.11 225 "Lowest Quartile Failures", place(e)) text(.06 224 "Highest Quartile Failures", place(e))
graph save "${RESULTS_FINAL}MeanPatients_FailureQuartile_`r_type'", replace
graph export "${RESULTS_FINAL}MeanPatients_FailureQuartile_`r_type'.png", as(png) replace		

	     
	     
******************************************************************	
** Event Studies (using PCPs with "unobserved" failures as control groups)
** note: in this case, we have panel of specialist/PCP type. A typical setup would have a panel of units, some of which are treated at some time, but this has
**   a panel of units x pcp-type. This means our typical unit fixed effects need to now include a specialist FE and a PCP-type FE (treat_group). Another specification
**   could include specialist/pcp-type FEs.


use temp_reduced_form, clear
merge m:1 Specialist_ID quarter using spec_failure_quarter, nogenerate keep(master match)
merge m:1 Specialist_ID using spec_quarter_of_failures, nogenerate keep(master match)

** find pairs that have and have not seen failures from same specialists
gen failure_diff=spec_cumul_failure-cumul_failures

** drop specialists with no failure in time period
drop if quarter1==.

** definte treatment groups (check number of quarters in spec_quarter_of_failures file)
gen group_1=(quarter<quarter2) if quarter2!=.
replace group_1=1 if quarter2==.
forvalues q=2/23 {
	local prior_q=`q'-1
	local next_q=`q'+1
	gen group_`q'=(quarter`prior_q'<quarter & quarter<quarter`next_q') if quarter`prior_q'!=. & quarter`next_q'!=.
	replace group_`q'=(quarter`prior_q'<quarter) if quarter`next_q'==. & quarter`prior_q'!=.
}
gen group_24=(quarter23<quarter) if quarter23!=.

forvalues q=1/10 {
	preserve
	keep if group_`q'==1
	bys pair: egen min_failures=min(cumul_failures)
	bys pair: egen max_failures=max(cumul_failures)
	gen treat_group=(min_failures<max_failures)
	**drop if cumul_failures>(`q'+1)
	save temp_panel_group_`q', replace
	restore
}

** Group 1
use temp_panel_group_1, clear
format quarter %tq
sort Specialist_ID pair quarter
replace patients=patients-any_bad
keep pair Practice_ID Specialist_ID patients spec_cumul_failure spec_cumul_patients cumul_failures treat_group quarter quarter1 quarter2

collapse (mean) patients (first) quarter1, by(Specialist_ID treat_group quarter)

gen event_time=(quarter-quarter1)*treat_group
replace event_time=-1 if event_time==0 & treat_group==0

forvalues l = 0/8 {
    gen L`l'event = (event_time==`l')
}
forvalues l = 1/8 {
    gen F`l'event = (event_time==-`l')
}
gen F9event=(event_time<=-9)
gen L9event=(event_time>=9)
save event_time1, replace

** for interpretation
sum patients if treat_group==1 & event_time<0
sum patients if treat_group==0
sum patients if event_time<0 | treat_group==0

egen spec_q_fe=group(Specialist_ID quarter)
areg patients F9event F8event F7event F6event F5event F4event F3event F2event ///
	L0event L1event L2event L3event L4event L5event L6event L7event L8event L9event i.treat_group, absorb(spec_q_fe) cluster(Specialist_ID)

gen coef = .
gen se = .
forvalues i = 2(1)9 {
    replace coef = _b[F`i'event] if F`i'event==1
    replace se = _se[F`i'event] if F`i'event==1
}
forvalues i = 0(1)9 {
    replace coef = _b[L`i'event] if L`i'event==1
    replace se = _se[L`i'event] if L`i'event==1
}
replace coef = 0 if F1event==1
replace se=0 if F1event==1

* Make confidence intervals
gen ci_top = coef+1.96*se
gen ci_bottom = coef - 1.96*se

* Limit ourselves to one observation per period
keep if event_time>=-9 & event_time<=9
*drop if event_time==0
keep event_time coef se ci_*
duplicates drop
sort event_time

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	     
set scheme uncluttered
twoway (sc coef event_time, connect(line) xline(0)) (rcap ci_top ci_bottom event_time) ///
    (function y = 0, range(-9 9)), xtitle("Event Time") ///
    ytitle("Point Estimates and 95% CIs") xlabel(-9(1)9) ylabel(-.2(.1).2)
graph save "${RESULTS_FINAL}EventStudy_Group1_`r_type'", replace
graph export "${RESULTS_FINAL}EventStudy_Group1_`r_type'.png", as(png) replace			




** Group 2
use temp_panel_group_2, clear
format quarter %tq
sort Specialist_ID pair quarter
replace patients=patients-any_bad
keep pair Practice_ID Specialist_ID patients spec_cumul_failure cumul_failures treat_group quarter quarter1 quarter2 quarter3

collapse (mean) patients (first) quarter2, by(Specialist_ID treat_group quarter)

gen event_time=(quarter-quarter2)*treat_group
replace event_time=-1 if event_time==.

forvalues l = 0/8 {
    gen L`l'event = (event_time==`l')
}
forvalues l = 1/8 {
    gen F`l'event = (event_time==-`l')
}
gen F9event=(event_time<=-9)
gen L9event=(event_time>=9)
save event_time2, replace

egen spec_q_fe=group(Specialist_ID quarter)
areg patients F9event F8event F7event F6event F5event F4event F3event F2event ///
	L0event L1event L2event L3event L4event L5event L6event L7event L8event L9event i.treat_group, absorb(spec_q_fe) cluster(Specialist_ID)

gen coef = .
gen se = .
forvalues i = 2(1)9 {
    replace coef = _b[F`i'event] if F`i'event==1
    replace se = _se[F`i'event] if F`i'event==1
}
forvalues i = 0(1)9 {
    replace coef = _b[L`i'event] if L`i'event==1
    replace se = _se[L`i'event] if L`i'event==1
}
replace coef = 0 if F1event==1
replace se=0 if F1event==1

* Make confidence intervals
gen ci_top = coef+1.96*se
gen ci_bottom = coef - 1.96*se

* Limit ourselves to one observation per period
keep if event_time>=-9 & event_time<=9
*drop if event_time==0
keep event_time coef se ci_*
duplicates drop
sort event_time

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	     
set scheme uncluttered
twoway (sc coef event_time, connect(line) xline(0)) (rcap ci_top ci_bottom event_time) ///
    (function y = 0, range(-9 9)), xtitle("Event Time") ///
    ytitle("Point Estimates and 95% CIs") xlabel(-9(1)9) ylabel(-.2(.1).2)
graph save "${RESULTS_FINAL}EventStudy_Group2_`r_type'", replace
graph export "${RESULTS_FINAL}EventStudy_Group2_`r_type'.png", as(png) replace			



** Group 3
use temp_panel_group_3, clear
format quarter %tq
sort Specialist_ID pair quarter
replace patients=patients-any_bad
keep pair Practice_ID Specialist_ID patients spec_cumul_failure cumul_failures treat_group quarter quarter1 quarter2 quarter3 quarter4

collapse (mean) patients (first) quarter3, by(Specialist_ID treat_group quarter)


gen event_time=(quarter-quarter3)*treat_group
replace event_time=-1 if event_time==.

forvalues l = 0/8 {
    gen L`l'event = (event_time==`l')
}
forvalues l = 1/8 {
    gen F`l'event = (event_time==-`l')
}
gen F9event=(event_time<=-9)
gen L9event=(event_time>=9)
save event_time3, replace

egen spec_q_fe=group(Specialist_ID quarter)
areg patients F9event F8event F7event F6event F5event F4event F3event F2event ///
	L0event L1event L2event L3event L4event L5event L6event L7event L8event L9event i.treat_group, absorb(spec_q_fe) cluster(Specialist_ID)

gen coef = .
gen se = .
forvalues i = 2(1)9 {
    replace coef = _b[F`i'event] if F`i'event==1
    replace se = _se[F`i'event] if F`i'event==1
}
forvalues i = 0(1)9 {
    replace coef = _b[L`i'event] if L`i'event==1
    replace se = _se[L`i'event] if L`i'event==1
}
replace coef = 0 if F1event==1
replace se=0 if F1event==1

* Make confidence intervals
gen ci_top = coef+1.96*se
gen ci_bottom = coef - 1.96*se

* Limit ourselves to one observation per period
keep if event_time>=-9 & event_time<=9
*drop if event_time==0
keep event_time coef se ci_*
duplicates drop
sort event_time

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	     
set scheme uncluttered
twoway (sc coef event_time, connect(line) xline(0)) (rcap ci_top ci_bottom event_time) ///
    (function y = 0, range(-9 9)), xtitle("Event Time") ///
    ytitle("Point Estimates and 95% CIs") xlabel(-9(1)9) ylabel(-.2(.1).2)
graph save "${RESULTS_FINAL}EventStudy_Group3_`r_type'", replace
graph export "${RESULTS_FINAL}EventStudy_Group3_`r_type'.png", as(png) replace			


** Group 4
use temp_panel_group_4, clear
format quarter %tq
sort Specialist_ID pair quarter
replace patients=patients-any_bad
keep pair Practice_ID Specialist_ID patients spec_cumul_failure cumul_failures treat_group quarter quarter1 quarter2 quarter3 quarter4 quarter5

collapse (mean) patients (first) quarter4, by(Specialist_ID treat_group quarter)


gen event_time=(quarter-quarter4)*treat_group
replace event_time=-1 if event_time==.

forvalues l = 0/8 {
    gen L`l'event = (event_time==`l')
}
forvalues l = 1/8 {
    gen F`l'event = (event_time==-`l')
}
gen F9event=(event_time<=-9)
gen L9event=(event_time>=9)
save event_time4, replace

egen spec_q_fe=group(Specialist_ID quarter)
areg patients F9event F8event F7event F6event F5event F4event F3event F2event ///
	L0event L1event L2event L3event L4event L5event L6event L7event L8event L9event i.treat_group, absorb(spec_q_fe) cluster(Specialist_ID)

gen coef = .
gen se = .
forvalues i = 2(1)9 {
    replace coef = _b[F`i'event] if F`i'event==1
    replace se = _se[F`i'event] if F`i'event==1
}
forvalues i = 0(1)9 {
    replace coef = _b[L`i'event] if L`i'event==1
    replace se = _se[L`i'event] if L`i'event==1
}
replace coef = 0 if F1event==1
replace se=0 if F1event==1

* Make confidence intervals
gen ci_top = coef+1.96*se
gen ci_bottom = coef - 1.96*se

* Limit ourselves to one observation per period
keep if event_time>=-9 & event_time<=9
*drop if event_time==0
keep event_time coef se ci_*
duplicates drop
sort event_time

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	     
set scheme uncluttered
twoway (sc coef event_time, connect(line) xline(0)) (rcap ci_top ci_bottom event_time) ///
    (function y = 0, range(-9 9)), xtitle("Event Time") ///
    ytitle("Point Estimates and 95% CIs") xlabel(-9(1)9) ylabel(-.2(.1).2)
graph save "${RESULTS_FINAL}EventStudy_Group4_`r_type'", replace
graph export "${RESULTS_FINAL}EventStudy_Group4_`r_type'.png", as(png) replace			


** Pooled/stacked estimates
use event_time1, clear
gen group=1

forvalues g=2/4 {
	append using event_time`g'
	replace group=`g' if group==.
}

** for interpretation
sum patients if treat_group==1 & event_time<0
local es_base = r(mean)
sum patients if treat_group==0
sum patients if event_time<0 | treat_group==0
save temp_stacked_est, replace


use temp_stacked_est, clear
egen spec_q_fe=group(Specialist_ID quarter)
egen spec_group_fe=group(Specialist_ID group treat_group)

reghdfe patients F9event F8event F7event F6event F5event F4event F3event F2event ///
	L0event L1event L2event L3event L4event L5event L6event L7event L8event L9event, absorb(spec_q_fe spec_group_fe) cluster(spec_group)
local es_coef = abs(_b[L0event])
gen coef = .
gen se = .
forvalues i = 2(1)9 {
    replace coef = _b[F`i'event] if F`i'event==1
    replace se = _se[F`i'event] if F`i'event==1
}
forvalues i = 0(1)9 {
    replace coef = _b[L`i'event] if L`i'event==1
    replace se = _se[L`i'event] if L`i'event==1
}
replace coef = 0 if F1event==1
replace se=0 if F1event==1

* Make confidence intervals
gen ci_top = coef+1.96*se
gen ci_bottom = coef - 1.96*se

* Limit ourselves to one observation per period
keep if event_time>=-9 & event_time<=9
**drop if event_time==0
keep event_time coef se ci_*
duplicates drop
sort event_time

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	     
set scheme uncluttered
twoway (sc coef event_time, connect(line) xline(0)) (rcap ci_top ci_bottom event_time) ///
    (function y = 0, range(-9 9)), xtitle("Event Time") ///
    ytitle("Point Estimates and 95% CIs") xlabel(-9(1)9) ylabel(-.2(.1).2)
graph save "${RESULTS_FINAL}EventStudy_Stacked_`r_type'", replace
graph export "${RESULTS_FINAL}EventStudy_Stacked_`r_type'.png", as(png) replace

** Paper numbers — event study scalars
local es_pct: di %2.0f `es_coef'/`es_base' * 100
local es_pct = strtrim("`es_pct'")

local outfile "${RESULTS_FINAL}paper-numbers-rf.tex"
file open fh using "`outfile'", write replace
file write fh "%% Auto-generated by A2-reduced-form.do — do not edit by hand" _n
file write fh "\newcommand{\eventStudyCoef}{`=string(`es_coef', "%5.3f")'}" _n
file write fh "\newcommand{\eventStudyBaseRate}{`=string(`es_base', "%5.3f")'}" _n
file write fh "\newcommand{\eventStudyPctReduction}{`es_pct'}" _n
file close fh


** Group 1 (CLEAN - NO FAILURES IN RECENT PERIOD)
use temp_panel_group_1, clear
format quarter %tq
sort Specialist_ID pair quarter
replace patients=patients-any_bad
keep pair Practice_ID Specialist_ID patients spec_cumul_failure spec_cumul_patients cumul_failures treat_group quarter quarter1 quarter2

collapse (mean) patients (first) quarter1, by(Specialist_ID treat_group quarter)

gen time_since_failure=quarter-quarter1
gen event_time=(quarter-quarter1)*treat_group
replace event_time=-1 if event_time==0 & treat_group==0
bys Specialist_ID: egen min_time_since_failure=min(time_since_failure)
keep if min_time_since_failure < -3

forvalues l = 0/8 {
    gen L`l'event = (event_time==`l')
}
forvalues l = 1/8 {
    gen F`l'event = (event_time==-`l')
}
gen F9event=(event_time<=-9)
gen L9event=(event_time>=9)

** for interpretation
sum patients if treat_group==1 & event_time<0
sum patients if treat_group==0
sum patients if event_time<0 | treat_group==0

egen spec_q_fe=group(Specialist_ID quarter)
areg patients F9event F8event F7event F6event F5event F4event F3event F2event ///
	L0event L1event L2event L3event L4event L5event L6event L7event L8event L9event i.treat_group, absorb(spec_q_fe) cluster(Specialist_ID)

gen coef = .
gen se = .
forvalues i = 2(1)9 {
    replace coef = _b[F`i'event] if F`i'event==1
    replace se = _se[F`i'event] if F`i'event==1
}
forvalues i = 0(1)9 {
    replace coef = _b[L`i'event] if L`i'event==1
    replace se = _se[L`i'event] if L`i'event==1
}
replace coef = 0 if F1event==1
replace se=0 if F1event==1

* Make confidence intervals
gen ci_top = coef+1.96*se
gen ci_bottom = coef - 1.96*se

* Limit ourselves to one observation per period
keep if event_time>=-9 & event_time<=9
*drop if event_time==0
keep event_time coef se ci_*
duplicates drop
sort event_time

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	     
set scheme uncluttered
twoway (sc coef event_time, connect(line) xline(0)) (rcap ci_top ci_bottom event_time) ///
    (function y = 0, range(-9 9)), xtitle("Event Time") ///
    ytitle("Point Estimates and 95% CIs") xlabel(-9(1)9) ylabel(-.2(.1).2)
graph save "${RESULTS_FINAL}EventStudy_Group1_CLEAN_`r_type'", replace
graph export "${RESULTS_FINAL}EventStudy_Group1_CLEAN_`r_type'.png", as(png) replace			


******************************************************************	
** Event Studies without collapsing to mean (i.e., at pcp-specialist level rather than type-specialist level)

** Group 1
forvalues i=1/4 {
	use temp_panel_group_`i', clear
	local stop=`i'+1
	format quarter %tq
	sort Specialist_ID pair quarter
	replace patients=patients-any_bad
	keep pair Practice_ID Specialist_ID patients spec_cumul_failure spec_cumul_patients cumul_failures treat_group quarter quarter1-quarter`stop'

	gen event_time=(quarter-quarter`i')*treat_group
	replace event_time=-1 if event_time==0 & treat_group==0

	forvalues l = 0/8 {
		gen L`l'event = (event_time==`l')
	}
	forvalues l = 1/8 {
		gen F`l'event = (event_time==-`l')
	}
	gen F9event=(event_time<=-9)
	gen L9event=(event_time>=9)
	save pcp_event_time`i', replace
}

** Pooled/stacked estimates
use pcp_event_time1, clear
gen group=1

forvalues g=2/4 {
	append using pcp_event_time`g'
	replace group=`g' if group==.
}

** for interpretation
sum patients if treat_group==1 & event_time<0
sum patients if treat_group==0
sum patients if event_time<0 | treat_group==0


reghdfe patients F9event F8event F7event F6event F5event F4event F3event F2event ///
	L0event L1event L2event L3event L4event L5event L6event L7event L8event L9event i.quarter, absorb(Specialist_ID Practice_ID group) cluster(Specialist_ID)
gen coef = .
gen se = .
forvalues i = 2(1)9 {
    replace coef = _b[F`i'event] if F`i'event==1
    replace se = _se[F`i'event] if F`i'event==1
}
forvalues i = 0(1)9 {
    replace coef = _b[L`i'event] if L`i'event==1
    replace se = _se[L`i'event] if L`i'event==1
}
replace coef = 0 if F1event==1
replace se=0 if F1event==1

* Make confidence intervals
gen ci_top = coef+1.96*se
gen ci_bottom = coef - 1.96*se

* Limit ourselves to one observation per period
keep if event_time>=-9 & event_time<=9
drop if event_time==0
keep event_time coef se ci_*
duplicates drop
sort event_time

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	     
set scheme uncluttered
twoway (sc coef event_time, connect(line) xline(0)) (rcap ci_top ci_bottom event_time) ///
    (function y = 0, range(-9 9)), xtitle("Event Time") ///
    ytitle("Point Estimates and 95% CIs") xlabel(-9(1)9) ylabel(-.2(.1).2)
graph save "${RESULTS_FINAL}PCP_EventStudy_Stacked_`r_type'", replace
graph export "${RESULTS_FINAL}PCP_EventStudy_Stacked_`r_type'.png", as(png) replace			


******************************************************************	
** Event Studies based on Peer information

** PCP practice tax IDs
use temp_base_data, clear
format Practice_ID %12.0f
collapse (count) patients=bene_id, by(Practice_ID pcp_phy_tin1 Year)
bys Practice_ID Year: egen max_patients=max(patients)
keep if max_patients==patients
bys Practice_ID Year: gen obs=_n
keep if obs==1
keep Practice_ID pcp_phy_tin1 Year
save temp_pcp_taxid, replace

use temp_reduced_form, clear
gen Year=yofd(dofq(quarter))
merge m:1 Specialist_ID quarter using spec_failure_quarter, nogenerate keep(master match)
merge m:1 Specialist_ID using spec_quarter_of_failures, nogenerate keep(master match)
merge m:1 Practice_ID Year using temp_pcp_taxid, nogenerate keep(master match)
egen pair_tin=group(pcp_phy_tin1 Specialist_ID)
bys pair_tin quarter: egen tin_cumul_failures=sum(cumul_failures)

** drop specialists with no failure in time period
drop if quarter1==.

** definte treatment groups (check number of quarters in spec_quarter_of_failures file)
gen group_1=(quarter<quarter2) if quarter2!=.
replace group_1=1 if quarter2==.
forvalues q=2/23 {
	local prior_q=`q'-1
	local next_q=`q'+1
	gen group_`q'=(quarter`prior_q'<quarter & quarter<quarter`next_q') if quarter`prior_q'!=. & quarter`next_q'!=.
	replace group_`q'=(quarter`prior_q'<quarter) if quarter`next_q'==. & quarter`prior_q'!=.
}
gen group_24=(quarter23<quarter) if quarter23!=.

forvalues q=1/10 {
	preserve
	keep if group_`q'==1
	bys pair: egen min_failures=min(cumul_failures)
	bys pair_tin: egen tin_min_failures=min(tin_cumul_failures)
	bys pair: egen max_failures=max(tin_cumul_failures)
	bys pair_tin: egen tin_max_failures=max(tin_cumul_failures)
	gen treat_group=(min_failures==max_failures & tin_min_failures<tin_max_failures)
	**drop if cumul_failures>(`q'+1)
	save temp_panel_group_`q', replace
	restore
}

** Group 1
use temp_panel_group_1, clear
format quarter %tq
sort Specialist_ID pair quarter
replace patients=patients-any_bad
keep pair Practice_ID Specialist_ID patients spec_cumul_failure spec_cumul_patients cumul_failures tin_cumul_failures treat_group quarter quarter1 quarter2

collapse (mean) patients (first) quarter1, by(Specialist_ID treat_group quarter)

gen event_time=(quarter-quarter1)*treat_group
replace event_time=-1 if event_time==0 & treat_group==0

forvalues l = 0/8 {
    gen L`l'event = (event_time==`l')
}
forvalues l = 1/8 {
    gen F`l'event = (event_time==-`l')
}
gen F9event=(event_time<=-9)
gen L9event=(event_time>=9)
save event_time1, replace

** for interpretation
sum patients if treat_group==1 & event_time<0
sum patients if treat_group==0
sum patients if event_time<0 | treat_group==0

egen spec_q_fe=group(Specialist_ID quarter)
areg patients F9event F8event F7event F6event F5event F4event F3event F2event ///
	L0event L1event L2event L3event L4event L5event L6event L7event L8event L9event i.treat_group, absorb(spec_q_fe) cluster(Specialist_ID)

gen coef = .
gen se = .
forvalues i = 2(1)9 {
    replace coef = _b[F`i'event] if F`i'event==1
    replace se = _se[F`i'event] if F`i'event==1
}
forvalues i = 0(1)9 {
    replace coef = _b[L`i'event] if L`i'event==1
    replace se = _se[L`i'event] if L`i'event==1
}
replace coef = 0 if F1event==1
replace se=0 if F1event==1

* Make confidence intervals
gen ci_top = coef+1.96*se
gen ci_bottom = coef - 1.96*se

* Limit ourselves to one observation per period
keep if event_time>=-9 & event_time<=9
*drop if event_time==0
keep event_time coef se ci_*
duplicates drop
sort event_time

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	     
set scheme uncluttered
twoway (sc coef event_time, connect(line) xline(0)) (rcap ci_top ci_bottom event_time) ///
    (function y = 0, range(-9 9)), xtitle("Event Time") ///
    ytitle("Point Estimates and 95% CIs") xlabel(-9(1)9) ylabel(-1(.2)1)
graph save "${RESULTS_FINAL}EventStudy_Group1_Placebo_`r_type'", replace
graph export "${RESULTS_FINAL}EventStudy_Group1_Placebo_`r_type'.png", as(png) replace			




******************************************************************
** Transition matrix and heat map
use "${DATA_FINAL}QuarterlyReferralPanel.dta", clear
xtset pair quarter
gen lag_patients=L1.patients

mat trans=J(11*11,3,.)
local step=0
forvalues i=0/10 {
  forvalues j=0/10 {
	local step=`step'+1
  	qui count if lag_patients==`i'
	local denom=r(N)
	qui count if patients==`j' & lag_patients==`i'
	local num=r(N)
	local share=`num'/`denom'
    mat trans[`step',1] = `i'
    mat trans[`step',2] = `j'
    mat trans[`step',3] = `share'
  }
}
svmat trans
keep if trans1!=.

* use twoway scatter to produce heat map
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	     
set scheme s2color
twoway (scatter trans1 trans2 if trans3>=.8, mcolor(gs4) msize(vhuge)) ///
		(scatter trans1 trans2 if trans3>=.4 & trans3<.8, mcolor(gs6) msize(vhuge)) /// 
		(scatter trans1 trans2 if trans3>=.2 & trans3<.4, mcolor(gs8) msize(vhuge) ) /// 
		(scatter trans1 trans2 if trans3>=.1 & trans3<.2, mcolor(gs10) msize(vhuge) ) /// 
		(scatter trans1 trans2 if trans3>=.05 & trans3<.1, mcolor(gs12) msize(vhuge) ) /// 
		(scatter trans1 trans2 if trans3>=0 & trans3<.05, mcolor(gs14) msize(vhuge) ), /// 
  ylabel(0(1)10) xlabel(0(1)10) xtitle("") ytitle("") ///
  legend(cols(1) stack position(3)  ///
  order(1 ".8-1.0" 2 ".4-.8" 3 ".2-.4" 4 ".1-.2" 5 ".05-.1" 6 "0-.05"))
graph save "${RESULTS_FINAL}TransitionHeatMap_`r_type'", replace
graph export "${RESULTS_FINAL}TransitionHeatMap_`r_type'.png", as(png) replace			

    
******************************************************************
** Event Studies using no failures as controls

** count quarters of bad events
use "${DATA_FINAL}QuarterlyReferralPanel.dta", clear
gen bad_quarter=(any_bad>0)
bys pair: egen ever_bad=max(bad_quarter)
bys pair: egen count_bad=total(bad_quarter)
bys pair: gen pair_obs=_n
egen group_line=group(count_bad)
**replace patients=patients-any_bad
save temp_pair_failure, replace

** track time of failure
use temp_pair_failure, clear
sort pair quarter
by pair: gen running_failures=sum(bad_quarter)
collapse (min) quarter, by(pair running_failures)
reshape wide quarter, i(pair) j(running_failures)
save temp_failure_quarters, replace


** plot referrals relative to failures
use temp_pair_failure, clear
merge m:1 pair using temp_failure_quarters, nogenerate keep(master match)

preserve
set scheme uncluttered
collapse (mean) patients any_bad, by(quarter)
format quarter %tq
graph twoway connected patients quarter, color(black) legend(off) ///
	xtitle("Calendar Time") ytitle("Count of Patients Referred") ylabel(0(.2)1)
graph save "${RESULTS_FINAL}Referrals_All", replace
graph export "${RESULTS_FINAL}Referrals_All.png", as(png) replace			

graph twoway connected any_bad quarter, color(black) legend(off) ///
	xtitle("Calendar Time") ytitle("Count of Failures") ylabel(0(.02).1)
graph save "${RESULTS_FINAL}Failures_All", replace
graph export "${RESULTS_FINAL}Failures_All.png", as(png) replace			
restore


preserve
keep if group_line==1
set scheme uncluttered
collapse (mean) patients, by(quarter)
format quarter %tq
graph twoway connected patients quarter, color(black) legend(off) ///
	xtitle("Calendar Time") ytitle("Count of Patients Referred") ylabel(0(.2)1)
graph save "${RESULTS_FINAL}Referrals_NoFailures", replace
graph export "${RESULTS_FINAL}Referrals_NoFailures.png", as(png) replace			
restore

preserve
keep if group_line==2
set scheme uncluttered
collapse (mean) patients, by(quarter)
format quarter %tq
graph twoway connected patients quarter, color(black) legend(off) ///
	xtitle("Calendar Time") ytitle("") ylabel(0(.2)1)
graph save "${RESULTS_FINAL}Referrals_OneFailure", replace
graph export "${RESULTS_FINAL}Referrals_OneFailure.png", as(png) replace		
restore

preserve
keep if group_line==2
gen event_time=quarter-quarter1
collapse (mean) patients, by(event_time)
keep if event_time>=-12 & event_time<=12
graph twoway connected patients event_time, color(black) xline(0) legend(off) ///
	xtitle("Event Time") ytitle("") ylabel(0(.2)1) xlabel(-12(2)12)
graph save "${RESULTS_FINAL}Referrals_OneFailure_EventTime", replace
graph export "${RESULTS_FINAL}Referrals_OneFailure_EventTime.png", as(png) replace			
restore

set scheme uncluttered
graph combine "${RESULTS_FINAL}Referrals_OneFailure.gph" "${RESULTS_FINAL}Referrals_OneFailure_EventTime.gph", ///
	col(1) iscale(1) l1("Count of Patients Referred")
graph save "${RESULTS_FINAL}Referrals_OneFailure_Combined", replace
graph export "${RESULTS_FINAL}Referrals_OneFailure_Combined.png", as(png) replace			

	
preserve
keep if group_line==3
drop if quarter<=quarter1
collapse (mean) patients, by(quarter)
format quarter %tq
graph twoway connected patients quarter, color(black) legend(off) ///
	xtitle("Calendar Time") ytitle("") ylabel(0(.25)2.5)
graph save "${RESULTS_FINAL}Referrals_TwoFailure", replace
graph export "${RESULTS_FINAL}Referrals_TwoFailure.png", as(png) replace				
restore

preserve
keep if group_line==3
gen event_time=quarter-quarter2
drop if quarter<=quarter1
collapse (mean) patients, by(event_time)
keep if event_time>=-12 & event_time<=12
graph twoway connected patients event_time, color(black) xline(0) legend(off) ///
	xtitle("Event Time") ytitle("") ylabel(0(2)14) xlabel(-12(2)12)
graph save "${RESULTS_FINAL}Referrals_TwoFailure_EventTime", replace
graph export "${RESULTS_FINAL}Referrals_TwoFailure_EventTime.png", as(png) replace				
restore

set scheme uncluttered
graph combine "${RESULTS_FINAL}Referrals_TwoFailure.gph" "${RESULTS_FINAL}Referrals_TwoFailure_EventTime.gph", ///
	col(1) iscale(1) l1("Count of Patients Referred")
graph save "${RESULTS_FINAL}Referrals_TwoFailure_Combined", replace
graph export "${RESULTS_FINAL}Referrals_TwoFailure_Combined.png", as(png) replace			


preserve
gen event_time=quarter-quarter1
collapse (mean) patients, by(event_time)
keep if event_time>=-12 & event_time<=12
graph twoway connected patients event_time, color(black) xline(0) legend(off) ///
	xtitle("Quarter from Bad Outcome") ytitle("Count of Patients Referred") ylabel(0(1)10) xlabel(-12(1)12)
graph save "${RESULTS_FINAL}PairFailureTrends", replace
graph export "${RESULTS_FINAL}PairFailureTrends.png", as(png) replace			
restore


preserve
set scheme uncluttered
replace group_line=3 if group_line>=3
collapse (mean) patients, by(quarter group_line)
format quarter %tq
graph twoway (connected patients quarter if group_line==1, color(black) lpattern(solid)) ///
    (connected patients quarter if group_line==2, color(black) lpattern(longdash)) ///
	(connected patients quarter if group_line==3, color(black) lpattern(dot)), ///	
	xtitle("Calendar Time") ytitle("Count of Patients Referred") ylabel(0(.1).5) ///
	legend(on) legend(label(1 "No Failures") label(2 "1 Failure") label(3 "2+ Failures")) ///
	legend(rows(1)) legend(region(lwidth(none)))
graph save "${RESULTS_FINAL}Referrals_ByGroup", replace
graph export "${RESULTS_FINAL}Referrals_ByGroup.png", as(png) replace		
restore



******************************************************************
** Experimentation over specialists
******************************************************************
use temp_base_data, clear
gen quarter=qofd(admit)
format quarter %tq
collapse (min) min_quarter=quarter, by(Practice_ID)
save pcp_min_quarter, replace

use "${DATA_FINAL}QuarterlyPCPPanel.dta", clear
merge m:1 Practice_ID using pcp_min_quarter, nogenerate keep(master match)
gen first_quarter=(quarter==min_quarter)
save temp_experiment_data, replace

** evolution
use temp_experiment_data, clear
keep if min_quarter>=quarterly("2013q1","YQ")
gen quarter_count=(quarter-min_quarter)

keep if patients>0
collapse (mean) total_specialists new_specialists ///
	(p25) p25_total=total_specialists p25_new=new_specialists ///
	(p75) p75_total=total_specialist p75_new=new_specialists, by(quarter_count)

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	     	
set scheme uncluttered
keep if quarter_count>0
graph twoway connected total_specialists quarter_count, color(black) legend(off) ///
	ytitle("Total Specialists Considered") ylabel(1(.5)2.5) xtitle("Quarter from Entry")
graph save "${RESULTS_FINAL}SizeEvolution_`r_type'", replace
graph export "${RESULTS_FINAL}SizeEvolution_`r_type'.png", as(png) replace		

graph twoway connected new_specialists quarter_count, color(black) legend(off) ///
	ytitle("New Specialists Considered") ylabel(0(.5)1.5) xtitle("Quarter from Entry")
graph save "${RESULTS_FINAL}ExperimentEvolution_`r_type'", replace
graph export "${RESULTS_FINAL}ExperimentEvolution_`r_type'.png", as(png) replace		



