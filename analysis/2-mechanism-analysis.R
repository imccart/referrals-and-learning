## Mechanism analysis: why does resetting familiarity produce negative health effects?
## Compares "current" (keep familiarity) vs "full" (reset familiarity) counterfactuals
## Run from project root: source("analysis/2-mechanism-analysis.R")

library(tidyverse)

csv_base <- "results/csv"

## ---------------------------------------------------------------
## Load data
## ---------------------------------------------------------------
cf_full <- read.csv(file.path(csv_base, "CounterFactualsSummary_full_Myopic1.csv"))
cf_cur  <- read.csv(file.path(csv_base, "CounterFactualsSummary_current_Myopic1.csv"))
diag_full <- read.csv(file.path(csv_base, "DiagDistance_full_Myopic1.csv"))
diag_cur  <- read.csv(file.path(csv_base, "DiagDistance_current_Myopic1.csv"))

## Merge into one HRR-level dataset
d <- cf_full %>%
  select(hrr, coef_m, pij_diff_cf, health_cf, corr_fe_qual, fe_sd, fe_range, qual_sd) %>%
  rename(realloc_full = pij_diff_cf, health_full = health_cf) %>%
  left_join(
    cf_cur %>% select(hrr, pij_diff_cf, health_cf) %>%
      rename(realloc_cur = pij_diff_cf, health_cur = health_cf),
    by = "hrr"
  ) %>%
  left_join(
    diag_full %>% select(hrr, qual_shift, dist_shift, corr_dist_qual) %>%
      rename(qual_shift_full = qual_shift, dist_shift_full = dist_shift),
    by = "hrr"
  ) %>%
  left_join(
    diag_cur %>% select(hrr, qual_shift, dist_shift) %>%
      rename(qual_shift_cur = qual_shift, dist_shift_cur = dist_shift),
    by = "hrr"
  ) %>%
  mutate(health_gap = health_full - health_cur)


## ---------------------------------------------------------------
## 1. Overall comparison: current vs full
## ---------------------------------------------------------------
cat("\n=== CURRENT (keep familiarity) vs FULL (reset familiarity) ===\n")
cat(sprintf("                     Current     Full\n"))
cat(sprintf("Mean health effect:  %9.6f   %9.6f\n", mean(d$health_cur), mean(d$health_full)))
cat(sprintf("Mean qual shift:     %9.7f   %9.7f\n", mean(d$qual_shift_cur), mean(d$qual_shift_full)))
cat(sprintf("Mean dist shift:     %9.4f   %9.4f\n", mean(d$dist_shift_cur), mean(d$dist_shift_full)))
cat(sprintf("Mean reallocation:   %9.4f   %9.4f\n", mean(d$realloc_cur), mean(d$realloc_full)))
cat(sprintf("Pct pos qual shift:  %9.1f%%  %9.1f%%\n",
            100 * mean(d$qual_shift_cur > 0), 100 * mean(d$qual_shift_full > 0)))
cat(sprintf("Full reallocates MORE in %d/%d markets\n",
            sum(d$realloc_full > d$realloc_cur), nrow(d)))
cat(sprintf("Full has WORSE qual shift in %d/%d markets\n",
            sum(d$qual_shift_full < d$qual_shift_cur), nrow(d)))


## ---------------------------------------------------------------
## 2. corr(FE, quality) and corr(distance, quality) distributions
## ---------------------------------------------------------------
cat("\n=== Market-level correlations ===\n")
cat(sprintf("corr(FE, quality):  mean=%.4f  median=%.4f  pct positive=%.1f%%\n",
            mean(d$corr_fe_qual, na.rm = TRUE),
            median(d$corr_fe_qual, na.rm = TRUE),
            100 * mean(d$corr_fe_qual > 0, na.rm = TRUE)))
cat(sprintf("corr(dist, quality): mean=%.4f  median=%.4f  pct positive=%.1f%%\n",
            mean(d$corr_dist_qual, na.rm = TRUE),
            median(d$corr_dist_qual, na.rm = TRUE),
            100 * mean(d$corr_dist_qual > 0, na.rm = TRUE)))


