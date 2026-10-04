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

run_checks <- function(long, reference) {
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
            "computed from the counts. Present in the provisional OIA history",
            "for ESPI 2. These rows are kept in counts but excluded from",
            "proportions.")
    ),
    check_result(
      "ESPI 1 counts services, so each row is 0 or 1 of 0 or 1", "error",
      key_view(dplyr::filter(long, indicator == "ESPI1" &
                               (!num_lo %in% c(0, 1) | !den_lo %in% c(0, 1))))
    ),
    check_district_totals(long)
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
