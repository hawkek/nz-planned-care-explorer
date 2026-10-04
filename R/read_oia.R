# Readers for ESPI tables.
#
# Both the OIA appendices (HNZ00201361) and, we expect, the ESPI web tool
# export share eight columns:
#   REGION_NAME, DHB_NAME, SPECIALTY_NAME, MONTH_YEAR,
#   NUMERATOR, DENOMINATOR, ESPI_DEFINITION, PERCENTAGE
# NUMERATOR and DENOMINATOR are text because counts of 1 to 4 are shown as "<5".

ESPI_COLUMNS <- c(
  "REGION_NAME", "DHB_NAME", "SPECIALTY_NAME", "MONTH_YEAR",
  "NUMERATOR", "DENOMINATOR", "ESPI_DEFINITION", "PERCENTAGE"
)

SUPPRESSED_TOKEN <- "<5"

# Parse one count column into lower and upper bounds.
# "<5" becomes [1, 4]; numbers become [x, x]; anything else is NA and is
# caught by the checks rather than silently dropped.
parse_count <- function(x) {
  x <- trimws(as.character(x))
  suppressed <- !is.na(x) & x == SUPPRESSED_TOKEN
  value <- suppressWarnings(as.numeric(ifelse(suppressed, NA, x)))
  list(
    lo = ifelse(suppressed, 1, value),
    hi = ifelse(suppressed, 4, value),
    suppressed = suppressed,
    unparsed = !suppressed & is.na(value) & !is.na(x)
  )
}

parse_month <- function(x) {
  if (inherits(x, "Date")) return(lubridate::floor_date(x, "month"))
  if (inherits(x, "POSIXt")) return(lubridate::floor_date(as.Date(x), "month"))
  x <- as.character(x)
  out <- suppressWarnings(as.Date(lubridate::parse_date_time(
    x, orders = c("Ymd", "Ymd HMS", "dmY", "mY", "bY", "Ym")
  )))
  lubridate::floor_date(out, "month")
}

# Convert a raw ESPI table (already read into a data frame) into the
# standard long format used everywhere else in the pipeline.
standardise_espi <- function(raw, indicator, source, source_file, retrieved) {
  missing_cols <- setdiff(ESPI_COLUMNS, names(raw))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "%s: missing expected columns: %s", source_file,
      paste(missing_cols, collapse = ", ")
    ), call. = FALSE)
  }
  num <- parse_count(raw$NUMERATOR)
  den <- parse_count(raw$DENOMINATOR)
  tibble::tibble(
    month = parse_month(raw$MONTH_YEAR),
    region = trimws(raw$REGION_NAME),
    district = trimws(raw$DHB_NAME),
    specialty = trimws(raw$SPECIALTY_NAME),
    indicator = indicator,
    num_lo = num$lo,
    num_hi = num$hi,
    den_lo = den$lo,
    den_hi = den$hi,
    num_suppressed = num$suppressed,
    den_suppressed = den$suppressed,
    num_unparsed = num$unparsed,
    den_unparsed = den$unparsed,
    definition = trimws(raw$ESPI_DEFINITION),
    source = source,
    source_file = source_file,
    retrieved = as.Date(retrieved)
  )
}

# Which ESPI does a sheet or file hold? Uses the sheet name first ("ESPI2"),
# then the file name.
detect_indicator <- function(...) {
  for (s in c(...)) {
    m <- regmatches(s, regexpr("ESPI[ _-]?[0-9]+", s, ignore.case = TRUE))
    if (length(m) == 1) return(toupper(gsub("[ _-]", "", m)))
  }
  NA_character_
}

read_oia_appendix <- function(path, retrieved = as.Date("2026-03-25"),
                              source = "OIA HNZ00201361") {
  sheets <- readxl::excel_sheets(path)
  dplyr::bind_rows(lapply(sheets, function(sheet) {
    raw <- readxl::read_excel(
      path, sheet = sheet, col_types = "text", .name_repair = "minimal"
    )
    raw$MONTH_YEAR <- excel_text_to_date(raw$MONTH_YEAR)
    indicator <- detect_indicator(sheet, basename(path))
    if (is.na(indicator)) stop("Cannot tell which ESPI is in ", path, call. = FALSE)
    standardise_espi(raw, indicator, source, basename(path), retrieved)
  }))
}

# readxl with col_types = "text" returns dates as Excel serial numbers.
excel_text_to_date <- function(x) {
  serial <- suppressWarnings(as.numeric(x))
  out <- as.Date(serial, origin = "1899-12-30")
  not_serial <- is.na(serial) & !is.na(x)
  out[not_serial] <- parse_month(x[not_serial])
  out
}

read_oia_dir <- function(dir = "data/raw/oia_HNZ00201361") {
  files <- list.files(dir, pattern = "\\.xlsx$", full.names = TRUE)
  if (length(files) == 0) stop("No OIA appendices found in ", dir, call. = FALSE)
  dplyr::bind_rows(lapply(files, read_oia_appendix))
}
