# Checks for the health target extracts. Same conventions as R/checks.R:
# an "error" stops publishing, a "warning" is published on the methods page.

run_extract_checks <- function(ext, tidy, latest, districts, references) {
  dplyr::bind_rows(
    check_result(
      "Extract: counts are numbers or '<5'", "error",
      dplyr::filter(ext, unparsed) |> dplyr::select(vintage, measure, month, district, specialty)
    ),
    check_result(
      "Extract: every row has a month, district and specialty", "error",
      dplyr::filter(ext, is.na(month) | is.na(district) | is.na(specialty)) |>
        dplyr::select(vintage, measure, source_file)
    ),
    check_result(
      "Extract: district is one of the expected 20 districts", "error",
      dplyr::filter(ext, !district %in% districts) |> dplyr::distinct(vintage, district)
    ),
    check_result(
      "Extract: no negative total waiting counts", "error",
      dplyr::filter(ext, total_lo < 0) |>
        dplyr::select(vintage, measure, month, district, specialty)
    ),
    check_result(
      "Extract: waiting under 120 days is not negative", "warning",
      dplyr::filter(tidy, under_negative, vintage == max(vintage)) |>
        dplyr::select(measure, month, district, specialty),
      paste("A negative count means more people waiting over four months than",
            "waiting in total. These are the same cells as the ESPI 2 rows with a",
            "numerator above the denominator. Kept in counts; shares for those",
            "cells are not meaningful.")
    ),
    check_result(
      "Extract: one row per month, district, specialty (and ethnicity, rurality)", "error",
      ext |>
        dplyr::count(vintage, measure, month, district, specialty, ethnicity, rurality) |>
        dplyr::filter(n > 1)
    ),
    check_result(
      "Extract: waiting under 120 days is not more than total waiting", "warning",
      dplyr::filter(tidy, under_gt_total) |>
        dplyr::select(vintage, measure, month, district, specialty)
    ),
    check_result(
      "Extract: no missing months in each national series", "error",
      latest |>
        dplyr::group_by(measure) |>
        dplyr::summarise(expected = list(seq(min(month), max(month), by = "month")),
                         present = list(unique(month)), .groups = "drop") |>
        dplyr::rowwise() |>
        dplyr::reframe(measure = measure,
                       month = as.Date(setdiff(expected, present), origin = "1970-01-01"))
    ),
    check_result(
      "Extract: no one-month spikes or dips in a district and specialty series", "warning",
      find_extract_spikes(latest),
      "Same rule as for ESPI. Values are published unchanged and listed in flagged_cells.csv."
    ),
    check_extract_health_target(tidy, references$FSA, "FSA"),
    check_extract_health_target(tidy, references$Treatment, "Treatment"),
    check_result(
      "Extract: no months from after the July 2026 change of data system", "warning",
      latest |> dplyr::filter(month >= NBRD_START) |> dplyr::count(measure, month),
      "Extracts from July 2026 onward are expected to come from NBRD; see the methods page."
    )
  )
}

find_extract_spikes <- function(latest) {
  latest |>
    dplyr::mutate(mid = (over_lo + over_hi) / 2) |>
    spikes_in(c("measure", "district", "specialty"))
}

# Published health target results must fall inside the range implied by the
# suppressed counts (allowing 0.05 points for rounding to one decimal place).
check_extract_health_target <- function(tidy, reference, measure) {
  name <- sprintf("Extract: matches published %s health target results",
                  if (measure == "FSA") "first specialist assessment" else "treatment")
  if (is.null(reference)) {
    return(check_result(name, "warning", data.frame(), "Not applicable: no reference file."))
  }
  # Compare each published figure with the extract published alongside it;
  # earlier figures have since been revised and are not compared.
  reference <- dplyr::filter(reference, vintage %in% unique(tidy$vintage))
  d <- dplyr::filter(tidy, .data$measure == !!measure,
                     paste(vintage, month) %in% paste(reference$vintage, reference$month))
  if (nrow(d) == 0) {
    return(check_result(name, "warning", data.frame(),
                        "Not applicable: no published figures for the extracts held."))
  }
  s <- dplyr::bind_rows(lapply(split(d, d$vintage), function(x)
    explorer_series(x) |> dplyr::mutate(vintage = x$vintage[1]))) |>
    dplyr::filter(spec == "All") |>
    add_shares() |>
    dplyr::transmute(vintage, month, area,
                     ours_lo = round(100 * (1 - p_hi), 2), ours_hi = round(100 * (1 - p_lo), 2))
  cmp <- dplyr::inner_join(reference, s, by = c("vintage", "month", "area"))
  # A national figure outside the possible range means something is wrong with
  # reading or aggregation: stop. District differences are published as warnings.
  nat_bad <- dplyr::filter(cmp, area == "New Zealand",
                           pct_within_4_months < ours_lo - 0.051 | pct_within_4_months > ours_hi + 0.051)
  if (nrow(nat_bad) > 0) {
    return(check_result(paste(name, "(national)"), "error",
                        dplyr::select(nat_bad, month, area, published = pct_within_4_months, ours_lo, ours_hi)))
  }
  check_result(
    name, "warning",
    dplyr::filter(cmp, pct_within_4_months < ours_lo - 0.051 | pct_within_4_months > ours_hi + 0.051) |>
      dplyr::select(month, area, published = pct_within_4_months, ours_lo, ours_hi),
    sprintf("Compared %d published figure(s) with the range implied by the extract.", nrow(cmp))
  )
}

read_reference <- function(path) {
  if (!file.exists(path)) return(NULL)
  readr::read_csv(path, show_col_types = FALSE, col_types = readr::cols(month = "D"))
}
