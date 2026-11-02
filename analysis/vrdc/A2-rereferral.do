set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Rereferral_`logdate'.log", replace

******************************************************************
**	Title:		Reduced-form evidence on response to failures: re-referral
**	Author:		Ian McCarthy
**	Date Created:	10/5/2026
**	Note:		Whether a PCP's referrals after a failure go back to the same
**			surgeon, compared with referrals after a success. Time is the
**			PCP's referral sequence, and the referral at t=0 is the event.
**			  1. Level: whether the next referral at least 91 days later (so
**			     the 90-day outcome is known) and within three years goes to
**			     the same surgeon. Linear probability and Poisson, with
**			     specialist-by-year fixed effects and pair-history bins; also
**			     with PCP fixed effects, by pair history, without the 91-day
**			     gap, with the PCP's previous five referrals as controls,
**			     within PCP-surgeon pair, by the calendar gap to the next referral,
**			     and with the next referral to a different surgeon in the same
**			     billing group as the outcome (spillover within the group).
**			  2. Stacked event study: each window is the PCP's five referrals
**			     before and after a referral, kept only if none of the PCP's
**			     other referrals in the window (to any surgeon) failed, so a
**			     failure window is one failure among successes and a comparison
**			     window is one success among successes. Window fixed effects,
**			     specialist-year by position and PCP by position fixed effects,
**			     position -1 as reference.
**			  3. Design checks, each the event study with one concern removed:
**			     without the PCP-by-position effects; history-bin by position
**			     effects; no failure in the PCP's previous ten referrals either
**			     (aftermath contamination); non-overlapping windows (isolated
**			     failures plus one success window per eleven PCP referrals,
**			     rotating the offset); a linear pre-trend extended through the
**			     post-period; post positions without the 91-day gap; windows split
**			     by the calendar gap from the event to the next referral.
**			Standard errors are two-way clustered by specialist and PCP.
**	Inputs:		${DATA_FINAL}EstReferrals.dta and temp_spec_yearly (from A0).
**			Sample restrictions follow the earlier reduced-form script (A2-reduced-form.do, archived).
**	Output:		paper-numbers-rereferral.tex, Rereferral_EventStudy.png,
**			Rereferral_Checks.csv (coefficient, SE, windows, and
**			failures by check and position; aggregates only).
******************************************************************

******************************************************************
** Sample, as in A2
use "${DATA_FINAL}EstReferrals.dta", clear
merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
bys Specialist_ID: egen max_yearly_ops=max(yearly_ops)
keep if max_yearly_ops>=${SPEC_MIN}
keep if EstPCPMatch==3
gen quarter=qofd(admit)
format quarter %tq
drop if quarter<quarterly("2008q1","YQ") | quarter==.
capture confirm variable parent_id
if _rc==0 {
	gen double spec_tin=parent_id	/* the unit's group: the billing TIN for a surgeon; missing when the unit is the practice */
}
else {
	gen double spec_tin=.
}
keep Practice_ID Specialist_ID spec_tin bene_id admit quarter Year any_bad
save temp_rr_referrals, replace

******************************************************************
** Windows: each referral with the PCP's surrounding referrals

** pair's prior referrals before this admission date
sort Practice_ID Specialist_ID admit bene_id
by Practice_ID Specialist_ID: gen e_prior=_n-1
by Practice_ID Specialist_ID admit: replace e_prior=e_prior[1]

sort Practice_ID admit bene_id Specialist_ID, stable
gen double event_id=_n
by Practice_ID: gen n_pcp=_n

** previous five referrals by the same PCP: s5 is the one just before, s1 five before
forvalues p=1/5 {
	local id=6-`p'
	by Practice_ID: gen s`id'=(Specialist_ID[_n-`p']==Specialist_ID) if _n-`p'>=1
	gen g`id'=s`id'
}

