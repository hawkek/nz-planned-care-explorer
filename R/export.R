# Build the JSON files the website reads, and the CSV downloads.

read_indicators <- function(path = "config/indicators.csv") {
  readr::read_csv(path, show_col_types = FALSE)
}

ind_row <- function(indicators, code) as.list(indicators[indicators$indicator == code, ])

r4 <- function(x) round(x, 4)
r1 <- function(x) round(x, 1)
mstr <- function(d) format(d, "%Y-%m")

write_json <- function(x, path) {
  jsonlite::write_json(x, path, auto_unbox = TRUE, null = "null", na = "null",
                       digits = NA, dataframe = "rows")
}

COUNT_INDICATORS <- c("ESPI2", "ESPI3", "ESPI5")
PCT_INDICATORS <- c("ESPI1", "ESPI8")
HEADLINE <- c("ESPI2", "ESPI5")

series_rows <- function(s, with_trend = FALSE) {
  out <- data.frame(
    m = mstr(s$month), nlo = s$n_lo, nhi = s$n_hi,
    dlo = s$d_lo, dhi = s$d_hi,
    plo = r4(s$p_lo), phi = r4(s$p_hi)
  )
  if (with_trend) {
    out$fit <- r1(s$fit); out$flo <- r1(s$lo); out$fhi <- r1(s$hi)
  }
  out
}

takeaway_for <- function(s, ind, area) {
  if (ind$indicator %in% PCT_INDICATORS) takeaway_pct(s, ind, area)
  else takeaway_count(s, ind, area)
}

build_national <- function(long, indicators) {
  nat <- aggregate_counts(long, c("indicator", "month"))
  out <- list()
  for (code in indicators$indicator) {
    ind <- ind_row(indicators, code)
    s <- dplyr::filter(nat, indicator == code) |> dplyr::arrange(month)
    y <- if (code %in% PCT_INDICATORS) NULL else s$n_mid
    tr <- if (is.null(y)) NULL else smooth_trend_by_system(s$month, y)
    if (!is.null(tr)) s <- dplyr::bind_cols(s, dplyr::select(tr, fit, lo, hi))
    out[[code]] <- list(
      series = series_rows(s, with_trend = !is.null(tr)),
      takeaway = takeaway_for(s, ind, "New Zealand")
    )
  }
  list(json = out, table = nat)
}

latest_by_specialty <- function(dist_spec, latest, prev) {
  now <- dplyr::filter(dist_spec, month == latest)
  before <- dplyr::filter(dist_spec, month == prev) |>
    dplyr::select(district, specialty, indicator, prev_lo = n_lo, prev_hi = n_hi)
  dplyr::left_join(now, before, by = c("district", "specialty", "indicator"))
}

top_list <- function(names, lo, hi, n = 3) {
  o <- order(-(lo + hi))[seq_len(min(n, length(names)))]
  items <- sprintf("%s (%s)", names[o], mapply(fmt_count_range, lo[o], hi[o]))
  if (length(items) == 1) return(items)
  paste(paste(items[-length(items)], collapse = ", "), "and", items[length(items)])
}

build_districts <- function(long, indicators) {
  latest <- max(long$month)
  prev <- seq(latest, by = "-1 year", length.out = 2)[2]
  dist <- aggregate_counts(long, c("indicator", "district", "month"))
  dist_spec <- aggregate_counts(long, c("indicator", "district", "specialty", "month"))
  spec_latest <- latest_by_specialty(dist_spec, latest, prev)
  out <- list()
  for (d in sort(unique(long$district))) {
    inds <- list()
    for (code in indicators$indicator) {
      ind <- ind_row(indicators, code)
      s <- dplyr::filter(dist, district == d, indicator == code) |> dplyr::arrange(month)
      if (nrow(s) == 0) next
      inds[[code]] <- list(series = series_rows(s), takeaway = takeaway_for(s, ind, d))
    }
    specs <- list()
    for (code in HEADLINE) {
      ind <- ind_row(indicators, code)
      sp <- dplyr::filter(spec_latest, district == d, indicator == code) |>
        dplyr::arrange(dplyr::desc(n_mid))
      specs[[code]] <- list(
        rows = data.frame(s = sp$specialty, nlo = sp$n_lo, nhi = sp$n_hi,
                          plo = r4(sp$p_lo), phi = r4(sp$p_hi),
                          prevlo = sp$prev_lo, prevhi = sp$prev_hi),
        takeaway = if (nrow(sp) > 0 && sum(sp$n_hi) > 0) sprintf(
          "In %s, the specialties in %s with the most patients %s were %s.",
          month_label(latest), d, ind$phrase, top_list(sp$specialty, sp$n_lo, sp$n_hi)
        ) else sprintf("In %s, no specialty in %s reported patients %s.",
                       month_label(latest), d, ind$phrase)
      )
    }
    out[[d]] <- list(indicators = inds, specialties = specs)
  }
  list(json = list(latest = mstr(latest), districts = out),
       table = dist, spec_table = dist_spec)
}

