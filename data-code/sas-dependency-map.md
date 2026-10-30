# SAS build: dependency map

What each live SAS program reads and writes, in run order, and how its output reaches the Stata build. Written from the code as it stands (2026-10-30), before the rewrite. Project library is `PL027710`. Every crossover to Stata is a tab-delimited export done by hand from Enterprise Guide into `data-sas/` (`${DATA_SAS}`); there is no `PROC EXPORT` anywhere in the chain.

## Run order

| Step | Program | Years | Reads (CMS source) | Reads (project tables) | Writes (`PL027710`) | Hand export → Stata reader |
|---|---|---|---|---|---|---|
| 0a | `UPIN2NPI_Data.sas` | 2007–2009 | `_UPLDS.UPIN2NPIXW` (uploaded crosswalk) | `Unique_UPIN_YYYY`, `Unique_PRVN_YYYY` (its own) | `UPIN_NPI_Merge_YYYY`, `PRVN_NPI_Merge_YYYY`, `Unique_UPIN_YYYY`, `Unique_PRVN_YYYY` | none |
| 0b | `NPPES_Data.sas` | 2007–2015 | `NPPES10`–`NPPES15.NPPES_DEC_YYYY` | none | `NPPES_YYYY` | none |
| 1 | `1_MajorJointReplacement.sas` | 2007–2018, in two macro blocks (2007–08, 2009–18) | `RIFYYYY.INPATIENT_CLAIMS_01`–`_12` | `UPIN_NPI_Merge_YYYY`, `PRVN_NPI_Merge_YYYY` (0a) | `MajorJoint_YYYY`, `MajorJointPatients_ByYear`, `MajorJointPatients_Unique` | `MAJORJOINT_YYYY.tab` → `R1_Operations.do` |
| 2 | `2_Outcomes.sas` | 2007–2018 (uses year+1 for the 90-day window) | `RIFYYYY.INPATIENT_CLAIMS_01`–`_12` | `MajorJoint_YYYY` (1); `QUALITY_ICD9_DIAGNOSIS`, `QUALITY_ICD9_PROCEDURE`, `QUALITY_ICD10_DIAGNOSIS`, `QUALITY_ICD10_PROCEDURE` (uploaded code lists, not built by any program) | `IP_Complications_YYYY`, `IP_Readmit_YYYY`, `OrthoOutcomes_YYYY` | `ORTHOOUTCOMES_YYYY.tab` → `R6_Outcomes.do` |
| 3 | `3_Carrier.sas` | 2007–2018, one copied block per year | `RIFYYYY.BCARRIER_LINE_01`–`_12`; `MD_PPAS.MDPPAS_V24_YYYY` | `MajorJointPatients_Unique` (1) | `PCPCarrier_YYYY`; **`IMC969SL.OrthoCarrier_YYYY`** (old library, see below) | `PCPCARRIER_YYYY.tab` → `R7_Saliency.do` |
| 4 | `4_ReferralAssignment.sas` | 2008–2018, one block per year, uses year−1 | none | `MajorJoint_YYYY` (1); **`PL027710.OrthoCarrier_YYYY` and `_YYYY-1`** (3) | `PreSurgery_Physicians_YYYY` | `PRESURGERY_PHYSICIANS_YYYY.tab` → `R2_Referrals.do` |
| 5 | `5_PhysicianData.sas` | 2007–2018, one block per year | `RIFYYYY.BCARRIER_LINE_01`–`_12` (2009+); `IN027710.BCARLINEK07_R6723`, `BCARLINEK08_R6723` (2007–08 carrier lines from the original request) | `MajorJoint_YYYY`, `MajorJointPatients_Unique` (1); `NPPES_YYYY` (0b); `UPIN_NPI_Merge_YYYY` (0a) | `OrthoPhysician_Data_YYYY` | `ORTHOPHYSICIAN_DATA_YYYY.tab` → `R4_Physicians.do` |
| 6 | `6_PatientData.sas` | 2007–2018, one block per year | `MBSF.MBSF_ABCD_YYYY` | `MajorJoint_YYYY` (1) | `OrthoPatient_Data_YYYY` | `ORTHOPATIENT_DATA_YYYY.tab` → `R3_Patients.do`, `R6_Outcomes.do` (year and year+1) |
| 7 | `7_CarrierReferral.sas` | 2008–2018, one block per year | `RIFYYYY.BCARRIER_CLAIMS_01`–`_12`, `BCARRIER_LINE_01`–`_12` | `MajorJoint_YYYY`, `MajorJointPatients_Unique` (1) | `ReferralsCarrier_YYYY` | `REFERRALSCARRIER_YYYY.tab` → `R2_Referrals.do` |
| 8 | `8_Zip.sas` | 2009–2018, one block per year | `RIFYYYY.BCARRIER_LINE_01`–`_12`; `MBSF.MBSF_ABCD_YYYY`; `PROVIDER.POS_YYYY` | none | `PhyLocation_YYYY`, `Hospital_Location_YYYY`, `BENE_Data_YYYY`, `PhyLocation_2018_test` | `PHYLOCATION_YYYY.tab` → `R4_Physicians.do`; `HOSPITAL_LOCATION_YYYY.tab` → `R5_Hospitals.do` (both use the 2009 file for 2008) |
| P1 | `P1-patient-cci.sas` | 2008–2018 | `RIFYYYY.INPATIENT_CLAIMS_01`–`_12` | `MajorJoint_YYYY` (1) | `PatientCCI_YYYY`, `PatientCCI_All` | `PATIENTCCI_ALL.tab` → `analysis/vrdc/R2-risk-adjustment.do` |

