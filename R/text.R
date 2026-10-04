# Plain-English takeaway sentences.
#
# Neutral framing: the same words describe a rise or a fall, in every
# district. The text says what the numbers show, never who is responsible.

fmt_int <- function(x) formatC(round(x), format = "d", big.mark = ",")

month_label <- function(d) format(d, "%B %Y")

# A count that may include suppressed cells. If the range is narrow relative
# to its size, give a rounded figure; otherwise give the range.
fmt_count_range <- function(lo, hi) {
  if (is.na(lo) || is.na(hi)) return("unknown")
  if (lo == hi) return(fmt_int(lo))
  mid <- (lo + hi) / 2
  if ((hi - lo) / max(mid, 1) <= 0.05 && mid >= 1000) {
    # Headline rounding: nearest 100 from 10,000, nearest 10 below. "About"
    # marks the figure as rounded; the exact range is in the data tables.
    step <- if (mid >= 10000) 100 else 10
    return(paste("about", fmt_int(round(mid / step) * step)))
  }
  paste(fmt_int(lo), "to", fmt_int(hi))
}

fmt_pct <- function(p, digits = 0) {
  ifelse(is.na(p), "unknown", paste0(formatC(100 * p, format = "f", digits = digits), "%"))
}

fmt_pct_range <- function(lo, hi, digits = 0) {
  a <- fmt_pct(lo, digits); b <- fmt_pct(hi, digits)
  if (identical(a, b)) a else paste(a, "to", b)
}

# "8,300 more than in December 2024" / "8,300 fewer than in December 2024".
# When suppression makes the direction uncertain, say so.
describe_change <- function(now_lo, now_hi, then_lo, then_hi, then_month) {
  ch_lo <- now_lo - then_hi
  ch_hi <- now_hi - then_lo
  when <- paste("in", month_label(then_month))
  if (ch_lo > 0) {
    paste(fmt_change(ch_lo, ch_hi), "more than", when)
  } else if (ch_hi < 0) {
    paste(fmt_change(-ch_hi, -ch_lo), "fewer than", when)
  } else if (ch_lo == 0 && ch_hi == 0) {
    paste("the same as", when)
  } else {
    paste("about the same as", when, "(the difference is within the range of suppressed counts)")
  }
}

fmt_change <- function(a, b) {
  mid <- (a + b) / 2
  if (a == b) return(fmt_int(a))
  if ((b - a) / max(mid, 1) <= 0.05 && mid >= 100) {
    return(paste("about", fmt_int(round(mid / 10) * 10)))
  }
  paste(fmt_int(a), "to", fmt_int(b))
}

# Sentence for a count indicator (ESPI 2, 3, 5) in one area.
takeaway_count <- function(series, ind, area = "New Zealand") {
  s <- dplyr::arrange(series, month)
  last <- utils::tail(s, 1)
  prev <- dplyr::filter(s, month == seq(last$month, by = "-1 year", length.out = 2)[2])
  base <- sprintf(
    "In %s, %s patients in %s were %s",
    month_label(last$month), fmt_count_range(last$n_lo, last$n_hi), area,
    tolower(ind$phrase)
  )
  if (nrow(prev) == 1) {
    base <- paste0(base, ", ", describe_change(last$n_lo, last$n_hi, prev$n_lo,
                                               prev$n_hi, prev$month))
  }
  paste0(base, ".")
}

