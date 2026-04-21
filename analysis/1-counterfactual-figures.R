## Counterfactual and structural figures from exported VRDC CSVs
## Run from project root

library(tidyverse)
library(scales)

cf_types <- c("full", "current", "fullfam", "fullnofe")
models <- c("Myopic", "FWD")
etas <- c(1, 5)


## Reallocation histograms ------------------------------------------------

for (model in models) {
  spec_dir <- paste0(tolower(model), "-timevary")
  prefix <- if (model == "Myopic") "StructureMyopic" else "StructureForward"
  hrr_size <- read.csv(file.path("results/coeffs", spec_dir, paste0(prefix, "_SummaryHRR.csv")))

  for (cf in cf_types) {
    for (eta_v in etas) {
      d <- read.csv(file.path("results/csv", paste0("CounterFactualsSummary_", cf, "_", model, eta_v, ".csv"))) %>%
        left_join(filter(hrr_size, eta == eta_v) %>% select(hrr, patients), by = "hrr") %>%
        filter(!is.na(patients))

      p <- ggplot(d, aes(x = pij_diff_cf, weight = patients)) +
        geom_histogram(aes(y = after_stat(count / sum(count))),
                       fill = "gray60", color = "white", bins = 40) +
        scale_y_continuous(labels = label_percent()) +
        scale_x_continuous(limits = c(0, 1)) +
        labs(x = "Reallocation", y = "Relative Frequency") +
        theme_minimal()
      ggsave(file.path("results/figures", spec_dir,
                       paste0("Reallocation_", cf, "_", model, "_eta", eta_v, ".png")),
             p, width = 6, height = 4)

      p <- ggplot(filter(d, coef_m > 0.001), aes(x = pij_diff_cf, weight = patients)) +
        geom_histogram(aes(y = after_stat(count / sum(count))),
                       fill = "gray60", color = "white", bins = 40) +
        scale_y_continuous(labels = label_percent()) +
        scale_x_continuous(limits = c(0, 1)) +
        labs(x = "Reallocation", y = "Relative Frequency") +
        theme_minimal()
      ggsave(file.path("results/figures", spec_dir,
                       paste0("ReallocationNC_", cf, "_", model, "_eta", eta_v, ".png")),
             p, width = 6, height = 4)
    }
  }
}


## Health-effect histograms -----------------------------------------------

for (model in models) {
  spec_dir <- paste0(tolower(model), "-timevary")
  prefix <- if (model == "Myopic") "StructureMyopic" else "StructureForward"
  hrr_size <- read.csv(file.path("results/coeffs", spec_dir, paste0(prefix, "_SummaryHRR.csv")))

  for (cf in cf_types) {
    for (eta_v in etas) {
      d <- read.csv(file.path("results/csv", paste0("CounterFactualsSummary_", cf, "_", model, eta_v, ".csv"))) %>%
        left_join(filter(hrr_size, eta == eta_v) %>% select(hrr, patients), by = "hrr") %>%
        filter(!is.na(patients), !is.na(health_cf)) %>%
        mutate(health_10k = pmax(pmin(health_cf * 10000, 100), -100))

      p <- ggplot(d, aes(x = health_10k, weight = patients)) +
        geom_histogram(aes(y = after_stat(count / sum(count))),
                       fill = "gray60", color = "white", bins = 40) +
        scale_y_continuous(labels = label_percent()) +
        labs(x = "Change in Successes per 10,000", y = "Relative Frequency") +
        theme_minimal()
      ggsave(file.path("results/figures", spec_dir,
                       paste0("Mean_Health_FX_", cf, "_", model, "_eta", eta_v, ".png")),
             p, width = 6, height = 4)

      p <- ggplot(filter(d, coef_m > 0.001), aes(x = health_10k, weight = patients)) +
        geom_histogram(aes(y = after_stat(count / sum(count))),
                       fill = "gray60", color = "white", bins = 40) +
        scale_y_continuous(labels = label_percent()) +
        labs(x = "Change in Successes per 10,000", y = "Relative Frequency") +
        theme_minimal()
      ggsave(file.path("results/figures", spec_dir,
                       paste0("Mean_Health_FXNC_", cf, "_", model, "_eta", eta_v, ".png")),
             p, width = 6, height = 4)
    }
  }
}


## Spending histograms (current and full only) ----------------------------

