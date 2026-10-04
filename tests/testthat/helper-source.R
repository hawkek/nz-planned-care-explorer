root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
for (f in list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)) source(f)

# A small long table in the pipeline's standard format.
make_long <- function(n = 3, months = as.Date(c("2025-01-01", "2025-02-01")),
                      districts = c("Auckland", "Waikato"), specialty = "Urology",
                      indicator = "ESPI2", num = 10, den = 100) {
  g <- expand.grid(month = months, district = districts, stringsAsFactors = FALSE)
  tibble::tibble(
    month = g$month, region = ifelse(g$district == "Auckland", "Northern", "Te Manawa Taki"),
    district = g$district, specialty = specialty, indicator = indicator,
    num_lo = num, num_hi = num, den_lo = den, den_hi = den,
    num_suppressed = FALSE, den_suppressed = FALSE,
    num_unparsed = FALSE, den_unparsed = FALSE,
    definition = "x", source = "test", source_file = "test.csv",
    retrieved = as.Date("2026-01-01")
  )
}
