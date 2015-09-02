/*-------------------------------------------------------------------------------
# Name:		08_remittances
# Purpose:	Process household data and create safetey nets and migration/remittances
# Author:	Tim Essam, Ph.D.
# Created:	2014/11/25
# Modified: 2014/11/25
# Owner:	USAID GeoCenter | OakStream Systems, LLC
# License:	MIT License
# Ado(s):	tabsort, 
# Dependencies: copylables, attachlabels, 00_SetupFoldersGlobals.do
#-------------------------------------------------------------------------------
*/

clear
capture log close
log using "$pathlog/08_remittances", replace

* Load social safety net data first
use "$pathin/040_mod_u_male.dta"

* Look at which saftey net programs are widely received
tab slno if u01 == 1, mi
g byte safetyNet = u01 == 1

* Calculate total monetary value for each program (rice & wheat are taka per kg)
g int riceTotVal = u03*u04 //ac(1)
g int wheatTotVal =u05*u06 //ac(1)
egen snettmp = rsum2(u02 riceTotVal wheatTotVal u08 u07) if u01 == 1

* Calculate total saftey net value by household
egen snetValue = total(snettmp), by(a01)

* Create groups of social safety nets
g byte snetEduc = inlist(slno, 1, 2, 3, 4, 5, 6, 7) if u01 == 1
g byte snetAge  = inlist(slno, 8) if u01 == 1
g byte snetAllow = inlist(slno, 9, 10, 11, 12, 13, 14, 15, 16) if u01 == 1
g byte snetAid = inlist(slno, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, /*
*/ 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43) if u01 == 1

la var snetEduc "Education safety net"
la var snetAge "Age related safety net"
la var snetAllow "Allowance based safety net"
la var snetAid "Aid related safety net (includes food)"

foreach x of varlist snetEduc snetAge snetAllow snetAid {
	egen `x'Value = total(snettmp) if `x' == 1, by(a01)
	copydesc `x' `x'Value
	}
*end

* Collapse and copy labels
include "$pathdo2/copylabels.do"
#delimit ;
collapse (max) snetValue snetEduc snetAge snetAllow snetAid snetEducValue 
		snetAgeValue snetAllowValue snetAidValue, by(a01);
# delimit cr
include "$pathdo2/attachlabels.do"

* Save safety nets and move to migration remmitances
save "$pathout/safetynets.dta", replace

* Load migration and remittances module
use "$pathin/041_mod_v1_male.dta", clear

g byte migrationNW = v1_01 == 1
la var migrationNW "Household is part of migration network"

g byte migType = inlist(v1_02, 2) == 1
la var migType "Migrant relation to hoh is husband/wife"

g byte migAbroad = (migrationNW == 1 & v1_09 == 2)
g byte migDomestic = (migrationNW == 1 & v1_09 == 1)
la var migAbroad "Migration abroad"
la var migDomest "Migration within Bangladesh"

/* Looking at migration variables; 
 * Most migration occured in last 5 years
 * 83% of migrants are males
 * (68% of all ) Dhaka and Chittagong are most common places
 * (32% of all) Saudia Arabia & UAE are most common abroad
 * Private enterprise is most common occupation
 * 73% migrate for employment purposes
*/

* Collapse down
include "$pathdo2/copylabels.do"
collapse (max) migrationNW migAbroad migDomestic migType, by(a01)
include "$pathdo2/attachlabels.do"

* Save migration files
save "$pathout/migration.dta", replace

* Load in remittances-in data
use "$pathin/042_mod_v2_male.dta", clear

g byte remitIn = v2_01 == 1
la var remitIn "HH received remittances in"

egen totremitIn = total(v2_06), by(a01)
la var totremitIn "Total remittances received"

* Nearly all money received for this is from Hoh spouse;
egen hohremitIn = total(v2_06) if v2_02 == 2, by(a01)
la var hohremitIn "Total remittances received from hoh spouse"

egen remitInChild = total(v2_06) if v2_02 == 3, by(a01)
la var remitInChild "Total remittances received from children"

* Collapse down
include "$pathdo2/copylabels.do"
collapse (max) remitIn totremitIn hohremitIn, by(a01)
include "$pathdo2/attachlabels.do"

save "$pathout/remitIn.dta", replace

* Calculate other income sources
clear
use "$pathin/044_mod_v4_male.dta"

* Calculate total value of other income streams
clonevar landRent = v4_01
egen otherInc = rsum2(v4_01 v4_02 v4_03 v4_04 v4_05 v4_06 v4_07 v4_08 v4_09 v4_10 v4_11 v4_12 v4_13)
la var otherInc "Total value of other income"
keep a01 landRent otherInc
save "$pathout/otherInc.dta", replace

* Load in remittances out data
use "$pathin/043_mod_v3_male.dta", replace

g byte remitOut = v3_01 == 1
la var remitOut "HH sent remittances out"

egen totremitOut = total(v3_06), by(a01)
la var totremitOut "Total remittances sent out"

egen totremitChild = total(v3_06) if v3_02 == 3, by(a01)
la var totremitChild "Total remittances sent to children"

* 77% of all remittances out are sent to children

* Collapse down
include "$pathdo2/copylabels.do"
collapse (max) remitOut totremitOut totremitChild, by(a01)
include "$pathdo2/attachlabels.do"

* Stitch all remittances data together and delete extra files
merge 1:1 a01 using "$pathout/safetynets.dta", gen(snets_merge)
merge 1:1 a01 using "$pathout/migration.dta", gen(mig_merge)
merge 1:1 a01 using "$pathout/remitIn.dta", gen(remit_merge)
merge 1:1 a01 using "$pathout/otherInc.dta", gen(othInc_merge)

* No merging errors, dump variables
drop *_merge

compress
save "$pathout/remittances.dta", replace

local efiles safetynets migration remitIn otherInc
cd "$pathout"
foreach x of local efiles {
	capture findfile `x'.dta
	if _rc!=601 {
		erase "$pathout/`x'.dta"
		display in red "`x' removed from data out folder"
		}
	else disp in yellow "`x' already removed."
}
*end

log2html "$pathlog/08_remittances", replace
log close




