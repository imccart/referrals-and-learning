## ============================================================
## Run Monte Carlo simulations for alpha identification
## Grid over: base_failure_rate x failure_sd x true_alpha
## ============================================================

## ============================================================
## Parameter grid
## ============================================================

## Base failure rates: from very low signal (2%) to high signal (20%)
failure_rates <- c(0.02, 0.05, 0.09, 0.15, 0.20)

## Quality dispersion across specialists (SD of failure rates)
failure_sds <- c(0.005, 0.01, 0.02, 0.03, 0.05, 0.08)

## True alpha values — focus on small positive values
## How close to 0 can alpha be before estimation breaks down?
true_alphas <- c(0.02, 0.05, 0.10, 0.20, 0.40)

## Eta: start with just 1
etas <- c(1)

## Smaller market for tractability
market_defaults <- list(
  n_pcp = 15,
  n_spec = 20,
  n_years = 6,
  refs_per_pcp_year = 4,
  true_pi = -0.07
)

## Replications and alternatives
n_reps <- 50
n_alts <- 15

## ============================================================
## Build configuration grid
## ============================================================

configs <- expand.grid(
  base_failure_rate = failure_rates,
  failure_sd = failure_sds,
  true_alpha = true_alphas,
  eta = etas,
  stringsAsFactors = FALSE
) %>%
  as_tibble() %>%
  filter(failure_sd < base_failure_rate) %>%
  mutate(config_id = row_number())

configs <- configs %>%
  mutate(
    n_pcp = market_defaults$n_pcp,
    n_spec = market_defaults$n_spec,
    n_years = market_defaults$n_years,
    refs_per_pcp_year = market_defaults$refs_per_pcp_year,
    true_pi = market_defaults$true_pi
  )

cat(sprintf("Total configurations: %d\n", nrow(configs)))
cat(sprintf("Total replications: %d\n", nrow(configs) * n_reps))

## ============================================================
## Run simulations (sequential)
## ============================================================

results <- list()

for (i in 1:nrow(configs)) {
  cfg <- as.list(configs[i, ])
  eta_val <- cfg$eta

  cat(sprintf(
    "Config %d/%d: failure=%.2f, sd=%.2f, alpha=%.2f, eta=%d ... ",
    i, nrow(configs), cfg$base_failure_rate, cfg$failure_sd,
    cfg$true_alpha, cfg$eta
  ))

  t0 <- proc.time()

  res_list <- lapply(1:n_reps, function(r) {
    run_one_replication(r, cfg, eta = eta_val, n_alts = n_alts)
  })
  res <- bind_rows(res_list)

  elapsed <- (proc.time() - t0)[3]
  n_conv <- sum(res$converged, na.rm = TRUE)
  cat(sprintf("%d/%d converged (%.0fs)\n", n_conv, n_reps, elapsed))

  results[[i]] <- res
  gc(verbose = FALSE)

  ## Save intermediate progress
  if (i %% 5 == 0) {
    intermediate <- bind_rows(results)
    write_csv(intermediate, "analysis/simulation/results-partial.csv")
  }
}

## Combine all results
all_results <- bind_rows(results)

## ============================================================
## Save
## ============================================================

write_csv(all_results, "analysis/simulation/results-raw.csv")
write_csv(configs, "analysis/simulation/configs.csv")

cat(sprintf("\nDone. %d total replications saved.\n", nrow(all_results)))
cat(sprintf("Converged: %d (%.1f%%)\n",
            sum(all_results$converged, na.rm = TRUE),
            100 * mean(all_results$converged, na.rm = TRUE)))

## ============================================================
## Quick summary to console
## ============================================================

summary_stats <- all_results %>%
  filter(converged) %>%
  group_by(config_id, true_alpha, base_failure_rate, failure_sd, eta) %>%
  summarize(
    n_converged = n(),
    bias = mean(alpha_hat - true_alpha, na.rm = TRUE),
    rmse = sqrt(mean((alpha_hat - true_alpha)^2, na.rm = TRUE)),
    mean_se = mean(alpha_se, na.rm = TRUE),
    sd_hat = sd(alpha_hat, na.rm = TRUE),
    coverage_95 = mean(
      abs(alpha_hat - true_alpha) <= 1.96 * alpha_se,
      na.rm = TRUE
    ),
    .groups = "drop"
  )

write_csv(summary_stats, "analysis/simulation/results-summary.csv")

cat("\nSummary by failure rate and true alpha (eta=1):\n")
summary_stats %>%
  filter(eta == 1) %>%
  select(base_failure_rate, failure_sd, true_alpha, bias, rmse, coverage_95) %>%
  print(n = 50)
