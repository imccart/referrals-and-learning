## ============================================================
## Simulation functions for identification of alpha
## ============================================================

## Generate one market of simulated referral data
## Returns a data frame of patient-level referral choices
simulate_market <- function(
    n_pcp = 50,
    n_spec = 70,
    n_years = 6,
    refs_per_pcp_year = 4,
    base_failure_rate = 0.09,
    failure_sd = 0.03,
    true_alpha = 0.20,
    true_pi = -0.07,
    true_kappa = c(0, 1.1, 1.4, 1.7, 1.9, 2.0, 2.2, 2.4),
    eta = 1,
    seed = NULL
) {
  if (!is.null(seed)) set.seed(seed)

  ## Specialist qualities (true failure rates)
  ## Use truncated normal to stay in (0, 1)
  fail_rates <- pmin(pmax(rnorm(n_spec, base_failure_rate, failure_sd), 0.001), 0.999)
  success_rates <- 1 - fail_rates

  ## Specialist fixed effects (random, mean zero)
  xi <- rnorm(n_spec, 0, 0.5)

  ## Distance matrix: PCP x Specialist (in miles, roughly calibrated)
  ## Use exponential distribution shifted to have reasonable range
  distances <- matrix(rexp(n_pcp * n_spec, rate = 0.05), nrow = n_pcp, ncol = n_spec)

  ## Differential distance: distance to spec j minus min distance for that PCP
  min_dist <- apply(distances, 1, min)
  diff_dist <- distances - min_dist

  ## Prior mean (rho) = market average success rate
  rho <- mean(success_rates)

  ## Familiarity bins matching our specification
  ## bins: 0, 1, 2, 3, 4, 5, [6,7], [8,10]
  get_fmly_bin <- function(e) {
    case_when(
      e == 0 ~ 1L,
      e == 1 ~ 2L,
      e == 2 ~ 3L,
      e == 3 ~ 4L,
      e == 4 ~ 5L,
      e == 5 ~ 6L,
      e %in% 6:7 ~ 7L,
      e >= 8 ~ 8L
    )
  }

  ## Simulate referrals sequentially
  ## Track running referrals and outcomes per PCP-specialist pair
  e_mat <- matrix(0L, nrow = n_pcp, ncol = n_spec)  # running referrals
  y_mat <- matrix(0L, nrow = n_pcp, ncol = n_spec)  # running successes

  total_patients <- n_pcp * refs_per_pcp_year * n_years
  records <- vector("list", total_patients)
  rec_idx <- 0L

  for (yr in 1:n_years) {
    ## Shuffle PCP order each year
    pcp_order <- sample(1:n_pcp)
    for (pcp_pos in seq_along(pcp_order)) {
      i <- pcp_order[pcp_pos]
      n_refs <- rpois(1, refs_per_pcp_year)
      if (n_refs == 0) next

      for (ref in 1:n_refs) {
        ## Compute beliefs for each specialist
        m <- (rho * eta + y_mat[i, ]) / (eta + e_mat[i, ])

        ## Familiarity
        fmly_bin <- get_fmly_bin(e_mat[i, ])
        fmly_val <- true_kappa[fmly_bin]

        ## Utility (deterministic part)
        v <- true_alpha * m + true_pi * diff_dist[i, ] + fmly_val + xi

        ## MNL choice probabilities
        v_shifted <- v - max(v)
        exp_v <- exp(v_shifted)
        prob <- exp_v / sum(exp_v)

        ## Draw choice
        j <- sample(1:n_spec, 1, prob = prob)

        ## Draw outcome
        success <- rbinom(1, 1, success_rates[j])

        ## Record
        rec_idx <- rec_idx + 1L
        records[[rec_idx]] <- list(
          pcp = i, spec = j, year = yr,
          e_ij = e_mat[i, j], y_ij = y_mat[i, j],
          diff_dist = diff_dist[i, j],
          fmly_bin = fmly_bin,
          success = success,
          choice = 1L
        )

        ## Update running variables
        e_mat[i, j] <- e_mat[i, j] + 1L
        y_mat[i, j] <- y_mat[i, j] + success
      }
    }
  }

  ## Build choice data (chosen + non-chosen alternatives)
  records <- records[1:rec_idx]
  chosen_df <- bind_rows(records)
  chosen_df$patient <- 1:nrow(chosen_df)

  ## For each patient, build the full choice set
  choice_data <- chosen_df %>%
    rowwise() %>%
    do({
      row <- .
      i <- row$pcp
      t_idx <- row$patient

      ## Build choice set for this patient
      ## Use the e_mat and y_mat state at time of choice
      ## (approximation: use current state, which is close for sequential sim)
      tibble(
        patient = t_idx,
        pcp = i,
        spec = 1:n_spec,
        choice = as.integer(1:n_spec == row$spec),
        diff_dist = diff_dist[i, ],
        xi = xi,
        success_rate = success_rates
      )
    }) %>%
    ungroup()

  ## This rowwise approach is too slow for large datasets.
  ## Rewrite with vectorized approach.
  NULL
}


