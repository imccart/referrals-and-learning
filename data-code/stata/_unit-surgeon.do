******************************************************************
**	Title:		Unit of the specialist choice: the surgeon
**	Author:		Ian McCarthy
**	Date Created:	11/2/2026
**	Notes:		define_unit y sets Practice_ID, Specialist_ID, parent_id on
**			the year's referral panel; unit_characteristics y writes
**			Specialist_y.dta with spec_ columns; unit_yearly_ops y writes
**			temp_ops_y for the SPEC_MIN cut. _unit-practice.do defines
**			the same three for the practice.
******************************************************************

capture program drop define_unit
program define define_unit
	args y
	gen double Practice_ID=pcp_npi
	gen double Specialist_ID=spec_npi
	gen double parent_id=spec_phy_tin1	/* the surgeon's billing group, for the same-group outcome in A2 */
end

capture program drop unit_characteristics
program define unit_characteristics
	args y
	use "${DATA_FINAL}Physician_`y'.dta", clear
	rename physician_npi Specialist_ID
	foreach x of varlist _all {
		if "`x'"!="Specialist_ID" {
			rename `x' spec_`x'
		}
	}
	save "${DATA_FINAL}Specialist_`y'.dta", replace
end

capture program drop unit_yearly_ops
program define unit_yearly_ops
	args y
	use "${DATA_FINAL}OrthoStays_`y'.dta", clear
	collapse (count) yearly_ops=bene_id, by(spec_npi)
	rename spec_npi Specialist_ID
	gen Year=`y'
	save temp_ops_`y', replace
end
