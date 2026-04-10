# VRDC Export List — April 2026

56 files total (S4 uniqueness_check.csv pending separately).
All from `${RESULTS_FINAL}` unless noted.

## CSVs (50)

HRR-level summary statistics, model coefficients, marginal effects, counterfactual predictions, and model diagnostics from a structural discrete choice model of physician referrals. All count-based cells with values ≤11 have been replaced with missing to comply with CMS cell size requirements.

- `StructureMyopicHRR_MainCoeff_1_1_0_rhobar.csv`
- `StructureForwardHRR_MainCoeff_1_1_0_rhobar.csv`
- `StructureMyopicHRR_FmlyCoeff_1_1_0_rhobar.csv`
- `StructureForwardHRR_FmlyCoeff_1_1_0_rhobar.csv`
- `StructureMyopicHRR_Spec_FEs_1_1_0_rhobar.csv`
- `StructureForwardHRR_Spec_FEs_1_1_0_rhobar.csv`
- `StructureMyopic_SummaryHRR.csv`
- `StructureForward_SummaryHRR.csv`
- `StructureMyopic_Summary.csv`
- `StructureForward_Summary.csv`
- `MarginalEffects_Myopic1.csv`
- `MarginalEffects_Myopic5.csv`
- `MarginalEffects_FWD1.csv`
- `MarginalEffects_FWD5.csv`
- `CounterFactualsSummary_full_Myopic1.csv`
- `CounterFactualsSummary_full_Myopic5.csv`
- `CounterFactualsSummary_full_FWD1.csv`
- `CounterFactualsSummary_full_FWD5.csv`
- `CounterFactualsSummary_current_Myopic1.csv`
- `CounterFactualsSummary_current_Myopic5.csv`
- `CounterFactualsSummary_current_FWD1.csv`
- `CounterFactualsSummary_current_FWD5.csv`
- `CounterFactualsSummary_fullfam_Myopic1.csv`
- `CounterFactualsSummary_fullfam_Myopic5.csv`
- `CounterFactualsSummary_fullfam_FWD1.csv`
- `CounterFactualsSummary_fullfam_FWD5.csv`
- `CounterFactualsSummary_fullnofe_Myopic1.csv`
- `CounterFactualsSummary_fullnofe_Myopic5.csv`
- `CounterFactualsSummary_fullnofe_FWD1.csv`
- `CounterFactualsSummary_fullnofe_FWD5.csv`
- `ModelDiagnostics_Myopic1.csv`
- `ModelDiagnostics_Myopic5.csv`
- `ModelDiagnostics_FWD1.csv`
- `ModelDiagnostics_FWD5.csv`
- `DiagDistance_full_Myopic1.csv`
- `DiagDistance_full_Myopic5.csv`
- `DiagDistance_full_FWD1.csv`
- `DiagDistance_full_FWD5.csv`
- `DiagDistance_current_Myopic1.csv`
- `DiagDistance_current_Myopic5.csv`
- `DiagDistance_current_FWD1.csv`
- `DiagDistance_current_FWD5.csv`
- `DiagDistance_fullfam_Myopic1.csv`
- `DiagDistance_fullfam_Myopic5.csv`
- `DiagDistance_fullfam_FWD1.csv`
- `DiagDistance_fullfam_FWD5.csv`
- `DiagDistance_fullnofe_Myopic1.csv`
- `DiagDistance_fullnofe_Myopic5.csv`
- `DiagDistance_fullnofe_FWD1.csv`
- `DiagDistance_fullnofe_FWD5.csv`

## TEX (6)

- `paper-numbers-desc.tex` (`${RESULTS_BASE}`)
- `paper-numbers-structural.tex`
- `MyopicCoefficient_Table.tex`
- `FWDCoefficient_Table.tex`
- `sum-stats-all_1_1_0.tex` (`${RESULTS_BASE}`)
- `sum-stats-pairs_1_1_0.tex` (`${RESULTS_BASE}`)

## PNGs (must export from VRDC)

Figures built from specialist- and patient-level data that cannot be exported directly. All figures display aggregated distributions or scatter plots at the HRR level or above, with no individual-level data points visible. Count-based cells with values ≤11 have been masked in the underlying data.

**O4-VRDC-figures.do** (2 types × 4 cf × 2 models × 2 etas = 32):
- `VolumeChange_{cf}_{model}_eta{eta}.png`
- `VolumeChangeNC_{cf}_{model}_eta{eta}.png`
- QualDist/SpendDist not yet on VRDC — see next steps

**O5-model-diagnostics.do** (5 types × 2 models × 2 etas = 20):
- `_est-diag-fe-quality_{model}_eta{eta}.png`
- `_est-diag-beliefs-quality_{model}_eta{eta}.png`
- `_est-diag-volume-quality_{model}_eta{eta}.png`
- `_est-diag-fit-shares_{model}_eta{eta}.png`
- `_est-diag-fit-health_{model}_eta{eta}.png`

**O1-coef-tables.do** (2 types × 2 models × 2 etas = 8):
- `Structure{Myopic/Forward}_2SLSFirstStage_eta{eta}_rhobar_1_1_0.png`
- `Structure{Myopic/Forward}_2SLSEstimate_eta{eta}_rhobar_1_1_0.png`

## Rebuilt locally from CSVs

These are created by `1-counterfactual-figures.R` using exported CSVs:
- `Reallocation_*`, `ReallocationNC_*`
- `Mean_Health_FX_*`, `Mean_Health_FXNC_*`
- `Gradient_Reallocation_*`, `Gradient_HealthFX_*`
- `HealthFX_by_FEQual_*`
- `alpha_*`, `dist_*`
- `Mean_Partial_FX_Failure_*`
- `_diag-health-vs-distqual_*`, `_diag-qualshift-vs-distshift_*` (from DiagDistance CSVs)

## Next steps

- Upload updated O4-VRDC-figures.do to VRDC and re-run O4 (adds QualDist/SpendDist figures using spec_quality_distribution from A1)
- Export QualDist/SpendDist PNGs (4 types × 4 cf × 2 models × 2 etas = 64 additional PNGs)
- Export uniqueness_check.csv when S4 completes

## Not exported

- `CounterFactualsSpec_*.csv` — specialist-level predicted counts, fails CMS cell size review
- `uniqueness_check.csv` — S4 still running, will export separately
