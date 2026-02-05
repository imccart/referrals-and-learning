set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )
log using "${LOG_PATH}Structural_FWDLooking_`logdate'.log", replace

******************************************************************
**	Title:		PCP Referrals & Forward Looking Learning
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	3/18/2025
******************************************************************


******************************************************************
** Estimation by HRR and over different values for eta
local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"

forvalues i=1/457 {
	capture confirm file "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta"
	if _rc==0 {
		use "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta", clear
		do "${CODE_FILES}_clean-analysis.do"

		** prepare for cmclogit syntax
		egen referral=group(bene_id admit)
		keep Practice_ID Specialist_ID choice referral case_obs casevar common_ref prop_failures_run prop_patients_run ///
			pair_success_run spec_qual pair_patients_run bene_spec_distance bene_distance diff_dist prac_vi pair_new ///
			fmly_np_* Year
		drop fmly_np_0
		
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
		replace Spec_ID_t=string(Specialist_ID,"%10.0f") if Specialist_ID==`base_ID'
		if ${CONG_t}==1 {
			encode Spec_ID_t, gen(Spec_ID)
		}
		else {
			gen Spec_ID=Specialist_ID
		}
		
		replace Spec_ID=0 if Specialist_ID==`base_ID'
		cmset Practice_ID referral case_obs
		
		qui sum spec_qual
		local rho=r(mean)
		gen m=.
		gen v_git=.
		gen s_git=.
		gen psi_git=.
		gen gittins=.
		foreach eta in 1 5 {
			replace m=(`rho'*`eta' + pair_success_run)/(`eta' + pair_patients_run)
			local beta=0.95
			replace v_git = m*(1-m)/(pair_patients_run+1)
			replace s_git = -(log(`beta')*(pair_patients_run+1))^(-1)
			replace psi_git=sqrt(s_git/2)
			replace psi_git=0.49 - 0.11*(1/sqrt(s_git)) if s_git>0.2 & s_git <=1
			replace psi_git=0.63 - 0.26*(1/sqrt(s_git)) if s_git>1   & s_git <=5
			replace psi_git=0.77 - 0.58*(1/sqrt(s_git)) if s_git>5   & s_git <=15
			replace psi_git=sqrt(2*log(s_git) - log(log(s_git)) - log(16*_pi)) if s_git>15
			replace gittins=m + sqrt(v_git)*psi_git

			** estimate and save results
			gsort casevar -common_ref			
			if ${OUTSIDE_OPTION}==1 {
				capture cmclogit choice gittins diff_dist fmly_np_* ib0.Spec_ID, noconstant basealternative(0) iterate(100)
			}
			else if ${OUTSIDE_OPTION}==0 {
				capture cmclogit choice gittins diff_dist fmly_np_* ib0.Spec_ID, noconstant iterate(100)
			}
				
			if _rc==0 {
				preserve
				gen belief_s=.
				local iter=0
				local lna_old=1
				local lna_new=ln(max(_b[gittins],0.01))
				while (abs( exp(`lna_new') - exp(`lna_old') ) > 0.005 & `iter'<10) {
					local iter=`iter' + 1
					local lna_old = `lna_new'
					qui replace belief_s = exp(`lna_old')*gittins
					qui cmclogit choice belief_s diff_dist fmly_np_* ib0.Spec_ID, noconstant iterate(100)
					local lna_new = `lna_old' + _b[belief_s]-1
				}
				est store cmclogit_est
				matrix b1=get(_b)
				mat b1[1,1]=exp(`lna_new')
				matrix var_cov=e(V)
				matrix var_diag=vecdiag(var_cov)
				matrix c1=(`i', `eta', e(converged), e(ll), b1)'
				matrix var1=(`i', `eta', e(converged), e(ll), var_diag)'
				svmat double c1, name(coef_`i')
				svmat double var1, name(coef_se_`i')
				gen coef_names_`i'=""
				replace coef_names_`i'="hrr" if _n==1
				replace coef_names_`i'="eta" if _n==2
				replace coef_names_`i'="converged" if _n==3
				replace coef_names_`i'="log_like" if _n==4
				local cov_list=rowsof(c1)
				local names : rownames c1
				forvalues l=5/`cov_list' {
					local name : word `l' of `names'
					replace coef_names_`i'="`name'" if _n==`l'
				}
				local conv=e(converged)
			
				keep if coef_`i'!=.
				keep coef_`i' coef_se_`i' coef_names_`i'
				replace coef_se_`i'=sqrt(coef_se_`i')
				save coef_data_`i'_`eta', replace
				restore
				
				preserve
				keep Spec_ID Spec_ID_t
				bys Spec_ID: gen obs=_n
				keep if obs==1
				drop obs
				save temp_id_match_`i'_`eta', replace
				restore				
				
				est drop cmclogit_est
			}
		}
	}
}


forvalues i=1/457 {
	foreach eta in 1 5 {
		capture confirm file "coef_data_`i'_`eta'.dta"
		if _rc==0 {
			use coef_data_`i'_`eta', clear
			rename coef_`i'1 coef_val
			rename coef_se_`i'1 coef_se
			rename coef_names_`i' coef_name
			replace coef_name=subinstr(coef_name,"a","",.) if strpos(coef_name,"Spec_ID")>0
			replace coef_name=subinstr(coef_name,"b","",.) if strpos(coef_name,"Spec_ID")>0
			split coef_name if strpos(coef_name,"Spec_ID")>0, generate(raw_spec) parse(".")
			drop raw_spec2
			rename raw_spec1 Spec_ID
			destring Spec_ID, replace
			merge m:1 Spec_ID using temp_id_match_`i'_`eta', nogenerate
			replace coef_name=Spec_ID_t if Spec_ID_t!=""
			drop Spec_ID Spec_ID_t			
			save coef_data_`i'_`eta', replace
		}
	}
}

local step=0
forvalues i=1/457 {
	foreach eta in 1 5 {
		capture confirm file "coef_data_`i'_`eta'.dta"
		if _rc==0 {
			local step=`step'+1
			if `step'==1 {
				use coef_data_`i'_`eta', clear
			}
			else {
				append using coef_data_`i'_`eta', force
			}
		}
		capture erase "coef_data_`i'_`eta'.dta"	
	}
}

local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
if ${OUTSIDE_OPTION}==1 {
	save "${RESULTS_FINAL}StructureForwardHRR_Coef_`r_type'_rhobar.dta", replace
}
else if ${OUTSIDE_OPTION}==0 {
	save "${RESULTS_FINAL}StructureForwardHRR_CoefFull_`r_type'_rhobar.dta", replace
}

log close
