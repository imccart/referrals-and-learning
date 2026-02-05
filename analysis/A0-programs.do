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
			
		*smooth changes
		quietly replace pred_iter_new=0.9*pred_iter_old + 0.1*pred_iter_new
			
		*assess convergence
		quietly count if spec_obs==1 & abs(pred_iter_new-pred_iter_old) > (tot_patients/1000)
		scalar changes=r(N)
		noisily dis changes " " _cont

	}
	noisily dis "converged"
	quietly replace `1' = pred_iter_new
	quietly replace no_equil=(abs(pred_iter_new-pred_iter_old) > (tot_patients/1000))
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
	scalar changes=999
	local step=0
	* loop
	while changes>0 & `step'<50 {
		local step=`step'+1
		* update equilibrium variable using result from last iteration
		quietly replace pred_iter_old=pred_iter_new
		drop pij pred_iter_new exp_uij sum_exp_uij

		* construct familiarity term endogenously (by month)
		sort admit
		qui gen month=mofd(admit)
		qui egen admit_group=group(month)
		qui sum admit_group
		local a_count=r(max)
		forvalues a=0/`a_count' {
			if `a'==0 {
				qui gen num_a=exp(coef_dist*diff_dist + coef_m*m + coef_val)
				qui bys casevar: egen denom_a=sum(num_a)
				qui gen pij_a=num_a/denom_a
				qui drop num_a denom_a
			}
			else {
				qui replace pij_a=0 if admit_group>`a'
				qui bys Practice_ID Specialist_ID: egen pair_run_a=sum(pij_a)
				qui egen fmly_level_a=cut(pair_run_a), at(0,1,2,3,4,5,6,8,11,16,10000)
				qui replace fmly_level_a=7 if fmly_level_a==6
				qui replace fmly_level_a=10 if fmly_level_a==8
				qui replace fmly_level_a=15 if fmly_level_a==11
				qui replace fmly_level_a=20 if fmly_level_a==16
				qui merge m:1 hrr fmly_level_a using fmly_effect_a, keep(master match) nogenerate
				qui replace fmly_agg_a=0 if fmly_agg_a==.
				qui gen num_a=exp(coef_dist*diff_dist + coef_m*m + xi_j + iv_pat*pred_iter_old)
				qui bys casevar: egen denom_a=sum(num_a)
				qui replace pij_a=num_a/denom_a if admit_group==`a'
				qui drop num_a denom_a fmly_level_a fmly_agg_a pair_run_a
			}
			display "Run `a' out of `a_count'"
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
		qui drop fmly_level_a fmly_agg_a pij_a pair_run_a month admit_group

		** incorporate updated fmly_agg into new prediction
		qui gen exp_uij=exp(coef_dist*diff_dist + coef_m*m + fmly_agg + xi_j + iv_pat*pred_iter_old)
		qui bys casevar: egen sum_exp_uij=sum(exp_uij)
		qui gen pij=exp_uij/sum_exp_uij
		qui bys Specialist_ID time_period: egen pred_iter_new=sum(pij)
			
		*smooth changes
		qui replace pred_iter_new=0.9*pred_iter_old + 0.1*pred_iter_new
			
		*assess convergence
		qui count if spec_obs==1 & abs(pred_iter_new-pred_iter_old) > max(2, (tot_patients/1000))
		scalar changes=r(N)
		dis changes " " _cont

	}
	dis "converged"
	qui replace `1' = pred_iter_new
	qui replace no_equil=(abs(pred_iter_new-pred_iter_old) > max(2, (tot_patients/1000)))
end
		
		