build_specialties <- function(long, indicators) {
  latest <- max(long$month)
  prev <- seq(latest, by = "-1 year", length.out = 2)[2]
  nat_spec <- aggregate_counts(long, c("indicator", "specialty", "month"))
  dist_spec <- aggregate_counts(long, c("indicator", "district", "specialty", "month"))
  now <- latest_by_specialty(dist_spec, latest, prev)
  out <- list()
  for (code in HEADLINE) {
    ind <- ind_row(indicators, code)
    specs <- list()
    for (sp in sort(unique(long$specialty[long$indicator == code]))) {
      s <- dplyr::filter(nat_spec, indicator == code, specialty == sp) |> dplyr::arrange(month)
      dd <- dplyr::filter(now, indicator == code, specialty == sp) |>
        dplyr::arrange(dplyr::desc(n_mid))
      if (nrow(dd) == 0) next
      share_ok <- !is.na(dd$p_mid)
      specs[[sp]] <- list(
        series = series_rows(s),
        national_takeaway = takeaway_count(s, ind, paste(sp, "across New Zealand")),
        districts = data.frame(d = dd$district, nlo = dd$n_lo, nhi = dd$n_hi,
                               dlo = dd$d_lo, dhi = dd$d_hi,
                               plo = r4(dd$p_lo), phi = r4(dd$p_hi),
                               prevlo = dd$prev_lo, prevhi = dd$prev_hi),
        takeaway = if (sum(dd$n_hi) > 0) sprintf(
          "In %s, the districts with the most %s patients %s were %s.%s",
          month_label(latest), sp, ind$phrase, top_list(dd$district, dd$n_lo, dd$n_hi),
          if (any(share_ok)) sprintf(
            " As a share of each district's %s waiting list, the highest was %s (%s).",
            sp, dd$district[share_ok][which.max(dd$p_mid[share_ok])],
            fmt_pct(max(dd$p_mid[share_ok]))
          ) else ""
        ) else sprintf("In %s, no district reported %s patients %s.",
                       month_label(latest), sp, ind$phrase)
      )
    }
    out[[code]] <- specs
  }
  list(latest = mstr(latest), indicators = out)
}

build_funnels <- function(district_table, indicators, population) {
  latest <- max(district_table$month)
  out <- list(latest = mstr(latest))
  for (code in HEADLINE) {
    dm <- dplyr::filter(district_table, indicator == code, month == latest)
    f <- funnel_waitlist_share(dm)
    pts <- f$points
    entry <- list(
      target = r4(f$target), phi = round(f$phi, 2), tau2 = signif(f$tau2, 3),
      points = data.frame(d = pts$district, size = pts$d_mid, y = r4(pts$p_mid),
                          nlo = pts$n_lo, nhi = pts$n_hi, status = pts$status),
      limits = dplyr::mutate(f$limits, dplyr::across(-size, r4), size = round(size)),
      takeaway = takeaway_funnel(dplyr::rename(pts, district = district))
    )
    if (!is.null(population)) {
      fp <- funnel_population_rate(dm, population)
      if (!is.null(fp)) {
        entry$population <- list(
          target = r1(fp$target), phi = round(fp$phi, 2),
          points = data.frame(d = fp$points$district, size = fp$points$population,
                              y = r1(fp$points$rate), status = fp$points$status),
          limits = dplyr::mutate(fp$limits, dplyr::across(-size, r1)),
          takeaway = takeaway_funnel(fp$points)
        )
      }
    }
    out[[code]] <- entry
  }
  out
}

build_targets <- function(national_table, district_table, indicators) {
  out <- list()
  one <- function(s, area, ind) {
    s <- dplyr::arrange(s, month)
    # Only the current source system is used, so a fit never spans July 2026.
    current <- source_system(s$month) == source_system(max(s$month))
    p <- project_to_target(s$month[current], s$n_mid[current])
    if (!all(current) && p$status == "not shown") {
      p$reason <- "the data source changed in July 2026 and there are not yet 24 months under the new system"
    }
    hist <- utils::tail(s, 36)
    list(
      status = p$status,
      takeaway = takeaway_target(p, area, ind),
      history = data.frame(m = mstr(hist$month), nlo = hist$n_lo, nhi = hist$n_hi),
      fitted = if (!is.null(p$fitted)) data.frame(m = mstr(p$fitted$month), fit = r1(p$fitted$fit)),
      path = if (!is.null(p$path) && p$status == "falling")
        data.frame(m = mstr(p$path$month), fit = r1(p$path$fit),
                   lo = p$path$lo, hi = p$path$hi),
      months = if (!is.null(p$months_to_target)) as.list(r1(p$months_to_target))
    )
  }
  for (code in HEADLINE) {
    ind <- ind_row(indicators, code)
    areas <- list(`New Zealand` = one(dplyr::filter(national_table, indicator == code),
                                      "New Zealand", ind))
    for (d in sort(unique(district_table$district))) {
      s <- dplyr::filter(district_table, indicator == code, district == d)
      if (nrow(s) > 0) areas[[d]] <- one(s, d, ind)
    }
    out[[code]] <- areas
  }
  out
}

data_version <- function(path) {
  substr(digest_file(path), 1, 12)
}

digest_file <- function(path) {
  # tools::md5sum avoids a dependency on the digest package.
  unname(tools::md5sum(path))
}
