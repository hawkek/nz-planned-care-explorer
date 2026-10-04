# Combine the OIA history and live web tool downloads into one long table,
# and record where the sources disagree.

KEY_COLS <- c("month", "district", "specialty", "indicator")

# For each indicator and month, keep the rows from the most recent retrieval
# that covers that month. Provisional figures are revised, so later wins.
combine_sources <- function(...) {
  all <- dplyr::bind_rows(...)
  latest <- all |>
    dplyr::distinct(indicator, month, retrieved) |>
    dplyr::group_by(indicator, month) |>
    dplyr::summarise(retrieved = max(retrieved), .groups = "drop")
  all |>
    dplyr::semi_join(latest, by = c("indicator", "month", "retrieved")) |>
    dplyr::arrange(indicator, month, district, specialty)
}

# Compare every pair of retrievals that cover the same month. Produces one row
# per changed cell, so revisions to provisional data are visible.
reconcile_overlap <- function(...) {
  all <- dplyr::bind_rows(...)
  retrievals <- all |>
    dplyr::distinct(indicator, month, retrieved, source) |>
    dplyr::group_by(indicator, month) |>
    dplyr::filter(dplyr::n() > 1) |>
    dplyr::arrange(retrieved, .by_group = TRUE) |>
    dplyr::summarise(
      earlier = dplyr::first(retrieved), later = dplyr::last(retrieved),
      .groups = "drop"
    )
  if (nrow(retrievals) == 0) return(empty_revisions())
  pick <- function(which) {
    all |>
      dplyr::inner_join(retrievals, by = c("indicator", "month")) |>
      dplyr::filter(retrieved == .data[[which]]) |>
      dplyr::select(dplyr::all_of(KEY_COLS), num_lo, num_hi, den_lo, den_hi, source)
  }
  compare_versions(pick("earlier"), pick("later"))
}

empty_revisions <- function() {
  tibble::tibble(
    month = as.Date(character()), district = character(), specialty = character(),
    indicator = character(), field = character(), old = character(),
    new = character()
  )
}

fmt_count <- function(lo, hi) {
  ifelse(is.na(lo), NA_character_, ifelse(lo == hi, format(lo, scientific = FALSE), "<5"))
}

# Cell-level differences between two versions of the long table.
compare_versions <- function(old, new) {
  j <- dplyr::full_join(
    dplyr::select(old, dplyr::all_of(KEY_COLS), num_lo, num_hi, den_lo, den_hi),
    dplyr::select(new, dplyr::all_of(KEY_COLS), num_lo, num_hi, den_lo, den_hi),
    by = KEY_COLS, suffix = c("_old", "_new")
  )
  out <- dplyr::bind_rows(
    dplyr::transmute(j, dplyr::across(dplyr::all_of(KEY_COLS)), field = "numerator",
                     old = fmt_count(num_lo_old, num_hi_old),
                     new = fmt_count(num_lo_new, num_hi_new)),
    dplyr::transmute(j, dplyr::across(dplyr::all_of(KEY_COLS)), field = "denominator",
                     old = fmt_count(den_lo_old, den_hi_old),
                     new = fmt_count(den_lo_new, den_hi_new))
  )
  out |>
    dplyr::filter(!(is.na(old) & is.na(new))) |>
    dplyr::filter(is.na(old) | is.na(new) | old != new) |>
    dplyr::arrange(indicator, month, district, specialty, field)
}

# Columns published in data/processed/espi_long.csv.
publishable <- function(long) {
  long |>
    dplyr::select(
      month, region, district, specialty, indicator,
      num_lo, num_hi, den_lo, den_hi, num_suppressed, den_suppressed,
      source, retrieved
    ) |>
    dplyr::arrange(indicator, month, district, specialty)
}

read_previous_long <- function(path = "data/processed/espi_long.csv") {
  if (!file.exists(path)) return(NULL)
  readr::read_csv(path, show_col_types = FALSE, progress = FALSE,
                  col_types = readr::cols(month = "D", retrieved = "D",
                                          .default = readr::col_guess()))
}

# Append changes since the previous published version to the revisions log.
log_revisions <- function(new, previous, run_date = Sys.Date(),
                          path = "data/processed/revisions.csv") {
  if (is.null(previous)) return(invisible(empty_revisions()))
  changes <- compare_versions(previous, new)
  if (nrow(changes) > 0) {
    changes$detected <- as.Date(run_date)
    readr::write_csv(changes, path, append = file.exists(path), na = "")
  }
  invisible(changes)
}
