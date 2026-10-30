******************************************************************
**	Title:		Programs shared by the data build and the analysis
**	Author:		Ian McCarthy
**	Date Created:	10/30/2026
**	Notes:		Run by _data-build.do and by analysis/_main.do.
******************************************************************

** sasload: read a SAS table from the library folder in the form the
** tab exports used to arrive in, so every script downstream is
** unchanged. Names are lowercased; SAS dates become the DDMonCCYY
** strings the exports carried, which date(x,"DMY") reads; and every
** column whose values are all numeric becomes numeric, as insheet did.
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