for (model in models) {
  spec_dir <- paste0(tolower(model), "-timevary")

  for (cf in c("current", "full")) {
    for (eta_v in etas) {
      d <- read.csv(file.path("results/csv", paste0("DistSummary_", cf, "_", model, eta_v, ".csv"))) %>%
        filter(!is.na(spend_change)) %>%
        mutate(spend_t = pmax(pmin(spend_change, 500), -500))

      p <- ggplot(d, aes(x = spend_t, weight = tot_patients)) +
        geom_histogram(aes(y = after_stat(count / sum(count))),
                       fill = "gray60", color = "white", bins = 40) +
        scale_y_continuous(labels = label_percent()) +
        scale_x_continuous(labels = label_dollar()) +
        labs(x = "Change in Mean Episode Spending", y = "Relative Frequency") +
        theme_minimal()
      ggsave(file.path("results/figures", spec_dir,
                       paste0("Mean_Spend_FX_", cf, "_", model, "_eta", eta_v, ".png")),
             p, width = 6, height = 4)
    }
  }
}


## Gradient plots: reallocation, health, spend vs alpha (alpha>0) ---------

for (model in models) {
  spec_dir <- paste0(tolower(model), "-timevary")
  prefix <- if (model == "Myopic") "StructureMyopic" else "StructureForward"
  hrr_size <- read.csv(file.path("results/coeffs", spec_dir, paste0(prefix, "_SummaryHRR.csv")))

  for (cf in cf_types) {
    for (eta_v in etas) {
      spend_path <- file.path("results/csv", paste0("DistSummary_", cf, "_", model, eta_v, ".csv"))
      spend <- if (file.exists(spend_path)) read.csv(spend_path) %>% select(hrr, spend_change)
               else tibble(hrr = integer(), spend_change = numeric())

      binned <- read.csv(file.path("results/csv", paste0("CounterFactualsSummary_", cf, "_", model, eta_v, ".csv"))) %>%
        left_join(filter(hrr_size, eta == eta_v) %>% select(hrr, patients), by = "hrr") %>%
        left_join(spend, by = "hrr") %>%
        filter(coef_m > 0.001) %>%
        mutate(alpha_bin = ntile(coef_m, 10)) %>%
        group_by(alpha_bin) %>%
        summarise(coef_m = weighted.mean(coef_m, patients, na.rm = TRUE),
                  pij_diff_cf = weighted.mean(pij_diff_cf, patients, na.rm = TRUE),
                  health_10k = weighted.mean(health_cf, patients, na.rm = TRUE) * 10000,
                  spend_change = weighted.mean(spend_change, patients, na.rm = TRUE),
                  bin_patients = sum(patients),
                  .groups = "drop")

      p <- ggplot(binned, aes(x = coef_m, y = pij_diff_cf, size = bin_patients)) +
        geom_point(color = "gray40", shape = 1) +
        labs(x = "α", y = "Reallocation") +
        theme_minimal() + theme(legend.position = "none")
      ggsave(file.path("results/figures", spec_dir,
                       paste0("Gradient_Reallocation_", cf, "_", model, "_eta", eta_v, ".png")),
             p, width = 6, height = 4)

      p <- ggplot(binned, aes(x = coef_m, y = health_10k, size = bin_patients)) +
        geom_point(color = "gray40", shape = 1) +
        labs(x = "α", y = "Change in Successes per 10,000") +
        theme_minimal() + theme(legend.position = "none")
      ggsave(file.path("results/figures", spec_dir,
                       paste0("Gradient_HealthFX_", cf, "_", model, "_eta", eta_v, ".png")),
             p, width = 6, height = 4)

      if (cf %in% c("current", "full")) {
        p <- ggplot(binned, aes(x = coef_m, y = spend_change, size = bin_patients)) +
          geom_point(color = "gray40", shape = 1) +
          scale_y_continuous(labels = label_dollar()) +
          labs(x = "α", y = "Change in Mean Episode Spending") +
          theme_minimal() + theme(legend.position = "none")
        ggsave(file.path("results/figures", spec_dir,
                         paste0("Gradient_Spend_", cf, "_", model, "_eta", eta_v, ".png")),
               p, width = 6, height = 4)
      }
    }
  }
}


## Off-diagonal percentile scatters ---------------------------------------

