# Run from the project root: Rscript tests/testthat.R
library(testthat)
test_dir("tests/testthat", stop_on_failure = TRUE)