## ---------------------------------------------------------------
## 3. What predicts health_full and health_gap?
## ---------------------------------------------------------------
cat("\n=== Correlations with health_full ===\n")
vars <- c("corr_fe_qual", "corr_dist_qual", "coef_m", "qual_shift_full",
          "dist_shift_full", "realloc_full", "fe_sd")
for (v in vars) {
  r <- cor(d$health_full, d[[v]], use = "complete.obs")
  cat(sprintf("  %-20s r = %7.4f\n", v, r))
}

cat("\n=== Correlations with health_gap (full - current) ===\n")
for (v in c("corr_fe_qual", "corr_dist_qual", "coef_m")) {
  r <- cor(d$health_gap, d[[v]], use = "complete.obs")
  cat(sprintf("  %-20s r = %7.4f\n", v, r))
}


## ---------------------------------------------------------------
## 4. Reallocation terciles
## ---------------------------------------------------------------
cat("\n=== Reallocation terciles (full cf) ===\n")
d <- d %>% mutate(realloc_tercile = ntile(realloc_full, 3))
d %>%
  group_by(realloc_tercile) %>%
  summarise(
    mean_realloc = mean(realloc_full),
    mean_health = mean(health_full),
    mean_qual_shift = mean(qual_shift_full),
    mean_dist_shift = mean(dist_shift_full),
    n = n(),
    .groups = "drop"
  ) %>%
  print()


## ---------------------------------------------------------------
## 5. Alpha terciles
## ---------------------------------------------------------------
cat("\n=== Alpha terciles (full cf) ===\n")
d <- d %>% mutate(alpha_tercile = ntile(coef_m, 3))
d %>%
  group_by(alpha_tercile) %>%
  summarise(
    mean_alpha = mean(coef_m),
    mean_health_full = mean(health_full),
    mean_health_cur = mean(health_cur),
    mean_realloc = mean(realloc_full),
    mean_qual_shift = mean(qual_shift_full),
    n = n(),
    .groups = "drop"
  ) %>%
  print()


## ---------------------------------------------------------------
## 6. FE dispersion vs alpha magnitude
## ---------------------------------------------------------------
cat("\n=== FE dispersion vs quality signal ===\n")
cat(sprintf("Mean FE sd across HRRs:     %.4f\n", mean(d$fe_sd, na.rm = TRUE)))
cat(sprintf("Mean alpha (all):           %.4f\n", mean(d$coef_m)))
cat(sprintf("Mean alpha (nonzero >0.001):%.4f\n", mean(d$coef_m[d$coef_m > 0.001])))
cat(sprintf("Ratio FE_sd / alpha:        %.1fx\n",
            mean(d$fe_sd, na.rm = TRUE) / mean(d$coef_m[d$coef_m > 0.001])))


## ---------------------------------------------------------------
## 7. Split by corr(FE, quality) and corr(dist, quality)
## ---------------------------------------------------------------
cat("\n=== By corr(FE, quality) sign ===\n")
d %>%
  filter(!is.na(corr_fe_qual)) %>%
  mutate(fe_qual_pos = corr_fe_qual > 0) %>%
  group_by(fe_qual_pos) %>%
  summarise(
    n = n(),
    mean_health_full = mean(health_full),
    mean_health_cur = mean(health_cur),
    mean_qual_shift = mean(qual_shift_full),
    mean_realloc = mean(realloc_full),
    .groups = "drop"
  ) %>%
  print()

cat("\n=== By corr(dist, quality) sign ===\n")
d %>%
  mutate(dist_qual_pos = corr_dist_qual > 0) %>%
  group_by(dist_qual_pos) %>%
  summarise(
    n = n(),
    mean_health_full = mean(health_full),
    mean_health_cur = mean(health_cur),
    mean_qual_shift = mean(qual_shift_full),
    mean_dist_shift = mean(dist_shift_full),
    .groups = "drop"
  ) %>%
  print()


## ---------------------------------------------------------------
## 8. Regression: health_full on market characteristics
## ---------------------------------------------------------------
cat("\n=== OLS: health_full ~ market characteristics ===\n")
reg <- lm(health_full ~ corr_fe_qual + corr_dist_qual + coef_m + fe_sd + realloc_full,
          data = d)
print(summary(reg))
