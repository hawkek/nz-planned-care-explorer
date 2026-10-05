# Automatic data checks, run on every update.
#
# Each check returns one row: check, severity ("error" stops the pipeline
# before anything is published; "warning" is logged and shown on the methods
# page), passed, n_failing and an example of a failing row.

check_result <- function(check, severity, failing, detail = "") {
  failing <- as.data.frame(failing)
  example <- if (nrow(failing) > 0) {
    paste(utils::capture.output(print(utils::head(failing, 3), row.names = FALSE)),
          collapse = "\n")
  } else ""
  tibble::tibble(
    check = check, severity = severity, passed = nrow(failing) == 0,
    n_failing = nrow(failing), detail = detail, example = example
  )
}

key_view <- function(d) {
  dplyr::select(d, dplyr::any_of(c("indicator", "month", "district", "specialty",
                                   "num_lo", "num_hi", "den_lo", "den_hi", "source_file")))
}

run_checks <- function(long, reference,
                       health_target = read_health_target_reference()) {
  dplyr::bind_rows(
    check_result(
      "Every row has a parseable month, district, specialty and indicator", "error",
      key_view(dplyr::filter(long, is.na(month) | is.na(district) | is.na(specialty) |
                               is.na(indicator)))
    ),
    check_result(
      "Counts are numbers or '<5'", "error",
      key_view(dplyr::filter(long, num_unparsed | den_unparsed |
                               (is.na(num_lo) & !num_suppressed) |
                               (is.na(den_lo) & !den_suppressed)))
    ),
    check_result(
      "Indicator is one of ESPI 1, 2, 3, 5, 8", "error",
      key_view(dplyr::filter(long, !indicator %in% reference$indicators))
    ),
    check_result(
      "District is one of the expected 20 districts", "error",
      key_view(dplyr::filter(long, !district %in% reference$districts))
    ),
    check_result(
      "Each district stays in its expected region", "error",
      long |>
        dplyr::distinct(district, region) |>
        dplyr::anti_join(reference$district_regions, by = c("district", "region"))
    ),
    check_result(
      "Specialty has been seen before for this indicator", "warning",
      long |>
        dplyr::distinct(indicator, specialty) |>
        dplyr::anti_join(reference$specialties, by = c("indicator", "specialty")),
      "A new specialty may be a rename; check before publishing."
    ),
    check_result(
      "No negative counts", "error",
      key_view(dplyr::filter(long, num_lo < 0 | den_lo < 0))
    ),
    check_result(
      "One row per month, district, specialty and indicator", "error",
      long |>
        dplyr::count(indicator, month, district, specialty) |>
        dplyr::filter(n > 1)
    ),
    check_result(
      "No missing months in each indicator's national series", "error",
      missing_months(long)
    ),
    check_result(
      "Numerator is not larger than denominator", "warning",
      key_view(dplyr::filter(long, num_lo > den_hi)),
      paste("Equivalent to percentages above 100, as all percentages are",
            "computed from the counts. Present in the provisional OIA history,",
            "mostly for ESPI 2. These rows are kept in counts but excluded from",
            "proportions.")
    ),
    check_result(
      "ESPI 1 counts services, so each row is 0 or 1 of 0 or 1", "error",
      key_view(dplyr::filter(long, indicator == "ESPI1" &
                               (!num_lo %in% c(0, 1) | !den_lo %in% c(0, 1))))
    ),
    check_district_totals(long),
    check_result(
      "No one-month spikes or dips in a district and specialty series", "warning",
      find_spikes(long),
      paste("A value more than 300 patients and 40% away from the median of",
            "the surrounding five months; the first and last month of each",
            "series are not tested. Usually a reporting error (for",
            "example a duplicated load). Values are published unchanged and",
            "listed here.")
    ),
    check_health_target(long, health_target),
    check_result(
      "No months from after the July 2026 change of data system", "warning",
      long |>
        dplyr::filter(month >= as.Date("2026-07-01")) |>
        dplyr::count(indicator, month),
      paste("From July 2026 Health NZ reports from NBRD instead of NBRS, with",
            "different rules for ESPI 2 and 5. Figures either side of the",
            "change may not be comparable; see the methods page.")
    )
  )
}

missing_months <- function(long) {
  long |>
    dplyr::group_by(indicator) |>
    dplyr::summarise(
      expected = list(seq(min(month), max(month), by = "month")),
      present = list(unique(month)), .groups = "drop"
    ) |>
    dplyr::rowwise() |>
    dplyr::reframe(indicator = indicator,
                   month = as.Date(setdiff(expected, present), origin = "1970-01-01"))
}

# District totals should equal the sum of specialties, allowing for
# suppression. The OIA appendices contain no district total rows, so this only
# runs when a source supplies them (as rows with an "All specialties" label).
TOTAL_LABELS <- c("All specialties", "All Specialties", "Total", "All")

