set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}MNL_Distance_`logdate'.log", replace

******************************************************************
**	Title:		IV estimation
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	2/16/2025
******************************************************************

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
forvalues i=1/457 {
	capture confirm file "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta"
	if _rc==0 {

		use "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta", clear		
		do "${CODE_FILES}_clean-analysis.do"
		
		** prepare for cmclogit syntax
		egen referral=group(bene_id admit)
		keep Practice_ID Specialist_ID choice referral case_obs casevar common_ref prop_failures_run prop_patients_run bene_distance bene_spec_distance diff_dist Year
		
		gen time_period=(Year>2015)
		gen Spec_ID_t=string(Specialist_ID, "%10.0f")
		replace Spec_ID_t=Spec_ID_t+"-a" if time_period==0
		replace Spec_ID_t=Spec_ID_t+"-b" if time_period==1
		
		bys Specialist_ID: gen spec_freq=_N
		qui sum spec_freq
		local freq_max=r(max)
		
		preserve
		keep if spec_freq==`freq_max'
		local base_ID=Specialist_ID[1]
		restore
		replace Spec_ID_t="base" if Specialist_ID==`base_ID'		
		cmset Practice_ID referral case_obs
		
		** estimate and save results
		gsort casevar -common_ref
	
		if ${OUTSIDE_OPTION}==1 {
			capture cmclogit choice diff_dist, noconstant basealternative(0) iterate(100)
		}
		else if ${OUTSIDE_OPTION}==0 {
			capture cmclogit choice diff_dist, noconstant iterate(100)
		}
				
		if e(converged)>0 & _rc==0 {
			predict yhat
			collapse (sum) yhat, by(Spec_ID_t)
			gen hrr=`i'
			save dist_pred_`i', replace
		}
	}	
}

local step=0
forvalues i=1/457 {
	capture confirm file "dist_pred_`i'.dta"
	if _rc==0 {
		local step=`step'+1
		if `step'==1 {
			use dist_pred_`i', clear
		}
		else {
			append using dist_pred_`i', force
		}
	}
	capture erase "dist_pred_`i'.dta"	
}

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"	
if ${OUTSIDE_OPTION}==1 {
	save "${RESULTS_FINAL}Distance_Prediction_`r_type'.dta", replace
}
else if ${OUTSIDE_OPTION}==0 {
	save "${RESULTS_FINAL}Distance_Prediction_Full_`r_type'.dta", replace
}


log close

