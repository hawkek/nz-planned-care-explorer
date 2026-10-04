test_that("the most recent retrieval wins for each month", {
  old <- make_long(num = 10)
  new <- make_long(months = as.Date("2025-02-01"), num = 12)
  new$retrieved <- as.Date("2026-02-01")
  out <- combine_sources(old, new)
  expect_equal(nrow(out), 4)
  feb <- out[out$month == as.Date("2025-02-01"), ]
  expect_equal(unique(feb$num_lo), 12)
  jan <- out[out$month == as.Date("2025-01-01"), ]
  expect_equal(unique(jan$num_lo), 10)
})

test_that("differences between overlapping retrievals are logged cell by cell", {
  old <- make_long(num = 10)
  new <- make_long(months = as.Date("2025-02-01"), num = 12)
  new$retrieved <- as.Date("2026-02-01")
  rec <- reconcile_overlap(old, new)
  expect_equal(nrow(rec), 2)
  expect_true(all(rec$field == "numerator"))
  expect_equal(unique(rec$old), "10")
  expect_equal(unique(rec$new), "12")
})

test_that("suppressed cells are logged as '<5'", {
  a <- make_long(); b <- a
  b$num_lo[1] <- 1; b$num_hi[1] <- 4
  ch <- compare_versions(a, b)
  expect_equal(ch$new, "<5")
})
