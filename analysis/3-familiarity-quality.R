## Familiarity encodes quality: longer referral relationships → higher specialist quality
## Uses ReferralPairs_Full.csv (ortho, 2008-2018)
## Run from project root: source("analysis/3-familiarity-quality.R")

library(tidyverse)

pairs <- read.csv("results/csv/ReferralPairs_Full.csv")

## Count years per PCP-specialist pair (= familiarity)
pair_summary <- pairs %>%
  group_by(Practice_ID, Specialist_ID) %>%
  summarise(
    familiarity = n(),
    spec_qual = mean(spec_qual),
    .groups = "drop"
  )

## Bin familiarity
pair_summary <- pair_summary %>%
  mutate(fam_bin = case_when(
    familiarity == 1 ~ "1",
    familiarity <= 3 ~ "2-3",
    familiarity <= 5 ~ "4-5",
    TRUE ~ "6+"
  ),
  fam_bin = factor(fam_bin, levels = c("1", "2-3", "4-5", "6+")))

## Bar chart: mean spec_qual by familiarity bin
bin_stats <- pair_summary %>%
  group_by(fam_bin) %>%
  summarise(
    mean_qual = mean(spec_qual),
    se_qual = sd(spec_qual) / sqrt(n()),
    n = n(),
    .groups = "drop"
  )

p <- ggplot(bin_stats, aes(x = fam_bin, y = mean_qual)) +
  geom_col(fill = "gray60", width = 0.6) +
  geom_errorbar(aes(ymin = mean_qual - 1.96 * se_qual,
                     ymax = mean_qual + 1.96 * se_qual),
                width = 0.2) +
  coord_cartesian(ylim = c(0.88, 0.91)) +
  labs(x = "Years of Referral Relationship",
       y = "Mean Specialist Quality (Success Rate)") +
  theme_minimal()

ggsave("results/figures/Familiarity_Quality.png", p, width = 6, height = 4)
cat("Saved: results/figures/Familiarity_Quality.png\n")


## ---------------------------------------------------------------
## Per-HRR familiarity-quality correlation vs counterfactual health
## ---------------------------------------------------------------

## Specialist-to-HRR mapping (specialists can appear in multiple HRRs)
spec_fes <- read.csv("results/coeffs/myopic-timevary/StructureMyopicHRR_Spec_FEs_1_1_0_rhobar.csv") %>%
  filter(eta == 1, time_period == 1) %>%
  mutate(Specialist_ID = as.character(Specialist_ID)) %>%
  select(Specialist_ID, hrr)

## Assign HRRs to referral pairs
pairs_hrr <- pairs %>%
  mutate(Specialist_ID = as.character(Specialist_ID)) %>%
  inner_join(spec_fes, by = "Specialist_ID", relationship = "many-to-many")

## Familiarity per PCP-specialist-HRR
pair_hrr_summary <- pairs_hrr %>%
  group_by(hrr, Practice_ID, Specialist_ID) %>%
  summarise(familiarity = n(), spec_qual = mean(spec_qual), .groups = "drop")

## Per-HRR correlation
hrr_fam_qual <- pair_hrr_summary %>%
  group_by(hrr) %>%
  filter(n() >= 10) %>%
  summarise(
    corr_fam_qual = cor(familiarity, spec_qual),
    n_pairs = n(),
    .groups = "drop"
  ) %>%
  filter(!is.na(corr_fam_qual))

## Merge with counterfactual health effects
cf_full <- read.csv("results/csv/CounterFactualsSummary_full_Myopic1.csv")
cf_cur  <- read.csv("results/csv/CounterFactualsSummary_current_Myopic1.csv")

d <- hrr_fam_qual %>%
  left_join(cf_full %>% select(hrr, health_cf, pij_diff_cf, coef_m) %>%
              rename(health_full = health_cf, realloc_full = pij_diff_cf),
            by = "hrr") %>%
  left_join(cf_cur %>% select(hrr, health_cf) %>%
              rename(health_cur = health_cf),
            by = "hrr") %>%
  mutate(health_gap = health_full - health_cur)

cat(sprintf("\nHRRs: %d\n", nrow(d)))
cat(sprintf("Mean corr(fam, qual): %.4f  Pct positive: %.1f%%\n",
            mean(d$corr_fam_qual), 100 * mean(d$corr_fam_qual > 0)))
cat(sprintf("Corr with health_full: %.4f\n", cor(d$corr_fam_qual, d$health_full)))
cat(sprintf("Corr with health_gap:  %.4f\n", cor(d$corr_fam_qual, d$health_gap)))

## Figure: grouped bar chart by tercile
d <- d %>%
  mutate(fq_tercile = ntile(corr_fam_qual, 3),
         fq_label = factor(fq_tercile, levels = 1:3, labels = c("Low", "Medium", "High")))

bar_data <- d %>%
  group_by(fq_label) %>%
  summarise(
    `Keep Familiarity` = mean(health_cur) * 10000,
    `Reset Familiarity` = mean(health_full) * 10000,
    .groups = "drop"
  ) %>%
  pivot_longer(cols = c(`Keep Familiarity`, `Reset Familiarity`),
               names_to = "Counterfactual", values_to = "health") %>%
  mutate(Counterfactual = factor(Counterfactual,
                                 levels = c("Keep Familiarity", "Reset Familiarity")))

p2 <- ggplot(bar_data, aes(x = fq_label, y = health, fill = Counterfactual)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  scale_fill_manual(values = c("Keep Familiarity" = "gray40",
                                "Reset Familiarity" = "gray75")) +
  labs(x = "Quality Sorting in Observed Familiarity",
       y = "Change in Successes per 10,000",
       fill = NULL) +
  theme_minimal() +
  theme(legend.position = "bottom")
ggsave("results/figures/FamQual_vs_Health.png", p2, width = 6, height = 4)
cat("Saved: results/figures/FamQual_vs_Health.png\n")
