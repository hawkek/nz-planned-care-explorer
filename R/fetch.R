# Download the latest 12 months from the ESPI web tool.
#
# STATUS: UNTESTED. The app (tewhatuora.shinyapps.io/ESPI_app) could not be
# reached from the environment this code was written in, so the page
# structure, the download button selector and the export format are
# assumptions. Run fetch_espi_app() by hand once, inspect what it saves, and
# adjust ESPI_DOWNLOAD_SELECTOR or read_espi_app_file() before relying on it.
# Optional supplement only; the site's main source is the quarterly extracts.
#
# Manual fallback: download the CSV(s) from the app yourself and save them in
# data/raw/espi_app/<YYYY-MM-DD>/ (the date you downloaded them). The pipeline
# reads every dated folder in the same way, whichever route the files took.

ESPI_APP_URL <- "https://tewhatuora.shinyapps.io/ESPI_app/"

fetch_espi_app <- function(out_dir = file.path("data/raw/espi_app", format(Sys.Date())),
                           url = ESPI_APP_URL,
                           selector = Sys.getenv(
                             "ESPI_DOWNLOAD_SELECTOR",
                             "a.shiny-download-link, button.shiny-download-link"
                           ),
                           timeout_s = 120) {
  if (!requireNamespace("chromote", quietly = TRUE)) {
    stop("The chromote package is needed to fetch from the web tool.", call. = FALSE)
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_dir <- normalizePath(out_dir)
  before <- list.files(out_dir)

  b <- chromote::ChromoteSession$new()
  on.exit(b$close(), add = TRUE)
  b$Browser$setDownloadBehavior(behavior = "allow", downloadPath = out_dir)
  b$Page$navigate(url)
  b$Page$loadEventFired(timeout = timeout_s)

  # Shiny renders download links after the server connects; wait for them.
  n_links <- 0
  deadline <- Sys.time() + timeout_s
  while (n_links == 0 && Sys.time() < deadline) {
    Sys.sleep(2)
    n_links <- b$Runtime$evaluate(sprintf(
      "document.querySelectorAll(%s).length", jsonlite::toJSON(selector, auto_unbox = TRUE)
    ))$result$value
  }
  if (n_links == 0) {
    stop("No download links matched selector: ", selector, call. = FALSE)
  }

  b$Runtime$evaluate(sprintf(
    "document.querySelectorAll(%s).forEach(el => el.click())",
    jsonlite::toJSON(selector, auto_unbox = TRUE)
  ))

  # Wait until the downloads finish (Chrome writes *.crdownload while busy).
  repeat {
    Sys.sleep(2)
    now <- setdiff(list.files(out_dir), before)
    busy <- grepl("\\.crdownload$", now)
    if (length(now) >= n_links && !any(busy)) break
    if (Sys.time() > deadline + timeout_s) {
      stop("Timed out waiting for downloads in ", out_dir, call. = FALSE)
    }
  }
  file.path(out_dir, setdiff(list.files(out_dir), before))
}

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
