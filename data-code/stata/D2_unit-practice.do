******************************************************************
**	Title:		Unit of the specialist choice: the surgeon's practice
**	Author:		Ian McCarthy
**	Date Created:	11/2/2026
**	Notes:		The practice is the surgeon's billing TIN (spec_phy_tin1);
**			the PCP stays an individual. Each surgeon belongs to the
**			practice that received most of his referrals in the year.
**			Same three programs as D1_unit-surgeon.do; see there.
**			To define the practice differently (TIN by office zip, say),
**			change Specialist_ID in define_unit and nothing else.
******************************************************************

capture program drop define_unit
program define define_unit
	args y
	gen double Practice_ID=pcp_npi
	gen double Specialist_ID=spec_phy_tin1
	gen double parent_id=.		/* the practice is the top of its own hierarchy */

	** surgeon-to-practice crosswalk for the year, used by the other two programs
	preserve
	bys Specialist_ID spec_npi: gen prac_spec=_N
	bys spec_npi: egen max_prac_spec=max(prac_spec)
	keep if prac_spec==max_prac_spec
	bys Specialist_ID spec_npi: gen prac_spec_obs=_n
	keep if prac_spec_obs==1
	rename spec_npi physician_id
	destring physician_id, replace force
	bys physician_id: keep if _n==1
	keep Specialist_ID physician_id
	save "${DATA_FINAL}practice_spec_xwalk_`y'.dta", replace
	restore
end

capture program drop unit_characteristics
program define unit_characteristics
	args y
	use "${DATA_FINAL}Physician_`y'.dta", clear
	rename physician_npi physician_id
	merge m:1 physician_id using "${DATA_FINAL}practice_spec_xwalk_`y'.dta", nogenerate keep(match)
	gen male=(phy_sex=="M") if phy_sex!=""
	bys physician_id: gen spec_obs=_n
	replace spec_obs=0 if spec_obs>1
	gen birth_date=date(phy_birth_dt, "DMY")
	gen age=`y' - year(birth_date)
	bys Specialist_ID: egen mode_state=mode(phy_state)
	bys Specialist_ID: egen mode_cbsa=mode(phy_cbsa_cd)
	bys Specialist_ID: egen mode_tin1=mode(phy_tin1)
	bys Specialist_ID: egen mode_tin2=mode(phy_tin2)

	** the practice's office zips, most claims first
	preserve
	keep Specialist_ID phy_zip_perf1
	rename phy_zip_perf1 spec_phy_zip_perf1
	bys Specialist_ID spec_phy_zip_perf1: gen claims_zip=_N
	bys Specialist_ID spec_phy_zip_perf1: gen obs=_n
	keep if obs==1
	gsort Specialist_ID -claims_zip
	drop obs claims_zip
	by Specialist_ID: gen obs=_n
	reshape wide spec_phy_zip_perf1, i(Specialist_ID) j(obs)
	save temp_spec_practice_zip, replace
	restore

	collapse (mean) spec_practice_male=male spec_practice_age=age (sum) spec_practice_size=spec_obs ///
		(first) spec_practice_state=mode_state spec_practice_cbsa=mode_cbsa ///
		(first) spec_phy_tin1=mode_tin1 spec_phy_tin2=mode_tin2, by(Specialist_ID)
	merge 1:1 Specialist_ID using temp_spec_practice_zip, nogenerate keep(master match)
	save "${DATA_FINAL}Specialist_`y'.dta", replace
	capture erase temp_spec_practice_zip.dta
end

capture program drop unit_yearly_ops
program define unit_yearly_ops
	args y
	use "${DATA_FINAL}OrthoStays_`y'.dta", clear
	collapse (count) yearly_ops=bene_id, by(spec_npi)
	rename spec_npi physician_id
	merge m:1 physician_id using "${DATA_FINAL}practice_spec_xwalk_`y'.dta", nogenerate keep(match)
	** a practice's operations are its busiest surgeon's, so a practice enters a choice set only
	** if at least one of its surgeons would on his own
	collapse (max) yearly_ops, by(Specialist_ID)
	gen Year=`y'
	save temp_ops_`y', replace
end
