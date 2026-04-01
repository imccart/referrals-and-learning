# Results Workflow

## Overview

Results are produced in two tiers:

1. **VRDC (Stata)**: estimation, counterfactuals, specialist-level figures, diagnostics
2. **Local (R)**: HRR-level figures from exported CSVs

The VRDC produces `.dta` files internally and `.csv` files for export. CMS reviews all exports; cells <=11 are masked to missing before CSV export. CounterFactualsSpec (specialist-level) is NOT exported.

## VRDC Code (`analysis/vrdc/`)

All Stata `.do` files live here. They run on the VRDC via `_main.do`. Key globals: `MODEL_TYPE` (Myopic or FWD), `RESULTS_FINAL` (output path).

### Pipeline order (per model type)

| Script | What it does | Outputs |
|---|---|---|
| O1-coef-tables.do | Coefficient extraction, IV/2SLS, tables | SummaryHRR.csv, MainCoeff.csv, FmlyCoeff.csv, Spec_FEs.csv, Summary.csv, CoefficientTable.tex |
| O2-baseline.do | Baseline predictions (pr_j), marginal/partial effects | base_hrr files (temp), MarginalEffects.csv |
| O5-model-diagnostics.do | Model fit checks (FE-quality corr, beliefs vs quality, volume-quality, predicted vs observed) | ModelDiagnostics.csv, _est-diag-*.png |
| O2-cf-full.do | Counterfactual: full info, familiarity rebuilt from 0 | CounterFactualsSummary_full.csv, CounterFactualsSpec (dta only) |
| O2-cf-current.do | Counterfactual: full info, existing familiarity | CounterFactualsSummary_current.csv, CounterFactualsSpec (dta only) |
| O2-cf-fullfam.do | Counterfactual: full info, no familiarity | CounterFactualsSummary_fullfam.csv, CounterFactualsSpec (dta only) |
| O2-cf-fullnofe.do | Counterfactual: full info, no FEs, familiarity rebuilt from 0 | CounterFactualsSummary_fullnofe.csv, CounterFactualsSpec (dta only) |
| O4-VRDC-figures.do | Volume change histograms (specialist-level, must stay on VRDC) | VolumeChange*.png, VolumeChangeNC*.png |

Run once after both model types complete:

| Script | What it does | Outputs |
|---|---|---|
| O3-paper-numbers.do | Generates \newcommand files for paper | paper-numbers-structural.tex |

### Key dependencies

- cf scripts require **base_hrr files** from O2-baseline (not cleaned until next baseline run)
- cf scripts require **fmly_effect_a.dta** (recreated inside each cf script's eta loop)
- O4-VRDC-figures requires **CounterFactualsSpec** .dta files from cf scripts
- O3-paper-numbers requires **CounterFactualsSummary** .dta files from cf scripts
- O5-model-diagnostics only requires **base_hrr files** (run anytime after baseline)

### Running individual counterfactuals

Each cf script is independent. To add or rerun one counterfactual:
1. Ensure base_hrr files exist (from a prior baseline run for that model type)
2. Upload the cf script
3. Set MODEL_TYPE and run

**Warning**: O2-baseline.do erases all base_hrr files at startup. Running baseline for FWD deletes Myopic base_hrr files. Run O5-model-diagnostics before switching model types.

## CSV Exports from VRDC

All CSVs land in `results/coeffs/{model}-timevary/` locally.

| CSV | Level | Used by | Cell masking |
|---|---|---|---|
| SummaryHRR | HRR | Alpha/dist histograms, partial effects | tot_spec, tot_pcp, spec_total, pcp_total |
| Summary | Overall | Paper numbers | None needed |
| MainCoeff | HRR | (coefficients) | None needed |
| FmlyCoeff | HRR × fmly_level | (coefficients) | None needed |
| Spec_FEs | Specialist | (coefficients) | None needed |
| MarginalEffects | HRR | Partial effect histograms | mfx_count, pfx_count |
| CounterFactualsSummary_{cf} | HRR | Reallocation, health, gradients, FE-qual | n_specs, n_cases |
| ModelDiagnostics | HRR | Seth's diagnostic checks | n_specs |

**NOT exported**: CounterFactualsSpec (specialist-level predicted counts fail cell size review)

## Local R Scripts (`analysis/`)

| Script | What it does | Input CSVs |
|---|---|---|
| 1-counterfactual-figures.R | All HRR-level figures (reallocation, health effects, gradients, FE-qual scatters, alpha/dist histograms, partial effects) | SummaryHRR, CounterFactualsSummary_{cf}, MarginalEffects |

Figures are saved to `results/figures/{model}-timevary/`, overwriting VRDC-generated versions.

## What can only be done on VRDC

- Volume change figures (specialist-level data)
- Model diagnostics graphs (base_hrr patient-level data)
- Anything requiring individual patient or specialist identifiers
- Paper numbers (loads .dta files directly)

## What can be done locally

- All reallocation histograms (all markets + NC)
- All health effect histograms (all markets + NC)
- Gradient plots (reallocation/health vs alpha)
- HealthFX by FE-quality correlation scatters
- Alpha and distance histograms
- Partial effect histograms

## Updating results

1. Run code on VRDC
2. Request CSV export (no PNGs needed except volume change and diagnostics)
3. Download CSVs to `results/coeffs/{model}-timevary/`
4. Run `analysis/1-counterfactual-figures.R` locally
5. Figures appear in `results/figures/{model}-timevary/`
6. Archive to `results/_archive/YYYYMM-{model}-timevary/`
7. Commit and push
