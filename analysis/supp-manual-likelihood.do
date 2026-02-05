
/* NOTES:

* Variable names:

pat is patient ID
doc is specialist ID
(no PCP ID needed here)

choice is binary indicator for the chosen specialist
 
dist is distance

pair_exp is number of past patients (past 5 years)
pair_suc is number of past successes (past 5 years)

* Scalars to be defined:

rho is (a_0) / (a_0 + b_0)
	It should be set equal to the average success rate across specialists in the market.
	For example, in the simulations I use the following code:
	quietly sum qual // (where qual is the specialists success rate)
	scalar rho = r(mean)

eta is (a_0 + b_0)
	It should be given a fixed value of 20, 10, 5, or 1
	Maybe start with 10?

*/



// SETUP (per HRR)

* Sort to put chosen specialist last for each patient:

sort pat choice doc

* Market-level success rate:

<SOME COMMANDS>

scalar rho = <SOMETHING BASED ON ABOVE COMMANDS>

* Fix value of eta:

scalar eta = 10



//  ESTIMATE PARAMETERS (with fixed value for eta)

* Define program to compute likelihood:

program define testlogit
	version 15
	args todo b lnf	
*	matrix list `b'
	* declare parameters
	tempvar theta1 alpha_hat
	mleval `theta1' = `b', eq(1)
	mleval `alpha_hat' = `b', eq(2)
	* likelihood contributions
	tempvar V eV den
	gen double `V' = `theta1' ///	
	+ `alpha_hat'*pair_suc/(eta + pair_exp) ///
	+ `alpha_hat'*rho*eta/(eta + pair_exp)
	gen double `eV' = exp(`V')
	quietly replace `eV' = 1e6 if `eV' == .
	quietly replace `eV' = 1e-6 if `eV' == 0
	by pat: gen double `den' = sum(`eV')
	* log likelihood
	mlsum `lnf' = `V' - log(`den') if choice
end

* Define ML model for Stata:

ml model d0 testlogit (dist i.doc, noconstant) /a

* Run maximization:

ml maximize, tolerance(1e-2) ltolerance(1e-5) nrtolerance(1e-4) showtolerance difficult iterate(33)
***NOTE: The options in the command above are giving looser convergence criteria
* and telling it to give up after 33 iterations.