Also exported by hand, straight from the CMS library with no program of ours in between: `MDPPAS_V24_YYYY.tab` → `R2_Referrals.do`, `R4_Physicians.do`.

Steps 1 through 8 each depend on step 1, and the only other cross-step dependencies are 1 ← 0a, 5 ← 0a and 0b, and 4 ← 3. So after step 1, steps 2, 3, 5, 6, 7, 8, and P1 can run in any order, and 4 runs after 3.

## Stata side

`_data-build.do` is the live driver. It runs `ZipHRR.do` (reads the uploaded `ZipHsaHrr18.csv`), builds `LatLong.dta` from the uploaded `zip-latlong-nber.csv`, then runs `R0_BuildReferralData.do`, `C0_BuildChoiceData.do`, and `S1_SpecialistCapacity.do`. `R0` loops 2008–2018 over `R1_Operations`, `R2_Referrals`, `R3_Patients`, `R4_Physicians`, `R5_Hospitals`, `R6_Outcomes`, then runs `R7_Saliency`, `R8_FailureEvents`, `R9_EstablishedPCPs`, and `R10_EpisodeSpend` once. `C1_BuildChoiceDataDRG.do` is not called by the driver.

## The rewrite (2026-10-30)

The new set is `data-code/sas/`, run by `_run_all.sas`, which `%INCLUDE`s `0_config.sas` and then `upin2npi`, `nppes`, `1_major_joint`, `2_outcomes`, `3_carrier_visits`, `4_referral_assignment`, `7_referring_physicians`, `5_physician_data`, `6_patient_data`, `8_locations`, `9_patient_cci`. The old programs are in `data-code/_archive/`. Every step is one macro looping over years with `%stack_months` for the monthly carrier pulls; the SQL inside is the old SQL. Year-specific rules are in the config as macro variables and small macros (`%nppes_year`, `%mdppas_year`, `%carrier_line_source`, `%pos_cols`). Not yet run on the seat.

What changed beyond the loops, each a deliberate choice:

