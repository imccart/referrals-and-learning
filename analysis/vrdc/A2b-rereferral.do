set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Rereferral_`logdate'.log", replace

******************************************************************
**	Title:		Reduced-form evidence on response to failures: re-referral
**	Author:		Ian McCarthy
**	Date Created:	10/5/2026
**	Note:		For each referral, whether the PCP's next joint-replacement
**			referral (at least 91 days later, so the 90-day outcome is known,
**			and within three years) goes to the same surgeon, after a failure
**			versus after a success. Two forms:
**			  1. Level: regression of the same-surgeon indicator on the failure
**			     indicator with specialist-by-year fixed effects and pair-history
**			     controls; also with PCP fixed effects, by pair history, and for
**			     the share of the next three referrals.
**			  2. Event study in referral order: the PCP's previous five and next
**			     five referrals, one row per event and position, event fixed
**			     effects, position -1 as reference; the position-by-failure
**			     interactions are the failure-minus-success profile.
**			Both condition on the PCP referring again, so the volume and exit
**			margins do not enter, and both compare failures with successes.
**	Inputs:		${DATA_FINAL}EstReferrals_`r_type'.dta and temp_spec_yearly (from A0).
**			Sample restrictions follow A2-reduced-form.do.
******************************************************************
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"

******************************************************************
** Sample, as in A2
use "${DATA_FINAL}EstReferrals_`r_type'.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
bys Specialist_ID: egen max_yearly_ops=max(yearly_ops)
keep if max_yearly_ops>=${SPEC_MIN}
keep if EstPCPMatch==3
gen quarter=qofd(admit)
format quarter %tq
drop if quarter<quarterly("2008q1","YQ") | quarter==.
keep Practice_ID Specialist_ID bene_id admit quarter Year any_bad
save temp_rr_referrals, replace

******************************************************************
** Event-level data: each referral with the PCP's surrounding referrals

** pair's prior referrals before this admission date
sort Practice_ID Specialist_ID admit bene_id
by Practice_ID Specialist_ID: gen e_prior=_n-1
by Practice_ID Specialist_ID admit: replace e_prior=e_prior[1]

sort Practice_ID admit bene_id
gen double event_id=_n

** previous referrals by the same PCP: s5 is the one just before the event, s1 five before
forvalues p=1/5 {
	local id=6-`p'
	by Practice_ID: gen s`id'=(Specialist_ID[_n-`p']==Specialist_ID) if _n-`p'>=1
}

** next referrals by the same PCP at least 91 days later and within three years:
** s7 is the first, s11 the fifth; n3 and n3_same count the first three
forvalues p=7/11 {
	gen s`p'=.
}
gen cnt=0
gen n3=0
gen n3_same=0
forvalues k=1/40 {
	by Practice_ID: gen double a_k=admit[_n+`k']
	by Practice_ID: gen double j_k=Specialist_ID[_n+`k']
	gen ok=(a_k!=. & a_k>=admit+91 & a_k<=admit+1095)
	replace cnt=cnt+ok
	forvalues p=7/11 {
		replace s`p'=(j_k==Specialist_ID) if ok==1 & cnt==`p'-6
	}
	replace n3_same=n3_same+(j_k==Specialist_ID) if ok==1 & cnt<=3
	replace n3=n3+1 if ok==1 & cnt<=3
	drop a_k j_k ok
}
drop cnt
gen rerefer=s7
gen share3=n3_same/n3 if n3>0

keep if quarter>=quarterly("2013q1","YQ")
gen e_bin=min(e_prior,5)
gen e_grp=cond(e_prior==0,0,cond(e_prior<=4,1,2))
egen spec_year=group(Specialist_ID Year)
keep event_id Practice_ID Specialist_ID spec_year Year quarter any_bad e_prior e_bin e_grp ///
	rerefer share3 s1 s2 s3 s4 s5 s7 s8 s9 s10 s11
save temp_rr_events, replace

******************************************************************
** 1. Level analysis
keep if rerefer!=.
qui count
local n_events=r(N)
qui count if any_bad==1
local n_fail=r(N)

sum rerefer if any_bad==0
local base_rr=r(mean)
reghdfe rerefer any_bad i.e_bin, absorb(spec_year) cluster(Specialist_ID)
local rr_fx=_b[any_bad]
local rr_se=_se[any_bad]
di "re-referral: failure effect `rr_fx' (se `rr_se') on base `base_rr', relative " `rr_fx'/`base_rr'

** within PCP: own failures against own successes
reghdfe rerefer any_bad i.e_bin, absorb(spec_year Practice_ID) cluster(Specialist_ID)
local rr_fx_pcp=_b[any_bad]
local rr_se_pcp=_se[any_bad]

** by pair history: first referral to the surgeon, 1-4 prior, 5+ prior
forvalues g=0/2 {
	sum rerefer if any_bad==0 & e_grp==`g'
	local base_rr`g'=r(mean)
	reghdfe rerefer any_bad i.e_bin if e_grp==`g', absorb(spec_year) cluster(Specialist_ID)
	local rr_fx`g'=_b[any_bad]
	local rr_se`g'=_se[any_bad]
	di "history group `g': failure effect `rr_fx`g'' (se `rr_se`g'') on base `base_rr`g''"
}

** share of the next three referrals
sum share3 if any_bad==0
local base_s3=r(mean)
reghdfe share3 any_bad i.e_bin, absorb(spec_year) cluster(Specialist_ID)
local s3_fx=_b[any_bad]
local s3_se=_se[any_bad]

******************************************************************
** 2. Event study in referral order
use temp_rr_events, clear
keep event_id Practice_ID Specialist_ID spec_year any_bad e_grp s1 s2 s3 s4 s5 s7 s8 s9 s10 s11
reshape long s, i(event_id) j(posid)
drop if s==.
rename s same
gen pos=posid-6
forvalues p=1/11 {
	if `p'!=6 {
		gen P`p'=(posid==`p')
		gen P`p'_f=P`p'*any_bad
	}
}
local pd  P1 P2 P3 P4 P7 P8 P9 P10 P11
local pdf P1_f P2_f P3_f P4_f P7_f P8_f P9_f P10_f P11_f
save temp_rr_es, replace

