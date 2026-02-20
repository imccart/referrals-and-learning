******************************************************************
**	Title:		Stata functions and programs
**	Author:		Ian McCarthy
**	Date Created:	1/3/2019
**	Date Updated:	6/7/2024
******************************************************************

** distance calculation
capture program drop finddist 
program define finddist 
	args lat1 long1 lat2 long2 
	local radius_earth=6.378136e3
	tempvar val 
	gen double `val'=sin(_pi*abs(`lat1')/180)*sin(_pi*abs(`lat2')/180)+cos(_pi*abs(`lat1')/180)*cos(_pi*abs(`lat2')/180)*cos(_pi*abs(`long1')/180-_pi*abs(`long2')/180) 
	qui replace `val'=1 if (`val'>1)&(`val'!=.)
	gen distance=`radius_earth'*acos(`val')
end 

		
** converge to equilibrium patient volumes
capture program drop converge
program define converge
	* variables
	tempvar pij pred_iter_old pred_iter_new exp_uij sum_exp_uij
	quietly gen pred_iter_new=`1'
	quietly gen pred_iter_old=.
	quietly gen pij=.
	quietly gen exp_uij=.
	quietly gen sum_exp_uij=.
	quietly gen no_equil=.
	quietly gen conv_crit=.
	quietly gen sign_flips = 0
	quietly gen prev_sign = 0
	quietly gen damp_weight = 0.1
	scalar changes=999
	local step=0
	* loop
	while changes>0 & `step'<250 {
		local step=`step'+1
		* update equilibrium variable using result from last iteration
		quietly replace pred_iter_old=pred_iter_new
		drop pij pred_iter_new exp_uij sum_exp_uij

		* prediction
		**gen m=(rho*`eta' + pair_success_run)/(`eta' + pair_patients_run)
		gen exp_uij=exp(coef_dist*diff_dist + coef_m*m + fmly_agg + xi_j + iv_pat*pred_iter_old)
		bys casevar: egen sum_exp_uij=sum(exp_uij)
		gen pij=exp_uij/sum_exp_uij
		bys Specialist_ID time_period: egen pred_iter_new=sum(pij)

		* track oscillation per specialist
		qui gen curr_sign = sign(pred_iter_new - pred_iter_old) if spec_obs==1
		qui replace sign_flips = sign_flips + (curr_sign * prev_sign < 0) if spec_obs==1
		qui replace prev_sign = curr_sign if spec_obs==1 & curr_sign != 0
		drop curr_sign

		* adaptive dampening: oscillators get heavier dampening
		qui replace damp_weight = cond(sign_flips >= 3, 0.03, 0.1) if spec_obs==1

		*smooth changes
		quietly replace pred_iter_new=(1-damp_weight)*pred_iter_old + damp_weight*pred_iter_new

		*assess convergence
		qui replace conv_crit = (abs(pred_iter_new-pred_iter_old) > (0.10*pred_iter_old + 1))
		qui count if spec_obs==1 & conv_crit==1
		**quietly count if spec_obs==1 & abs(pred_iter_new-pred_iter_old) > (tot_patients/1000)
		scalar changes=r(N)
		noisily dis changes " " _cont

	}
	* diagnostics at termination
	qui count if spec_obs==1 & sign_flips >= 3
	local n_osc = r(N)
	if changes > 0 {
		noisily dis "WARNING: " changes " specialists did not converge (`n_osc' oscillating)"
		qui sum abs(pred_iter_new - pred_iter_old) if spec_obs==1 & conv_crit==1
		noisily dis "  Mean gap: `=string(r(mean), "%9.4f")', Max gap: `=string(r(max), "%9.4f")'"
	}
	else {
		noisily dis "converged"
	}
	quietly replace `1' = pred_iter_new
	quietly replace no_equil=(conv_crit==1)
	drop sign_flips prev_sign damp_weight
end

capture program drop converge_dyn
program define converge_dyn
	
	* variables
	tempvar pij pred_iter_old pred_iter_new exp_uij sum_exp_uij
	quietly gen pred_iter_new=`1'
	quietly gen pred_iter_old=.
	quietly gen pij=.
	quietly gen exp_uij=.
	quietly gen sum_exp_uij=.
	quietly gen no_equil=.
	quietly gen conv_crit=.
	quietly gen sign_flips = 0
	quietly gen prev_sign = 0
	quietly gen damp_weight = 0.2
	scalar changes=999
	local step=0
	* loop
	while changes>0 & `step'<75 {
		local step=`step'+1
		* update equilibrium variable using result from last iteration
		quietly replace pred_iter_old=pred_iter_new
		drop pij pred_iter_new exp_uij sum_exp_uij

		* construct familiarity term endogenously (by quarter)
		sort admit
		**qui gen month=mofd(admit)
		**qui egen admit_group=group(month)
		**qui sum admit_group		
		qui gen qtr=qofd(admit)
		qui egen admit_group=group(qtr)
		qui sum admit_group
		local a_count=r(max)
		forvalues a=0/`a_count' {
			if `a'==0 {
				qui egen fmly_level_a=cut(base_patients), at(0,1,2,3,4,5,6,8,11,16,10000)
				qui replace fmly_level_a=7 if fmly_level_a==6
				qui replace fmly_level_a=10 if fmly_level_a==8
				qui replace fmly_level_a=15 if fmly_level_a==11
				qui replace fmly_level_a=20 if fmly_level_a==16
				qui merge m:1 hrr fmly_level_a using fmly_effect_a, keep(master match) nogenerate
				qui replace fmly_agg_a=0 if fmly_agg_a==.
				
				qui gen num_a=exp(coef_dist*diff_dist + coef_m*m + xi_j + fmly_agg_a + iv_pat*pred_iter_old)
				qui bys casevar: egen denom_a=sum(num_a)
				qui gen pij_a=num_a/denom_a
				qui drop num_a denom_a fmly_level_a fmly_agg_a
			}
			else {
				qui replace pij_a=0 if admit_group>`a'
				qui bys Practice_ID Specialist_ID: egen pair_run_a=sum(pij_a)
				qui replace pair_run_a=pair_run_a + base_patients
				qui egen fmly_level_a=cut(pair_run_a), at(0,1,2,3,4,5,6,8,11,16,10000)
				qui replace fmly_level_a=7 if fmly_level_a==6
				qui replace fmly_level_a=10 if fmly_level_a==8
				qui replace fmly_level_a=15 if fmly_level_a==11
				qui replace fmly_level_a=20 if fmly_level_a==16
				qui merge m:1 hrr fmly_level_a using fmly_effect_a, keep(master match) nogenerate
				qui replace fmly_agg_a=0 if fmly_agg_a==.
				
				qui gen num_a=exp(coef_dist*diff_dist + coef_m*m + xi_j + fmly_agg_a + iv_pat*pred_iter_old)
				qui bys casevar: egen denom_a=sum(num_a)
				qui replace pij_a=num_a/denom_a if admit_group==`a'
				qui drop num_a denom_a fmly_level_a fmly_agg_a pair_run_a
			}

		}
		sort Practice_ID Specialist_ID admit
		qui by Practice_ID Specialist_ID: gen pair_run_a=sum(pij_a)
		qui egen fmly_level_a=cut(pair_run_a), at(0,1,2,3,4,5,6,8,11,16,10000)
		qui replace fmly_level_a=7 if fmly_level_a==6
		qui replace fmly_level_a=10 if fmly_level_a==8
		qui replace fmly_level_a=15 if fmly_level_a==11
		qui replace fmly_level_a=20 if fmly_level_a==16
		qui merge m:1 hrr fmly_level_a using fmly_effect_a, keep(master match) nogenerate
		qui replace fmly_agg_a=0 if fmly_agg_a==.
		qui replace fmly_agg=fmly_agg_a
		qui drop fmly_level_a fmly_agg_a pij_a pair_run_a qtr admit_group

		** incorporate updated fmly_agg into new prediction
		qui gen exp_uij=exp(coef_dist*diff_dist + coef_m*m + fmly_agg + xi_j + iv_pat*pred_iter_old)
		qui bys casevar: egen sum_exp_uij=sum(exp_uij)
		qui gen pij=exp_uij/sum_exp_uij
		qui bys Specialist_ID time_period: egen pred_iter_new=sum(pij)
			
		* track oscillation per specialist
		qui gen curr_sign = sign(pred_iter_new - pred_iter_old) if spec_obs==1
		qui replace sign_flips = sign_flips + (curr_sign * prev_sign < 0) if spec_obs==1
		qui replace prev_sign = curr_sign if spec_obs==1 & curr_sign != 0
		drop curr_sign

		* adaptive dampening: oscillators get heavier dampening
		qui replace damp_weight = cond(sign_flips >= 3, 0.05, 0.2) if spec_obs==1

		*smooth changes
		qui replace pred_iter_new=(1-damp_weight)*pred_iter_old + damp_weight*pred_iter_new

		*assess convergence
		qui replace conv_crit = (abs(pred_iter_new-pred_iter_old) > (0.10*pred_iter_old + 1))
		qui count if spec_obs==1 & conv_crit==1
		scalar changes=r(N)
		qui count if spec_obs==1
		local all_spec_obs=r(N)
		qui sum pred_iter_new if spec_obs==1 & conv_crit==1
		local new_nc=r(mean)
		qui sum pred_iter_old if spec_obs==1 & conv_crit==1
		local old_nc=r(mean)
		dis "iteration `step': " changes " out of `all_spec_obs': non-coverged post-mean, `new_nc', and pre-mean `old_nc'"

	}
	* diagnostics at termination
	qui count if spec_obs==1 & sign_flips >= 3
	local n_osc = r(N)
	if changes > 0 {
		dis "WARNING: " changes " specialists did not converge (`n_osc' oscillating)"
		qui sum abs(pred_iter_new - pred_iter_old) if spec_obs==1 & conv_crit==1
		dis "  Mean gap: `=string(r(mean), "%9.4f")', Max gap: `=string(r(max), "%9.4f")'"
	}
	else {
		dis "converged"
	}
	qui replace `1' = pred_iter_new
	qui replace no_equil=(conv_crit==1)
	drop sign_flips prev_sign damp_weight
end
		

		
** standard MNL for sensitivity analysis
capture program drop run_mnl_specs
program define run_mnl_specs
	syntax , Regressors(string)
	
	local r_type="${PCP_First}_${PCP_Only}_${RFR_Priority}"
	forvalues i=1/457 {
		capture confirm file "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta"
		if _rc==0 {
			use "${DATA_FINAL}ChoiceData_HRR`i'_`r_type'.dta", clear
			do "${CODE_FILES}_clean-analysis.do"

			** prepare for cmclogit syntax
			egen referral=group(bene_id admit)
			keep Practice_ID Specialist_ID choice referral case_obs casevar common_ref prop_failures_run prop_patients_run ///
				pair_success_run spec_qual pair_patients_run pair_failures_run bene_spec_distance bene_distance diff_dist prac_vi pair_new ///
				fmly_np_* Year pcp_phy_tin1 pcp_phy_tin2				
			sum fmly_np_*
			drop fmly_np_0
			local step=0
			foreach x of varlist pcp_phy_tin1 pcp_phy_tin2 {
				local step=`step'+1
				bys `x': egen practice_patients_`step'=sum(pair_patients_run)
				replace practice_patients_`step'=practice_patients_`step'-pair_patients_run
				bys `x': egen practice_failures_`step'=sum(pair_failures_run)
				replace practice_failures_`step'=practice_failures_`step'-pair_failures_run
				gen practice_info_`step'=(practice_patients_`step'-practice_failures_`step')/practice_patients_`step'
			}
			
			
			cmset Practice_ID referral case_obs
			qui sum spec_qual
			local rho=r(mean)
			gen m=(`rho' + pair_success_run)/(1 + pair_patients_run)
		
			** estimate and save results
			gsort casevar -common_ref
			capture cmclogit choice m `regressors', noconstant iterate(100)

			if _rc==0 {
				gen belief_s=.
				local iter=0
				local lna_old=1
				local lna_new=ln(max(_b[m],0.01))
				while (abs( exp(`lna_new') - exp(`lna_old') ) > 0.005 & `iter'<10) {
					local iter=`iter' + 1
					local lna_old = `lna_new'
					qui replace belief_s = exp(`lna_old')*m
					qui cmclogit choice belief_s `regressors', noconstant iterate(100)
					local lna_new = `lna_old' + _b[belief_s]-1
				}
				est store cmclogit_est
				matrix b1=get(_b)				
				mat b1[1,1]=exp(`lna_new')
				matrix var_cov=e(V)
				matrix var_diag=vecdiag(var_cov)
				matrix c1=(`i', e(converged), e(ll), b1)'
				matrix var1=(`i', e(converged), e(ll), var_diag)'
				svmat double c1, name(coef_`i')
				svmat double var1, name(coef_se_`i')
				gen coef_names_`i'=""
				replace coef_names_`i'="hrr" if _n==1
				replace coef_names_`i'="converged" if _n==2
				replace coef_names_`i'="log_like" if _n==3
				local cov_list=rowsof(c1)
				local names : rownames c1
				forvalues l=4/`cov_list' {
					local name : word `l' of `names'
					replace coef_names_`i'="`name'" if _n==`l'
				}

				keep if coef_`i'!=.
				keep coef_`i' coef_se_`i' coef_names_`i'
				replace coef_se_`i'=sqrt(coef_se_`i')
				save coef_data_`i', replace
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
end
