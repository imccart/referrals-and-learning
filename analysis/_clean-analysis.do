** create final variables and impose sample restrictions
** this code file is for final adjustments after the primary choice set data have already been created

keep Specialist_ID Practice_ID bene_id pair_patients_* pcp_patients_* spec_patients_* pair_failures_* pcp_failures_* spec_failures_* ///
	pair_death_* pcp_death_* spec_death_* pair_readmit_* pcp_readmit_* spec_readmit_* pair_comp_* pcp_comp_* spec_comp_* ///
	bene_birth_dt admit bene_hosp_distance* choice casevar pcp_phy_tin* spec_phy_tin* Year EstPCPMatch case_obs ///
	common_ref bene_spec_distance* 
	
** same practice dummy
gen prac_vi=0
replace prac_vi=1 if pcp_phy_tin1==spec_phy_tin1 & pcp_phy_tin1!=. & spec_phy_tin1!=.
replace prac_vi=1 if pcp_phy_tin1==spec_phy_tin2 & pcp_phy_tin1!=. & spec_phy_tin2!=. 
replace prac_vi=1 if pcp_phy_tin2==spec_phy_tin1 & pcp_phy_tin2!=. & spec_phy_tin1!=. 
replace prac_vi=1 if pcp_phy_tin2==spec_phy_tin2 & pcp_phy_tin2!=. & spec_phy_tin2!=.

merge m:1 Specialist_ID Year using temp_spec_yearly, keep(master match) nogenerate
keep if yearly_ops>=${SPEC_MIN}
keep if EstPCPMatch==3
foreach x of varlist pair_patients_* pcp_patients_* spec_patients_* pair_failures_* pcp_failures_* spec_failures_* ///
	pair_death_* pcp_death_* spec_death_* pair_readmit_* pcp_readmit_* spec_readmit_* pair_comp_* pcp_comp_* spec_comp_* {
		replace `x'=0 if `x'<0 | `x'==.
	}
gen pair_new=(pair_patients_run==0)
foreach x of newlist tot run {
	gen prop_patients_`x'=pair_patients_`x'/pcp_patients_`x'
	replace prop_patients_`x'=0 if prop_patients_`x'==.
		
	foreach z of newlist failures death readmit comp {
		gen prop_`z'_`x'=pair_`z'_`x'/pair_patients_`x'
		replace prop_`z'_`x'=0 if prop_`z'_`x'==.
				
		gen prop_spec_`z'_`x'=spec_`z'_`x'/spec_patients_`x'
		replace prop_spec_`z'_`x'=0 if prop_spec_`z'_`x'==.
	}
}
bys Specialist_ID Year: gen spec_obs=_n
gen pair_success_run=pair_patients_run-pair_failures_run
gen spec_success_tot=spec_patients_tot-spec_failures_tot
gen spec_qual=spec_success_tot/spec_patients_tot
replace spec_qual=. if choice==0

** beneficiary age and distance
gen bene_birth=date(bene_birth_dt, "DMY")
drop bene_birth_dt
gen bene_age=(admit-bene_birth)/364.25
egen bene_distance=rowmin(bene_hosp_distance*)
egen bene_spec_distance=rowmin(bene_spec_distance*)
qui sum bene_spec_distance, detail
local max_distance=r(p90)
local dist_cutoff=min(75,`max_distance')
drop if bene_spec_distance==. | bene_spec_distance>=`dist_cutoff'
bys casevar: egen min_dist=min(bene_spec_distance)
gen diff_dist=bene_spec_distance-min_dist

** drop referrals without observed choice (choice made outside of distance requirements)
bys casevar: egen max_choice=max(choice)
drop if max_choice==0
drop max_choice

** drop cases with 1+choice
bys casevar: egen max_choice=sum(choice)
drop if max_choice>1
drop max_choice

** drop specialists that are never selected after prior restrictions
bys Specialist_ID: egen max_choice=max(choice)
drop if max_choice==0
drop max_choice


if ${OUTSIDE_OPTION}==1 {

	** collapse outside option
	preserve
	keep if pair_patients_run>0
	save temp_inside_option, replace
	restore

	preserve
	keep if pair_patients_run==0
	collapse (max) choice (mean) casevar spec_failures_run prop_failures_run prop_patients_run ///
		pair_patients_run pair_failures_run prop_spec_failures_tot bene_age bene_distance, by(Practice_ID admit bene_id)
	gen Specialist_ID=0
	gen case_obs=0
	gen common_ref=0
	gen prac_vi=0
	save temp_outside_option, replace
	restore

	use temp_inside_option, clear
	append using temp_outside_option
}

** create familiarity variables
forvalues p=0(1)5 {
	gen fmly_np_`p'=(pair_patients_run==`p')
}
gen fmly_np_7=(pair_patients_run>5 & pair_patients_run<=7)
gen fmly_np_10=(pair_patients_run>7 & pair_patients_run<=10)
gen fmly_np_15=(pair_patients_run>10 & pair_patients_run<=15)
gen fmly_np_20=(pair_patients_run>15)
