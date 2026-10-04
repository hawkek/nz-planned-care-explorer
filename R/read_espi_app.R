# Reader for exports from the ESPI web tool (tewhatuora.shinyapps.io/ESPI_app).
#
# The site's main source is the quarterly health target extracts. A manual
# export from the web tool can still be added: save the file(s) in
# data/raw/espi_app/<YYYY-MM-DD>/ (the date downloaded) and rerun the pipeline.
# The reader expects the same eight columns as the OIA appendices; if the
# export differs, the pipeline stops with a clear error.

# Read one exported file. The indicator is identified from ESPI_DEFINITION,
# using the definitions found in the OIA appendices, and failing that from the
# file name.
read_espi_app_file <- function(path, definition_map, retrieved) {
  raw <- if (grepl("\\.xlsx?$", path, ignore.case = TRUE)) {
    readxl::read_excel(path, col_types = "text")
  } else {
    readr::read_csv(path, col_types = readr::cols(.default = "c"), progress = FALSE)
  }
  if ("MONTH_YEAR" %in% names(raw)) raw$MONTH_YEAR <- excel_text_to_date(raw$MONTH_YEAR)
  defs <- unique(trimws(raw$ESPI_DEFINITION))
  ind <- definition_map$indicator[match(defs, definition_map$definition)]
  if (length(defs) == 1 && !is.na(ind)) {
    indicator <- ind
  } else {
    indicator <- detect_indicator(basename(path))
  }
  if (is.na(indicator)) stop("Cannot tell which ESPI is in ", path, call. = FALSE)
  standardise_espi(raw, indicator, "ESPI web tool", basename(path), retrieved)
}

# Every dated subfolder of data/raw/espi_app holds one retrieval.
read_espi_app_dir <- function(definition_map, dir = "data/raw/espi_app") {
  folders <- list.dirs(dir, recursive = FALSE)
  folders <- folders[grepl("^\\d{4}-\\d{2}-\\d{2}$", basename(folders))]
  out <- lapply(folders, function(f) {
    files <- list.files(f, pattern = "\\.(csv|xlsx?)$", full.names = TRUE,
                        ignore.case = TRUE)
    lapply(files, read_espi_app_file,
           definition_map = definition_map, retrieved = as.Date(basename(f)))
  })
  out <- dplyr::bind_rows(unlist(out, recursive = FALSE))
  if (nrow(out) == 0) NULL else out
}