** next five referrals: s7-s11 at least 91 days later and within three years,
** g7-g11 the next five on any later date within three years
forvalues p=7/11 {
	gen s`p'=.
	gen g`p'=.
}
gen cnt=0
gen cnt0=0
gen kend=0
gen kend0=0
forvalues k=1/40 {
	by Practice_ID: gen double a_k=admit[_n+`k']
	by Practice_ID: gen double j_k=Specialist_ID[_n+`k']
	gen ok=(a_k!=. & a_k>=admit+91 & a_k<=admit+1095)
	replace cnt=cnt+ok
	forvalues p=7/11 {
		replace s`p'=(j_k==Specialist_ID) if ok==1 & cnt==`p'-6
	}
	replace kend=`k' if ok==1 & cnt<=5
	gen ok0=(a_k!=. & a_k>admit & a_k<=admit+1095)
	replace cnt0=cnt0+ok0
	forvalues p=7/11 {
		replace g`p'=(j_k==Specialist_ID) if ok0==1 & cnt0==`p'-6
	}
	replace kend0=`k' if ok0==1 & cnt0<=5
	drop a_k j_k ok ok0
}
drop cnt cnt0
gen rerefer=s7
gen rerefer0=g7

** calendar gap (days) from the event to the next referral at least 91 days later,
** and whether that referral went to a different surgeon in the same billing group
gen gap1=.
gen rerefer_tin=.
gen cnt=0
forvalues k=1/40 {
	by Practice_ID: gen double a_k=admit[_n+`k']
	by Practice_ID: gen double j_k=Specialist_ID[_n+`k']
	by Practice_ID: gen double t_k=spec_tin[_n+`k']
	gen ok=(a_k!=. & a_k>=admit+91 & a_k<=admit+1095)
	replace cnt=cnt+ok
	replace gap1=a_k-admit if ok==1 & cnt==1
	replace rerefer_tin=(t_k==spec_tin & j_k!=Specialist_ID) if ok==1 & cnt==1 & spec_tin!=. & t_k!=.
	drop a_k j_k t_k ok
}
drop cnt
gen gapbin=cond(gap1<=180,1,cond(gap1<=365,2,3)) if gap1!=.

** failures among the PCP's other referrals around each one
by Practice_ID: gen cumbad=sum(any_bad)
by Practice_ID: gen c_m1=cond(_n>1, cumbad[_n-1], 0)
by Practice_ID: gen c_m6=cond(_n>6, cumbad[_n-6], 0)
by Practice_ID: gen c_m11=cond(_n>11, cumbad[_n-11], 0)
by Practice_ID: gen c_end=cumbad[_n+kend]
by Practice_ID: gen c_end0=cumbad[_n+kend0]
by Practice_ID: gen c_p10=cumbad[min(_n+10,_N)]
gen fail_pre5=c_m1-c_m6
gen fail_pre10_6=c_m6-c_m11
gen fail_post=c_end-cumbad
gen fail_post0=c_end0-cumbad
gen fail_post10=c_p10-cumbad

** clean: no other failure from five before through the fifth post-event referral
** clean0: the same without the 91-day gap
** sutva_ok: clean and no failure in the previous ten referrals
** nofail10: no other failure within ten referrals either side
gen clean=(fail_pre5==0 & fail_post==0)
gen clean0=(fail_pre5==0 & fail_post0==0)
gen sutva_ok=(clean==1 & fail_pre10_6==0)
gen nofail10=(fail_pre5==0 & fail_pre10_6==0 & fail_post10==0)
drop cumbad c_* fail_* kend kend0

keep if quarter>=quarterly("2013q1","YQ")
gen e_bin=min(e_prior,5)
gen e_grp=cond(e_prior==0,0,cond(e_prior<=4,1,2))
egen spec_year=group(Specialist_ID Year)

** previous five referrals as controls, with indicators for positions before the PCP's first referral
forvalues p=1/5 {
	gen l`p'=cond(s`p'==.,0,s`p')
	gen m`p'=(s`p'==.)
}
keep event_id n_pcp Practice_ID Specialist_ID spec_year Year quarter any_bad e_prior e_bin e_grp ///
	rerefer rerefer0 rerefer_tin gap1 gapbin clean clean0 sutva_ok nofail10 l1 l2 l3 l4 l5 m1 m2 m3 m4 m5 ///
	s1 s2 s3 s4 s5 s7 s8 s9 s10 s11 g1 g2 g3 g4 g5 g7 g8 g9 g10 g11
