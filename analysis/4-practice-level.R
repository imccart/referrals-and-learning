## Practice-level robustness figures (PCP_Practice=1, Myopic only)
## Reads from results/coeffs/myopic-timevary-practice/
## Writes to results/figures/myopic-timevary-practice/

library(tidyverse)
library(scales)

src_dir <- "results/coeffs/myopic-timevary-practice"
out_dir <- "results/figures/myopic-timevary-practice"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

hrr_size <- read.csv(file.path(src_dir, "StructureMyopic_SummaryHRR.csv"))

cfs <- c("current", "full", "qualmax_amatch")
etas <- c(1, 5)

for (cf in cfs) {
  for (eta_v in etas) {
    d <- read.csv(file.path(src_dir, paste0("CounterFactualsSummary_", cf, "_Myopic", eta_v, ".csv"))) %>%
      select(-any_of("eta")) %>%
      left_join(filter(hrr_size, eta == eta_v) %>% select(hrr, patients), by = "hrr") %>%
      filter(!is.na(patients))

    health_lo <- if (cf == "qualmax_amatch") -200 else -100
    health_hi <- if (cf == "qualmax_amatch")  500 else  100

    d <- d %>%
      filter(!is.na(health_cf)) %>%
      mutate(health_10k = pmax(pmin(health_cf * 10000, health_hi), health_lo))

    p <- ggplot(d, aes(x = pij_diff_cf, weight = patients)) +
      geom_histogram(aes(y = after_stat(count / sum(count))),
                     fill = "gray60", color = "white", bins = 40) +
      scale_y_continuous(labels = label_percent()) +
      scale_x_continuous(limits = c(0, 1)) +
      labs(x = "Reallocation", y = "Relative Frequency") +
      theme_minimal()
    ggsave(file.path(out_dir, paste0("Reallocation_", cf, "_Myopic_eta", eta_v, ".png")),
           p, width = 6, height = 4)

    p <- ggplot(d, aes(x = health_10k, weight = patients)) +
      geom_histogram(aes(y = after_stat(count / sum(count))),
                     fill = "gray60", color = "white", bins = 40) +
      scale_y_continuous(labels = label_percent()) +
      labs(x = "Change in Successes per 10,000", y = "Relative Frequency") +
      theme_minimal()
    ggsave(file.path(out_dir, paste0("Mean_Health_FX_", cf, "_Myopic_eta", eta_v, ".png")),
           p, width = 6, height = 4)
  }
}
