test_that("'<5' is read as a range of 1 to 4, never zero", {
  p <- parse_count(c("<5", "0", "12", " <5 ", "abc", NA))
  expect_equal(p$lo, c(1, 0, 12, 1, NA, NA))
  expect_equal(p$hi, c(4, 0, 12, 4, NA, NA))
  expect_equal(p$suppressed, c(TRUE, FALSE, FALSE, TRUE, FALSE, FALSE))
  expect_equal(p$unparsed, c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE))
})

test_that("a table missing an expected column is rejected", {
  raw <- data.frame(REGION_NAME = "Northern", DHB_NAME = "Auckland")
  expect_error(standardise_espi(raw, "ESPI2", "test", "f.csv", Sys.Date()),
               "missing expected columns")
})

test_that("indicator is detected from sheet or file name", {
  expect_equal(detect_indicator("ESPI2"), "ESPI2")
  expect_equal(detect_indicator("Sheet1", "Appendix_Four_ESPI5.xlsx"), "ESPI5")
  expect_equal(detect_indicator("espi 8"), "ESPI8")
  expect_true(is.na(detect_indicator("Sheet1")))
})

test_that("months parse from Excel serials and text", {
  expect_equal(excel_text_to_date(c("43466", "2019-02-01")),
               as.Date(c("2019-01-01", "2019-02-01")))
})

test_that("the OIA ESPI 2 appendix reads completely", {
  f <- file.path(root, "data/raw/oia_HNZ00201361/Appendix_Two_ESPI2.xlsx")
  skip_if_not(file.exists(f))
  d <- read_oia_appendix(f)
  expect_equal(nrow(d), 33667)
  expect_equal(unique(d$indicator), "ESPI2")
  expect_equal(sum(d$num_suppressed), 5610)
  expect_equal(range(d$month), as.Date(c("2019-01-01", "2025-12-01")))
  expect_equal(length(unique(d$district)), 20)
  expect_false(any(d$num_unparsed | d$den_unparsed))
})