## Faster version: generate data and build estimation dataset
simulate_market_fast <- function(
    n_pcp = 50,
    n_spec = 70,
    n_years = 6,
    refs_per_pcp_year = 4,
    base_failure_rate = 0.09,
    failure_sd = 0.03,
    true_alpha = 0.20,
    true_pi = -0.07,
    true_kappa = c(0, 1.1, 1.4, 1.7, 1.9, 2.0, 2.2, 2.4),
    eta = 1,
    seed = NULL
) {
  if (!is.null(seed)) set.seed(seed)

  ## Specialist qualities
  fail_rates <- pmin(pmax(rnorm(n_spec, base_failure_rate, failure_sd), 0.001), 0.999)
  success_rates <- 1 - fail_rates

  ## Specialist FEs
  xi <- rnorm(n_spec, 0, 0.5)

  ## Distances
  distances <- matrix(rexp(n_pcp * n_spec, rate = 0.05), nrow = n_pcp, ncol = n_spec)
  min_dist <- apply(distances, 1, min)
  diff_dist <- distances - min_dist

  ## Prior
  rho <- mean(success_rates)

  ## Familiarity lookup (index 1 = e=0, index 2 = e=1, ..., index 8 = e>=8)
  kappa_lookup <- function(e) {
    idx <- pmin(e + 1L, 8L)
    idx[e >= 6 & e <= 7] <- 7L
    idx[e >= 8] <- 8L
    true_kappa[idx]
  }

  ## Running variables
  e_mat <- matrix(0L, nrow = n_pcp, ncol = n_spec)
  y_mat <- matrix(0L, nrow = n_pcp, ncol = n_spec)

  ## Pre-allocate storage for chosen specialist records
  max_records <- n_pcp * refs_per_pcp_year * n_years * 2
  rec_pcp <- integer(max_records)
  rec_spec <- integer(max_records)
  rec_year <- integer(max_records)
  rec_e <- integer(max_records)
  rec_y <- integer(max_records)
  rec_success <- integer(max_records)
  idx <- 0L

  for (yr in 1:n_years) {
    for (i in 1:n_pcp) {
      n_refs <- rpois(1, refs_per_pcp_year)
      if (n_refs == 0) next

      for (ref in 1:n_refs) {
        ## Beliefs
        m <- (rho * eta + y_mat[i, ]) / (eta + e_mat[i, ])

        ## Familiarity
        fmly_val <- kappa_lookup(e_mat[i, ])

        ## Utility
        v <- true_alpha * m + true_pi * diff_dist[i, ] + fmly_val + xi

        ## MNL probabilities
        v <- v - max(v)
        exp_v <- exp(v)
        prob <- exp_v / sum(exp_v)

        ## Choice
        j <- sample.int(n_spec, 1L, prob = prob)

        ## Outcome
        success <- rbinom(1L, 1L, success_rates[j])

        ## Store
        idx <- idx + 1L
        rec_pcp[idx] <- i
        rec_spec[idx] <- j
        rec_year[idx] <- yr
        rec_e[idx] <- e_mat[i, j]
        rec_y[idx] <- y_mat[i, j]
        rec_success[idx] <- success

        ## Update
        e_mat[i, j] <- e_mat[i, j] + 1L
        y_mat[i, j] <- y_mat[i, j] + success
      }
    }
  }

  ## Trim to actual size
  n <- idx
  chosen <- tibble(
    patient = 1:n,
    pcp = rec_pcp[1:n],
    spec_chosen = rec_spec[1:n],
    year = rec_year[1:n],
    e_chosen = rec_e[1:n],
    y_chosen = rec_y[1:n],
    success = rec_success[1:n]
  )

  ## Return list with everything needed for estimation
  list(
    chosen = chosen,
    e_mat = e_mat,
    y_mat = y_mat,
    diff_dist = diff_dist,
    xi = xi,
    success_rates = success_rates,
    fail_rates = fail_rates,
    rho = rho,
    n_pcp = n_pcp,
    n_spec = n_spec,
    params = list(
      true_alpha = true_alpha,
      true_pi = true_pi,
      true_kappa = true_kappa,
      eta = eta,
      base_failure_rate = base_failure_rate,
      failure_sd = failure_sd
    )
  )
}