save temp_rr_events, replace

******************************************************************
** 1. Level analysis

** without the 91-day gap, on events with any later referral within three years
preserve
keep if rerefer0!=.
qui count
local n0_events=r(N)
sum rerefer0 if any_bad==0
local base0=r(mean)
reghdfe rerefer0 any_bad i.e_bin, absorb(spec_year) vce(cluster Specialist_ID Practice_ID)
local fx0=_b[any_bad]
local se0=_se[any_bad]
forvalues g=0/2 {
	sum rerefer0 if any_bad==0 & e_grp==`g'
	local base0_`g'=r(mean)
	reghdfe rerefer0 any_bad i.e_bin if e_grp==`g', absorb(spec_year) vce(cluster Specialist_ID Practice_ID)
	local fx0_`g'=_b[any_bad]
	local se0_`g'=_se[any_bad]
}
ppmlhdfe rerefer0 any_bad i.e_bin, absorb(spec_year) vce(cluster Specialist_ID Practice_ID)
local pp0_b=_b[any_bad]
local pp0_se=_se[any_bad]
restore

keep if rerefer!=.
qui count
local n_events=r(N)
qui count if any_bad==1
local n_fail=r(N)

sum rerefer if any_bad==0
local base_rr=r(mean)
reghdfe rerefer any_bad i.e_bin, absorb(spec_year) vce(cluster Specialist_ID Practice_ID)
local rr_fx=_b[any_bad]
local rr_se=_se[any_bad]
di "re-referral: failure effect `rr_fx' (se `rr_se') on base `base_rr', relative " `rr_fx'/`base_rr'

** within PCP: own failures against own successes
reghdfe rerefer any_bad i.e_bin, absorb(spec_year Practice_ID) vce(cluster Specialist_ID Practice_ID)
local rr_fx_pcp=_b[any_bad]
local rr_se_pcp=_se[any_bad]

** with the PCP's previous five referrals as controls
reghdfe rerefer any_bad i.e_bin l1 l2 l3 l4 l5 m1 m2 m3 m4 m5, absorb(spec_year) vce(cluster Specialist_ID Practice_ID)
local rr_fx_lag=_b[any_bad]
local rr_se_lag=_se[any_bad]

