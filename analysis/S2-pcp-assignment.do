set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}PCPAssignment_`logdate'.log", replace

******************************************************************
**	Title:		PCP Identification Method Validation
**	Author:		Ian McCarthy
**	Date Created:	1/30/2023
**	Date Updated:	2/27/2026
**	Notes:		Compares carrier-lookback PCP identification
**			(our method) with claims-listed rfr_physn_npi.
**			Produces LaTeX table and figure for appendix.
**			Based on original Assignment_Alg.do.
******************************************************************

local r_type "${PCP_First}_${PCP_Only}_${RFR_Priority}"


******************************************************************
** Build comparison data by year

forvalues y=2013/2018 {

	** PCP list from MDPPAS
	insheet using "${DATA_SAS}MDPPAS_V24_`y'.tab", tab clear
	destring npi, force replace
	rename npi physician_id
	bys physician_id: gen obs=_n
	drop if obs>1
	drop obs
	keep if spec_broad==1
	keep physician_id
	save temp_pcps, replace


	** rfr_physn_npi from carrier claims on surgeon's claim
	insheet using "${DATA_SAS}REFERRALSCARRIER_`y'.tab", tab clear
	keep if rfr_physn_npi !=.
	rename prf_physn_npi spec_npi
	rename rfr_physn_npi physician_id
	keep spec_npi physician_id bene_id clm_from_dt clm_thru_dt

	rename physician_id RFR_PCP_ID
	bys spec_npi bene_id RFR_PCP_ID clm_from_dt clm_thru_dt: gen dup=_n
	drop if dup>1
	drop dup

	bys spec_npi bene_id clm_from_dt clm_thru_dt: gen rfr_obs=_n
	reshape wide RFR_PCP_ID, i(bene_id spec_npi clm_from_dt clm_thru_dt) j(rfr_obs)
	destring spec_npi, replace
	save temp_listed, replace


	** PCP-only lookback (our method): most-visited PCP in pre-surgery E&M claims
	insheet using "${DATA_SAS}PRESURGERY_PHYSICIANS_`y'.tab", tab clear
	destring physician_id, force replace
	merge m:1 physician_id using temp_pcps, nogenerate keep(match)

	bys bene_id date: egen max_visits=max(visits)
	keep if max_visits==visits
	bys bene_id date: gen num_max=_N

	** unique most-visited PCP
	preserve
		keep if num_max==1
		keep bene_id date physician_id
		save temp_max, replace
	restore

	** break ties with most recent visit
	keep if num_max>1
	gen pcp_max_visit2=date(max_visit_date, "DMY")
	bys bene_id date: egen pcp_last_date=max(pcp_max_visit2)
	keep if pcp_last_date==pcp_max_visit2
	bys bene_id date: gen num_max_recent=_N
	keep if num_max_recent==1
	keep bene_id date physician_id
	save temp_max_recent, replace

	use temp_max, clear
	append using temp_max_recent
	rename physician_id Lookback_PCP
	destring Lookback_PCP, replace
	gen admit=date(date,"DMY")
	drop date
	sort bene_id admit
	save temp_lookback, replace


	** merge onto ortho stays
	use "${DATA_FINAL}OrthoStays_`y'.dta", clear

	merge m:1 bene_id admit using temp_lookback, keep(master match) generate(has_lookback)

	merge m:1 bene_id spec_npi clm_from_dt clm_thru_dt using temp_listed, keep(master match) generate(has_rfr)

	** look up rfr specialty
	gen double physician_npi=RFR_PCP_ID1
	merge m:1 physician_npi using "${DATA_FINAL}Physician_`y'.dta", keep(master match) keepusing(phy_spec_broad) nogenerate
	rename phy_spec_broad rfr_spec_broad
	drop physician_npi

	** classify rfr_physn_npi into mutually exclusive categories
	gen rfr_cat = 0
	replace rfr_cat = 1 if has_rfr==3 & RFR_PCP_ID1 == spec_npi
	replace rfr_cat = 2 if has_rfr==3 & RFR_PCP_ID1 != spec_npi & (rfr_spec_broad != 1 | rfr_spec_broad == .)
	replace rfr_cat = 3 if has_rfr==3 & RFR_PCP_ID1 != spec_npi & rfr_spec_broad == 1
	label define rfr_lbl 0 "Not populated" 1 "Surgeon (self)" 2 "Non-PCP" 3 "PCP"
	label values rfr_cat rfr_lbl

	** concordance: same NPI when both methods identify a PCP
	gen concordance = (Lookback_PCP == RFR_PCP_ID1) if has_lookback==3 & rfr_cat==3

	keep Year rfr_cat has_lookback has_rfr concordance Lookback_PCP RFR_PCP_ID1
	save temp_validation_`y', replace
}

** append all years
use temp_validation_2013, clear
forvalues y=2014/2018 {
	append using temp_validation_`y'
}
save temp_validation_all, replace


