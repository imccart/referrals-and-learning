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
local mean_refs_pcp: di %3.2f r(mean)
local mean_refs_pcp = strtrim("`mean_refs_pcp'")
qui sum tot_specs
local mean_specs_pcp: di %3.2f r(mean)
local mean_specs_pcp = strtrim("`mean_specs_pcp'")
qui sum tot_failures
local mean_failures_pcp: di %3.2f r(mean)
local mean_failures_pcp = strtrim("`mean_failures_pcp'")
restore

* Per specialist-year averages (received referrals)
preserve
collapse (sum) patients, by(Specialist_ID Year)
qui sum patients
local mean_refs_spec: di %3.2f r(mean)
local mean_refs_spec = strtrim("`mean_refs_spec'")
restore

* Per pair-year averages
qui sum patients
local mean_refs_pair: di %3.2f r(mean)
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
local spec_fail_p25: di %4.2f r(p25)*100
local spec_fail_p25 = strtrim("`spec_fail_p25'")
local spec_fail_p75: di %4.2f r(p75)*100
local spec_fail_p75 = strtrim("`spec_fail_p75'")


** SD of specialist patient volume (for congestion effect interpretation)
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN} & Year>=2013
collapse (count) patients=bene_id, by(Specialist_ID)
qui sum patients, detail
local spec_patients_sd_6yr: di %3.2f r(sd)
local spec_patients_sd_6yr = strtrim("`spec_patients_sd_6yr'")
local spec_patients_mean_6yr: di %3.2f r(mean)
local spec_patients_mean_6yr = strtrim("`spec_patients_mean_6yr'")

** Same for 3-year half-periods
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN} & Year>=2013
gen half = cond(Year<=2015, 1, 2)
collapse (count) patients=bene_id, by(Specialist_ID half)
qui sum patients if half==1, detail
local spec_patients_sd_h1: di %3.2f r(sd)
local spec_patients_sd_h1 = strtrim("`spec_patients_sd_h1'")
local spec_patients_mean_h1: di %3.2f r(mean)
local spec_patients_mean_h1 = strtrim("`spec_patients_mean_h1'")
qui sum patients if half==2, detail
local spec_patients_sd_h2: di %3.2f r(sd)
local spec_patients_sd_h2 = strtrim("`spec_patients_sd_h2'")
local spec_patients_mean_h2: di %3.2f r(mean)
local spec_patients_mean_h2 = strtrim("`spec_patients_mean_h2'")


** Referral probabilities: top specialist and conditional on prior referral
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN} & Year>=2013
collapse (count) patients=bene_id, by(Practice_ID Specialist_ID)
bys Practice_ID: egen pcp_total=sum(patients)
gen ref_share=patients/pcp_total

* Average share to PCP's top specialist
bys Practice_ID: egen max_share=max(ref_share)
bys Practice_ID: gen _pobs=_n
qui sum max_share if _pobs==1
local top_spec_share: di %3.2f r(mean)
local top_spec_share = strtrim("`top_spec_share'")
drop _pobs

* Average referral prob conditional on positive referral history
qui sum ref_share
local cond_ref_prob: di %3.2f r(mean)
local cond_ref_prob = strtrim("`cond_ref_prob'")


** Running referrals (cumulative referrals per PCP-specialist pair)
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if EstPCPMatch==3 & yearly_ops>=${SPEC_MIN}
qui sum pair_patients_cuml
local running_refs: di %3.2f r(mean)
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
local iqr_p25: di %3.2f r(p25)
local iqr_p25 = strtrim("`iqr_p25'")
local iqr_med: di %3.2f r(p50)
local iqr_med = strtrim("`iqr_med'")
local iqr_p75: di %3.2f r(p75)
local iqr_p75 = strtrim("`iqr_p75'")
qui sum iqr_payment, detail
local pay_iqr_med: di %3.0f r(p50)
local pay_iqr_med = strtrim("`pay_iqr_med'")


** Capacity stats from A1 temp file
use temp_a1_capacity, clear
qui sum sufficient
local cap_pct: di %2.0f r(mean)*100
local cap_pct = strtrim("`cap_pct'")


