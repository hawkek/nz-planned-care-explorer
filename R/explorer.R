# Data for the home page: three findings, the explorer, and the district
# comparison, all built from the latest health target extract.

MEASURE_LABEL <- c(
  FSA = "first specialist assessment",
  Treatment = "planned treatment"
)
MEASURE_FOR <- c(
  FSA = "a first specialist assessment",
  Treatment = "planned treatment"
)
MEASURE_PHRASE <- c(
  FSA = "waited more than four months for a first specialist assessment",
  Treatment = "waited more than four months for planned treatment"
)

# Aggregate the tidy extract (one measure) to every area x specialty
# combination the explorer offers: districts and New Zealand, each specialty
# and "All".
explorer_series <- function(d) {
  sums <- function(x, area_expr, spec_expr) {
    x |>
      dplyr::mutate(area = {{ area_expr }}, spec = {{ spec_expr }}) |>
      dplyr::group_by(area, spec, month) |>
      dplyr::summarise(o_lo = sum(over_lo), o_hi = sum(over_hi),
                       t_lo = sum(total_lo), t_hi = sum(total_hi), .groups = "drop")
  }
  dplyr::bind_rows(
    sums(d, district, specialty),
    sums(d, "New Zealand", specialty),
    sums(d, district, "All"),
    sums(d, "New Zealand", "All")
  )
}

# Shares as ranges: the smallest possible share waiting over four months
# divides the lowest count by the highest total, and vice versa.
add_shares <- function(s) {
  s |>
    dplyr::mutate(
      o_mid = (o_lo + o_hi) / 2, t_mid = (t_lo + t_hi) / 2,
      p_lo = safe_div(o_lo, t_hi), p_hi = pmin(1, safe_div(o_hi, t_lo)),
      p_mid = safe_div(o_mid, t_mid)
    )
}

build_explorer <- function(lv, measure) {
  d <- dplyr::filter(lv, .data$measure == !!measure)
  months <- seq(min(d$month), max(d$month), by = "month")
  s <- explorer_series(d)
  # Arrays aligned to `months`; months with no rows are null, never zero.
  idx <- match(s$month, months)
  keys <- paste(s$area, s$spec, sep = "|")
  series <- lapply(split(seq_len(nrow(s)), keys), function(i) {
    arr <- function(v) { out <- rep(NA_real_, length(months)); out[idx[i]] <- v[i]; out }
    o <- arr(s$o_lo); t <- arr(s$t_lo)
    list(o = o, od = arr(s$o_hi) - o, t = t, td = arr(s$t_hi) - t)
  })
  nat <- dplyr::filter(s, area == "New Zealand", spec == "All") |> dplyr::arrange(month)
  tr <- smooth_trend_by_system(nat$month, (nat$o_lo + nat$o_hi) / 2)
  # Cells flagged as one-month spikes or dips (see find_extract_spikes()).
  # Values stay as released; the front end marks affected months.
  fl <- find_extract_spikes(d)
  flags <- data.frame(d = fl$district, s = fl$specialty, i = match(fl$month, months) - 1L,
                      dev = round(fl$value - fl$local_median))
  list(
    measure = measure,
    label = unname(MEASURE_LABEL[measure]),
    months = format(months, "%Y-%m"),
    areas = c("New Zealand", sort(unique(d$district))),
    specialties = sort(unique(d$specialty)),
    series = series,
    trend = list(fit = round(tr$fit, 1), lo = round(tr$lo, 1), hi = round(tr$hi, 1)),
    flags = flags
  )
}

# ---- Findings ----------------------------------------------------------------

national_row <- function(s, when) {
  add_shares(dplyr::filter(s, area == "New Zealand", spec == "All", month == when))
}

