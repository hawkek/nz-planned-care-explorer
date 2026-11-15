ext_row <- function(vintage = "2025-26-Q4", month = as.Date("2026-06-01"), district = "Auckland",
                    specialty = "Urology", under = c(80, 80), total = c(100, 100),
                    measure = "FSA", ethnicity = NA_character_) {
  tibble::tibble(measure = measure, month = month, region = "Northern", district = district,
                 specialty = specialty, ethnicity = ethnicity, rurality = NA_character_,
                 under_lo = under[1], under_hi = under[2], total_lo = total[1], total_hi = total[2],
                 suppressed = under[1] != under[2] | total[1] != total[2], unparsed = FALSE,
                 vintage = vintage, source_file = "test.xlsx")
}

test_that("waiting over four months is total minus under 120 days, as a range", {
  d <- dplyr::bind_rows(
    ext_row(under = c(80, 80), total = c(100, 100)),
    ext_row(specialty = "Vascular", under = c(1, 4), total = c(10, 10)),
    ext_row(specialty = "Dental", under = c(1, 4), total = c(1, 4))
  )
  t <- tidy_extract(d)
  expect_equal(t$over_lo[t$specialty == "Urology"], 20)
  expect_equal(c(t$over_lo[t$specialty == "Vascular"], t$over_hi[t$specialty == "Vascular"]), c(6, 9))
  expect_equal(c(t$over_lo[t$specialty == "Dental"], t$over_hi[t$specialty == "Dental"]), c(0, 3))
})

test_that("ethnicity rows are summed with their ranges", {
  d <- dplyr::bind_rows(
    ext_row(measure = "Treatment", ethnicity = "Asian", under = c(1, 4), total = c(1, 4)),
    ext_row(measure = "Treatment", ethnicity = "Pacific", under = c(10, 10), total = c(20, 20))
  )
  t <- tidy_extract(d)
  expect_equal(nrow(t), 1)
  expect_equal(c(t$total_lo, t$total_hi), c(21, 24))
  expect_equal(c(t$over_lo, t$over_hi), c(10, 13))
})

test_that("district spellings are normalised", {
  expect_equal(normalise_district(c("Hawkes Bay", paste0("Waitemat", intToUtf8(0x101)), " Lakes ")),
               c("Hawke's Bay", "Waitemata", "Lakes"))
})

test_that("the latest extract wins and months before July 2015 are dropped", {
  d <- dplyr::bind_rows(
    ext_row(vintage = "2025-26-Q3", total = c(100, 100)),
    ext_row(vintage = "2025-26-Q4", total = c(110, 110)),
    ext_row(vintage = "2025-26-Q4", month = as.Date("2015-01-01"))
  )
  lv <- latest_vintage(tidy_extract(d))
  expect_equal(nrow(lv), 1)
  expect_equal(lv$total_lo, 110)
})

test_that("revisions between extracts are found cell by cell and nationally", {
  d <- dplyr::bind_rows(
    ext_row(vintage = "2025-26-Q3", total = c(100, 100)),
    ext_row(vintage = "2025-26-Q4", total = c(110, 110)),
    ext_row(vintage = "2025-26-Q4", month = as.Date("2026-07-01"))
  )
  t <- tidy_extract(d)
  rv <- extract_revisions(t)
  expect_equal(nrow(rv), 1)
  expect_equal(c(rv$old_lo, rv$new_lo), c(20, 30))
  rs <- revision_summary(t)
  expect_equal(rs$change, 10)
})

test_that("explorer series cover district, national and all-specialty totals", {
  d <- dplyr::bind_rows(
    ext_row(district = "Auckland", specialty = "Urology"),
    ext_row(district = "Waikato", specialty = "Urology"),
    ext_row(district = "Waikato", specialty = "Vascular", under = c(1, 4), total = c(10, 10))
  )
  s <- explorer_series(tidy_extract(d))
  nz <- s[s$area == "New Zealand" & s$spec == "All", ]
  expect_equal(c(nz$o_lo, nz$o_hi, nz$t_lo), c(46, 49, 210))
  expect_equal(nrow(s[s$area == "Waikato", ]), 3)  # two specialties + All
})

test_that("published health target figures are checked against the matching extract", {
  d <- tidy_extract(dplyr::bind_rows(
    ext_row(vintage = "2025-26-Q4", under = c(66, 66), total = c(100, 100))
  ))
  ref <- tibble::tibble(month = as.Date("2026-06-01"), area = c("New Zealand", "Auckland"),
                        pct_within_4_months = c(66.0, 70.0), vintage = "2025-26-Q4", source = "t")
  res <- check_extract_health_target(d, ref, "FSA")
  expect_equal(res$n_failing, 1)   # Auckland 70.0 against 66
  old <- dplyr::mutate(ref, vintage = "2024-25-Q4")
  expect_match(check_extract_health_target(d, old, "FSA")$detail, "Not applicable")
})

test_that("a national health target mismatch is an error, a district one a warning", {
  d <- tidy_extract(ext_row(vintage = "2025-26-Q4", under = c(66, 66), total = c(100, 100)))
  ref <- tibble::tibble(month = as.Date("2026-06-01"), area = "New Zealand",
                        pct_within_4_months = 70, vintage = "2025-26-Q4", source = "t")
  expect_equal(check_extract_health_target(d, ref, "FSA")$severity, "error")
})

test_that("explorer data carries flagged cells with their month index", {
  m <- seq(as.Date("2024-09-01"), by = "month", length.out = 7)
  d <- dplyr::bind_rows(lapply(seq_along(m), function(k)
    ext_row(month = m[k], under = c(400, 400), total = if (k == 4) c(1600, 1600) else c(1000, 1000))))
  ex <- build_explorer(latest_vintage(tidy_extract(d)), "FSA")
  expect_equal(nrow(ex$flags), 1)
  expect_equal(ex$flags$i, 3)            # zero-based index of the fourth month
  expect_equal(ex$flags$dev, 600)
})

test_that("confirmed errors are read with dates", {
  f <- tempfile(fileext = ".csv")
  writeLines(c("measure,district,month,confirmed_by,recorded",
               "FSA,Hawke's Bay,2025-01-01,Health NZ,2026-11-15"), f)
  x <- read_confirmed_errors(f)
  expect_equal(x$month, as.Date("2025-01-01"))
  expect_equal(nrow(read_confirmed_errors(tempfile())), 0)
})
