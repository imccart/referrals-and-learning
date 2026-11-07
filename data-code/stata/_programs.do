******************************************************************
**	Title:		Programs shared by the data build and the analysis
**	Author:		Ian McCarthy
**	Date Created:	10/30/2026
**	Notes:		Run by the build and analysis drivers (_build-*.do, _main-*.do).
******************************************************************

** sasload: reads a SAS table from the library folder. Names are lowercased,
** SAS dates become DDMonCCYY strings (what date(x,"DMY") reads), and
** all-numeric columns are destrung. A date column with no SAS format attached
** arrives as a plain number; SAS and Stata both count days from 1 January
** 1960, so it is read as a Stata date. Such columns are recognized by name
** (*_dt, *_date, date), the CMS and project naming. A value above a million
** is a YYYYMMDD number rather than a day count.
capture program drop sasload
program define sasload
	args name
	import sas using "${DATA_SAS}`name'.sas7bdat", clear
	rename *, lower
	foreach v of varlist _all {
		capture confirm numeric variable `v'
		if _rc continue
		local f : format `v'
		local named=(substr("`v'",-3,.)=="_dt" | substr("`v'",-5,.)=="_date" | "`v'"=="date")
		if substr("`f'",1,3)!="%td" & `named'==0 continue
		qui sum `v'
		tempvar s
		if r(N)>0 & r(max)>1000000 {
			gen str9 `s'=string(date(string(`v',"%8.0f"),"YMD"),"%tdDDMonCCYY")
		}
		else {
			gen str9 `s'=string(`v',"%tdDDMonCCYY")
		}
		replace `s'="" if `v'==.
		drop `v'
		rename `s' `v'
	}
	destring _all, replace
end

** collapse_16 is what 2h_running-failures calls; it is collapse under another name.
capture program drop collapse_16
program define collapse_16
	collapse `0'
end
