# Project: Referrals and Learning

Research on physician referrals and learning about specialist quality. Joint work with Seth Richards-Shubik (JHU).

## Quick Context

- **Question:** Do PCPs learn about specialist quality from patient outcomes and adjust referrals?
- **Application:** Major joint replacements, Medicare 2008-2018
- **Outcome:** 90-day failure (mortality, readmission, or complication)

## Results Organization

Results are organized by **specification**, not export date:

- `myopic-timevary/` - Main baseline (all markets, unestimated alpha=0)
- `fwd-timevary/` - Forward-looking model
- `*-excl_unest/` - Sensitivity: excludes markets with unestimated alpha
- `*-practice/` - Practice-level (vs physician-level)

Old VRDC exports live in `results/_archive/` (gitignored).

## Key Files

- `analysis/_main.do` - Master script, has key parameter toggles
- `data-code/_BuildReferralData.do` - Orchestrates data construction
- Results naming: `1_1_0` suffix = `PCP_First=1, PCP_Only=1, PCP_Practice=0`

## When Updating Results

1. New VRDC exports go to `results/_archive/YYYYMM-spec-name/`
2. Review and validate against current tracked version
3. Copy to spec folder, commit with descriptive message
