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

- `analysis/_main.do` - Master script, has key parameter toggles
- `data-code/_BuildReferralData.do` - Orchestrates data construction
- `papers/learning-draft.tex` - Main manuscript
- Results naming: `1_1_0` suffix = `PCP_First=1, PCP_Only=1, PCP_Practice=0`

## When Updating Results

1. New VRDC exports go to `results/_archive/YYYYMM-spec-name/`
2. Review and validate against current tracked version
3. Rename files if needed (e.g., remove "2" suffix from filenames)
4. Apply table formatting fixes (see below)
5. Copy to spec folder, commit with descriptive message
6. After pushing, pull into Overleaf to sync

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

## Known Issues
- `results/_archive/figures/lpoly_hhi.png` - deprecated, referenced in appendix but not in repo (compile error in Overleaf)
- `results/_archive/figures/MFX_HRR_1_1_0.png` - deprecated, same as above
- `\ref{fig:network-size-yearly}` in draft has no matching `\label` (renders as "??")