** within PCP-surgeon pair: the pair's failures against its own successes (pairs with one event, or
** with no variation in failure, drop out, so the estimation sample is recorded)
reghdfe rerefer any_bad i.e_bin, absorb(spec_year Practice_ID#Specialist_ID) vce(cluster Specialist_ID Practice_ID)
local rr_fx_pair=_b[any_bad]
local rr_se_pair=_se[any_bad]
local rr_n_pair=e(N)

** by the calendar gap from the event to the next referral: 91-180 days, 181-365, over a year
forvalues b=1/3 {
	sum rerefer if any_bad==0 & gapbin==`b'
	local base_gap`b'=r(mean)
	reghdfe rerefer any_bad i.e_bin if gapbin==`b', absorb(spec_year) vce(cluster Specialist_ID Practice_ID)
	local rr_fx_gap`b'=_b[any_bad]
	local rr_se_gap`b'=_se[any_bad]
	local rr_n_gap`b'=e(N)
}

** spillover within the billing group: the next referral goes to a different surgeon in the same
** group as the event's surgeon (defined only when the unit has a group, so not at the practice level)
local rr_fx_tin=.
local rr_se_tin=.
local base_tin=.
local rr_n_tin=.
qui count if rerefer_tin!=.
if r(N)>0 {
	sum rerefer_tin if any_bad==0
	local base_tin=r(mean)
	reghdfe rerefer_tin any_bad i.e_bin, absorb(spec_year) vce(cluster Specialist_ID Practice_ID)
	local rr_fx_tin=_b[any_bad]
	local rr_se_tin=_se[any_bad]
	local rr_n_tin=e(N)
}

** by pair history: first referral to the surgeon, 1-4 prior, 5+ prior
forvalues g=0/2 {
	sum rerefer if any_bad==0 & e_grp==`g'
	local base_rr`g'=r(mean)
	reghdfe rerefer any_bad i.e_bin if e_grp==`g', absorb(spec_year) vce(cluster Specialist_ID Practice_ID)
	local rr_fx`g'=_b[any_bad]
	local rr_se`g'=_se[any_bad]
	di "history group `g': failure effect `rr_fx`g'' (se `rr_se`g'') on base `base_rr`g''"
}

** Poisson versions: the coefficient is a log ratio, so 100*(exp(b)-1) is the percent effect;
** fixed-effect groups with no re-referrals drop, so the estimation sample is recorded
ppmlhdfe rerefer any_bad i.e_bin, absorb(spec_year) vce(cluster Specialist_ID Practice_ID)
local pp_b=_b[any_bad]
local pp_se=_se[any_bad]
local pp_n=e(N)
forvalues g=0/2 {
	ppmlhdfe rerefer any_bad i.e_bin if e_grp==`g', absorb(spec_year) vce(cluster Specialist_ID Practice_ID)
	local pp_b`g'=_b[any_bad]
	local pp_se`g'=_se[any_bad]
	local pp_n`g'=e(N)
}

******************************************************************
** 2. Event study in referral order

** long form: one row per window and position; same uses the 91-day gap, same0 does not
use temp_rr_events, clear
keep event_id n_pcp Practice_ID Specialist_ID spec_year any_bad e_bin e_grp gapbin ///
	clean clean0 sutva_ok nofail10 s1 s2 s3 s4 s5 s7 s8 s9 s10 s11 g1 g2 g3 g4 g5 g7 g8 g9 g10 g11
reshape long s g, i(event_id) j(posid)
rename s same
rename g same0
gen pos=posid-6
forvalues p=1/11 {
	if `p'!=6 {
		gen P`p'_f=(posid==`p')*any_bad
	}
}
gen pos_f=pos*any_bad
save temp_rr_es, replace

** every estimate goes to the checks file: one row per check and position
file open fc using "${RESULTS_BASE}Rereferral_Checks.csv", write replace
file write fc "check,pos,coef,se,n_windows,n_fail" _n

capture program drop rrcheck
program define rrcheck
	args label outcome cond absorb
	reghdfe `outcome' P1_f P2_f P3_f P4_f P7_f P8_f P9_f P10_f P11_f if `cond', ///
		absorb(`absorb') vce(cluster Specialist_ID Practice_ID)
	tempvar tag
	egen `tag'=tag(event_id) if e(sample)
	qui count if `tag'==1
	local nw=r(N)
	qui count if `tag'==1 & any_bad==1
	local nf=r(N)
	forvalues p=1/11 {
		if `p'==5 {
			file write fc "`label',-1,0,0,`nw',`nf'" _n
		}
		else if `p'!=6 {
			file write fc "`label',`=`p'-6',`=_b[P`p'_f]',`=_se[P`p'_f]',`nw',`nf'" _n
		}
	}
	lincom (P1_f+P2_f+P3_f+P4_f)/4
	di "`label': pre average " r(estimate) " (se " r(se) ")"
	lincom (P7_f+P8_f+P9_f+P10_f+P11_f)/5
	di "`label': post average " r(estimate) " (se " r(se) "), windows `nw', failures `nf'"
	c_local nw `nw'
	c_local nf `nf'
end

local fe_full event_id spec_year#posid Practice_ID#posid
local fe_spec event_id spec_year#posid

