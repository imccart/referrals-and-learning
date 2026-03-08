## ============================================================
## Monte Carlo simulation: identification of alpha
## Master script — run from project root
## ============================================================

cat("=== Step 0: Setup ===\n")
source("analysis/simulation/0-setup.R")

cat("\n=== Step 1: Load functions ===\n")
source("analysis/simulation/1-functions.R")

cat("\n=== Step 2: Run simulations ===\n")
source("analysis/simulation/2-run-simulations.R")

cat("\n=== Step 3: Summarize results ===\n")
source("analysis/simulation/3-summarize.R")

cat("\n=== Done ===\n")