## Build choice-level dataset for estimation from simulated data
## Uses a subsample of non-chosen alternatives for speed
build_choice_data <- function(sim, eta, n_alts = NULL) {
  chosen <- sim$chosen
  n_spec <- sim$n_spec
  rho <- sim$rho

  if (is.null(n_alts)) n_alts <- n_spec - 1  # full choice set

  ## For each patient, we need the state (e_ij, y_ij) at the time of choice.
  ## The simulation stored e and y for the chosen spec at time of choice.
  ## For non-chosen specs, we need to reconstruct.
  ## Approximation: rebuild e_mat and y_mat incrementally.

  n_pcp <- sim$n_pcp
  e_state <- matrix(0L, nrow = n_pcp, ncol = n_spec)
  y_state <- matrix(0L, nrow = n_pcp, ncol = n_spec)

  n_patients <- nrow(chosen)

  ## Pre-allocate (each patient has 1 chosen + n_alts non-chosen)
  rows_per_patient <- min(n_alts + 1, n_spec)
  total_rows <- n_patients * rows_per_patient

  out_patient <- integer(total_rows)
  out_spec <- integer(total_rows)
  out_choice <- integer(total_rows)
  out_m <- numeric(total_rows)
  out_dist <- numeric(total_rows)
  out_fmly <- integer(total_rows)
  out_xi <- numeric(total_rows)
  row_idx <- 0L

  kappa_bin <- function(e) {
    if (e == 0) return(1L)
    if (e <= 5) return(as.integer(e + 1L))
    if (e <= 7) return(7L)
    return(8L)
  }

  for (t in 1:n_patients) {
    i <- chosen$pcp[t]
    j_chosen <- chosen$spec_chosen[t]

    ## Non-chosen alternatives
    others <- setdiff(1:n_spec, j_chosen)
    if (length(others) > n_alts) {
      others <- sample(others, n_alts)
    }
    alts <- c(j_chosen, others)

    for (j in alts) {
      row_idx <- row_idx + 1L
      e_ij <- e_state[i, j]
      y_ij <- y_state[i, j]
      m_ij <- (rho * eta + y_ij) / (eta + e_ij)

      out_patient[row_idx] <- t
      out_spec[row_idx] <- j
      out_choice[row_idx] <- as.integer(j == j_chosen)
      out_m[row_idx] <- m_ij
      out_dist[row_idx] <- sim$diff_dist[i, j]
      out_fmly[row_idx] <- kappa_bin(e_ij)
      out_xi[row_idx] <- sim$xi[j]
    }

    ## Update state for chosen specialist
    e_state[i, j_chosen] <- e_state[i, j_chosen] + 1L
    y_state[i, j_chosen] <- y_state[i, j_chosen] + chosen$success[t]
  }

  ## Trim
  tibble(
    patient = out_patient[1:row_idx],
    spec = out_spec[1:row_idx],
    choice = out_choice[1:row_idx],
    m = out_m[1:row_idx],
    diff_dist = out_dist[1:row_idx],
    fmly_bin = out_fmly[1:row_idx],
    xi_true = out_xi[1:row_idx]
  )
}