** main specification
rrcheck base same "clean==1 & same!=." "`fe_full'"
local es_events=`nw'
local es_fail=`nf'
lincom (P7_f+P8_f+P9_f+P10_f+P11_f)/5
local es_post=r(estimate)
local es_post_se=r(se)
lincom (P1_f+P2_f+P3_f+P4_f)/4
local es_pre=r(estimate)
local es_pre_se=r(se)
local es_first=_b[P7_f]
local es_first_se=_se[P7_f]
sum same if any_bad==0 & pos<0 & clean==1
local es_base=r(mean)

** PCPs in the main sample, and those with at least one failure window and one success window,
** which are the PCPs the position coefficients are identified from
preserve
use temp_rr_events, clear
keep if clean==1 & s7!=.
bys Practice_ID: egen hf=max(any_bad)
bys Practice_ID: egen hs=min(any_bad)
bys Practice_ID: gen one=(_n==1)
qui count if one==1
local es_pcps=r(N)
qui count if one==1 & hf==1 & hs==0
local es_pcps_both=r(N)
restore

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
	ytitle("Difference in probability of referring to the same surgeon") xlabel(-5(1)5) legend(off)
graph save "${RESULTS_BASE}Rereferral_EventStudy", replace
graph export "${RESULTS_BASE}Rereferral_EventStudy.png", as(png) replace
restore

** by pair history (for first referrals the pre-positions are zero by construction; post only)
forvalues g=0/2 {
	rrcheck hist`g' same "clean==1 & same!=. & e_grp==`g'" "`fe_full'"
	lincom (P7_f+P8_f+P9_f+P10_f+P11_f)/5
	local es_post`g'=r(estimate)
	local es_post`g'_se=r(se)
}

******************************************************************
** 3. Design checks

** without the PCP-by-position effects
rrcheck base_nopcp same "clean==1 & same!=." "`fe_spec'"

** history composition
rrcheck history same "clean==1 & same!=." "`fe_full' e_bin#posid"

** aftermath contamination: no failure in the previous ten referrals either
rrcheck sutva same "sutva_ok==1 & same!=." "`fe_full'"
local sutva_events=`nw'
local sutva_fail=`nf'
local sutva_first=_b[P7_f]
local sutva_first_se=_se[P7_f]
lincom (P7_f+P8_f+P9_f+P10_f+P11_f)/5
local sutva_post=r(estimate)
local sutva_post_se=r(se)
lincom (P1_f+P2_f+P3_f+P4_f)/4
local sutva_pre=r(estimate)
local sutva_pre_se=r(se)

** windows split by the calendar gap from the event to the next referral
forvalues b=1/3 {
	rrcheck gap`b' same "clean==1 & same!=. & gapbin==`b'" "`fe_full'"
}

** non-overlapping windows, rotating which successes are kept
forvalues r=0/10 {
	rrcheck nooverlap_`r' same "nofail10==1 & same!=. & (any_bad==1 | mod(n_pcp,11)==`r')" "`fe_spec'"
}
rrcheck nooverlap_0_pcp same "nofail10==1 & same!=. & (any_bad==1 | mod(n_pcp,11)==0)" "`fe_full'"

