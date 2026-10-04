ref <- list(
  indicators = c("ESPI1", "ESPI2", "ESPI3", "ESPI5", "ESPI8"),
  districts = c("Auckland", "Waikato"),
  district_regions = tibble::tibble(district = c("Auckland", "Waikato"),
                                    region = c("Northern", "Te Manawa Taki")),
  specialties = tibble::tibble(indicator = "ESPI2", specialty = "Urology")
)
failed <- function(res) res$check[!res$passed]

test_that("clean data passes every error-level check", {
  res <- run_checks(make_long(), ref)
  expect_true(all(res$passed[res$severity == "error"]))
  expect_silent(stop_on_errors(res))
})

test_that("negative counts, duplicates and unknown districts are errors", {
  d <- make_long()
  d$num_lo[1] <- -1
  d <- dplyr::bind_rows(d, d[2, ])
  d$district[3] <- "Atlantis"
  res <- run_checks(d, ref)
  expect_true("No negative counts" %in% failed(res))
  expect_true("One row per month, district, specialty and indicator" %in% failed(res))
  expect_true("District is one of the expected 20 districts" %in% failed(res))
  expect_error(stop_on_errors(res), "Data checks failed")
})

test_that("a missing month in the national series is an error", {
  d <- make_long(months = as.Date(c("2025-01-01", "2025-03-01")))
  res <- run_checks(d, ref)
  expect_true("No missing months in each indicator's national series" %in% failed(res))
})

test_that("numerator above denominator is a warning, not an error", {
  d <- make_long(num = 150, den = 100)
  res <- run_checks(d, ref)
  row <- res[res$check == "Numerator is not larger than denominator", ]
  expect_false(row$passed)
  expect_equal(row$severity, "warning")
  expect_silent(stop_on_errors(res))
})

test_that("district totals are checked against specialties when present", {
  d <- make_long(districts = "Auckland", months = as.Date("2025-01-01"))
  tot <- d; tot$specialty <- "All specialties"; tot$num_lo <- tot$num_hi <- 99
  res <- run_checks(dplyr::bind_rows(d, tot), ref)
  row <- res[grepl("District totals", res$check), ]
  expect_false(row$passed)
})

test_that("months after the July 2026 data system change raise a warning", {
  d <- make_long(months = as.Date(c("2026-06-01", "2026-07-01")))
  res <- run_checks(d, ref)
  row <- res[grepl("July 2026", res$check), ]
  expect_false(row$passed)
  expect_equal(row$severity, "warning")
})

test_that("a one-month doubling is flagged as a spike", {
  m <- seq(as.Date("2024-09-01"), by = "month", length.out = 7)
  d <- make_long(months = m, districts = "Auckland", num = 600, den = 2000)
  d$num_lo[4] <- d$num_hi[4] <- 1200
  s <- find_spikes(d)
  expect_equal(nrow(s), 1)
  expect_equal(s$month, m[4])
})

test_that("published health target results are compared with 100% minus the ESPI 2 share", {
  d <- make_long(months = as.Date("2025-06-01"), num = 380, den = 1000)
  good <- tibble::tibble(month = as.Date("2025-06-01"), area = "New Zealand",
                         pct_within_4_months = 62.0, source = "test")
  expect_true(check_health_target(d, good)$passed)
  bad <- dplyr::mutate(good, pct_within_4_months = 66.0)
  expect_false(check_health_target(d, bad)$passed)
  none <- dplyr::mutate(good, month = as.Date("2020-01-01"))
  expect_match(check_health_target(d, none)$detail, "Not applicable")
})
