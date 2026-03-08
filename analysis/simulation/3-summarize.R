## ============================================================
## Summarize and visualize Monte Carlo results
## ============================================================

## Expects 0-setup.R already sourced via _main.R

## ============================================================
## Load results
## ============================================================

raw <- read_csv("analysis/simulation/results-raw.csv", show_col_types = FALSE)
configs <- read_csv("analysis/simulation/configs.csv", show_col_types = FALSE)

cat(sprintf("Total replications: %d\n", nrow(raw)))
cat(sprintf("Converged: %d (%.1f%%)\n",
            sum(raw$converged, na.rm = TRUE),
            100 * mean(raw$converged, na.rm = TRUE)))

## ============================================================
## Compute summary statistics
## ============================================================

summary_stats <- raw %>%
  filter(converged) %>%
  group_by(config_id, true_alpha, base_failure_rate, failure_sd, eta) %>%
  summarize(
    n_reps = n(),
    mean_alpha = mean(alpha_hat, na.rm = TRUE),
    median_alpha = median(alpha_hat, na.rm = TRUE),
    bias = mean(alpha_hat - true_alpha, na.rm = TRUE),
    rel_bias = mean((alpha_hat - true_alpha) / true_alpha, na.rm = TRUE),
    rmse = sqrt(mean((alpha_hat - true_alpha)^2, na.rm = TRUE)),
    sd_hat = sd(alpha_hat, na.rm = TRUE),
    mean_se = mean(alpha_se, na.rm = TRUE),
    coverage_95 = mean(abs(alpha_hat - true_alpha) <= 1.96 * alpha_se, na.rm = TRUE),
    reject_null = mean(alpha_hat / alpha_se > 1.96, na.rm = TRUE),
    .groups = "drop"
  )

## Labels
summary_stats <- summary_stats %>%
  mutate(
    alpha_label = factor(
      paste0("alpha = ", true_alpha),
      levels = paste0("alpha = ", sort(unique(true_alpha)))
    )
  )

write_csv(summary_stats, "analysis/simulation/results-summary.csv")

## ============================================================
## Figure 1: Bias heatmaps — one panel per alpha
## x = base failure rate, y = failure SD, fill = bias
## ============================================================