** linear pre-trend extended through the post-period
reghdfe same pos_f P7_f P8_f P9_f P10_f P11_f if clean==1 & same!=., ///
	absorb(`fe_full') vce(cluster Specialist_ID Practice_ID)
tempvar tag
egen `tag'=tag(event_id) if e(sample)
qui count if `tag'==1
local nw=r(N)
qui count if `tag'==1 & any_bad==1
local nf=r(N)
file write fc "trend_slope,0,`=_b[pos_f]',`=_se[pos_f]',`nw',`nf'" _n
forvalues p=7/11 {
	file write fc "trend,`=`p'-6',`=_b[P`p'_f]',`=_se[P`p'_f]',`nw',`nf'" _n
}

** without the 91-day gap
rrcheck nogap same0 "clean0==1 & same0!=." "`fe_full'"

** level regressions, for comparison with position 1
file write fc "level,1,`rr_fx',`rr_se',`n_events',`n_fail'" _n
file write fc "level_pcp,1,`rr_fx_pcp',`rr_se_pcp',`n_events',`n_fail'" _n
file write fc "level_lagctrl,1,`rr_fx_lag',`rr_se_lag',`n_events',`n_fail'" _n
file write fc "level_nogap,1,`fx0',`se0',`n0_events'," _n
file write fc "level_pair,1,`rr_fx_pair',`rr_se_pair',`rr_n_pair'," _n
forvalues b=1/3 {
	file write fc "level_gap`b',1,`rr_fx_gap`b'',`rr_se_gap`b'',`rr_n_gap`b''," _n
}
file write fc "level_tin,1,`rr_fx_tin',`rr_se_tin',`rr_n_tin'," _n
file close fc

******************************************************************
** Paper numbers
local outfile "${RESULTS_BASE}paper-numbers-rereferral.tex"
file open fh using "`outfile'", write replace
file write fh "%% Auto-generated by A2-rereferral.do" _n
file write fh "\newcommand{\rereferEvents}{`=string(`n_events', "%12.0fc")'}" _n
file write fh "\newcommand{\rereferFailures}{`=string(`n_fail', "%12.0fc")'}" _n
file write fh "\newcommand{\rereferBase}{`=string(`base_rr', "%5.3f")'}" _n
file write fh "\newcommand{\rereferFX}{`=string(`rr_fx', "%6.4f")'}" _n
file write fh "\newcommand{\rereferSE}{`=string(`rr_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferPct}{`=string(100*`rr_fx'/`base_rr', "%4.1f")'}" _n
file write fh "\newcommand{\rereferFXpcp}{`=string(`rr_fx_pcp', "%6.4f")'}" _n
file write fh "\newcommand{\rereferSEpcp}{`=string(`rr_se_pcp', "%6.4f")'}" _n
file write fh "\newcommand{\rereferFXlag}{`=string(`rr_fx_lag', "%6.4f")'}" _n
file write fh "\newcommand{\rereferSElag}{`=string(`rr_se_lag', "%6.4f")'}" _n
forvalues g=0/2 {
	local w=word("zero one two", `g'+1)
	file write fh "\newcommand{\rereferFXhist`w'}{`=string(`rr_fx`g'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferSEhist`w'}{`=string(`rr_se`g'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferBasehist`w'}{`=string(`base_rr`g'', "%5.3f")'}" _n
	file write fh "\newcommand{\rereferPcthist`w'}{`=string(100*`rr_fx`g''/`base_rr`g'', "%4.1f")'}" _n
}
file write fh "\newcommand{\rereferPoisB}{`=string(`pp_b', "%6.4f")'}" _n
file write fh "\newcommand{\rereferPoisSE}{`=string(`pp_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferPoisPct}{`=string(100*(exp(`pp_b')-1), "%4.1f")'}" _n
file write fh "\newcommand{\rereferPoisN}{`=string(`pp_n', "%12.0fc")'}" _n
forvalues g=0/2 {
	local w=word("zero one two", `g'+1)
	file write fh "\newcommand{\rereferPoisBhist`w'}{`=string(`pp_b`g'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferPoisSEhist`w'}{`=string(`pp_se`g'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferPoisPcthist`w'}{`=string(100*(exp(`pp_b`g'')-1), "%4.1f")'}" _n
	file write fh "\newcommand{\rereferPoisNhist`w'}{`=string(`pp_n`g'', "%12.0fc")'}" _n
}
file write fh "\newcommand{\rereferNoGapEvents}{`=string(`n0_events', "%12.0fc")'}" _n
file write fh "\newcommand{\rereferNoGapBase}{`=string(`base0', "%5.3f")'}" _n
file write fh "\newcommand{\rereferNoGapFX}{`=string(`fx0', "%6.4f")'}" _n
file write fh "\newcommand{\rereferNoGapSE}{`=string(`se0', "%6.4f")'}" _n
file write fh "\newcommand{\rereferNoGapPct}{`=string(100*`fx0'/`base0', "%4.1f")'}" _n
file write fh "\newcommand{\rereferNoGapPoisPct}{`=string(100*(exp(`pp0_b')-1), "%4.1f")'}" _n
file write fh "\newcommand{\rereferNoGapPoisSE}{`=string(`pp0_se', "%6.4f")'}" _n
forvalues g=0/2 {
	local w=word("zero one two", `g'+1)
	file write fh "\newcommand{\rereferNoGapFXhist`w'}{`=string(`fx0_`g'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferNoGapSEhist`w'}{`=string(`se0_`g'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferNoGapBasehist`w'}{`=string(`base0_`g'', "%5.3f")'}" _n
	file write fh "\newcommand{\rereferNoGapPcthist`w'}{`=string(100*`fx0_`g''/`base0_`g'', "%4.1f")'}" _n
}
file write fh "\newcommand{\rereferESEvents}{`=string(`es_events', "%12.0fc")'}" _n
file write fh "\newcommand{\rereferESFailures}{`=string(`es_fail', "%12.0fc")'}" _n
file write fh "\newcommand{\rereferESPost}{`=string(`es_post', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESPostSE}{`=string(`es_post_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESPre}{`=string(`es_pre', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESPreSE}{`=string(`es_pre_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESFirst}{`=string(`es_first', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESFirstSE}{`=string(`es_first_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESBase}{`=string(`es_base', "%5.3f")'}" _n
file write fh "\newcommand{\rereferESPCPs}{`=string(`es_pcps', "%12.0fc")'}" _n
file write fh "\newcommand{\rereferESPCPsBoth}{`=string(`es_pcps_both', "%12.0fc")'}" _n
file write fh "\newcommand{\rereferESEventsSutva}{`=string(`sutva_events', "%12.0fc")'}" _n
file write fh "\newcommand{\rereferESFailuresSutva}{`=string(`sutva_fail', "%12.0fc")'}" _n
file write fh "\newcommand{\rereferESFirstSutva}{`=string(`sutva_first', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESFirstSESutva}{`=string(`sutva_first_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESPostSutva}{`=string(`sutva_post', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESPostSESutva}{`=string(`sutva_post_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESPreSutva}{`=string(`sutva_pre', "%6.4f")'}" _n
file write fh "\newcommand{\rereferESPreSESutva}{`=string(`sutva_pre_se', "%6.4f")'}" _n
file write fh "\newcommand{\rereferFXpair}{`=string(`rr_fx_pair', "%6.4f")'}" _n
file write fh "\newcommand{\rereferSEpair}{`=string(`rr_se_pair', "%6.4f")'}" _n
file write fh "\newcommand{\rereferNpair}{`=string(`rr_n_pair', "%12.0fc")'}" _n
forvalues b=1/3 {
	local w=word("short mid long", `b')
	file write fh "\newcommand{\rereferFXgap`w'}{`=string(`rr_fx_gap`b'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferSEgap`w'}{`=string(`rr_se_gap`b'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferBasegap`w'}{`=string(`base_gap`b'', "%5.3f")'}" _n
	file write fh "\newcommand{\rereferNgap`w'}{`=string(`rr_n_gap`b'', "%12.0fc")'}" _n
}
file write fh "\newcommand{\rereferFXtin}{`=string(`rr_fx_tin', "%6.4f")'}" _n
file write fh "\newcommand{\rereferSEtin}{`=string(`rr_se_tin', "%6.4f")'}" _n
file write fh "\newcommand{\rereferBasetin}{`=string(`base_tin', "%5.3f")'}" _n
file write fh "\newcommand{\rereferNtin}{`=string(`rr_n_tin', "%12.0fc")'}" _n
forvalues g=0/2 {
	local w=word("zero one two", `g'+1)
	file write fh "\newcommand{\rereferESPosthist`w'}{`=string(`es_post`g'', "%6.4f")'}" _n
	file write fh "\newcommand{\rereferESPostSEhist`w'}{`=string(`es_post`g'_se', "%6.4f")'}" _n
}
file close fh

log close
