set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}PaperNumbers_`logdate'.log", replace

******************************************************************
**	Title:		Auto-generated Paper Numbers
**	Author:		Ian McCarthy
**	Date Created:	2/25/2026
**	Notes:		Centralizes ALL paper number generation.
**			Writes paper-numbers-desc.tex and
**			paper-numbers-structural.tex.
******************************************************************

local r_type "${PCP_First}_${PCP_Only}_${RFR_Priority}"


******************************************************************
** paper-numbers-desc.tex
******************************************************************

** Unique PCPs and specialists (from estimation period)
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}
keep if Year>=2013

bys Practice_ID: gen _pcp_obs=_n
qui count if _pcp_obs==1
local n_pcps: di %9.0fc r(N)
local n_pcps = strtrim("`n_pcps'")
drop _pcp_obs

bys Specialist_ID: gen _spec_obs=_n
qui count if _spec_obs==1
local n_specs: di %9.0fc r(N)
local n_specs = strtrim("`n_specs'")
drop _spec_obs

** Per-year stats for estimation period (pairs table)
collapse (count) patients=bene_id (sum) any_bad, by(Practice_ID Specialist_ID Year)
bys Practice_ID Year: gen spec_count=_n
bys Practice_ID Year: egen tot_specs=max(_n) if spec_count==spec_count
bys Practice_ID Year: egen tot_patients=sum(patients)
bys Practice_ID Year: egen tot_failures=sum(any_bad)

* Per PCP-year averages
preserve
bys Practice_ID Year: keep if spec_count==1
qui sum tot_patients
local mean_refs_pcp: di %3.1f r(mean)
local mean_refs_pcp = strtrim("`mean_refs_pcp'")
qui sum tot_specs
local mean_specs_pcp: di %3.1f r(mean)
local mean_specs_pcp = strtrim("`mean_specs_pcp'")
qui sum tot_failures
local mean_failures_pcp: di %3.1f r(mean)
local mean_failures_pcp = strtrim("`mean_failures_pcp'")
restore

* Per pair-year averages
qui sum patients
local mean_refs_pair: di %3.1f r(mean)
local mean_refs_pair = strtrim("`mean_refs_pair'")

* Failure rate
qui sum any_bad
local tot_bad = r(sum)
qui sum patients
local tot_pat = r(sum)
local failure_rate_mean: di %2.0f `tot_bad'/`tot_pat' * 100
local failure_rate_mean = strtrim("`failure_rate_mean'")


** Specialist failure rate percentiles
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}
keep if Year>=2013
collapse (sum) any_bad (count) patients=bene_id, by(Specialist_ID)
gen spec_fail_rate = any_bad / patients
qui sum spec_fail_rate, detail
local spec_fail_p25: di %4.1f r(p25)*100
local spec_fail_p25 = strtrim("`spec_fail_p25'")
local spec_fail_p75: di %4.1f r(p75)*100
local spec_fail_p75 = strtrim("`spec_fail_p75'")


** Running referrals (cumulative referrals per PCP-specialist pair)
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}
qui sum pair_patients_cuml
local running_refs: di %3.1f r(mean)
local running_refs = strtrim("`running_refs'")


** Specialists per HRR per year
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN} & Year>=2013
bys bene_hrr Year Specialist_ID: keep if _n==1
collapse (count) n_specs=Specialist_ID, by(bene_hrr Year)
qui sum n_specs
local specs_per_hrr_yr: di %2.0f r(mean)
local specs_per_hrr_yr = strtrim("`specs_per_hrr_yr'")


** Cumulative network size (unique specialists per PCP, 2013-2018)
use temp_networks_yearly, clear
keep if Year>=2013
bys Practice_ID Specialist_ID: keep if _n==1
collapse (count) cuml_network=Specialist_ID, by(Practice_ID)
qui sum cuml_network
local cuml_network_mean: di %2.0f r(mean)
local cuml_network_mean = strtrim("`cuml_network_mean'")