** Choice set and market stats (from post-filter estimation data)
use "${DATA_FINAL}ChoiceEstData_Summary.dta", clear
qui bys hrr casevar: gen _cs = _N if _n==1
qui sum _cs
local mean_cs: di %2.0f r(mean)
local mean_cs = strtrim("`mean_cs'")
qui bys hrr Specialist_ID: gen _so = (_n==1)
qui count if _so==1
local total_specs_hrr = r(N)
qui bys hrr: gen _ho = (_n==1)
qui count if _ho==1
local hrr_count = r(N)
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
file write fh "\newcommand{\meanRefsPerSpec}{`mean_refs_spec'}" _n
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
file write fh "\newcommand{\specPatientsMeanSixYr}{`spec_patients_mean_6yr'}" _n
file write fh "\newcommand{\specPatientsSdSixYr}{`spec_patients_sd_6yr'}" _n
file write fh "\newcommand{\specPatientsMeanHone}{`spec_patients_mean_h1'}" _n
file write fh "\newcommand{\specPatientsSdHone}{`spec_patients_sd_h1'}" _n
file write fh "\newcommand{\specPatientsMeanHtwo}{`spec_patients_mean_h2'}" _n
file write fh "\newcommand{\specPatientsSdHtwo}{`spec_patients_sd_h2'}" _n
file write fh "\newcommand{\topSpecShare}{`top_spec_share'}" _n
file write fh "\newcommand{\condRefProb}{`cond_ref_prob'}" _n
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
	local alpha_dist: di %3.2f `mean_alpha'/`mean_pi'

	** mean reallocation and health effects (conditional on alpha>0)
	foreach eta in 1 5 {
		use "${RESULTS_FINAL}CounterFactualsSummary_`model'`eta'.dta", clear
		merge 1:1 hrr using hrr_size, nogenerate keep(master match)
		keep if coef_m>0

		** Full info counterfactual
		qui sum pij_diff_full [aweight=patients]
		local realloc_mean_`eta': di %4.2f 100*r(mean)
		local realloc_mean_`eta' = strtrim("`realloc_mean_`eta''")
		qui sum health_full [aweight=patients]
		local health_mean_`eta': di %4.2f 100*r(mean)
		local health_mean_`eta' = strtrim("`health_mean_`eta''")

		** FullFam counterfactual
		qui sum pij_diff_fullfam [aweight=patients]
		local realloc_ff_`eta': di %4.2f 100*r(mean)
		local realloc_ff_`eta' = strtrim("`realloc_ff_`eta''")
		qui sum health_fullfam [aweight=patients]
		local health_ff_`eta': di %4.2f 100*r(mean)
		local health_ff_`eta' = strtrim("`health_ff_`eta''")

		** Current info counterfactual
		qui sum pij_diff_current [aweight=patients]
		local realloc_cur_`eta': di %4.2f 100*r(mean)
		local realloc_cur_`eta' = strtrim("`realloc_cur_`eta''")
		qui sum health_current [aweight=patients]
		local health_cur_`eta': di %4.2f 100*r(mean)
		local health_cur_`eta' = strtrim("`health_cur_`eta''")
	}


	** mean partial effect of one failure (excluding alpha=0 HRRs)
	use "${RESULTS_FINAL}MarginalEffects_`model'1.dta", clear
	merge 1:1 hrr using temp_summary_eta1, nogenerate keep(match) keepusing(coef_m)
	merge 1:1 hrr using hrr_size, nogenerate keep(master match)
	qui sum pfx_mean [aweight=patients] if coef_m>0
	local pfx_nonzero: di %3.2f -100*r(mean)
	local pfx_nonzero = strtrim("`pfx_nonzero'")
	qui sum pfx_mean [aweight=patients]
	local pfx_all: di %3.2f -100*r(mean)
	local pfx_all = strtrim("`pfx_all'")

	** mean choice probability and relative partial effect (for event study comparison)
	qui sum pr_mean [aweight=patients] if coef_m>0
	local pr_base = r(mean)
	local pr_base_pct: di %4.2f 100*`pr_base'
	local pr_base_pct = strtrim("`pr_base_pct'")
	qui sum pfx_mean [aweight=patients] if coef_m>0
	local pfx_abs = r(mean)
	local pfx_rel: di %3.2f -`pfx_abs'/`pr_base' * 100
	local pfx_rel = strtrim("`pfx_rel'")


	** eta=1 counterfactual numbers
	file write numfh "\newcommand{\reallocationMeanEtaOne`model'}{`realloc_mean_1'}" _n
	file write numfh "\newcommand{\healthFXMeanEtaOne`model'}{`health_mean_1'}" _n
	file write numfh "\newcommand{\reallocationMeanCurrentEtaOne`model'}{`realloc_cur_1'}" _n
	file write numfh "\newcommand{\healthFXMeanCurrentEtaOne`model'}{`health_cur_1'}" _n
	file write numfh "\newcommand{\reallocationMeanFullFamEtaOne`model'}{`realloc_ff_1'}" _n
	file write numfh "\newcommand{\healthFXMeanFullFamEtaOne`model'}{`health_ff_1'}" _n
	** eta=5 counterfactual numbers
	file write numfh "\newcommand{\reallocationMeanEtaFive`model'}{`realloc_mean_5'}" _n
	file write numfh "\newcommand{\healthFXMeanEtaFive`model'}{`health_mean_5'}" _n
	file write numfh "\newcommand{\reallocationMeanCurrentEtaFive`model'}{`realloc_cur_5'}" _n
	file write numfh "\newcommand{\healthFXMeanCurrentEtaFive`model'}{`health_cur_5'}" _n
	file write numfh "\newcommand{\reallocationMeanFullFamEtaFive`model'}{`realloc_ff_5'}" _n
	file write numfh "\newcommand{\healthFXMeanFullFamEtaFive`model'}{`health_ff_5'}" _n
	** backward-compatible aliases (eta=5, used in existing paper text)
	file write numfh "\newcommand{\reallocationMean`model'}{`realloc_mean_5'}" _n
	file write numfh "\newcommand{\healthFXMean`model'}{`health_mean_5'}" _n
	file write numfh "\newcommand{\reallocationMeanFullFam`model'}{`realloc_ff_5'}" _n
	file write numfh "\newcommand{\healthFXMeanFullFam`model'}{`health_ff_5'}" _n
	** other structural numbers
	file write numfh "\newcommand{\partialFXNonzero`model'}{`pfx_nonzero'}" _n
	file write numfh "\newcommand{\partialFXAll`model'}{`pfx_all'}" _n
	file write numfh "\newcommand{\partialFXBase`model'}{`pr_base_pct'}" _n
	file write numfh "\newcommand{\partialFXRelative`model'}{`pfx_rel'}" _n
	file write numfh "\newcommand{\nHRRs`model'}{`n_hrrs'}" _n
	file write numfh "\newcommand{\nAlphaZero`model'}{`n_alpha0'}" _n
	file write numfh "\newcommand{\alphaDistRatio`model'}{`alpha_dist'}" _n
	file write numfh "\newcommand{\nHRRsEtaFive`model'}{`n_hrrs_eta5'}" _n
}

file close numfh


log close
