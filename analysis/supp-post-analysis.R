# Meta --------------------------------------------------------------------
## Title:         Analysis of coefficients by market
## Author:        Ian McCarthy
## Date Created:  1/9/2025
## Date Edited:   1/9/2025


# Preliminaries -----------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, ggplot2, dplyr, lubridate, stringr)


# Import Data -------------------------------------------------------------

myopic.dat <- read_csv("results/coeffs/20241219-myopic-choice/StructureMyopic_SummaryHRR.csv")
fwd.dat <- read_csv("results/coeffs/20241219-fwd-choice/StructureForward_SummaryHRR.csv")


# Merge and compare -------------------------------------------------------

merge.dat <- myopic.dat %>% 
                filter(converged==1) %>%
                select(eta, hrr, alpha_myopic=coef_m, ll_myopic=log_like, spec_hhi, patients, mean_vi, tot_pcp) %>%
                inner_join(fwd.dat %>% 
                            filter(converged==1) %>% 
                            select(eta, hrr, alpha_fwd=coef_m, ll_fwd=log_like), 
                        by=c("eta","hrr"))

alpha.scatter <- ggplot(merge.dat, aes(x = alpha_myopic, y = alpha_fwd, shape = factor(eta))) +
    geom_point(size = 3) +
    scale_shape_manual(values = c(16, 21)) +  # Solid for eta=1, Hollow for eta=5
    labs(
        title = "Scatterplot of Alpha Coefficients by Model Type",
        x = "Myopic",
        y = "Forward Looking",
        shape = "Eta"
    ) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "blue") +  # 45-degree line
    theme_minimal()

ll.scatter <- ggplot(merge.dat, aes(x = ll_myopic, y = ll_fwd, shape = factor(eta))) +
    geom_point(size = 3) +
    scale_shape_manual(values = c(16, 21)) +  # Solid for eta=1, Hollow for eta=5
    labs(
        title = "Scatterplot of Log-Likelihood by Model Type",
        x = "Myopic",
        y = "Forward Looking",
        shape = "Eta"
    ) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "blue") +  # 45-degree line
    theme_minimal()

ggsave("results/figures/two-way-alpha.pdf", plot = alpha.scatter, width = 8, height = 6)
ggsave("results/figures/two-way-ll.pdf", plot = ll.scatter, width = 8, height = 6)

# Heterogeneity by Market ---------------------------------------------------

plot.dat <- merge.dat %>% filter(eta==1, spec_hhi<0.7)
het.scatter.hhi <- ggplot(plot.dat, aes(x = spec_hhi)) +
  geom_point(aes(y = alpha_myopic, size=patients), shape = 1, color = "black") +  # Hollow circles for myopic
  geom_point(aes(y = alpha_fwd, size=patients), shape = 16, color = "black") +    # Full circles for forward-looking
  geom_smooth(aes(y = alpha_myopic, weight=patients), method = "loess", color = "gray", se = FALSE, linetype = "dashed") +
  # Spline for forward-looking
  geom_smooth(aes(y = alpha_fwd, weight=patients), method = "loess", color = "gray", se = FALSE) +
  scale_size_continuous(name = "Patient Volume") +  # Add legend for circle sizes
  annotate("text", x = 0.44, y = 0.5, 
           label = "Forward-Looking", color = "black", size = 4, hjust = 0) +
  annotate("text", x = 0.5, y = 0.38, 
           label = "Myopic", color = "black", size = 4, hjust = 0) +
  labs(
    x = "Specialist Market Concentration (HHI)",
    y = "Coefficient on Patient Outcome"
  ) +
  theme_minimal() +
  theme(
    legend.position = "none",
    plot.title = element_text(size = 14, face = "bold"),
    axis.title = element_text(size = 12)
  )


het.scatter.pcps <- ggplot(plot.dat, aes(x = tot_pcp)) +
  geom_point(aes(y = alpha_myopic, size=patients), shape = 1, color = "black") +  # Hollow circles for myopic
  geom_point(aes(y = alpha_fwd, size=patients), shape = 16, color = "black") +    # Full circles for forward-looking
  geom_smooth(aes(y = alpha_myopic, weight=patients), method = "loess", color = "gray", se = FALSE, linetype = "dashed") +
  # Spline for forward-looking
  geom_smooth(aes(y = alpha_fwd, weight=patients), method = "loess", color = "gray", se = FALSE) +
  scale_size_continuous(name = "Patient Volume") +  # Add legend for circle sizes
  annotate("text", x = 1050, y = 0.25, 
           label = "Forward-Looking", color = "black", size = 4, hjust = 0) +
  annotate("text", x = 1100, y = 0.15, 
           label = "Myopic", color = "black", size = 4, hjust = 0) +
  labs(
    x = "Total Number of PCPs",
    y = "Coefficient on Patient Outcome"
  ) +
  theme_minimal() +
  theme(
    legend.position = "none",
    plot.title = element_text(size = 14, face = "bold"),
    axis.title = element_text(size = 12)
  )

ggsave("results/figures/effects-hhi.png", plot = het.scatter.hhi, width = 8, height = 6)  
ggsave("results/figures/effects-pcps.png", plot = het.scatter.pcps, width = 8, height = 6)  