** IQR stats from A1 temp file
use temp_a1_iqr_stats, clear
qui sum iqr_failure, detail
local iqr_p25: di %3.1f r(p25)
local iqr_p25 = strtrim("`iqr_p25'")
local iqr_med: di %3.1f r(p50)
local iqr_med = strtrim("`iqr_med'")
local iqr_p75: di %3.1f r(p75)
local iqr_p75 = strtrim("`iqr_p75'")
qui sum iqr_payment, detail
local pay_iqr_med: di %3.0f r(p50)
local pay_iqr_med = strtrim("`pay_iqr_med'")


** Capacity stats from A1 temp file
use temp_a1_capacity, clear
qui sum sufficient
local cap_pct: di %2.0f r(mean)*100
local cap_pct = strtrim("`cap_pct'")


** Choice set and market stats
local hrr_count = 0
local total_cs = 0
local total_specs_hrr = 0
local cs_n = 0
forvalues i=1/500 {
	capture confirm file "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta"
	if _rc==0 {
		local hrr_count = `hrr_count' + 1
		use "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta", clear
		qui bys casevar: gen _cs = _N if _n==1
		qui sum _cs
		local total_cs = `total_cs' + r(sum)
		local cs_n = `cs_n' + r(N)
		qui bys Specialist_ID: gen _so = (_n==1)
		qui count if _so==1
		local total_specs_hrr = `total_specs_hrr' + r(N)
	}
}
local mean_cs: di %2.0f `total_cs'/`cs_n'
local mean_cs = strtrim("`mean_cs'")
local mean_specs_hrr: di %2.0f `total_specs_hrr'/`hrr_count'
local mean_specs_hrr = strtrim("`mean_specs_hrr'")


** Count converged MNL HRRs (from MNL_Specs1.dta)
use "${RESULTS_BASE}MNL_Specs1.dta", clear
keep if coef_name=="converged" & coef_val==1
qui count
local n_hrrs_mnl = r(N)


** Write paper-numbers-desc.tex
local outfile "${RESULTS_BASE}paper-numbers-desc.tex"
file open fh using "`outfile'", write replace
file write fh "%% Auto-generated by O4-paper-numbers.do — do not edit by hand" _n
file write fh "\newcommand{\nPCPs}{`n_pcps'}" _n
file write fh "\newcommand{\nSpecialists}{`n_specs'}" _n
file write fh "\newcommand{\meanRefsPerPCP}{`mean_refs_pcp'}" _n
file write fh "\newcommand{\meanSpecsPerPCP}{`mean_specs_pcp'}" _n
file write fh "\newcommand{\meanRefsPerPair}{`mean_refs_pair'}" _n
file write fh "\newcommand{\meanFailuresPerPCP}{`mean_failures_pcp'}" _n
file write fh "\newcommand{\failureRateMean}{`failure_rate_mean'}" _n
file write fh "\newcommand{\specFailurePtwentyfive}{`spec_fail_p25'}" _n
file write fh "\newcommand{\specFailurePseventyfive}{`spec_fail_p75'}" _n
file write fh "\newcommand{\failureIQRPtwentyfive}{`iqr_p25'}" _n
file write fh "\newcommand{\failureIQRMedian}{`iqr_med'}" _n
file write fh "\newcommand{\failureIQRPseventyfive}{`iqr_p75'}" _n
file write fh "\newcommand{\paymentIQRMedian}{`pay_iqr_med'}" _n
file write fh "\newcommand{\capacitySuffPct}{`cap_pct'}" _n
file write fh "\newcommand{\meanChoiceSet}{`mean_cs'}" _n
file write fh "\newcommand{\meanSpecsPerHRR}{`mean_specs_hrr'}" _n
file write fh "\newcommand{\runningReferrals}{`running_refs'}" _n
file write fh "\newcommand{\specsPerHRRYear}{`specs_per_hrr_yr'}" _n
file write fh "\newcommand{\cumlNetworkSize}{`cuml_network_mean'}" _n
file write fh "\newcommand{\nHRRsMNL}{`n_hrrs_mnl'}" _n
file close fh


******************************************************************
** paper-numbers-structural.tex
******************************************************************