finding_measure <- function(lv, measure, base = as.Date("2019-01-01")) {
  d <- dplyr::filter(lv, .data$measure == !!measure)
  s <- explorer_series(d)
  latest <- max(d$month)
  now <- national_row(s, latest)
  then <- national_row(s, base)
  ratio <- now$o_mid / then$o_mid
  list(
    measure = measure,
    title = sprintf("%s people have %s", cap_first(fmt_count_range(now$o_lo, now$o_hi)),
                    MEASURE_PHRASE[[measure]]),
    text = paste0(
      sprintf("In %s, that was %s of everyone waiting for %s (%s people). ",
              month_label(latest), fmt_pct_range(now$p_lo, now$p_hi),
              MEASURE_FOR[[measure]], fmt_count_range(now$t_lo, now$t_hi)),
      sprintf("In %s it was %s (%s), so the number is now %s times as high. ",
              month_label(base), fmt_count_range(then$o_lo, then$o_hi),
              fmt_pct_range(then$p_lo, then$p_hi), formatC(ratio, format = "f", digits = 1)),
      sprintf("%s were waiting less than four months, against a health target of 95%% by 2030.",
              cap_first(fmt_pct_range(1 - now$p_hi, 1 - now$p_lo)))
    ),
    series = "New Zealand|All"
  )
}

finding_spread <- function(lv, measure = "FSA") {
  d <- dplyr::filter(lv, .data$measure == !!measure)
  latest <- max(d$month)
  dist <- explorer_series(d) |>
    dplyr::filter(area != "New Zealand", spec == "All", month == latest) |>
    add_shares() |>
    dplyr::mutate(under = 1 - p_mid) |>
    dplyr::arrange(dplyr::desc(under))
  hi <- dist[1, ]; lo <- dist[nrow(dist), ]
  n95 <- sum(dist$under >= 0.95)
  list(
    measure = measure,
    title = sprintf("Districts range from %s to %s waiting under four months",
                    fmt_pct(lo$under), fmt_pct(hi$under)),
    text = sprintf(paste(
      "In %s, the share of people who had waited less than four months for %s",
      "ranged from %s in %s to %s in %s. %s of the %d districts %s at or",
      "above the 95%% health target. Districts provide different mixes of",
      "services, so this is a description, not a ranking of performance."),
      month_label(latest), MEASURE_FOR[[measure]], fmt_pct(lo$under), lo$area,
      fmt_pct(hi$under), hi$area, cap_first(number_word(n95)), nrow(dist),
      if (n95 == 1) "was" else "were"),
    bars = data.frame(d = dist$area, u = round(dist$under, 4),
                      ulo = round(1 - dist$p_hi, 4), uhi = round(1 - dist$p_lo, 4))
  )
}

cap_first <- function(x) paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))

number_word <- function(n) {
  words <- c("none", "one", "two", "three", "four", "five", "six", "seven", "eight",
             "nine", "ten")
  if (n <= 10) words[n + 1] else as.character(n)
}

# ---- District comparison -----------------------------------------------------

build_extract_funnels <- function(lv) {
  out <- list()
  for (m in names(MEASURE_LABEL)) {
    d <- dplyr::filter(lv, measure == m)
    latest <- max(d$month)
    dm <- explorer_series(d) |>
      dplyr::filter(area != "New Zealand", spec == "All", month == latest) |>
      add_shares() |>
      dplyr::transmute(district = area, p_mid, d_mid = t_mid, n_lo = o_lo, n_hi = o_hi)
    f <- funnel_waitlist_share(dm)
    pts <- f$points
    out[[m]] <- list(
      latest = format(latest, "%Y-%m"),
      target = r4(f$target), phi = round(f$phi, 2), tau2 = signif(f$tau2, 3),
      points = data.frame(d = pts$district, size = round(pts$d_mid), y = r4(pts$p_mid),
                          nlo = pts$n_lo, nhi = pts$n_hi, status = pts$status),
      limits = dplyr::mutate(f$limits, dplyr::across(-size, r4), size = round(size)),
      takeaway = takeaway_funnel(pts)
    )
  }
  out
}
