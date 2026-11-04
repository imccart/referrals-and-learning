set logtype text
capture log close
local logdate = string( d(`c(current_date)'), "%dCYND" )

******************************************************************
**	Title:		Structural estimation
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	2/25/2026
**	Note:		Parameterized by MODEL_TYPE (Myopic or FWD). Every market's
**			estimation outcome goes to Convergence_<model>.csv.
**			Myopic uses posterior mean m; FWD uses Gittins index.
******************************************************************

** Resolve model type
if "${MODEL_TYPE}" == "Myopic" {
	local model "Myopic"
	local coef_prefix "StructureMyopic"
	local belief_var "m"
	local log_label "MyopicLearning"
}
else if "${MODEL_TYPE}" == "FWD" {
	local model "FWD"
	local coef_prefix "StructureForward"
	local belief_var "gittins"
	local log_label "FWDLooking"
}
log using "${LOG_PATH}Structural_`log_label'_`logdate'.log", replace


******************************************************************
** Estimation by HRR and over different values for eta

file open fconv using "${RESULTS_FINAL}Convergence_`model'.csv", write replace
file write fconv "hrr,eta,cases,surgeons,pcps,rc,converged,scale_iter,scale_converged,attempt" _n

forvalues i=1/457 {
	capture confirm file "${DATA_FINAL}ChoiceData_HRR`i'.dta"
	if _rc==0 {
		use "${DATA_FINAL}ChoiceData_HRR`i'.dta", clear
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

		** an alternative never chosen within its period has no finite fixed effect
		bys Spec_ID_t: egen any_choice=max(choice)
		drop if any_choice==0
		drop any_choice
		qui count if choice==1
		local cases=r(N)
		bys Spec_ID_t: gen first_s=(_n==1)
		qui count if first_s==1
		local surgeons=r(N)
		bys Practice_ID: gen first_p=(_n==1)
		qui count if first_p==1
		local pcps=r(N)
		drop first_s first_p

		bys Specialist_ID: gen spec_freq=_N
		qui sum spec_freq
		local freq_max=r(max)

		preserve
		keep if spec_freq==`freq_max'
		local base_ID=Specialist_ID[1]
		restore
		replace Spec_ID_t=string(Specialist_ID,"%10.0f") if Specialist_ID==`base_ID'
		encode Spec_ID_t, gen(Spec_ID)

		replace Spec_ID=0 if Specialist_ID==`base_ID'
		cmset Practice_ID referral case_obs
		qui sum spec_qual
		local rho=r(mean)
		gen m=.

		** Forward-looking: additional variables for Gittins index
		if "`model'" == "FWD" {
			gen v_git=.
			gen s_git=.
			gen psi_git=.
			gen gittins=.
		}

		foreach eta in 1 5 {
			replace m=(`rho'*`eta' + pair_success_run)/(`eta' + pair_patients_run)

			** Forward-looking: compute Gittins index
			if "`model'" == "FWD" {
				local beta=0.95
				replace v_git = m*(1-m)/(pair_patients_run+1)
				replace s_git = -(log(`beta')*(pair_patients_run+1))^(-1)
				replace psi_git=sqrt(s_git/2)
				replace psi_git=0.49 - 0.11*(1/sqrt(s_git)) if s_git>0.2 & s_git <=1
				replace psi_git=0.63 - 0.26*(1/sqrt(s_git)) if s_git>1   & s_git <=5
				replace psi_git=0.77 - 0.58*(1/sqrt(s_git)) if s_git>5   & s_git <=15
				replace psi_git=sqrt(2*log(s_git) - log(log(s_git)) - log(16*_pi)) if s_git>15
				replace gittins=m + sqrt(v_git)*psi_git
			}

			** estimate and save results
			gsort casevar -common_ref
			local baseopt=cond(${OUTSIDE_OPTION}==1, "basealternative(0)", "")
			local attempt=1
			local mlopt iterate(100)
			capture cmclogit choice `belief_var' diff_dist fmly_np_* ib0.Spec_ID, noconstant `baseopt' `mlopt'
			local rc=_rc
			if `rc'!=0 | e(converged)==0 {
				local attempt=2
				local mlopt iterate(300) difficult technique(bfgs 20 nr 10)
				capture cmclogit choice `belief_var' diff_dist fmly_np_* ib0.Spec_ID, noconstant `baseopt' `mlopt'
				local rc=_rc
			}

			if `rc'==0 {
				preserve
				gen belief_s=.
				local iter=0
				local lna_old=1
				local lna_new=ln(max(_b[`belief_var'],0.01))
				while (abs( exp(`lna_new') - exp(`lna_old') ) > 0.005 & `iter'<10) {
					local iter=`iter' + 1
					local lna_old = `lna_new'
					qui replace belief_s = exp(`lna_old')*`belief_var'
					qui cmclogit choice belief_s diff_dist fmly_np_* ib0.Spec_ID, noconstant `baseopt' `mlopt'
					local lna_new = `lna_old' + _b[belief_s]-1
				}
				local scale_conv=(abs( exp(`lna_new') - exp(`lna_old') ) <= 0.005)
				file write fconv "`i',`eta',`cases',`surgeons',`pcps',0,`=e(converged)',`iter',`scale_conv',`attempt'" _n
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
			else {
				file write fconv "`i',`eta',`cases',`surgeons',`pcps',`rc',0,,,`attempt'" _n
			}
		}
	}
}
file close fconv

import delimited using "${RESULTS_FINAL}Convergence_`model'.csv", clear
merge m:1 hrr using hrr_size, keep(master match) nogenerate keepusing(patients pcp_total spec_total mean_choice_size spec_hhi)
export delimited using "${RESULTS_FINAL}Convergence_`model'.csv", replace


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
		capture erase "temp_id_match_`i'_`eta'.dta"
	}
}

if ${OUTSIDE_OPTION}==1 {
	save "${RESULTS_FINAL}`coef_prefix'HRR_Coef_rhobar.dta", replace
}
else if ${OUTSIDE_OPTION}==0 {
	save "${RESULTS_FINAL}`coef_prefix'HRR_CoefFull_rhobar.dta", replace
}

log close