local numfile "${RESULTS_FINAL}paper-numbers-structural.tex"
capture file close numfh
file open numfh using "`numfile'", write replace
file write numfh "%% Auto-generated by O4-paper-numbers.do — do not edit by hand" _n

foreach model_type in Myopic FWD {
	if "`model_type'" == "Myopic" {
		local coef_prefix "StructureMyopic"
	}
	else {
		local coef_prefix "StructureForward"
	}
	local model "`model_type'"

	** count HRRs and alpha=0 HRRs
	use "${RESULTS_FINAL}`coef_prefix'_SummaryHRR.dta", clear
	keep if eta==1
	qui count
	local n_hrrs = r(N)
	qui count if coef_m==0
	local n_alpha0 = r(N)
	save temp_summary_eta1, replace

	use "${RESULTS_FINAL}`coef_prefix'_SummaryHRR.dta", clear
	keep if eta==5
	qui count
	local n_hrrs_eta5 = r(N)
	save temp_summary_eta5, replace

	** alpha/distance ratio
	use temp_summary_eta1, clear
	qui sum coef_m
	local mean_alpha = r(mean)
	qui sum coef_dist
	local mean_pi = abs(r(mean))
	local alpha_dist: di %3.1f `mean_alpha'/`mean_pi'

	** mean reallocation
	use "${RESULTS_FINAL}CounterFactuals_`model'5.dta", clear
	gen success_diff_full=success_prob1_full-success_prob0
	collapse (mean) pij_diff_full success_diff_full, by(hrr)
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)
	qui sum pij_diff_full [aweight=patients]
	local realloc_mean: di %4.1f 100*r(mean)
	local realloc_mean = strtrim("`realloc_mean'")
	qui sum success_diff_full [aweight=patients]
	local health_mean: di %4.1f 100*r(mean)
	local health_mean = strtrim("`health_mean'")


	** mean reallocation — FullFam counterfactual
	use "${RESULTS_FINAL}CounterFactuals_`model'5.dta", clear
	gen success_diff_fullfam=success_prob1_fullfam-success_prob0
	collapse (mean) pij_diff_fullfam success_diff_fullfam, by(hrr)
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)
	qui sum pij_diff_fullfam [aweight=patients]
	local realloc_ff: di %4.1f 100*r(mean)
	local realloc_ff = strtrim("`realloc_ff'")
	qui sum success_diff_fullfam [aweight=patients]
	local health_ff: di %4.1f 100*r(mean)
	local health_ff = strtrim("`health_ff'")


	** mean partial effect of one failure (excluding alpha=0 HRRs)
	use "${RESULTS_FINAL}MarginalEffects_`model'1.dta", clear
	merge 1:1 hrr using temp_summary_eta1, nogenerate keep(match) keepusing(coef_m)
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)
	qui sum pfx_mean [aweight=patients] if coef_m>0
	local pfx_nonzero: di %3.1f -100*r(mean)
	local pfx_nonzero = strtrim("`pfx_nonzero'")
	qui sum pfx_mean [aweight=patients]
	local pfx_all: di %3.1f -100*r(mean)
	local pfx_all = strtrim("`pfx_all'")


	file write numfh "\newcommand{\reallocationMean`model'}{`realloc_mean'}" _n
	file write numfh "\newcommand{\healthFXMean`model'}{`health_mean'}" _n
	file write numfh "\newcommand{\reallocationMeanFullFam`model'}{`realloc_ff'}" _n
	file write numfh "\newcommand{\healthFXMeanFullFam`model'}{`health_ff'}" _n
	file write numfh "\newcommand{\partialFXNonzero`model'}{`pfx_nonzero'}" _n
	file write numfh "\newcommand{\partialFXAll`model'}{`pfx_all'}" _n
	file write numfh "\newcommand{\nHRRs`model'}{`n_hrrs'}" _n
	file write numfh "\newcommand{\nAlphaZero`model'}{`n_alpha0'}" _n
	file write numfh "\newcommand{\alphaDistRatio`model'}{`alpha_dist'}" _n
	file write numfh "\newcommand{\nHRRsEtaFive`model'}{`n_hrrs_eta5'}" _n
}

file close numfh


log close