## Estimate alpha using constrained MLE (Fader-Pratt iteration)
## Matches the Stata estimation procedure
estimate_alpha <- function(choice_data, eta, max_iter = 100, tol = 1e-6) {

  ## Create spec FE dummies (omit first spec as reference)
  specs <- sort(unique(choice_data$spec))
  n_specs <- length(specs)
  spec_map <- setNames(1:n_specs, specs)
  choice_data$spec_idx <- spec_map[as.character(choice_data$spec)]

  ## Familiarity dummies (bin 1 = e=0 is reference)
  choice_data$fmly2 <- as.integer(choice_data$fmly_bin == 2)
  choice_data$fmly3 <- as.integer(choice_data$fmly_bin == 3)
  choice_data$fmly4 <- as.integer(choice_data$fmly_bin == 4)
  choice_data$fmly5 <- as.integer(choice_data$fmly_bin == 5)
  choice_data$fmly6 <- as.integer(choice_data$fmly_bin == 6)
  choice_data$fmly7 <- as.integer(choice_data$fmly_bin == 7)
  choice_data$fmly8 <- as.integer(choice_data$fmly_bin == 8)

  ## Spec FE matrix (sparse approach: just track spec index)
  ## We'll use the conditional logit formulation

  patients <- unique(choice_data$patient)
  n_patients <- length(patients)

  ## Group data by patient for log-likelihood
  grouped <- split(choice_data, choice_data$patient)

  ## Fader-Pratt iteration for constrained alpha >= 0
  ## Start with ln(alpha) = 0, i.e., alpha = 1
  ln_alpha <- 0

  for (iter in 1:max_iter) {
    alpha_current <- exp(ln_alpha)

    ## Construct transformed belief variable: alpha_current * m
    ## Then estimate coefficient delta on this variable
    ## along with other parameters

    ## Conditional log-likelihood for MNL
    ## v_ij = delta * (alpha_current * m_ij) + pi * dist_ij + sum(kappa * fmly) + xi_j
    ## We estimate delta, pi, kappa, xi jointly

    ## Build design matrix
    X <- choice_data %>%
      mutate(
        alpha_m = alpha_current * m
      ) %>%
      select(alpha_m, diff_dist, fmly2, fmly3, fmly4, fmly5, fmly6, fmly7, fmly8)

    ## Add spec FE dummies (omit spec 1)
    fe_mat <- matrix(0L, nrow = nrow(choice_data), ncol = n_specs - 1)
    for (s in 2:n_specs) {
      fe_mat[, s - 1] <- as.integer(choice_data$spec_idx == s)
    }
    colnames(fe_mat) <- paste0("fe_", 2:n_specs)

    X_full <- cbind(as.matrix(X), fe_mat)

    ## MNL log-likelihood
    y <- choice_data$choice
    patient_ids <- choice_data$patient

    ## Estimate via maxLik
    ll_mnl <- function(beta) {
      xb <- X_full %*% beta
      ## Group by patient, compute log-sum-exp
      ll <- 0
      for (g in grouped) {
        rows <- g$patient[1]
        idx <- which(patient_ids == rows)
        xb_g <- xb[idx]
        xb_g <- xb_g - max(xb_g)
        ll <- ll + xb_g[g$choice[which(g$patient == rows)] == 1] -
          log(sum(exp(xb_g)))
      }
      ## This is too slow. Use vectorized version.
      ll
    }

    ## Vectorized log-likelihood using patient grouping
    ## Pre-compute group indices
    if (iter == 1) {
      grp_start <- integer(n_patients)
      grp_end <- integer(n_patients)
      grp_chosen <- integer(n_patients)
      sorted <- choice_data %>% arrange(patient)
      cur <- 0L
      for (p in 1:n_patients) {
        pid <- patients[p]
        idx <- which(choice_data$patient == pid)
        grp_start[p] <- idx[1]
        grp_end[p] <- idx[length(idx)]
        grp_chosen[p] <- idx[which(choice_data$choice[idx] == 1)]
      }
    }

    ll_vec <- function(beta) {
      xb <- as.numeric(X_full %*% beta)
      ll <- 0
      for (p in 1:n_patients) {
        idx <- grp_start[p]:grp_end[p]
        xb_g <- xb[idx]
        xb_g <- xb_g - max(xb_g)
        chosen_pos <- grp_chosen[p] - grp_start[p] + 1
        ll <- ll + xb_g[chosen_pos] - log(sum(exp(xb_g)))
      }
      ll
    }

    ## Initial values
    beta0 <- rep(0, ncol(X_full))
    beta0[1] <- 1  # delta starts at 1

    result <- tryCatch(
      maxLik(ll_vec, start = beta0, method = "BFGS",
             control = list(iterlim = 200, tol = 1e-8)),
      error = function(e) NULL
    )

    if (is.null(result)) {
      return(list(alpha = NA, se = NA, converged = FALSE, iter = iter))
    }

    delta_hat <- coef(result)[1]
    delta_se <- tryCatch(sqrt(vcov(result)[1, 1]), error = function(e) NA)

    ## Update
    ln_alpha_new <- ln_alpha + delta_hat - 1

    if (abs(ln_alpha_new - ln_alpha) < tol) {
      alpha_hat <- exp(ln_alpha_new)
      alpha_se <- alpha_hat * delta_se
      pi_hat <- coef(result)[2]
      return(list(
        alpha = alpha_hat,
        se = alpha_se,
        pi = pi_hat,
        converged = TRUE,
        iter = iter,
        ln_alpha = ln_alpha_new
      ))
    }

    ln_alpha <- ln_alpha_new
  }

  ## Did not converge
  alpha_hat <- exp(ln_alpha)
  list(alpha = alpha_hat, se = NA, converged = FALSE, iter = max_iter)
}