for (model in models) {
  spec_dir <- paste0(tolower(model), "-timevary")

  for (cf in c("current", "full")) {
    for (eta_v in etas) {
      ds <- read.csv(file.path("results/csv", paste0("DistSummary_", cf, "_", model, eta_v, ".csv")))

      for (pctl in c("p10", "p90")) {
        d2 <- tibble(base = ds[[paste0("wt_qual_base_", pctl)]],
                     cf   = ds[[paste0("wt_qual_cf_",   pctl)]]) %>%
          filter(!is.na(base), !is.na(cf), base != cf)
        lims <- range(c(d2$base, d2$cf))
        p <- ggplot(d2, aes(x = base, y = cf)) +
          geom_abline(slope = 1, intercept = 0, color = "gray50", linetype = "dashed") +
          geom_point(color = "gray30", alpha = 0.6, size = 1.2) +
          coord_fixed(xlim = lims, ylim = lims) +
          labs(x = paste0("Baseline ", toupper(pctl)),
               y = paste0("Counterfactual ", toupper(pctl))) +
          theme_minimal()
        ggsave(file.path("results/figures", spec_dir,
                         paste0("QualOffDiag_", toupper(pctl), "_", cf, "_", model, "_eta", eta_v, ".png")),
               p, width = 5, height = 5)

        d3 <- tibble(base = ds[[paste0("wt_spend_base_", pctl)]],
                     cf   = ds[[paste0("wt_spend_cf_",   pctl)]]) %>%
          filter(!is.na(base), !is.na(cf), base != cf)
        lims <- range(c(d3$base, d3$cf))
        p <- ggplot(d3, aes(x = base, y = cf)) +
          geom_abline(slope = 1, intercept = 0, color = "gray50", linetype = "dashed") +
          geom_point(color = "gray30", alpha = 0.6, size = 1.2) +
          coord_fixed(xlim = lims, ylim = lims) +
          scale_x_continuous(labels = label_dollar()) +
          scale_y_continuous(labels = label_dollar()) +
          labs(x = paste0("Baseline ", toupper(pctl)),
               y = paste0("Counterfactual ", toupper(pctl))) +
          theme_minimal()
        ggsave(file.path("results/figures", spec_dir,
                         paste0("SpendOffDiag_", toupper(pctl), "_", cf, "_", model, "_eta", eta_v, ".png")),
               p, width = 5, height = 5)
      }
    }
  }
}


## Health vs FE-quality correlation (alpha>0) -----------------------------

for (model in models) {
  spec_dir <- paste0(tolower(model), "-timevary")
  prefix <- if (model == "Myopic") "StructureMyopic" else "StructureForward"
  hrr_size <- read.csv(file.path("results/coeffs", spec_dir, paste0(prefix, "_SummaryHRR.csv")))

  for (cf in cf_types) {
    for (eta_v in etas) {
      d <- read.csv(file.path("results/csv", paste0("CounterFactualsSummary_", cf, "_", model, eta_v, ".csv"))) %>%
        left_join(filter(hrr_size, eta == eta_v) %>% select(hrr, patients), by = "hrr") %>%
        filter(coef_m > 0, !is.na(corr_fe_qual)) %>%
        mutate(health_10k = health_cf * 10000)

      p <- ggplot(d, aes(x = corr_fe_qual, y = health_10k, size = patients)) +
        geom_point(shape = 1, color = "gray40") +
        geom_smooth(method = "lm", aes(weight = patients),
                    color = "black", linewidth = 0.8, se = FALSE) +
        labs(x = "Corr(ξ, quality)", y = "Change in Successes per 10,000") +
        theme_minimal() + theme(legend.position = "none")
      ggsave(file.path("results/figures", spec_dir,
                       paste0("HealthFX_by_FEQual_", cf, "_", model, "_eta", eta_v, ".png")),
             p, width = 6, height = 4)
    }
  }
}


## Alpha and distance histograms ------------------------------------------

