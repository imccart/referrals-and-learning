******************************************************************
**	Title:		Unit of the specialist choice: the surgeon
**	Author:		Ian McCarthy
**	Date Created:	11/2/2026
**	Notes:		Defines the three programs through which the build and the
**			analysis learn what a "specialist" is. D2_unit-practice.do
**			defines the same three for the practice. A driver loads one
**			of the two and nothing else refers to the level.
**			  define_unit y          on the year's referral panel (R0): sets
**			                         Practice_ID, Specialist_ID, parent_id
**			  unit_characteristics y writes ${DATA_FINAL}Specialist_y.dta, one
**			                         row per unit, every column prefixed spec_
**			  unit_yearly_ops y      writes temp_ops_y, the unit's operations in
**			                         the year, for the SPEC_MIN cut
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
