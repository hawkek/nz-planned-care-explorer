# Aggregates, smoothed trends, funnel limits and illustrative projections.

# ---- Aggregation with suppression -------------------------------------------

# Sum counts within groups, carrying suppression through as a range.
# Proportions use only rows where the numerator does not exceed the
# denominator (see the "Numerator is not larger than denominator" check).
aggregate_counts <- function(long, by) {
  long |>
    dplyr::mutate(valid = den_hi > 0 & num_lo <= den_hi) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
    dplyr::summarise(
      n_lo = sum(num_lo), n_hi = sum(num_hi),
      d_lo = sum(den_lo), d_hi = sum(den_hi),
      n_suppressed = sum(num_suppressed),
      rows = dplyr::n(),
      p_lo = safe_div(sum(num_lo[valid]), sum(den_hi[valid])),
      p_hi = pmin(1, safe_div(sum(num_hi[valid]), sum(den_lo[valid]))),
      p_mid = safe_div(sum((num_lo + num_hi)[valid]), sum((den_lo + den_hi)[valid])),
      .groups = "drop"
    ) |>
    dplyr::mutate(n_mid = (n_lo + n_hi) / 2, d_mid = (d_lo + d_hi) / 2)
}

safe_div <- function(a, b) ifelse(b > 0, a / b, NA_real_)

# ---- Smoothed trend ---------------------------------------------------------

# Negative binomial GAM with a smooth in time. Returns the fitted mean and a
# 95% confidence band on the response scale.
smooth_trend <- function(month, y) {
  ok <- !is.na(y)
  d <- data.frame(t = as.numeric(month[ok] - min(month[ok])) / 30.4375,
                  y = round(y[ok]))
  if (nrow(d) < 24 || all(d$y == 0)) {
    return(tibble::tibble(month = month, fit = NA_real_, lo = NA_real_, hi = NA_real_))
  }
  k <- min(20, floor(nrow(d) / 4))
  m <- mgcv::gam(y ~ s(t, k = k), family = mgcv::nb(), data = d, method = "REML")
  nd <- data.frame(t = as.numeric(month - min(month[ok])) / 30.4375)
  p <- mgcv::predict.gam(m, newdata = nd, se.fit = TRUE, type = "link")
  inv <- m$family$linkinv
  tibble::tibble(
    month = month,
    fit = as.numeric(inv(p$fit)),
    lo = as.numeric(inv(p$fit - 1.96 * p$se.fit)),
    hi = as.numeric(inv(p$fit + 1.96 * p$se.fit))
  )
}

# ---- Funnel plot ------------------------------------------------------------

# Control limits around a target with additive overdispersion
# (Spiegelhalter 2005, Statistics in Medicine 24:1185-1202).
#
#   y      observed indicator per unit (proportion or rate)
#   size   precision parameter per unit (waitlist size, or population)
#   target the national value
#   var_fn function(target, size) giving the sampling variance under the null
#
# z-scores are winsorised at the 10th and 90th centiles to estimate the
# overdispersion factor phi. If phi suggests more spread than chance,
# a between-unit variance tau^2 is added, so limits do not shrink to zero
# width for very large units.
funnel_limits <- function(y, size, target, var_fn, winsor = 0.1) {
  s2 <- var_fn(target, size)
  z <- (y - target) / sqrt(s2)
  q <- stats::quantile(z, c(winsor, 1 - winsor), na.rm = TRUE)
  zw <- pmin(pmax(z, q[1]), q[2])
  k <- sum(!is.na(z))
  phi <- sum(zw^2, na.rm = TRUE) / k
  w <- 1 / s2
  tau2 <- if (k * phi > k - 1) {
    max(0, (k * phi - (k - 1)) / (sum(w) - sum(w^2) / sum(w)))
  } else 0
  list(target = target, phi = phi, tau2 = tau2, z = z,
       se = function(n) sqrt(var_fn(target, n) + tau2))
}

var_binomial <- function(p, n) p * (1 - p) / n
var_poisson_rate <- function(r, pop) r / pop

classify_funnel <- function(y, size, lim) {
  se <- lim$se(size)
  dplyr::case_when(
    y > lim$target + 3.09 * se ~ "above 99.8% limit",
    y > lim$target + 1.96 * se ~ "above 95% limit",
    y < lim$target - 3.09 * se ~ "below 99.8% limit",
    y < lim$target - 1.96 * se ~ "below 95% limit",
    TRUE ~ "within limits"
  )
}

# Proportion of the waitlist waiting more than four months, by district,
# against waitlist size. Needs no external data.
funnel_waitlist_share <- function(district_month) {
  d <- dplyr::filter(district_month, !is.na(p_mid), d_mid > 0)
  target <- sum(d$p_mid * d$d_mid) / sum(d$d_mid)
  lim <- funnel_limits(d$p_mid, d$d_mid, target, var_binomial)
  sizes <- exp(seq(log(max(10, min(d$d_mid) * 0.8)), log(max(d$d_mid) * 1.2),
                   length.out = 120))
  list(
    points = dplyr::mutate(d, status = classify_funnel(p_mid, d_mid, lim)),
    limits = funnel_curve(sizes, lim, lower_floor = 0, upper_cap = 1),
    target = target, phi = lim$phi, tau2 = lim$tau2
  )
}