for (model in models) {
  spec_dir <- paste0(tolower(model), "-timevary")
  prefix <- if (model == "Myopic") "StructureMyopic" else "StructureForward"

  for (eta_v in etas) {
    d <- read.csv(file.path("results/coeffs", spec_dir, paste0(prefix, "_SummaryHRR.csv"))) %>%
      filter(eta == eta_v)

    p <- ggplot(d, aes(x = coef_m, weight = patients)) +
      geom_histogram(aes(y = after_stat(count / sum(count))),
                     fill = "gray60", color = "white", binwidth = 0.3) +
      scale_y_continuous(labels = label_percent()) +
      labs(x = "α", y = "Relative Frequency") +
      theme_minimal()
    ggsave(file.path("results/figures", spec_dir,
                     paste0("alpha_", model, "_eta", eta_v, "_rhobar_1_1_0.png")),
           p, width = 6, height = 4)

    p <- ggplot(d, aes(x = coef_dist, weight = patients)) +
      geom_histogram(aes(y = after_stat(count / sum(count))),
                     fill = "gray60", color = "white", binwidth = 0.01) +
      scale_y_continuous(labels = label_percent()) +
      labs(x = "Differential Distance", y = "Relative Frequency") +
      theme_minimal()
    ggsave(file.path("results/figures", spec_dir,
                     paste0("dist_", model, "_eta", eta_v, "_rhobar_1_1_0.png")),
           p, width = 6, height = 4)
  }
}


## QualMax (amatch) histograms --------------------------------------------

for (model in models) {
  spec_dir <- paste0(tolower(model), "-timevary")
  prefix <- if (model == "Myopic") "StructureMyopic" else "StructureForward"
  hrr_size <- read.csv(file.path("results/coeffs", spec_dir, paste0(prefix, "_SummaryHRR.csv")))

  for (eta_v in etas) {
    d <- read.csv(file.path("results/csv", paste0("CounterFactualsSummary_qualmax_amatch_", model, eta_v, ".csv"))) %>%
      select(-any_of("eta")) %>%
      left_join(filter(hrr_size, eta == eta_v) %>% select(hrr, patients), by = "hrr") %>%
      filter(!is.na(patients), !is.na(health_cf)) %>%
      mutate(health_10k = pmax(pmin(health_cf * 10000, 500), -200))

    p <- ggplot(d, aes(x = health_10k, weight = patients)) +
      geom_histogram(aes(y = after_stat(count / sum(count))),
                     fill = "gray60", color = "white", bins = 40) +
      scale_y_continuous(labels = label_percent()) +
      labs(x = "Change in Successes per 10,000", y = "Relative Frequency") +
      theme_minimal()
    ggsave(file.path("results/figures", spec_dir,
                     paste0("Mean_Health_FX_qualmax_amatch_", model, "_eta", eta_v, ".png")),
           p, width = 6, height = 4)

    p <- ggplot(d, aes(x = pij_diff_cf, weight = patients)) +
      geom_histogram(aes(y = after_stat(count / sum(count))),
                     fill = "gray60", color = "white", bins = 40) +
      scale_y_continuous(labels = label_percent()) +
      scale_x_continuous(limits = c(0, 1)) +
      labs(x = "Reallocation", y = "Relative Frequency") +
      theme_minimal()
    ggsave(file.path("results/figures", spec_dir,
                     paste0("Reallocation_qualmax_amatch_", model, "_eta", eta_v, ".png")),
           p, width = 6, height = 4)
  }
}


## Partial effect histograms ----------------------------------------------

for (model in models) {
  spec_dir <- paste0(tolower(model), "-timevary")
  prefix <- if (model == "Myopic") "StructureMyopic" else "StructureForward"
  hrr_size <- read.csv(file.path("results/coeffs", spec_dir, paste0(prefix, "_SummaryHRR.csv")))

  for (eta_v in etas) {
    d <- read.csv(file.path("results/csv", paste0("MarginalEffects_", model, eta_v, ".csv"))) %>%
      left_join(filter(hrr_size, eta == eta_v) %>% select(hrr, patients), by = "hrr") %>%
      mutate(pfx_t = pmax(pfx_mean, -0.02))

    p <- ggplot(d, aes(x = pfx_t, weight = patients)) +
      geom_histogram(aes(y = after_stat(count / sum(count))),
                     fill = "gray60", color = "white", binwidth = 0.001) +
      scale_y_continuous(labels = label_percent()) +
      labs(x = "Mean Partial Effect of One Failure", y = "Relative Frequency") +
      theme_minimal()
    ggsave(file.path("results/figures", spec_dir,
                     paste0("Mean_Partial_FX_Failure_", model, "_eta", eta_v, ".png")),
           p, width = 6, height = 4)
  }
}
