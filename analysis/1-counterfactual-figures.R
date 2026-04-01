## Counterfactual and structural figures from exported VRDC CSVs
## Reads HRR-level summary CSVs, produces all reallocation/health/gradient figures
## Run from project root

library(tidyverse)
library(scales)

results_base <- "results"
cf_types <- c("full", "current", "fullfam", "fullnofe")
models <- c("Myopic", "FWD")
etas <- c(1, 5)

cf_labels <- c(
  full = "Full Info",
  current = "Current Info",
  fullfam = "Full Info and No Familiarity",
  fullnofe = "Full Info, No FEs"
)


## ---------------------------------------------------------------
## Helper: load CounterFactualsSummary for a given cf/model/eta
## ---------------------------------------------------------------
load_cf_summary <- function(cf, model, eta) {
  f <- file.path(results_base, "coeffs",
                 paste0(tolower(model), "-timevary"),
                 paste0("CounterFactualsSummary_", cf, "_", model, eta, ".csv"))
  if (!file.exists(f)) return(NULL)
  read.csv(f)
}


## ---------------------------------------------------------------
## Helper: load SummaryHRR for hrr_size (patients per HRR)
## ---------------------------------------------------------------
load_summary_hrr <- function(model) {
  prefix <- ifelse(model == "Myopic", "StructureMyopic", "StructureForward")
  f <- file.path(results_base, "coeffs",
                 paste0(tolower(model), "-timevary"),
                 paste0(prefix, "_SummaryHRR.csv"))
  if (!file.exists(f)) return(NULL)
  read.csv(f) %>%
    select(hrr, eta, patients)
}


## ---------------------------------------------------------------
## Helper: load MarginalEffects
## ---------------------------------------------------------------
load_marginal_effects <- function(model, eta) {
  f <- file.path(results_base, "coeffs",
                 paste0(tolower(model), "-timevary"),
                 paste0("MarginalEffects_", model, eta, ".csv"))
  if (!file.exists(f)) return(NULL)
  read.csv(f)
}


## ---------------------------------------------------------------
## Reallocation histograms
## ---------------------------------------------------------------
for (model in models) {
  hrr_size <- load_summary_hrr(model)
  if (is.null(hrr_size)) next

  for (cf in cf_types) {
    for (eta in etas) {
      d <- load_cf_summary(cf, model, eta)
      if (is.null(d)) next
      d <- d %>% left_join(hrr_size %>% filter(eta == !!eta), by = "hrr")

      spec_dir <- paste0(tolower(model), "-timevary")
      outdir <- file.path(results_base, "figures", spec_dir)

      ## all markets
      p <- ggplot(d, aes(x = pij_diff_cf, weight = patients)) +
        geom_histogram(fill = "gray60", color = "white", bins = 40) +
        scale_y_continuous(labels = label_percent()) +
        scale_x_continuous(limits = c(0, 1)) +
        labs(x = paste0("Reallocation with ", cf_labels[cf], ", eta=", eta),
             y = "Relative Frequency") +
        theme_minimal()
      ggsave(file.path(outdir, paste0("Reallocation_", cf, "_", model, "_eta", eta, ".png")),
             p, width = 6, height = 4)

      ## alpha > 0
      d_nc <- d %>% filter(coef_m > 0)
      p <- ggplot(d_nc, aes(x = pij_diff_cf, weight = patients)) +
        geom_histogram(fill = "gray60", color = "white", bins = 40) +
        scale_y_continuous(labels = label_percent()) +
        scale_x_continuous(limits = c(0, 1)) +
        labs(x = paste0("Reallocation with ", cf_labels[cf], ", eta=", eta),
             y = "Relative Frequency") +
        theme_minimal()
      ggsave(file.path(outdir, paste0("ReallocationNC_", cf, "_", model, "_eta", eta, ".png")),
             p, width = 6, height = 4)
    }
  }
}


