# Reader for Health NZ's quarterly waitlist detail extracts (health targets).
#
# Each workbook has an "FSA Waitlist" and an "Elective Waitlist" sheet with
# month end, region, district, specialty, waiting under 120 days and total
# waiting (elective also by ethnicity). Column sets vary a little between
# quarters (Q1 and Q2 2025/26 add a "Quarter ... Extracted" column, Q1 a
# "Rurality" column), so columns are matched by name and extras ignored.
#
# "Waiting more than four months" = total waiting - waiting under 120 days.
# Both may be "<5", so the result is carried as a range.

EXTRACT_SHEETS <- c("FSA Waitlist" = "FSA", "Elective Waitlist" = "Treatment")

# Spellings seen in the extracts, mapped to the names used in the ESPI data.
# Names with a macron (U+0101) are built at run time so the file stays ASCII
# and parses in any locale.
DISTRICT_ALIASES <- stats::setNames(
  c("Hawke's Bay", "Tairawhiti", "Waitemata"),
  c("Hawkes Bay", paste0("Tair", intToUtf8(0x101), "whiti"), paste0("Waitemat", intToUtf8(0x101)))
)

normalise_district <- function(x) {
  x <- trimws(x)
  hit <- x %in% names(DISTRICT_ALIASES)
  x[hit] <- unname(DISTRICT_ALIASES[x[hit]])
  x
}

extract_col <- function(raw, pattern, required = TRUE) {
  hit <- grep(pattern, names(raw), ignore.case = TRUE, value = TRUE)
  if (length(hit) == 0) {
    if (required) stop("Extract sheet has no column matching '", pattern, "'", call. = FALSE)
    return(NULL)
  }
  raw[[hit[1]]]
}

read_extract_sheet <- function(path, sheet, vintage) {
  raw <- readxl::read_excel(path, sheet = sheet, col_types = "text", .name_repair = "minimal")
  under <- parse_count(extract_col(raw, "^Waiting under 120 days$"))
  total <- parse_count(extract_col(raw, "^Total Waiting$"))
  eth <- extract_col(raw, "^Ethnicity$", required = FALSE)
  rur <- extract_col(raw, "^Rurality$", required = FALSE)
  tibble::tibble(
    measure = unname(EXTRACT_SHEETS[sheet]),
    month = excel_text_to_date(extract_col(raw, "^Month End Date$")) |>
      lubridate::floor_date("month"),
    region = trimws(extract_col(raw, "^Region$")),
    district = normalise_district(extract_col(raw, "^District$")),
    specialty = trimws(extract_col(raw, "^Specialty$")),
    ethnicity = if (is.null(eth)) NA_character_ else trimws(eth),
    rurality = if (is.null(rur)) NA_character_ else trimws(rur),
    under_lo = under$lo, under_hi = under$hi,
    total_lo = total$lo, total_hi = total$hi,
    suppressed = under$suppressed | total$suppressed,
    unparsed = under$unparsed | total$unparsed,
    vintage = vintage,
    source_file = basename(path)
  )
}

read_extract_file <- function(path, vintage) {
  sheets <- intersect(names(EXTRACT_SHEETS), readxl::excel_sheets(path))
  if (length(sheets) == 0) stop("No waitlist sheets in ", path, call. = FALSE)
  dplyr::bind_rows(lapply(sheets, read_extract_sheet, path = path, vintage = vintage))
}

# One folder per extract, named by financial-year quarter (e.g. 2025-26-Q4).
read_extract_dir <- function(dir = "data/raw/health_targets_extract") {
  folders <- list.dirs(dir, recursive = FALSE)
  folders <- folders[grepl("^\\d{4}-\\d{2}-Q[1-4]$", basename(folders))]
  if (length(folders) == 0) return(NULL)
  dplyr::bind_rows(lapply(folders, function(f) {
    files <- list.files(f, pattern = "\\.xlsx$", full.names = TRUE)
    dplyr::bind_rows(lapply(files, read_extract_file, vintage = basename(f)))
  }))
}

# Collapse ethnicity (treatment list) to district x specialty, and add the
# "waiting more than four months" range. Bounds add, so the sum of ranges is a
# valid range for the total.
tidy_extract <- function(ext) {
  ext |>
    # Per-row range first: summarise() evaluates in order, so computing it
    # after summing totals would use the summed columns.
    dplyr::mutate(row_over_lo = pmax(0, total_lo - under_hi),
                  row_over_hi = pmax(0, total_hi - under_lo)) |>
    dplyr::group_by(vintage, measure, month, region, district, specialty) |>
    dplyr::summarise(
      over_lo = sum(row_over_lo), over_hi = sum(row_over_hi),
      under_lo = sum(under_lo), under_hi = sum(under_hi),
      total_lo = sum(total_lo), total_hi = sum(total_hi),
      suppressed = sum(suppressed), unparsed = any(unparsed),
      under_gt_total = any(under_lo > total_hi),
      under_negative = any(under_hi < 0),
      .groups = "drop"
    )
}

# Health NZ states the extracts cover July 2015 onward; earlier rows in some
# files are not used.
EXTRACT_START <- as.Date("2015-07-01")

# Latest vintage wins for every measure and month it covers.
latest_vintage <- function(tidy) {
  tidy |>
    dplyr::filter(month >= EXTRACT_START) |>
    dplyr::group_by(measure, month) |>
    dplyr::filter(vintage == max(vintage)) |>
    dplyr::ungroup()
}

# Cell-level changes in "waiting more than four months" between consecutive
# vintages, for months present in both (from EXTRACT_START, as published).
extract_revisions <- function(tidy) {
  tidy <- dplyr::filter(tidy, month >= EXTRACT_START)
  v <- sort(unique(tidy$vintage))
  if (length(v) < 2) return(NULL)
  dplyr::bind_rows(lapply(seq_along(v)[-1], function(i) {
    old <- dplyr::filter(tidy, vintage == v[i - 1])
    new <- dplyr::filter(tidy, vintage == v[i])
    keys <- c("measure", "month", "district", "specialty")
    common <- as.Date(intersect(unique(old$month), unique(new$month)), origin = "1970-01-01")
    dplyr::full_join(
      dplyr::filter(old, month %in% common) |> dplyr::select(dplyr::all_of(keys), old_lo = over_lo, old_hi = over_hi),
      dplyr::filter(new, month %in% common) |> dplyr::select(dplyr::all_of(keys), new_lo = over_lo, new_hi = over_hi),
      by = keys
    ) |>
      dplyr::filter(is.na(old_lo) | is.na(new_lo) | old_lo != new_lo | old_hi != new_hi) |>
      dplyr::mutate(from = v[i - 1], to = v[i], .before = 1)
  }))
}

# National effect of each revision step, by measure and month.
revision_summary <- function(tidy) {
  tidy <- dplyr::filter(tidy, month >= EXTRACT_START)
  v <- sort(unique(tidy$vintage))
  if (length(v) < 2) return(NULL)
  nat <- tidy |>
    dplyr::group_by(vintage, measure, month) |>
    dplyr::summarise(over = sum((over_lo + over_hi) / 2), .groups = "drop")
  dplyr::bind_rows(lapply(seq_along(v)[-1], function(i) {
    a <- dplyr::filter(nat, vintage == v[i - 1]) |> dplyr::select(measure, month, before = over)
    b <- dplyr::filter(nat, vintage == v[i]) |> dplyr::select(measure, month, after = over)
    dplyr::inner_join(a, b, by = c("measure", "month")) |>
      dplyr::mutate(from = v[i - 1], to = v[i], change = after - before, .before = 1)
  }))
}
