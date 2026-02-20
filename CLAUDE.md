# Project: Referrals and Learning

Research on physician referrals and learning about specialist quality. Joint work with Seth Richards-Shubik (JHU).

## Quick Context

- **Question:** Do PCPs learn about specialist quality from patient outcomes and adjust referrals?
- **Application:** Major joint replacements, Medicare 2008-2018
- **Outcome:** 90-day failure (mortality, readmission, or complication)

## Overleaf Integration

Project syncs with Overleaf via GitHub (new Overleaf project created from GitHub repo).
- `grants/` is gitignored (uploaded manually to Overleaf; stays Overleaf + local, not GitHub)
- LaTeX paths are from project root (e.g., `results/figures/desc/foo.png`)
- Overleaf main document: `papers/learning-draft.tex`
- Presentation images live in `presentations/images/`
- Papers live in `papers/`, presentations in `presentations/tex/`

## Results Organization

Results are organized by **specification**, not export date:

- `myopic-timevary/` - Main baseline (all markets, unestimated alpha=0)
- `fwd-timevary/` - Forward-looking model
- `*-excl_unest/` - Sensitivity: excludes markets with unestimated alpha
- `myopic-timevary-practice/` - Practice-level robustness (myopic only)

Old VRDC exports live in `results/_archive/` (gitignored).

## Key Files

- `analysis/_main.do` - Master script, has key parameter toggles + `MODEL_TYPE`, `GRAPHS_ONLY` globals
- `analysis/O2-structural-summary.do` - Consolidated structural output (replaces old O2-myopic + O3-fwdlooking)
- `data-code/_BuildReferralData.do` - Orchestrates data construction
- `papers/learning-draft.tex` - Main manuscript (uses `\input` for auto-generated number files)
- `results/tables/paper-numbers-{desc,rf,structural}.tex` - Auto-generated `\newcommand` files
- Results naming: `1_1_0` suffix = `PCP_First=1, PCP_Only=1, PCP_Practice=0`

## When Updating Results

1. New VRDC exports go to `results/_archive/YYYYMM-spec-name/`
2. Review and validate against current tracked version — visually check key graphs (e.g., reallocation histograms should have spike at 0 from alpha=0 markets)
3. **Never rename "2" suffix files in place** — "2" suffix files are from a different VRDC run and may not match the current spec. Compare against archive before promoting.
4. Apply table formatting fixes (see below)
5. Copy to spec folder, commit with descriptive message
6. After pushing, pull into Overleaf to sync

**Caution on "2" suffix files:** Stata `replace` overwrites, so "2" suffixes come from manual renaming during VRDC export, not from Stata. They indicate a re-run that may differ from the validated version. Always compare against archive figures before using.

## Table Formatting (post-export fixes)

Stata exports have known issues. Always check and fix after importing new tables:

**Typo fixes:**
- `\multoclumn` → `\multicolumn`
- `\multiclumn` → `\multicolumn`
- Missing braces: `\multicolumn{N}{c}Text` → `\multicolumn{N}{c}{Text}`

**Style rules (descriptive stats tables):**
- Use `\hline\hline` after the column header row and before the Observations row
- Use `\hline` above and below `\emph{...}` subheader rows
- Do not stack `\hline\hline` + `\hline` (if a subheader immediately follows the header, `\hline\hline` alone suffices)
- No `\midrule`, `\addlinespace`, or other booktabs commands — use `\hline` only
- Keep `\emph{...}` for subheader labels

**Style rules (coefficient/parameter tables):**
- Use `\hline\hline` after the main header row (Parameter, Mean, SD/SE, percentiles)
- Use `\\[-0.5ex]` between parameter sections (alpha, pi, rho, gamma, kappa) for spacing — no dividing lines
- For the kappa section: `\cline{2-8}` below the subheader, then `\hline\hline` below the `1, 2, 3...` range row

## Code Inventory (completed Feb 2026)

Full pipeline mapped: SAS (8 files) → data-code Stata (17 .do files) → analysis Stata (13 .do files). See memory files for detailed inventory and dependency graph.