## Lighter-weight estimator: use clogit from survival package
## Much faster than hand-coded MNL
estimate_alpha_clogit <- function(choice_data, eta, max_iter = 200, tol = 1e-3) {

  if (!requireNamespace("survival", quietly = TRUE)) {
    stop("survival package required")
  }

  specs <- sort(unique(choice_data$spec))
  n_specs <- length(specs)

  ## Create spec FE dummies (omit first)
  for (s in 2:n_specs) {
    choice_data[[paste0("fe_", s)]] <- as.integer(choice_data$spec == specs[s])
  }

  ## Familiarity dummies
  for (b in 2:8) {
    choice_data[[paste0("fmly", b)]] <- as.integer(choice_data$fmly_bin == b)
  }

  ## Fader-Pratt iteration
  ln_alpha <- 0

  for (iter in 1:max_iter) {
    alpha_current <- exp(ln_alpha)
    choice_data$alpha_m <- alpha_current * choice_data$m

    ## Build formula
    fe_vars <- paste0("fe_", 2:n_specs)
    fmly_vars <- paste0("fmly", 2:8)
    rhs <- paste(c("alpha_m", "diff_dist", fmly_vars, fe_vars), collapse = " + ")
    fml <- as.formula(paste0("choice ~ ", rhs, " + strata(patient)"))

    fit <- tryCatch(
      survival::clogit(fml, data = choice_data, method = "efron"),
      error = function(e) NULL
    )

    if (is.null(fit)) {
      return(list(alpha = NA, se = NA, pi = NA, converged = FALSE, iter = iter))
    }

    delta_hat <- coef(fit)["alpha_m"]
    delta_se <- tryCatch(sqrt(vcov(fit)["alpha_m", "alpha_m"]), error = function(e) NA)

    if (is.na(delta_hat)) {
      return(list(alpha = NA, se = NA, pi = NA, converged = FALSE, iter = iter))
    }

    ln_alpha_new <- ln_alpha + delta_hat - 1

    if (is.na(ln_alpha_new) || abs(ln_alpha_new - ln_alpha) < tol) {
      alpha_hat <- exp(ln_alpha_new)
      alpha_se <- alpha_hat * delta_se
      pi_hat <- coef(fit)["diff_dist"]
      return(list(
        alpha = alpha_hat,
        se = alpha_se,
        pi = pi_hat,
        converged = TRUE,
        iter = iter
      ))
    }

    ln_alpha <- ln_alpha_new
  }

  alpha_hat <- exp(ln_alpha)
  list(alpha = alpha_hat, se = NA, pi = NA, converged = FALSE, iter = max_iter)
}


## Single replication: simulate + estimate
run_one_replication <- function(rep_id, config, eta = 1, n_alts = 30) {
  tryCatch({
    sim <- simulate_market_fast(
      n_pcp = config$n_pcp,
      n_spec = config$n_spec,
      n_years = config$n_years,
      refs_per_pcp_year = config$refs_per_pcp_year,
      base_failure_rate = config$base_failure_rate,
      failure_sd = config$failure_sd,
      true_alpha = config$true_alpha,
      true_pi = config$true_pi,
      eta = eta,
      seed = rep_id * 1000 + config$config_id
    )

    cdata <- build_choice_data(sim, eta = eta, n_alts = n_alts)
    est <- estimate_alpha_clogit(cdata, eta = eta)

    tibble(
      rep = rep_id,
      config_id = config$config_id,
      true_alpha = config$true_alpha,
      base_failure_rate = config$base_failure_rate,
      failure_sd = config$failure_sd,
      eta = eta,
      alpha_hat = est$alpha,
      alpha_se = est$se,
      pi_hat = est$pi,
      converged = est$converged,
      n_patients = nrow(sim$chosen),
      n_specs = sim$n_spec
    )
  }, error = function(e) {
    tibble(
      rep = rep_id,
      config_id = config$config_id,
      true_alpha = config$true_alpha,
      base_failure_rate = config$base_failure_rate,
      failure_sd = config$failure_sd,
      eta = eta,
      alpha_hat = NA_real_,
      alpha_se = NA_real_,
      pi_hat = NA_real_,
      converged = FALSE,
      n_patients = NA_integer_,
      n_specs = NA_integer_
    )
  })
}
