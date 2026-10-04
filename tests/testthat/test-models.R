test_that("suppressed cells widen totals into a range", {
  d <- make_long(districts = c("Auckland", "Waikato"), months = as.Date("2025-01-01"))
  d$num_lo[2] <- 1; d$num_hi[2] <- 4; d$num_suppressed[2] <- TRUE
  a <- aggregate_counts(d, c("indicator", "month"))
  expect_equal(c(a$n_lo, a$n_hi), c(11, 14))
  expect_equal(a$n_suppressed, 1)
  expect_equal(a$p_lo, 11 / 200)
  expect_equal(a$p_hi, 14 / 200)
})

test_that("rows with numerator above denominator stay in counts but not shares", {
  d <- make_long(districts = c("Auckland", "Waikato"), months = as.Date("2025-01-01"))
  d$num_lo[1] <- d$num_hi[1] <- 500
  a <- aggregate_counts(d, c("indicator", "month"))
  expect_equal(a$n_lo, 510)
  expect_equal(a$p_mid, 10 / 100)
})

test_that("funnel limits add no extra variance when spread is only chance", {
  set.seed(1)
  n <- round(exp(runif(40, log(200), log(20000))))
  y <- rbinom(40, n, 0.3) / n
  lim <- funnel_limits(y, n, 0.3, var_binomial)
  expect_lt(lim$phi, 1.6)
  expect_true(lim$tau2 < 1e-4)
})

test_that("funnel limits widen when districts genuinely differ", {
  set.seed(2)
  n <- round(exp(runif(40, log(2000), log(20000))))
  p <- plogis(qlogis(0.3) + rnorm(40, 0, 0.4))
  y <- rbinom(40, n, p) / n
  lim <- funnel_limits(y, n, 0.3, var_binomial)
  expect_gt(lim$phi, 5)
  expect_gt(lim$tau2, 0)
  expect_gt(lim$se(1e6), 0.01)  # limits do not collapse for huge lists
})

test_that("a clearly falling series gets a projection; a flat one does not", {
  m <- seq(as.Date("2024-01-01"), by = "month", length.out = 24)
  falling <- project_to_target(m, round(1000 * exp(-0.05 * 0:23)))
  expect_equal(falling$status, "falling")
  expect_gt(falling$months_to_target[["mid"]], 100)
  expect_lt(falling$months_to_target[["mid"]], 140)
  set.seed(3)
  flat <- project_to_target(m, rpois(24, 500))
  expect_equal(flat$status, "no clear trend")
  expect_null(flat$months_to_target)
  small <- project_to_target(m, rep(3, 24))
  expect_equal(small$status, "not shown")
})