- Step 3 writes `MJ_OrthoCarrier_yyyy` (`&carrier_tbl`) and builds `PCPCarrier_yyyy` for every year from `&mdppas_first`, where the old program built it from a hand-edited stub.
- Step 5 applies the fullest (2012) version of the block to every year, so `OrthoPhysician_Data_yyyy` has the same columns in every year; the place-of-service zips are blank before 2009, where the request tables lack the field. The pointless left join of the whole carrier file to the patient list, and a duplicated column in that select, are gone; the wide reshapes use one macro instead of four copies.
- Step 7 drops the `CLM_ID` that only the 2009 block selected.
- Step 8 does not build `BENE_Data_yyyy` (nothing read it) or the 2018 test table.
- `nppes` builds 2007–2009 from the December 2010 file as before; `upin2npi` builds the UPIN crosswalk through 2008 and the provider-number crosswalk through 2009 as before.
- The major joint DRG list and the excluded placeholder NPIs are macro variables.
- Step 2 reads the following year's first quarter only when there is a following year. The old program read `RIF2019` for 2018, which does not exist; the `SET` failed and the rest of that iteration ran on 2017's `WORK` tables, which is why `ORTHOOUTCOMES_2018` has 22,586 rows against 55,000 to 61,000 in every other year. The 2018 outcomes in the library, and everything built from them, are wrong. In the new build, stays discharged within 90 days of 31 December 2018 have a shorter window; `R6_Outcomes.do` writes `window_days` and `window_full` (`DATA_END` in `_data-build.do`), and `R0_BuildReferralData.do` drops every stay with `window_full==0` when it assembles the panel, so the sample ends with discharges on 2 October 2018 and every stay in it has a full window.

Two more things the listing showed, not changed:

- `MAJORJOINT_2007` has 170,302 rows against 390,148 for 2008, because the DRG list covers MS-DRGs only and claims before October 2007 carry CMS-DRG codes. 2007 is not an analysis year; the gap shortens the patient list used for the carrier pulls and the lookback year behind 2008 referrals.
- The DRG list (`&mj_drg_list`) is wider than hip and knee replacement: it also has hip and femur procedures other than replacement (480–482), knee procedures other than replacement (485–489), and shoulder, elbow, and forearm procedures (483, 507–512). Narrowing it is one line in the config and a decision for the paper.

### Stata side

The build scripts moved to `data-code/stata/` (`_data-build.do`, `ZipHRR`, `R0`–`R10`, `C0`, `S1`; `C1_BuildChoiceDataDRG.do` archived, nothing called it). `_data-build.do` has the same paths and the same level loop as `analysis/_main.do`, and runs `_programs.do`, which defines `sasload`. `sasload name` does `import sas` from the library folder, lowercases the names, turns SAS dates back into the `DDMonCCYY` strings the tab exports carried (so every `date(x,"DMY")` downstream, in the build and in the analysis, is unchanged), and `destring`s every all-numeric column as `insheet` did. Each `insheet ... .tab` became `sasload <table>_yyyy`, including the two analysis scripts that read exports (`S2-pcp-assignment`, `R2-risk-adjustment`). Two reads stay on tab files in the library folder: `MDPPAS_V24_yyyy.tab`, since MD-PPAS is not in `PL027710`, and `EPISODE_yyyy.tab` (`R10`), whose origin is loose end 2. The referral-assignment switches are gone: `R0` assigns the most-visited PCP and keeps PCPs only, `R2` always restricts to MD-PPAS PCPs, and the `_1_1_0` suffix is off every file name. The dead alternative blocks (PCP at the practice level) are removed from `R0` and `C0`.

## Decisions for the rewrite

1. Stata reads the SAS tables directly with `import sas` from the library folder, `/sas/vrdc/data/dua/dua_027710/files/Users/imc969/libs`, which is visible from the Stata side. The hand exports and `data-sas/` go away. Until the rebuild runs, that folder already holds every `.tab` this project's build reads, including `HOSPITAL_LOCATION_YYYY`, so pointing `DATA_SAS` at it makes the current Stata build rerunnable from the top with no copying.
2. One library, `PL027710`, throughout. Step 3 writes its carrier table under a name that does not collide with referral-formation's `OrthoCarrier_YYYY` (see loose end 8).
3. One config program for library names, year ranges, and macros, and `%do` loops over years in place of the copied year blocks, following `physician-variation/code/data-build/sas/0_config.sas`.
4. The hospital block of `8_Zip.sas` is rerun with the rest; its `.tab` export survives in the library folder (loose end 9), so nothing has to run before the Stata side can be rerun.
5. The referral-assignment switches (`PCP_First`, `PCP_Only`, `RFR_Priority`) and the `_1_1_0` suffix are dropped on the Stata side; the live rule is written in directly. `PCP_Practice` stays.