check_district_totals <- function(long) {
  totals <- dplyr::filter(long, specialty %in% TOTAL_LABELS)
  name <- "District totals equal the sum of specialties, allowing for suppression"
  if (nrow(totals) == 0) {
    return(check_result(name, "warning", data.frame(),
                        "Not applicable: no district total rows in the current sources."))
  }
  parts <- long |>
    dplyr::filter(!specialty %in% TOTAL_LABELS) |>
    dplyr::group_by(indicator, month, district) |>
    dplyr::summarise(sum_lo = sum(num_lo), sum_hi = sum(num_hi), .groups = "drop")
  bad <- totals |>
    dplyr::inner_join(parts, by = c("indicator", "month", "district")) |>
    dplyr::filter(num_hi < sum_lo | num_lo > sum_hi)
  check_result(name, "error", key_view(bad))
}

# Reference lists come from the OIA history: it is the longest record and was
# released by Health NZ, so a new value in a live download is worth a look.
build_reference <- function(oia) {
  list(
    indicators = c("ESPI1", "ESPI2", "ESPI3", "ESPI5", "ESPI8"),
    districts = sort(unique(oia$district)),
    district_regions = dplyr::distinct(oia, district, region),
    specialties = dplyr::distinct(oia, indicator, specialty)
  )
}

stop_on_errors <- function(results) {
  bad <- dplyr::filter(results, severity == "error" & !passed)
  if (nrow(bad) > 0) {
    msg <- paste0("- ", bad$check, " (", bad$n_failing, " rows)\n", bad$example,
                  collapse = "\n")
    stop("Data checks failed; nothing was published.\n", msg, call. = FALSE)
  }
  invisible(results)
}

# One-month outliers in ESPI 2 and ESPI 5 series: compare each month with the
# median of the five months centred on it.
find_spikes <- function(long, min_abs = 300, min_rel = 0.4) {
  long |>
    dplyr::filter(indicator %in% c("ESPI2", "ESPI5")) |>
    dplyr::mutate(mid = (num_lo + num_hi) / 2) |>
    spikes_in(c("indicator", "district", "specialty"), min_abs, min_rel)
}

# Shared rule: a month more than `min_abs` and `min_rel` away from the median
# of the five months centred on it, within each series defined by `keys`.
# The first and last month of a series are never flagged: without a month on
# each side, a genuine change at the end of the series looks like a dip.
spikes_in <- function(d, keys, min_abs = 300, min_rel = 0.4) {
  d |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c(keys, "month")))) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
    dplyr::mutate(local_median = centred_median(mid, 5)) |>
    dplyr::ungroup() |>
    dplyr::filter(!is.na(local_median),
                  abs(mid - local_median) > min_abs,
                  abs(mid - local_median) > min_rel * local_median) |>
    dplyr::select(dplyr::all_of(keys), month, value = mid, local_median)
}

centred_median <- function(x, width) {
  half <- width %/% 2
  n <- length(x)
  vapply(seq_len(n), function(i) {
    w <- x[max(1, i - half):min(n, i + half)]
    if (i == 1 || i == n || length(w) < 3) NA_real_ else stats::median(w)
  }, numeric(1))
}

read_health_target_reference <- function(path = "config/reference/health_target_fsa.csv") {
  if (!file.exists(path)) return(NULL)
  readr::read_csv(path, show_col_types = FALSE, col_types = readr::cols(month = "D"))
}

# The FSA health target (% waiting under four months at the end of the period)
# should equal 100% minus the ESPI 2 share of the list. Compare wherever both
# cover the same month; differences over 0.5 percentage points are flagged.
check_health_target <- function(long, reference, tolerance = 0.5) {
  name <- "Matches published FSA health target results"
  if (is.null(reference)) {
    return(check_result(name, "warning", data.frame(), "Not applicable: no reference file."))
  }
  e2 <- dplyr::filter(long, indicator == "ESPI2", month %in% reference$month)
  if (nrow(e2) == 0) {
    return(check_result(name, "warning", data.frame(),
                        "Not applicable: no months in common with the published results."))
  }
  nat <- aggregate_counts(e2, "month") |> dplyr::mutate(area = "New Zealand")
  dist <- aggregate_counts(e2, c("month", "district")) |> dplyr::rename(area = district)
  ours <- dplyr::bind_rows(nat, dist) |>
    dplyr::transmute(month, area, ours = round(100 * (1 - p_mid), 1))
  cmp <- dplyr::inner_join(reference, ours, by = c("month", "area")) |>
    dplyr::mutate(difference = round(ours - pct_within_4_months, 1))
  check_result(
    name, "warning",
    dplyr::filter(cmp, abs(difference) > tolerance) |>
      dplyr::select(month, area, published = pct_within_4_months, ours, difference),
    sprintf("Compared %d published figure(s) with 100%% minus the ESPI 2 share of the list.",
            nrow(cmp))
  )
}