## ---------------------------------------------------------------
## Health effect histograms
## ---------------------------------------------------------------
for (model in models) {
  hrr_size <- load_summary_hrr(model)
  if (is.null(hrr_size)) next

  for (cf in cf_types) {
    for (eta in etas) {
      d <- load_cf_summary(cf, model, eta)
      if (is.null(d)) next
      d <- d %>%
        left_join(hrr_size %>% filter(eta == !!eta), by = "hrr") %>%
        mutate(health_cf_t = pmax(pmin(health_cf, 0.01), -0.01))

      spec_dir <- paste0(tolower(model), "-timevary")
      outdir <- file.path(results_base, "figures", spec_dir)

      ## all markets
      p <- ggplot(d, aes(x = health_cf_t, weight = patients)) +
        geom_histogram(fill = "gray60", color = "white", binwidth = 0.001) +
        scale_y_continuous(labels = label_percent()) +
        labs(x = paste0("Health Effects of ", cf_labels[cf], ", eta=", eta),
             y = "Relative Frequency") +
        theme_minimal()
      ggsave(file.path(outdir, paste0("Mean_Health_FX_", cf, "_", model, "_eta", eta, ".png")),
             p, width = 6, height = 4)

      ## alpha > 0
      d_nc <- d %>% filter(coef_m > 0)
      p <- ggplot(d_nc, aes(x = health_cf_t, weight = patients)) +
        geom_histogram(fill = "gray60", color = "white", binwidth = 0.001) +
        scale_y_continuous(labels = label_percent()) +
        labs(x = paste0("Health Effects of ", cf_labels[cf], ", eta=", eta),
             y = "Relative Frequency") +
        theme_minimal()
      ggsave(file.path(outdir, paste0("Mean_Health_FXNC_", cf, "_", model, "_eta", eta, ".png")),
             p, width = 6, height = 4)
    }
  }
}


## ---------------------------------------------------------------
## Gradient plots (reallocation and health vs alpha, alpha>0)
## ---------------------------------------------------------------
for (model in models) {
  hrr_size <- load_summary_hrr(model)
  if (is.null(hrr_size)) next

  for (cf in cf_types) {
    for (eta in etas) {
      d <- load_cf_summary(cf, model, eta)
      if (is.null(d)) next
      d <- d %>%
        left_join(hrr_size %>% filter(eta == !!eta), by = "hrr") %>%
        filter(coef_m > 0)

      if (nrow(d) < 5) next

      ## bin by alpha ventiles
      d <- d %>%
        mutate(alpha_bin = ntile(coef_m, 20)) %>%
        group_by(alpha_bin) %>%
        summarise(pij_diff_cf = weighted.mean(pij_diff_cf, patients),
                  health_cf = weighted.mean(health_cf, patients),
                  coef_m = weighted.mean(coef_m, patients),
                  .groups = "drop")

      spec_dir <- paste0(tolower(model), "-timevary")
      outdir <- file.path(results_base, "figures", spec_dir)

      p <- ggplot(d, aes(x = coef_m, y = pij_diff_cf)) +
        geom_point(color = "gray40") +
        labs(x = bquote(alpha ~ ", eta=" ~ .(eta)),
             y = paste0("Reallocation with ", cf_labels[cf])) +
        theme_minimal()
      ggsave(file.path(outdir, paste0("Gradient_Reallocation_", cf, "_", model, "_eta", eta, ".png")),
             p, width = 6, height = 4)

      p <- ggplot(d, aes(x = coef_m, y = health_cf)) +
        geom_point(color = "gray40") +
        labs(x = bquote(alpha ~ ", eta=" ~ .(eta)),
             y = paste0("Health Effects of ", cf_labels[cf])) +
        theme_minimal()
      ggsave(file.path(outdir, paste0("Gradient_HealthFX_", cf, "_", model, "_eta", eta, ".png")),
             p, width = 6, height = 4)
    }
  }
}


