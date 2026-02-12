# Project: Referrals and Learning

Research on physician referrals and learning about specialist quality. Joint work with Seth Richards-Shubik (JHU).

## Quick Context

- **Question:** Do PCPs learn about specialist quality from patient outcomes and adjust referrals?
- **Application:** Major joint replacements, Medicare 2008-2018
- **Outcome:** 90-day failure (mortality, readmission, or complication)

## Overleaf Integration

Project syncs with Overleaf via GitHub. Key points:
- `grants/` is gitignored (stays in Overleaf + local, not GitHub)
- LaTeX paths are from project root (e.g., `results/figures/desc/foo.png`)
- Presentation images live in `presentations/images/`
- Papers live in `papers/`, presentations in `presentations/tex/`
- **Status**: GitHub ready; pull into Overleaf after fwd-timevary results added

## Results Organization

Results are organized by **specification**, not export date:

- `myopic-timevary/` - Main baseline (all markets, unestimated alpha=0)
- `fwd-timevary/` - Forward-looking model (placeholder, results coming)
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
4. Copy to spec folder, commit with descriptive message
5. After pushing, pull into Overleaf to sync

## Known Missing Figures (will fail in Overleaf)
- `results/_archive/figures/lpoly_hhi.png` - deprecated, not in repo
- `results/_archive/figures/MFX_HRR_1_1_0.png` - deprecated, not in repo
- `results/figures/fwd-timevary/*` - placeholder until new results arrive