# Rate per 100,000 population, by district. Needs data/raw/population.
funnel_population_rate <- function(district_month, population) {
  d <- district_month |>
    dplyr::inner_join(population, by = "district") |>
    dplyr::mutate(rate = n_mid / population * 1e5)
  if (nrow(d) == 0) return(NULL)
  target <- sum(d$n_mid) / sum(d$population) * 1e5
  lim <- funnel_limits(d$rate, d$population / 1e5, target, var_poisson_rate)
  sizes <- exp(seq(log(min(d$population) * 0.8), log(max(d$population) * 1.2),
                   length.out = 120))
  list(
    points = dplyr::mutate(d, status = classify_funnel(rate, population / 1e5, lim)),
    limits = funnel_curve(sizes / 1e5, lim, lower_floor = 0) |>
      dplyr::mutate(size = size * 1e5),
    target = target, phi = lim$phi, tau2 = lim$tau2
  )
}

funnel_curve <- function(sizes, lim, lower_floor = -Inf, upper_cap = Inf) {
  se <- lim$se(sizes)
  tibble::tibble(
    size = sizes,
    lo95 = pmax(lower_floor, lim$target - 1.96 * se),
    hi95 = pmin(upper_cap, lim$target + 1.96 * se),
    lo998 = pmax(lower_floor, lim$target - 3.09 * se),
    hi998 = pmin(upper_cap, lim$target + 3.09 * se)
  )
}

# Optional population file: data/raw/population/district_population.csv with
# columns district, year, population. Uses the most recent year available.
read_population <- function(path = "data/raw/population/district_population.csv") {
  if (!file.exists(path)) return(NULL)
  readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::group_by(district) |>
    dplyr::filter(year == max(year)) |>
    dplyr::ungroup() |>
    dplyr::select(district, population, population_year = year)
}

# ---- Time to target ---------------------------------------------------------

# Fit a log-linear quasi-Poisson trend to the last `window` months and ask
# when the expected count would fall below one, if the trend continued.
# Shown only where the series is long and large enough, and labelled as
# illustrative. Uncertainty combines intercept and slope by simulation.
project_to_target <- function(month, y, window = 24, horizon = 60,
                              min_mean = 10, n_sim = 4000, seed = 2019) {
  ord <- order(month)
  month <- month[ord]; y <- y[ord]
  recent <- utils::tail(seq_along(month), window)
  out <- list(status = "not shown", reason = NULL, months_to_target = NULL,
              path = NULL, slope_pct = NULL)
  if (length(recent) < window || any(is.na(y[recent]))) {
    out$reason <- sprintf("fewer than %d months of data", window)
    return(out)
  }
  yy <- round(y[recent])
  if (mean(yy) < min_mean) {
    out$reason <- "too few patients for a stable trend"
    return(out)
  }
  t <- seq(-(window - 1), 0)
  m <- stats::glm(yy ~ t, family = stats::quasipoisson())
  phi <- max(1, summary(m)$dispersion)
  b <- stats::coef(m); V <- stats::vcov(m)
  ci <- b[2] + c(-1.96, 1.96) * sqrt(V[2, 2])
  out$slope_pct <- 100 * (exp(c(b[2], ci)) - 1)
  out$status <- if (ci[2] < 0) "falling" else if (ci[1] > 0) "rising" else "no clear trend"

  set.seed(seed)
  draws <- MASS::mvrnorm(n_sim, b, V)
  ahead <- seq_len(horizon)
  mu <- exp(draws[, 1] + outer(draws[, 2], ahead))
  ysim <- if (phi > 1) {
    matrix(stats::rnbinom(length(mu), mu = mu, size = mu / (phi - 1)), nrow = n_sim)
  } else {
    matrix(stats::rpois(length(mu), mu), nrow = n_sim)
  }
  months_ahead <- seq(max(month), by = "month", length.out = horizon + 1)[-1]
  out$path <- tibble::tibble(
    month = months_ahead,
    fit = exp(b[1] + b[2] * ahead),
    lo = apply(ysim, 2, stats::quantile, 0.025),
    hi = apply(ysim, 2, stats::quantile, 0.975)
  )
  out$fitted <- tibble::tibble(month = month[recent], fit = exp(b[1] + b[2] * t))

  if (out$status == "falling") {
    # Months until the expected count drops below 1: a + b * t = 0.
    tt <- ifelse(draws[, 2] < 0, -draws[, 1] / draws[, 2], Inf)
    tt <- pmax(tt, 0)
    q <- stats::quantile(tt, c(0.025, 0.5, 0.975))
    out$months_to_target <- c(lo = q[[1]], mid = -b[[1]] / b[[2]], hi = q[[3]])
  }
  out
}
