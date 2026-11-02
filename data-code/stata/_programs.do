******************************************************************
**	Title:		Programs shared by the data build and the analysis
**	Author:		Ian McCarthy
**	Date Created:	10/30/2026
**	Notes:		Run by the build and analysis drivers (_build-*.do, _main-*.do).
******************************************************************

** sasload: reads a SAS table from the library folder. Names are lowercased,
** SAS dates become DDMonCCYY strings (what date(x,"DMY") reads), and
** all-numeric columns are destrung.
capture program drop sasload
program define sasload
	args name
	import sas using "${DATA_SAS}`name'.sas7bdat", clear
	rename *, lower
	foreach v of varlist _all {
		local f : format `v'
		if substr("`f'",1,3)=="%td" {
			tempvar s
			gen str9 `s'=string(`v',"%tdDDMonCCYY")
			replace `s'="" if `v'==.
			drop `v'
			rename `s' `v'
		}
	}
	destring _all, replace
end