## Hand steps the code does not record

1. Uploads to the seat: the UPIN-to-NPI crosswalk (`_UPLDS.UPIN2NPIXW`), the four `QUALITY_ICD*` code-list tables, `ZipHsaHrr18.csv`, `zip-latlong-nber.csv`.
2. The twelve tab exports in the table above plus `MDPPAS_V24_YYYY.tab`, each done per year from Enterprise Guide.
3. Export filenames are upper case in the files the live Stata scripts read; the SAS table names are mixed case.

## Breaks and loose ends

1. **Steps 3 and 4 do not connect as written.** `3_Carrier.sas` writes `IMC969SL.OrthoCarrier_YYYY` (the pre-2021 library) in every year block, and `4_ReferralAssignment.sas` reads `PL027710.OrthoCarrier_YYYY`. The `IMC969SL` library no longer exists on the seat (confirmed 2026-10-30), so step 3 cannot run at all in its current form. The rewrite writes and reads `PL027710`.
2. **`EPISODE_YYYY.tab` has no visible origin.** `R10_EpisodeSpend.do` reads it, and `2_Outcomes.sas` has a block headed "Collect Episode Inpatient Claims," but no program writes a table by that name. Whatever was exported under that name was built interactively or under another name.
3. `BENE_Data_2009`–`_2018` are written by `8_Zip.sas` and nothing in SAS or Stata reads them.
4. `PhyLocation_2018_test` in `8_Zip.sas` is a test table.
5. `1_MajorJointReplacement.sas` handles 2007–08 and 2009–18 in separate macro blocks, and `5_PhysicianData.sas` reads 2007–08 carrier lines from `IN027710.BCARLINEK07/08_R6723` rather than the RIF tables. The reason is not stated in the code.
6. Steps 3 through 8 are one copied block per year with `%LET year_data=` at the top of each, so a fix has to be made up to twelve times; `1_`, `2_`, and `P1` use `%do` loops.
7. `NPPES_Data.sas` stops at 2015 and `UPIN2NPI_Data.sas` at 2009. The 2016–2018 blocks of step 5 read `NPPES_2015`, so the last NPPES vintage is reused for the final three years.
8. **Name collision on `OrthoCarrier_YYYY`.** `physician-referral-formation` writes its ortho carrier extract to `PL027710.OrthoCarrier_YYYY` (its `&prefix.Carrier_&year` with prefix `Ortho`), the same name step 3 here writes and step 4 reads, and SAS names are case-insensitive. The `ORTHOCARRIER_2008`–`_2018` tables in the library on 2026-10-30 are referral-formation's. The rewritten step 3 writes under another name (`MJ_Carrier_YYYY` or similar) and step 4 reads that.
9. **`HOSPITAL_LOCATION_YYYY.tab` is in the SAS library folder, not in `data-sas/`.** The `Hospital_Location_YYYY` tables are no longer in `PL027710`, but the `.tab` exports exist in `/sas/vrdc/data/dua/dua_027710/files/Users/imc969/libs`, where Enterprise Guide writes exports; only some exports were then copied to `data-sas/`. `R5_Hospitals.do` reads the `data-sas/` copy, so as the code stands step R5 cannot rerun until the files are copied over, and under rewrite decision 1 Stata reads them from the library folder directly. The `Hospital_YYYY.dta` files R5 produced exist in `data/pcp-level/`, so the current build is intact either way.
