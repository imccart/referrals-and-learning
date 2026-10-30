******************************************************************
**	Title:		Episode Spend
**	Description:	Form total episode-spending for each procedure
**	Author:		Ian McCarthy
**	Date Created:	11/3/17
**	Date Updated:	10/18/22
******************************************************************

forvalues y=2008/2018 {
	insheet using "${DATA_SAS}EPISODE_`y'.tab", tab clear
	foreach x of varlist ip_pay ip_claims op_pay op_claims ///
		carrier_pay carrier_claims hha_pay hha_claims snf_pay snf_claims {
			replace `x'=0 if `x'==.
		}
	gen episode_spend=ip_pay + op_pay + carrier_pay + hha_pay + snf_pay
	keep bene_id clm_id episode_spend
	gen Year=`y'
	save "${DATA_FINAL}Episode_`y'.dta", replace
}

use "${DATA_FINAL}Episode_2008.dta", clear
forvalues y=2009/2018 {
	append using "${DATA_FINAL}Episode_`y'.dta"
}
save "${DATA_FINAL}Episode_Spending.dta", replace