### SAS Files (renumbered Feb 18, 2026)
1. `1_MajorJointReplacement.sas` — DRG filter + inpatient extraction
2. `2_Outcomes.sas` — complications, readmissions
3. `3_Carrier.sas` — E&M visits for PCP identification
4. `4_ReferralAssignment.sas` — carrier lookback, visit counts
5. `5_PhysicianData.sas` — specialty, TINs, NPPES (formerly 6_)
6. `6_PatientData.sas` — demographics (formerly 7_)
7. `7_CarrierReferral.sas` — rfr_physn_npi extraction (formerly 8_)
8. `8_Zip.sas` — locations (formerly 9_)
- Deleted: `2_AllProcedures.sas` (orphaned, only consumer was old 5_Outcomes), `5_Outcomes.sas` (old version of 2_Outcomes)

### Key Stata Files
- `data-code/_data-build.do` — Master data orchestrator (calls ZipHRR, R0, C0)
- `data-code/R0_BuildReferralData.do` — Referral pipeline orchestrator (calls R1-R10)
- `data-code/C0_BuildChoiceData.do` — Choice set construction (one file per HRR, years 2013-2018)
- `analysis/_main.do` — Master analysis script (calls A0-A6, O2-structural-summary x2)
- `analysis/A0-programs.do` — Defines converge, converge_dyn, run_mnl_specs programs
- `analysis/O2-structural-summary.do` — Consolidated output script parameterized by MODEL_TYPE
- Deleted: `O3-structural-fwdlooking-summary.do` (superseded by consolidated O2)
- Legacy/orphaned: O1-mnl-summary.do (not called by _main), O2-structural-myopic-summary.do (superseded), C1_BuildChoiceDataDRG.do (old naming), Assignment_Alg.do (diagnostic)

## Fixes Applied (Feb 18, 2026)

### Applied locally and in VRDC
1. **R6_Outcomes.do**: Mortality `<90` → `<=90` (align with readmission definition in 2_Outcomes.sas)
2. **R8_FailureEvents.do**: Stacked all years of fwup_visits for 5-year lookback (was only using current year). Fixed title R7→R8, updated date.
3. **R0_BuildReferralData.do ~line 200**: `pcp_phy_zip*` → `spec_phy_zip*` in first distance loop (specialist lat/long). No impact on results (estimation uses C0 distances).
4. **O2-structural-myopic-summary.do line 983**: `pred_patients0s` → `pred_patients0` (accidental trailing `s`).
5. **3_Carrier.sas**: LEFT JOIN → INNER JOIN for MajorJointPatients_Unique. (SAS EG access to RIF2007-2011 still restricted — admin issue.)
6. **All SAS files**: `IMC969SL` → `PL027710` (8 files, ~396 occurrences). Done locally and in VRDC.
7. **6_PatientData.sas** (formerly 7_): Deleted duplicate 2008 block.
8. **SAS renumbering**: 6→5, 7→6, 8→7, 9→8. Deleted orphaned 2_AllProcedures.sas and 5_Outcomes.sas.
9. **O3 eta=5**: Already fixed by Ian in VRDC. (Not touched locally this session.)

### Not bugs (confirmed Feb 18)
- **NPPES_Data.sas** missing 2016-2018: NPPES data doesn't exist after 2015; NPPES fields are never used in Stata anyway.
- **2_Outcomes.sas** ICD-9-only procedure check: Categories (Joint Infection, SS Bleeding) are identical in ICD-9 and ICD-10 procedure tables.

## Pending VRDC Changes
- SAS EG access to RIF2007-2011 still restricted (admin issue)

## Next Steps

1. ~~Code inventory & reproduction package~~ — Done (Feb 17-18).
2. ~~O2/O3 consolidation~~ — Done (Feb 20). Unified into `O2-structural-summary.do` parameterized by `MODEL_TYPE`. O3 deleted.
3. ~~A0 convergence fix~~ — Done (Feb 20). Adaptive dampening added to `converge` and `converge_dyn`. I/O optimization (fmly_effect_a merges) deferred.
4. ~~Hardcoded numbers → automated output~~ — Done (Feb 20). A1 writes `paper-numbers-desc.tex`, A2 writes `paper-numbers-rf.tex`, O2 appends to `paper-numbers-structural.tex`. Paper uses `\input` + `\newcommand` refs. Placeholder files created for local compilation. Inconsistencies resolved (event study %, capacity percentile, IQR range).
5. **Re-run in VRDC** — Next step. Upload updated A0, O2, A1, A2, _main.do. Run produces clean consistent export with new figure names (`_Myopic_`/`_FWD_`, `FX` suffix) and auto-generated number files.
6. **Analysis-only scope** — Data rebuild not planned unless SAS EG access restored.
7. **Extend to other specialties (referrals-formation repo, not here)** — Use this project's data-code pipeline as a template.