p1 <- summary_stats %>%
  ggplot(aes(x = factor(base_failure_rate), y = factor(failure_sd), fill = bias)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.2f", bias)), size = 2.5) +
  facet_wrap(~alpha_label, nrow = 1) +
  scale_fill_gradient2(low = "steelblue", mid = "white", high = "firebrick", midpoint = 0) +
  labs(
    x = "Base failure rate",
    y = "Quality dispersion (SD)",
    fill = "Bias",
    title = "Bias in estimated alpha"
  ) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("analysis/simulation/fig-bias-heatmap.png", p1, width = 14, height = 5, dpi = 150)


## ============================================================
## Figure 2: RMSE heatmaps — one panel per alpha
## ============================================================

p2 <- summary_stats %>%
  ggplot(aes(x = factor(base_failure_rate), y = factor(failure_sd), fill = rmse)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.2f", rmse)), size = 2.5) +
  facet_wrap(~alpha_label, nrow = 1) +
  scale_fill_gradient(low = "white", high = "firebrick") +
  labs(
    x = "Base failure rate",
    y = "Quality dispersion (SD)",
    fill = "RMSE",
    title = "RMSE of alpha estimates"
  ) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("analysis/simulation/fig-rmse-heatmap.png", p2, width = 14, height = 5, dpi = 150)


## ============================================================
## Figure 3: Relative bias heatmaps — one panel per alpha
## More interpretable: bias as fraction of true alpha
## ============================================================

p3 <- summary_stats %>%
  ggplot(aes(x = factor(base_failure_rate), y = factor(failure_sd), fill = rel_bias)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.0f%%", rel_bias * 100)), size = 2.5) +
  facet_wrap(~alpha_label, nrow = 1) +
  scale_fill_gradient2(low = "steelblue", mid = "white", high = "firebrick",
                       midpoint = 0, limits = c(-1, max(summary_stats$rel_bias, 5))) +
  labs(
    x = "Base failure rate",
    y = "Quality dispersion (SD)",
    fill = "Relative\nbias",
    title = "Relative bias in estimated alpha (% of true value)"
  ) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("analysis/simulation/fig-relbias-heatmap.png", p3, width = 14, height = 5, dpi = 150)


## ============================================================
## Figure 4: Coverage heatmaps
## ============================================================

p4 <- summary_stats %>%
  ggplot(aes(x = factor(base_failure_rate), y = factor(failure_sd), fill = coverage_95)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.0f%%", coverage_95 * 100)), size = 2.5) +
  facet_wrap(~alpha_label, nrow = 1) +
  scale_fill_gradient2(low = "firebrick", mid = "white", high = "steelblue",
                       midpoint = 0.95, limits = c(0.5, 1)) +
  labs(
    x = "Base failure rate",
    y = "Quality dispersion (SD)",
    fill = "Coverage",
    title = "95% CI coverage rate"
  ) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("analysis/simulation/fig-coverage-heatmap.png", p4, width = 14, height = 5, dpi = 150)


## ============================================================
## Figure 5: Power heatmaps
## ============================================================

p5 <- summary_stats %>%
  ggplot(aes(x = factor(base_failure_rate), y = factor(failure_sd), fill = reject_null)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.0f%%", reject_null * 100)), size = 2.5) +
  facet_wrap(~alpha_label, nrow = 1) +
  scale_fill_gradient(low = "white", high = "forestgreen") +
  labs(
    x = "Base failure rate",
    y = "Quality dispersion (SD)",
    fill = "Power",
    title = "Power to reject alpha = 0"
  ) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("analysis/simulation/fig-power-heatmap.png", p5, width = 14, height = 5, dpi = 150)


## ============================================================
## Figure 6: Convergence rate heatmaps
## ============================================================

conv_stats <- raw %>%
  group_by(config_id, true_alpha, base_failure_rate, failure_sd) %>%
  summarize(conv_rate = mean(converged, na.rm = TRUE), .groups = "drop") %>%
  mutate(alpha_label = factor(
    paste0("alpha = ", true_alpha),
    levels = paste0("alpha = ", sort(unique(true_alpha)))
  ))

p6 <- conv_stats %>%
  ggplot(aes(x = factor(base_failure_rate), y = factor(failure_sd), fill = conv_rate)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.0f%%", conv_rate * 100)), size = 2.5) +
  facet_wrap(~alpha_label, nrow = 1) +
  scale_fill_gradient(low = "firebrick", high = "white") +
  labs(
    x = "Base failure rate",
    y = "Quality dispersion (SD)",
    fill = "Conv.\nrate",
    title = "Fader-Pratt convergence rate"
  ) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("analysis/simulation/fig-convergence-heatmap.png", p6, width = 14, height = 5, dpi = 150)


## ============================================================
## Figure 7: Distributions for selected configs
## ============================================================

selected <- raw %>%
  filter(converged, failure_sd == 0.03,
         true_alpha %in% c(0.05, 0.20),
         base_failure_rate %in% c(0.05, 0.09, 0.20))

if (nrow(selected) > 0) {
  p7 <- selected %>%
    ggplot(aes(x = alpha_hat)) +
    geom_histogram(bins = 30, fill = "gray60", color = "white") +
    geom_vline(aes(xintercept = true_alpha), linetype = "dashed", color = "firebrick") +
    facet_grid(
      factor(paste0("alpha = ", true_alpha)) ~
      factor(paste0("failure = ", base_failure_rate * 100, "%"))
    ) +
    labs(
      x = "Estimated alpha",
      y = "Count",
      title = "Distribution of alpha estimates (SD = 0.03)"
    ) +
    theme_minimal(base_size = 11)

  ggsave("analysis/simulation/fig-alpha-distributions.png", p7, width = 10, height = 6, dpi = 150)
}


## ============================================================
## Summary table
## ============================================================

paper_table <- summary_stats %>%
  select(true_alpha, base_failure_rate, failure_sd,
         n_reps, bias, rel_bias, rmse, coverage_95, reject_null) %>%
  arrange(true_alpha, base_failure_rate, failure_sd)

write_csv(paper_table, "analysis/simulation/table-summary.csv")

cat("\nSummary table saved to analysis/simulation/table-summary.csv\n")
cat("Figures saved to analysis/simulation/fig-*.png\n")
