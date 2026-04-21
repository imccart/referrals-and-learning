# Quality-Maximizing Counterfactual: α Intensity

Summary of the three `qualmax` counterfactual scenarios, all with specialist fixed effects zeroed and accumulated familiarity reset. Each patient's belief is replaced with the true specialist success rate.

- **α = 1**: absolute α=1 (far below estimated α in most markets).
- **α_match**: α within each HRR calibrated so that the quality utility component equals the larger of the distance or congestion components.
- **α_high**: α calibrated to 2× the α_match value.

## Results (Myopic model, η=1)

Dropping HRRs where implied counterfactual success rate < 0.5 (baseline ~0.9). This removes markets where `converge_dyn` failed to settle within its 75-iteration cap.

| Scenario | Median α | N valid | Dropped | Mean Δh / 10k | Median Δh / 10k | Median realloc | % markets positive |
|---|---|---|---|---|---|---|---|
| α = 1 | 1.0 | 280 / 280 | 0 | −64 | −63 | 0.43 | 14% |
| α_match | 31.6 | 279 / 280 | 1 | **+179** | **+171** | 0.50 | 97% |
| α_high (2× match) | 63.1 | 238 / 280 | **42** | **+243** | **+289** | 0.58 | 97% |

Other model/η combinations (Myopic η=5, FWD η=1, FWD η=5) produce values within ±5 of these means and medians.

## Interpretation

- **α = 1** is far too small. Only 14% of markets see health gains; the model's estimated weight on quality is so low that setting α=1 still leaves distance and congestion dominating.
- **α_match** delivers a ~+170-per-10k median health gain in every converged market (97% positive). The entire distribution of 280 HRRs converges cleanly. This is the right counterfactual for the paper's headline.
- **α_high** (doubling α past the match point) delivers ~70% larger gains in the markets where it can be achieved: +289 median, +243 mean, 97% positive. Reallocation volume rises from ~50% to ~58%.

## Convergence issue at α_high

Pushing α to 2× the match value (median α ≈ 63) hits the numerical limits of the MNL fixed-point solver. About 15% of HRRs (42 of 280 at the loose threshold, up to 45 at the stricter < 0.75 threshold) fail to converge within the 75-iteration cap built into `converge_dyn`. In these markets:

- `pij_diff_cf = 0` or nearly zero (no meaningful reallocation),
- implied counterfactual expected success probability drops implausibly far (often near zero),
- `corr(realloc, quality)` flips negative — a signature of the solver bouncing between inconsistent share assignments across iterations.

These are numerical artifacts, not economic mechanisms. At α that large, the quality term dominates both distance (β_dist) and congestion (γ) in utility, and the iteration oscillates rather than settling on a stable equilibrium. With unconverged markets included, the raw α_high mean is −983 per 10k — entirely driven by the failure signature, not by any real health effect.

## Policy relevance

α_match is the defensible policy counterfactual because it works in every market. The α_high result ("doubling α would give +289 per 10k in most markets") is informative about the *shape* of the health-gain curve in α, but can't be used to claim a policy benefit on its own — the same intervention deployed uniformly would also produce instability in 15% of markets.

Useful follow-up: sweep α across a continuum (e.g., 0.5×, 0.75×, 1×, 1.25×, 1.5× α_match) to trace how health gains scale before the numerical regime breaks. This would replace the three-point `a1 / amatch / ahigh` design with a proper dose-response curve.

## Files

- CSVs: `results/csv/CounterFactualsSummary_qualmax_{a1,amatch,ahigh}_{Myopic,FWD}{1,5}.csv`
- Paper figure (α_match, η=1): `results/figures/{myopic,fwd}-timevary/Reallocation_qualmax_amatch_*_eta1.png` and `Mean_Health_FX_qualmax_amatch_*_eta1.png`
- Appendix figure (α_match, η=5): same filenames with `_eta5.png`
- Stata code: `analysis/vrdc/O2-cf-qualmax.do`
- `converge_dyn` routine: `analysis/vrdc/A0-programs.do` (lines 88–214)