## Known Issues
- `results/_archive/figures/lpoly_hhi.png` - deprecated, referenced in appendix but not in repo (compile error in Overleaf)
- `results/_archive/figures/MFX_HRR_1_1_0.png` - deprecated, same as above
- `\ref{fig:network-size-yearly}` in draft has no matching `\label` (renders as "??")
- **myopic-timevary figures restored from archive** (Feb 20, 2026): The "2" suffix files from Jan 2026 VRDC export were incorrect (missing spike at 0, shifted distribution). Replaced with validated 202508-myopic-timevary archive. NC variants (ReallocationNC, etc.) removed — need re-export from VRDC.
- **myopic-timevary coefficients may not match figures**: Current coefficients are from Jan 2026 (like=-5001.462, 280 HRRs), while figures are from Aug 2025 archive (like=-4980.722, 200 HRRs). Next VRDC run should produce a consistent set.
- **excl_unest folder is mixed**: coefficients from Aug 2025, figures from Dec 2025 — two different VRDC exports. Needs clean re-export.

## TODO: Referral Identification Validation (post-export)

Once updated VRDC code is exported, add a validation script that checks concordance between the carrier-lookback PCP and `rfr_physn_npi` where both are available. Specifically:

1. Among ortho inpatient stays where `rfr_physn_npi` is populated AND points to a PCP (`spec_broad == 1`), compute agreement rate with the carrier-lookback PCP (most-visited physician in pre-surgery window).
2. Report concordance overall and by year (expect improvement post-Jan 2014 when CMS Phase 2 ordering/referring edits began denying claims with missing fields).
3. Examine cases of disagreement: is the lookback PCP a different PCP, or a non-PCP specialist?

This serves two purposes:
- Internal validation of the carrier-lookback method used in the referral-formation paper
- Methodological contribution: no published study has validated `rfr_physn_npi` against a gold standard or compared it to lookback-based PCP identification

Key context from literature review (Feb 2026):
- ResDAC reports ~80.8% completeness for `rfr_physn_npi` on carrier claims, but field is only required for ordered/referred services
- `rfr_physn_npi` captures ordering physicians (labs, imaging) in addition to clinical referrals
- Specialists frequently list themselves as the referring physician
- CMS Phase 2 edits (Jan 2014) improved completeness via claim denials
- No published validation study exists for this field (as of Feb 2026)

Related work: Barnett et al. (2011 HSR) validated shared-patient networks against physician self-reports (AUC 0.73). Landon et al. (2018 Applied Network Science) showed episode-based networks outperform thresholded patient sharing.

## Last Session

Date: 2026-02-20
- Implemented full plan: A0 adaptive dampening, O2/O3 consolidation, hardcoded numbers automation, paper updates
- A0: adaptive per-specialist dampening in `converge` and `converge_dyn` (track sign flips, heavier dampening for oscillators)
- O2/O3: consolidated into single `O2-structural-summary.do` parameterized by `MODEL_TYPE` global; deleted O3
- A1/A2: added scalar output sections writing `paper-numbers-desc.tex` (16 commands) and `paper-numbers-rf.tex` (3 commands); O2 appends to `paper-numbers-structural.tex`
- Paper: updated figure paths (`_Myopic_`/`_FWD_`, `Effect`→`FX`), replaced ~15 hardcoded numbers with `\newcommand` refs, fixed capacity footnote (90th→75th), added `\input` for number files
- Created placeholder .tex files in `results/tables/` for local compilation
- Next: upload updated code to VRDC and re-run for clean consistent export
