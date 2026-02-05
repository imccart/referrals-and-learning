set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}MyopicLearning_`logdate'.log", replace

******************************************************************
**	Title:		PCP Referrals & Myopic Learning
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	7/25/2023
******************************************************************


******************************************************************
** Estimation with FE
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
forvalues i=1/457 {
	capture confirm file "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta"
	if _rc==0 {
		use "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta", clear
		do "${CODE_FILES}_clean-analysis.do"

		** prepare for cmclogit syntax
		egen referral=group(bene_id admit)
		keep Practice_ID Specialist_ID choice referral case_obs casevar common_ref prop_failures_run prop_patients_run bene_spec_distance bene_distance diff_dist
		cmset Practice_ID referral case_obs
			
		** estimate and save results
		gsort casevar -common_ref			
		if ${OUTSIDE_OPTION}==1 {
			capture cmclogit choice c.prop_failures_run##c.prop_patients_run diff_dist ib0.Specialist_ID, noconstant basealternative(0) iterate(100)
		}
		else if ${OUTSIDE_OPTION}==0 {
			capture cmclogit choice c.prop_failures_run##c.prop_patients_run diff_dist ib(freq).Specialist_ID, noconstant iterate(100)
		}
		if _rc==0 {
			est store cmclogit_est`i'
			matrix b1=get(_b)
			matrix var_cov=e(V)
			matrix var_diag=vecdiag(var_cov)
			matrix c1=(`i', e(converged), b1)'
			matrix var1=(`i', e(converged), var_diag)'
			svmat double c1, name(coef_`i')
			svmat double var1, name(coef_se_`i')
			gen coef_names_`i'=""
			replace coef_names_`i'="hrr" if _n==1
			replace coef_names_`i'="converged" if _n==2
			local cov_list=rowsof(c1)
			local names : rownames c1
			forvalues l=3/`cov_list' {
				local name : word `l' of `names'
				replace coef_names_`i'="`name'" if _n==`l'
			}
			local conv=e(converged)
		
			preserve
			keep if coef_`i'!=.
			keep coef_`i' coef_se_`i' coef_names_`i'
			replace coef_se_`i'=sqrt(coef_se_`i')
			save coef_data_`i', replace
			restore
			
			if `conv'>0 {
				est restore cmclogit_est`i'
				predict yhat
				gen touse=e(sample)
				replace touse=0 if missing(yhat)
			
				capture margins if touse, dydx(prop_failures_run prop_patients_run) outcome(1) alternative(1) post
				if _rc==0 {
					est store mfx_est
					mat var_mat=e(V)
					matrix b2=e(b)
					matrix c2=(`i',b2,sqrt(var_mat[1,1]),sqrt(var_mat[2,2]))'
					svmat double c2, name(mfx_`i')
				
					gen mfx_names_`i'=""
					replace mfx_names_`i'="hrr" if _n==1
					replace mfx_names_`i'="mfx_failures" if _n==2
					replace mfx_names_`i'="mfx_patients" if _n==3
					replace mfx_names_`i'="mfx_failures_se" if _n==4
					replace mfx_names_`i'="mfx_patients_se" if _n==5
				
					keep if mfx_`i'!=.
					keep mfx_`i' mfx_names_`i'
					save mfx_data_`i', replace
				}
			}
			est drop cmclogit_est`i'
		}
	}
}	


forvalues i=1/457 {
	capture confirm file "coef_data_`i'.dta"
	if _rc==0 {
		use coef_data_`i', clear
		rename coef_`i'1 coef_val
		rename coef_se_`i'1 coef_se
		rename coef_names_`i' coef_name
		save coef_data_`i', replace
	}
}

local step=0
forvalues i=1/457 {
	capture confirm file "coef_data_`i'.dta"
	if _rc==0 {
		local step=`step'+1
		if `step'==1 {
			use coef_data_`i', clear
		}
		else {
			append using coef_data_`i', force
		}
	}
	capture erase "coef_data_`i'.dta"	
}

if ${OUTSIDE_OPTION}==1 {
	save "${RESULTS_FINAL}MyopicHRR_Coef_`r_type'.dta", replace
}
else if ${OUTSIDE_OPTION}==0 {
	save "${RESULTS_FINAL}MyopicHRR_CoefFull_`r_type'.dta", replace
}

				
		
forvalues i=1/457 {
	capture confirm file "mfx_data_`i'.dta"
	if _rc==0 {
		use mfx_data_`i', clear
		rename mfx_`i'1 mfx_val
		rename mfx_names_`i' mfx_name
		save mfx_data_`i', replace
	}
}
		
local step=0
forvalues i=1/457 {
	capture confirm file "mfx_data_`i'.dta"
	if _rc==0 {
		local step=`step'+1
		if `step'==1 {
			use mfx_data_`i', clear
		}
		else {
			append using mfx_data_`i', force
		}
	}
	capture erase "mfx_data_`i'.dta"		
}

if ${OUTSIDE_OPTION}==1 {
	save "${RESULTS_FINAL}MyopicHRR_mfx_`r_type'.dta", replace
}
else if ${OUTSIDE_OPTION}==0 {
	save "${RESULTS_FINAL}MyopicHRR_mfxFull_`r_type'.dta", replace
}

log close

capture reg choice spec_failures_run
est store reg_test

est table reg_test