# Sentence for a percentage indicator (ESPI 1, 8).
takeaway_pct <- function(series, ind, area = "New Zealand") {
  s <- dplyr::arrange(series, month)
  latest <- max(s$month)
  s <- dplyr::filter(s, !is.na(p_lo))
  if (nrow(s) == 0) return(sprintf("%s has no reported %s data.", area, ind$indicator))
  last <- utils::tail(s, 1)
  prev <- dplyr::filter(s, month == seq(last$month, by = "-1 year", length.out = 2)[2])
  gap <- if (last$month < latest) sprintf(
    "No %s figure was reported for %s in %s. ", sub("ESPI", "ESPI ", ind$indicator),
    area, month_label(latest)
  ) else ""
  what <- if (ind$indicator == "ESPI1") {
    "of specialty services in %s processed more than 90%% of referrals within 15 days"
  } else {
    "of patients treated in %s were prioritised using a nationally recognised tool"
  }
  out <- sprintf(paste0(gap, "In %s, %s ", what), month_label(last$month),
                 fmt_pct_range(last$p_lo, last$p_hi), area)
  if (nrow(prev) == 1) {
    out <- paste0(out, sprintf(", compared with %s in %s",
                               fmt_pct_range(prev$p_lo, prev$p_hi),
                               month_label(prev$month)))
  }
  out <- paste0(out, ".")
  # A drop in how many services or patients reported changes what the
  # percentage covers, so say so.
  before <- utils::tail(s, 2)
  if (nrow(before) == 2 && before$d_lo[2] < 0.95 * before$d_lo[1]) {
    unit <- if (ind$indicator == "ESPI1") "services" else "patients"
    out <- paste(out, sprintf(
      "Fewer %s reported than in the month before (%s, compared with %s).",
      unit, fmt_int(before$d_lo[2]), fmt_int(before$d_lo[1])
    ))
  }
  out
}

takeaway_funnel <- function(points, area_col = "district") {
  above <- points[[area_col]][grepl("^above 99.8", points$status)]
  below <- points[[area_col]][grepl("^below 99.8", points$status)]
  list_names <- function(x) {
    if (length(x) == 0) return("none")
    if (length(x) == 1) return(x)
    paste(paste(x[-length(x)], collapse = ", "), "and", x[length(x)])
  }
  sprintf(paste(
    "Districts outside the outer limits differ from the national pattern by more",
    "than chance and normal variation between districts would explain.",
    "Higher share than expected: %s. Lower share than expected: %s."
  ), list_names(above), list_names(below))
}

takeaway_target <- function(proj, area, ind) {
  what <- tolower(ind$phrase)
  if (proj$status == "not shown") {
    return(sprintf("No projection is shown for %s: %s.", area, proj$reason))
  }
  pct <- proj$slope_pct
  # A falling series is described by the size of the fall, so the interval
  # is reported as positive numbers in the same order.
  if (proj$status == "falling") pct <- -pct[c(1, 3, 2)]
  f1 <- function(x) {
    out <- formatC(x, format = "f", digits = 1)
    sub("^-(0\\.0)$", "\\1", out)
  }
  rate <- sprintf("%s%% a month (95%% interval %s%% to %s%%)",
                  f1(pct[1]), f1(pct[2]), f1(pct[3]))
  rate_flat <- sprintf("estimated change %s%% a month; 95%% interval %s%% to %s%%",
                       f1(pct[1]), f1(pct[2]), f1(pct[3]))
  if (proj$status == "rising") {
    return(sprintf(paste(
      "Over the last 24 months the number of patients in %s %s has been",
      "rising, by about %s. On that trend the target is not reached."
    ), area, what, rate))
  }
  if (proj$status == "no clear trend") {
    return(sprintf(paste(
      "Over the last 24 months the number of patients in %s %s shows no clear",
      "rise or fall (%s), so no date can be projected."
    ), area, what, rate_flat))
  }
  mt <- proj$months_to_target
  yrs <- function(m) if (is.infinite(m) || m > 120) "more than 10 years" else
    if (m < 24) paste(round(m), "months") else paste(formatC(m / 12, format = "f", digits = 1), "years")
  sprintf(paste(
    "Over the last 24 months the number of patients in %s %s has been falling,",
    "by about %s. If that trend simply continued, which is not a forecast,",
    "it would reach fewer than one patient in about %s (95%% interval %s to %s)."
  ), area, what, rate, yrs(mt[["mid"]]), yrs(mt[["lo"]]), yrs(mt[["hi"]]))
}