## ---------------------------------------------------------------
## Health effects by FE-quality correlation (alpha>0)
## ---------------------------------------------------------------
for (model in models) {
  hrr_size <- load_summary_hrr(model)
  if (is.null(hrr_size)) next

  for (cf in cf_types) {
    for (eta in etas) {
      d <- load_cf_summary(cf, model, eta)
      if (is.null(d)) next
      d <- d %>%
        left_join(hrr_size %>% filter(eta == !!eta), by = "hrr") %>%
        filter(coef_m > 0, !is.na(corr_fe_qual))

      if (nrow(d) < 5) next

      spec_dir <- paste0(tolower(model), "-timevary")
      outdir <- file.path(results_base, "figures", spec_dir)

      p <- ggplot(d, aes(x = corr_fe_qual, y = health_cf, size = patients)) +
        geom_point(shape = 1, color = "gray40") +
        geom_smooth(method = "lm", aes(weight = patients),
                    color = "black", linewidth = 0.8, se = FALSE) +
        labs(x = bquote("Corr(" ~ xi ~ ", quality), eta=" ~ .(eta)),
             y = paste0("Health Effects of ", cf_labels[cf])) +
        theme_minimal() +
        theme(legend.position = "none")
      ggsave(file.path(outdir, paste0("HealthFX_by_FEQual_", cf, "_", model, "_eta", eta, ".png")),
             p, width = 6, height = 4)
    }
  }
}


## ---------------------------------------------------------------
## Alpha and distance histograms
## ---------------------------------------------------------------
for (model in models) {
  hrr_size <- load_summary_hrr(model)
  if (is.null(hrr_size)) next

  spec_dir <- paste0(tolower(model), "-timevary")
  outdir <- file.path(results_base, "figures", spec_dir)
  r_type <- "1_1_0"

  for (eta in etas) {
    d <- hrr_size %>% filter(eta == !!eta)

    ## need coef_m and coef_dist from SummaryHRR
    prefix <- ifelse(model == "Myopic", "StructureMyopic", "StructureForward")
    f <- file.path(results_base, "coeffs", spec_dir,
                   paste0(prefix, "_SummaryHRR.csv"))
    if (!file.exists(f)) next
    hrr_data <- read.csv(f) %>% filter(eta == !!eta)

    p <- ggplot(hrr_data, aes(x = coef_m, weight = patients)) +
      geom_histogram(fill = "gray60", color = "white", binwidth = 0.3) +
      labs(x = bquote("Estimates for " ~ alpha ~ " with eta=" ~ .(eta)),
           y = "Relative Frequency") +
      theme_minimal()
    ggsave(file.path(outdir, paste0("alpha_", model, "_eta", eta, "_rhobar_", r_type, ".png")),
           p, width = 6, height = 4)

    p <- ggplot(hrr_data, aes(x = coef_dist, weight = patients)) +
      geom_histogram(fill = "gray60", color = "white", binwidth = 0.01) +
      labs(x = bquote("Estimates for diff. distance with eta=" ~ .(eta)),
           y = "Relative Frequency") +
      theme_minimal()
    ggsave(file.path(outdir, paste0("dist_", model, "_eta", eta, "_rhobar_", r_type, ".png")),
           p, width = 6, height = 4)
  }
}


## ---------------------------------------------------------------
## Partial effect histograms
## ---------------------------------------------------------------
for (model in models) {
  hrr_size <- load_summary_hrr(model)
  if (is.null(hrr_size)) next

  spec_dir <- paste0(tolower(model), "-timevary")
  outdir <- file.path(results_base, "figures", spec_dir)

  for (eta in etas) {
    d <- load_marginal_effects(model, eta)
    if (is.null(d)) next
    d <- d %>%
      left_join(hrr_size %>% filter(eta == !!eta), by = "hrr") %>%
      mutate(pfx_mean_t = pmax(pfx_mean, -0.02))

    p <- ggplot(d, aes(x = pfx_mean_t, weight = patients)) +
      geom_histogram(fill = "gray60", color = "white", binwidth = 0.001) +
      labs(x = paste0("Mean Partial Effect of One Failure, eta=", eta),
           y = "Relative Frequency") +
      theme_minimal()
    ggsave(file.path(outdir, paste0("Mean_Partial_FX_Failure_", model, "_eta", eta, ".png")),
           p, width = 6, height = 4)
  }
}