reghdfe same `pd' `pdf', absorb(event_id spec_year) cluster(Specialist_ID)
lincom (P7_f+P8_f+P9_f+P10_f+P11_f)/5
local es_post=r(estimate)
local es_post_se=r(se)
lincom (P1_f+P2_f+P3_f+P4_f)/4
local es_pre=r(estimate)
local es_pre_se=r(se)
local es_first=_b[P7_f]
local es_first_se=_se[P7_f]
sum same if any_bad==0 & pos<0
local es_base=r(mean)
di "referral-order event study: post `es_post' (se `es_post_se'), pre `es_pre' (se `es_pre_se'), first `es_first' (se `es_first_se'), base `es_base'"

** figure
preserve
gen coef=.
gen se=.
forvalues p=1/11 {
	if `p'!=5 & `p'!=6 {
		replace coef=_b[P`p'_f] if posid==`p'
		replace se=_se[P`p'_f] if posid==`p'
	}
}
replace coef=0 if posid==5
replace se=0 if posid==5
gen ci_top=coef+1.96*se
gen ci_bot=coef-1.96*se
keep pos coef se ci_top ci_bot
duplicates drop
sort pos
set scheme uncluttered
twoway (sc coef pos, connect(line) xline(0)) (rcap ci_top ci_bot pos) ///
	(function y=0, range(-5 5)), xtitle("Referral number relative to the event") ///
	ytitle("Failure minus success, same surgeon, point estimates and 95% CIs") xlabel(-5(1)5) legend(off)
graph save "${RESULTS_BASE}Rereferral_EventStudy_`r_type'", replace
graph export "${RESULTS_BASE}Rereferral_EventStudy_`r_type'.png", as(png) replace
restore

** by pair history (for first referrals the pre-positions are zero by construction; post only)
forvalues g=0/2 {
	use temp_rr_es, clear
	keep if e_grp==`g'
	reghdfe same `pd' `pdf', absorb(event_id spec_year) cluster(Specialist_ID)
	lincom (P7_f+P8_f+P9_f+P10_f+P11_f)/5
	local es_post`g'=r(estimate)
	local es_post`g'_se=r(se)
	di "history group `g': post `es_post`g'' (se `es_post`g'_se')"
}

******************************************************************
** Paper numbers
local outfile "${RESULTS_BASE}paper-numbers-rereferral.tex"
file open fh using "`outfile'", write replace
file write fh "%% Auto-generated by A2b-rereferral.do" _n
file write fh "\newcommand{\rereferEvents}{`n_events'}" _n
file write fh "\newcommand{\rereferFailures}{`n_fail'}" _n
file write fh "\newcommand{\rereferBase}{`=string(`base_rr', "%5.3f")'}" _n
file write fh "\newcommand{\rereferFX}{`=string(`rr_fx', "%6.4f")'}" _n
file write fh "\newcommand{\rereferSE}{`=string(`rr_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferPct}{`=string(100*`rr_fx'/`base_rr', "%4.1f")'}" _n
file write fh "\newcommand{\rereferFXpcp}{`=string(`rr_fx_pcp', "%6.4f")'}" _n
file write fh "\newcommand{\rereferSEpcp}{`=string(`rr_se_pcp', "%6.4f")'}" _n
forvalues g=0/2 {
	local w=word("zero one two", `g'+1)
	file write fh "\newcommand{\rereferFXhist`w'}{`=string(`rr_fx`g'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferSEhist`w'}{`=string(`rr_se`g'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferBasehist`w'}{`=string(`base_rr`g'', "%5.3f")'}" _n
	file write fh "\newcommand{\rereferPcthist`w'}{`=string(100*`rr_fx`g''/`base_rr`g'', "%4.1f")'}" _n
}
file write fh "\newcommand{\shareThreeBase}{`=string(`base_s3', "%5.3f")'}" _n
file write fh "\newcommand{\shareThreeFX}{`=string(`s3_fx', "%6.4f")'}" _n
file write fh "\newcommand{\shareThreeSE}{`=string(`s3_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESPost}{`=string(`es_post', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESPostSE}{`=string(`es_post_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESPre}{`=string(`es_pre', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESPreSE}{`=string(`es_pre_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESFirst}{`=string(`es_first', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESFirstSE}{`=string(`es_first_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESBase}{`=string(`es_base', "%5.3f")'}" _n
forvalues g=0/2 {
	local w=word("zero one two", `g'+1)
	file write fh "\newcommand{\rereferESPosthist`w'}{`=string(`es_post`g'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferESPostSEhist`w'}{`=string(`es_post`g'_se', "%6.4f")'}" _n
}
file close fh

log close