******************************************************************
** Compute statistics by year

use temp_validation_all, clear
gen n = 1
gen lookback = (has_lookback==3)
gen rfr_missing = (rfr_cat==0)
gen rfr_self = (rfr_cat==1)
gen rfr_nonpcp = (rfr_cat==2)
gen rfr_pcp = (rfr_cat==3)

** year-level stats
preserve
collapse (sum) n (mean) lookback rfr_missing rfr_self rfr_nonpcp rfr_pcp (mean) concordance, by(Year)
save temp_stats_yearly, replace
restore

** overall stats
collapse (sum) n (mean) lookback rfr_missing rfr_self rfr_nonpcp rfr_pcp (mean) concordance
gen Year = 0
save temp_stats_all, replace

use temp_stats_yearly, clear
append using temp_stats_all
save temp_stats_combined, replace


******************************************************************
** LaTeX table

use temp_stats_combined, clear
foreach v of varlist lookback rfr_missing rfr_self rfr_nonpcp rfr_pcp concordance {
	replace `v' = `v' * 100
}

capture file close tabfh
file open tabfh using "${RESULTS_BASE}PCP_Validation.tex", write replace
file write tabfh "\begin{tabular}{lrcccccc}" _n
file write tabfh "\hline\hline" _n
file write tabfh " & & \multicolumn{4}{c}{Composition of Referral Field (\%)} & Lookback & \\" _n
file write tabfh "\cline{3-6}" _n
file write tabfh "Year & Procedures & Not Pop. & Self-Referral & Non-PCP & PCP & Coverage (\%) & Concordance (\%) \\" _n
file write tabfh "\hline" _n

forvalues y=2013/2018 {
	qui sum n if Year==`y'
	local nn = string(r(mean), "%12.0gc")
	qui sum rfr_missing if Year==`y'
	local rm = string(r(mean), "%5.1f")
	qui sum rfr_self if Year==`y'
	local rs = string(r(mean), "%5.1f")
	qui sum rfr_nonpcp if Year==`y'
	local rn = string(r(mean), "%5.1f")
	qui sum rfr_pcp if Year==`y'
	local rp = string(r(mean), "%5.1f")
	qui sum lookback if Year==`y'
	local lb = string(r(mean), "%5.1f")
	qui sum concordance if Year==`y'
	local cc = string(r(mean), "%5.1f")
	file write tabfh "`y' & `nn' & `rm' & `rs' & `rn' & `rp' & `lb' & `cc' \\" _n
}

file write tabfh "\hline" _n
qui sum n if Year==0
local nn = string(r(mean), "%12.0gc")
qui sum rfr_missing if Year==0
local rm = string(r(mean), "%5.1f")
qui sum rfr_self if Year==0
local rs = string(r(mean), "%5.1f")
qui sum rfr_nonpcp if Year==0
local rn = string(r(mean), "%5.1f")
qui sum rfr_pcp if Year==0
local rp = string(r(mean), "%5.1f")
qui sum lookback if Year==0
local lb = string(r(mean), "%5.1f")
qui sum concordance if Year==0
local cc = string(r(mean), "%5.1f")
file write tabfh "All & `nn' & `rm' & `rs' & `rn' & `rp' & `lb' & `cc' \\" _n

file write tabfh "\hline\hline" _n
file write tabfh "\end{tabular}" _n
file close tabfh


******************************************************************
** Figure: rfr_physn_npi composition (stacked bar) + lookback coverage (line)

use temp_stats_yearly, clear
foreach v of varlist rfr_missing rfr_self rfr_nonpcp rfr_pcp lookback {
	replace `v' = `v' * 100
}

** cumulative sums for stacked bars (PCP at bottom, missing at top)
gen cum1 = rfr_pcp
gen cum2 = cum1 + rfr_nonpcp
gen cum3 = cum2 + rfr_self
gen zero = 0
gen hundred = 100

twoway (rbar zero cum1 Year, barw(0.7) color(black%80)) ///
	(rbar cum1 cum2 Year, barw(0.7) color(gs6%70)) ///
	(rbar cum2 cum3 Year, barw(0.7) color(gs10%70)) ///
	(rbar cum3 hundred Year, barw(0.7) color(gs14%40)) ///
	(connected lookback Year, color(black) lwidth(medthick) msymbol(circle) msize(medium)), ///
	ytitle("Share of Procedures (%)") xtitle("") ///
	ylabel(0(20)100) xlabel(2013(1)2018) ///
	text(85 2013 "Lookback Coverage", size(vsmall) color(black) placement(e)) ///
	legend(on order(1 "PCP" 2 "Non-PCP Spec." 3 "Self-Referral" 4 "Not Populated") ///
		rows(1) position(6) size(vsmall))

graph save "${RESULTS_BASE}PCP_Validation_Figure", replace
graph export "${RESULTS_BASE}PCP_Validation_Figure.png", as(png) replace


log close
