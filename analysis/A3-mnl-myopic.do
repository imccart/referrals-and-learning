set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}MNL_`logdate'.log", replace

******************************************************************
**	Title:		PCP Referrals with MNL Specifications
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	9/24/2025
**	Note:		Regressor list should include everything except 'm'
******************************************************************


******************************************************************
** RUN SPECIFICATIONS

global RESULTS_FINAL "${PROJ_PATH}results/pcp-level/"	

** Baseline specification
run_mnl_specs, regressors(diff_dist fmly_np_1 fmly_np_2 fmly_np_3 fmly_np_4 fmly_np_5 fmly_np_7 fmly_np_10 fmly_np_15 fmly_np_20 ib(freq).Specialist_ID)
save "${RESULTS_FINAL}MNL_Specs1.dta", replace

** Role of practice affiliation
run_mnl_specs, regressors(diff_dist prac_vi fmly_np_1 fmly_np_2 fmly_np_3 fmly_np_4 fmly_np_5 fmly_np_7 fmly_np_10 fmly_np_15 fmly_np_20 ib(freq).Specialist_ID)
save "${RESULTS_FINAL}MNL_Specs2.dta", replace

** Role of peer information
run_mnl_specs, regressors(diff_dist practice_info_1 practice_info_2 fmly_np_1 fmly_np_2 fmly_np_3 fmly_np_4 fmly_np_5 fmly_np_7 fmly_np_10 fmly_np_15 fmly_np_20 ib(freq).Specialist_ID)
save "${RESULTS_FINAL}MNL_Specs3.dta", replace



******************************************************************
** ORGANIZE RESULTS

** baseline
use "${RESULTS_FINAL}MNL_Specs1.dta", clear
gen hrr=coef_val if coef_name=="hrr"
replace hrr=hrr[_n-1] if hrr==.

replace coef_name="belief_s" if coef_name=="o.belief_s"
keep if inlist(coef_name, "belief_s", "converged", "log_like", "diff_dist") | ///
	inlist(coef_name, "fmly_np_1", "fmly_np_2", "fmly_np_3", "fmly_np_4", "fmly_np_5", "fmly_np_7", "fmly_np_10", "fmly_np_15", "fmly_np_20")

rename coef_val est_
rename coef_se se_
reshape wide est_ se_, i(hrr) j(coef_name) string

foreach x of newlist converged log_like {
	rename est_`x' `x'
	drop se_`x'
}
order hrr converged log_like
drop if converged==0

drop est_fmly_np* se_fmly_np* converged
replace se_belief_s=est_belief_s*se_belief_s
gen spec="baseline"
save temp_specs1, replace


** with integration
use "${RESULTS_FINAL}MNL_Specs2.dta", clear
gen hrr=coef_val if coef_name=="hrr"
replace hrr=hrr[_n-1] if hrr==.

replace coef_name="belief_s" if coef_name=="o.belief_s"
keep if inlist(coef_name, "belief_s", "converged", "log_like", "diff_dist", "prac_vi") | ///
	inlist(coef_name, "fmly_np_1", "fmly_np_2", "fmly_np_3", "fmly_np_4", "fmly_np_5", "fmly_np_7", "fmly_np_10", "fmly_np_15", "fmly_np_20")

rename coef_val est_
rename coef_se se_
reshape wide est_ se_, i(hrr) j(coef_name) string

foreach x of newlist converged log_like {
	rename est_`x' `x'
	drop se_`x'
}
order hrr converged log_like
drop if converged==0

drop est_fmly_np* se_fmly_np* converged
replace se_belief_s=est_belief_s*se_belief_s
gen spec="vi"
save temp_specs2, replace



** with other pcp info
use "${RESULTS_FINAL}MNL_Specs3.dta", clear
gen hrr=coef_val if coef_name=="hrr"
replace hrr=hrr[_n-1] if hrr==.

replace coef_name="belief_s" if coef_name=="o.belief_s"
keep if inlist(coef_name, "belief_s", "converged", "log_like", "diff_dist", "practice_info_1", "practice_info_2") | ///
	inlist(coef_name, "fmly_np_1", "fmly_np_2", "fmly_np_3", "fmly_np_4", "fmly_np_5", "fmly_np_7", "fmly_np_10", "fmly_np_15", "fmly_np_20")

rename coef_val est_
rename coef_se se_
reshape wide est_ se_, i(hrr) j(coef_name) string

foreach x of newlist converged log_like {
	rename est_`x' `x'
	drop se_`x'
}
order hrr converged log_like
drop if converged==0

drop est_fmly_np* se_fmly_np* converged
replace se_belief_s=est_belief_s*se_belief_s
gen spec="other_info"
save temp_specs3, replace


** merge results
use temp_specs1, clear
append using temp_specs2
append using temp_specs3

tempfile table_tex
postfile table_tex str200 line using "`table_tex'", replace
post table_tex ("")
post table_tex ("& & & \multoclumn{5}{c}{Percentile} \\")
post table_tex ("\cline{4-8}")
post table_tex ("Parameter & Mean & 10th & 25th & 50th & 75th & 90th \\")
post table_tex ("\hline")

qui sum est_belief_s if spec=="baseline", detail
post table_tex (" Baseline & `=string(r(mean), "%9.4f")' & `=string(r(p10), "%9.4f")'  & `=string(r(p25), "%9.4f")'  & `=string(r(p50), "%9.4f")'  & `=string(r(p75), "%9.4f")'  & `=string(r(p90), "%9.4f")' \\")
post table_tex ("\hline")

qui sum est_belief_s if spec=="vi", detail
post table_tex (" Integrated & `=string(r(mean), "%9.4f")' & `=string(r(p10), "%9.4f")'  & `=string(r(p25), "%9.4f")'  & `=string(r(p50), "%9.4f")'  & `=string(r(p75), "%9.4f")'  & `=string(r(p90), "%9.4f")' \\")
post table_tex ("\hline")

qui sum est_belief_s if spec=="other_info", detail
post table_tex (" Peer Outcomes & `=string(r(mean), "%9.4f")' & `=string(r(p10), "%9.4f")'  & `=string(r(p25), "%9.4f")'  & `=string(r(p50), "%9.4f")'  & `=string(r(p75), "%9.4f")'  & `=string(r(p90), "%9.4f")' \\")
post table_tex ("\hline")
postclose table_tex

use "`table_tex'", clear
outfile line using "${RESULTS_FINAL}MNL_Specs.tex", noquote replace


