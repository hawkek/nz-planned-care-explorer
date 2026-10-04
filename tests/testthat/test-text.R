d <- as.Date("2024-12-01")

test_that("rises and falls use the same neutral wording", {
  expect_equal(describe_change(110, 110, 100, 100, d), "10 more than in December 2024")
  expect_equal(describe_change(90, 90, 100, 100, d), "10 fewer than in December 2024")
})

test_that("an uncertain direction is said plainly", {
  expect_match(describe_change(100, 104, 101, 101, d), "within the range of suppressed counts")
})

test_that("counts with suppression are shown as ranges or rounded", {
  expect_equal(fmt_count_range(5, 5), "5")
  expect_equal(fmt_count_range(1, 4), "1 to 4")
  expect_equal(fmt_count_range(75076, 75322), "about 75,200")
})

test_that("takeaways never mention blame words", {
  ind <- list(indicator = "ESPI2", phrase = "waiting more than four months")
  s <- tibble::tibble(month = as.Date(c("2024-12-01", "2025-12-01")),
                      n_lo = c(100, 80), n_hi = c(100, 80))
  txt <- takeaway_count(s, ind, "Waikato")
  expect_equal(txt, paste("In December 2025, 80 patients in Waikato were waiting",
                          "more than four months, 20 fewer than in December 2024."))
  expect_false(grepl("fail|poor|worse|better|blame", txt, ignore.case = TRUE))
})

test_that("headline figures round to 10 or 100", {
  expect_equal(fmt_count_range(5732, 5735), "about 5,730")
})

test_that("large headline figures round to the nearest 100", {
  expect_equal(fmt_count_range(66633, 66678), "about 66,700")
  expect_equal(fmt_change(56402, 56477), "about 56,400")
  expect_equal(fmt_change(7880, 7920), "about 7,900")
})
