# Analysis

All analysis was performed through a secure remote desktop using R. Below, we separate our files into functions and other code files. The functions are stand-alone and called by different individual code files. All files are called by the [Main Analysis](analysis/_main.R) file.

## Functions

1. [Discrete Choice](analysis/fn_logit_model.R). This function estimates the multinomial logit model for patient selection of hospitals in their market for their procedure.

2. [Bootstrap Standard Errors](analysis/fn_choice_reg_bs.R). This function calculates bootstrapped standard errors for the multinomial logit model.


## Analysis Files

1. [Summary Statistics](analysis/summary_stats.R). Form tables of descriptive stats on CH vs. Non-CH hospitals.

2. [Discrete Choice](analysis/choice_reg_year.R). The purpose of this file is to calculate the willingness to pay for CH versus NCH. To do this, we estimate the choice model in each year, calling the logit model function above. We do this separately by year and within different care settings. The [inpatient](analysis/choice_reg_ip.R) file estimates discrete choice models for inpatient stays and the [outpatient](analysis/choice_reg_op.R) file estimates discrete choice models for outpatient stays. The IP/OP settings involve very different procedures (e.g., spinal surgery or appendectomy versus adenoidectomy), so we split the analysis accordingly. We then summarize the results in terms of willingness to pay for a hospital. 
    
3. [Differentiation](analysis/differentiation.R). Here, we identify entrants (as described in the text) and estimate the effects of entry of a CH (NCH) on prices among CH (NCH), and vice versa. We consider several different estimators, including that of Sun and Abraham as well as Callaway and Sant'Anna. We also consider different thresholds for identifying an entrant, with one analysis imposing [a minimum of 5 claims](analysis/differentiation_5claims.R) for a new entrant and another analysis requiring [a minimum of 10 claims](analysis/differentiation_10claims.R).

4. [Bargaining](analysis/bargaining.R). An alternative explanation for higher prices among CH versus NCH is that CH are able to negotiate higher prices for common procedures due to their near-monopoly power on other, more specialized procedures. This code file considers this alternative explanation empirically by estimate the effects of changes in competition specifically among highly specialized procedures.