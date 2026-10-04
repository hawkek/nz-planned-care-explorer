#!/usr/bin/env Rscript
# Run the whole pipeline: read sources, combine, check, model, export.
#
#   Rscript run_pipeline.R
#
# Stops before writing any published output if a data check fails.

suppressPackageStartupMessages({
  library(dplyr)
})
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)

run_date <- Sys.Date()

message("Reading OIA history")
oia <- read_oia_dir()
reference <- build_reference(oia)
definition_map <- distinct(oia, indicator, definition)

message("Reading web tool downloads")
live <- read_espi_app_dir(definition_map)
message(sprintf("  %d rows from %d retrieval(s)", NROW(live),
                length(unique(live$retrieved))))

message("Reading health target extracts")
ext <- read_extract_dir()
ext_tidy <- tidy_extract(ext)
ext_latest <- latest_vintage(ext_tidy)
message(sprintf("  %d rows from %d extract(s); latest %s", nrow(ext),
                length(unique(ext$vintage)), max(ext$vintage)))

long_all <- bind_rows(oia, live)
long <- combine_sources(oia, live)
reconciliation <- reconcile_overlap(oia, live)

message("Running checks")
checks <- bind_rows(
  run_checks(long, reference),
  run_extract_checks(ext, ext_tidy, ext_latest, reference$districts, list(
    FSA = read_reference("config/reference/health_target_fsa.csv"),
    Treatment = read_reference("config/reference/health_target_treatment.csv")
  ))
)
print(select(checks, severity, passed, n_failing, check), n = Inf)
stop_on_errors(checks)

message("Modelling")
indicators <- read_indicators()
population <- read_population()
national <- build_national(long, indicators)
districts <- build_districts(long, indicators)
specialties <- build_specialties(long, indicators)
funnels <- build_funnels(districts$table, indicators, population)
targets <- build_targets(national$table, districts$table, indicators)
explore <- lapply(c(FSA = "FSA", Treatment = "Treatment"), build_explorer, lv = ext_latest)
findings <- list(
  finding_measure(ext_latest, "FSA"),
  finding_measure(ext_latest, "Treatment"),
  finding_spread(ext_latest, "FSA")
)
ext_funnels <- build_extract_funnels(ext_latest)
ext_revs <- extract_revisions(ext_tidy)
ext_rev_summary <- revision_summary(ext_tidy)

message("Writing outputs")
dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
previous <- read_previous_long()
pub <- publishable(long)
revisions <- log_revisions(pub, previous, run_date)
message(sprintf("  %d changed cells since the previous version", nrow(revisions)))

readr::write_csv(pub, "data/processed/espi_long.csv", na = "")
readr::write_csv(
  transmute(national$table, indicator, month, count_lo = n_lo, count_hi = n_hi,
            denominator_lo = d_lo, denominator_hi = d_hi, suppressed_cells = n_suppressed,
            proportion_lo = p_lo, proportion_hi = p_hi),
  "data/processed/national_monthly.csv", na = ""
)
readr::write_csv(
  transmute(districts$table, indicator, district, month, count_lo = n_lo, count_hi = n_hi,
            denominator_lo = d_lo, denominator_hi = d_hi, suppressed_cells = n_suppressed,
            proportion_lo = p_lo, proportion_hi = p_hi),
  "data/processed/district_monthly.csv", na = ""
)
readr::write_csv(select(checks, -example), "data/processed/checks.csv", na = "")
readr::write_csv(
  bind_rows(
    find_spikes(long) |> mutate(source = "OIA HNZ00201361", measure = indicator) |> select(-indicator),
    find_extract_spikes(ext_latest) |> mutate(source = paste("Health target extract", max(ext$vintage)))
  ) |> select(source, measure, month, district, specialty, value, local_median),
  "data/processed/flagged_cells.csv", na = ""
)
readr::write_csv(
  ext_latest |>
    transmute(measure, month, region, district, specialty,
              waiting_lo = total_lo, waiting_hi = total_hi,
              under_4_months_lo = under_lo, under_4_months_hi = under_hi,
              over_4_months_lo = over_lo, over_4_months_hi = over_hi, vintage) |>
    arrange(measure, month, district, specialty),
  "data/processed/waitlist_monthly.csv", na = ""
)
readr::write_csv(if (is.null(ext_revs)) tibble() else ext_revs,
                 "data/processed/extract_revisions.csv", na = "")
readr::write_csv(reconciliation, "data/processed/reconciliation.csv", na = "")
if (!file.exists("data/processed/revisions.csv")) {
  readr::write_csv(mutate(empty_revisions(), detected = as.Date(character())),
                   "data/processed/revisions.csv")
}

version <- substr(digest_text(paste(
  digest_file("data/processed/espi_long.csv"),
  digest_file("data/processed/waitlist_monthly.csv")
)), 1, 12)
sources <- long |>
  group_by(source, retrieved) |>
  summarise(first = min(month), last = max(month), rows = n(), .groups = "drop")

meta <- list(
  built = format(run_date),
  data_version = version,
  first_month = format(min(long$month), "%Y-%m"),
  latest_month = format(max(long$month), "%Y-%m"),
  sources = mutate(sources, retrieved = format(retrieved),
                   first = format(first, "%Y-%m"), last = format(last, "%Y-%m")),
  indicators = indicators,
  checks = select(checks, check, severity, passed, n_failing, detail),
  annotations = readr::read_csv("config/annotations.csv", show_col_types = FALSE) |>
    mutate(start = format(start), end = format(end)),
  population_available = !is.null(population),
  extract = list(
    vintages = sort(unique(ext$vintage)),
    latest_vintage = max(ext$vintage),
    first_month = format(min(ext_latest$month), "%Y-%m"),
    latest_month = format(max(ext_latest$month), "%Y-%m"),
    revisions = if (is.null(ext_rev_summary)) list() else
      ext_rev_summary |>
        group_by(from, to, measure) |>
        summarise(months = n(), max_abs = round(max(abs(change))),
                  max_month = format(month[which.max(abs(change))], "%Y-%m"),
                  mean_abs = round(mean(abs(change))), .groups = "drop")
  ),
  districts = reference$districts
)
writeLines(jsonlite::toJSON(list(data_version = version, built = format(run_date)),
                            auto_unbox = TRUE, pretty = TRUE),
           "data/processed/data_version.json")

dir.create("site/data", showWarnings = FALSE, recursive = TRUE)
write_json(meta, "site/data/meta.json")
write_json(national$json, "site/data/national.json")
write_json(districts$json, "site/data/districts.json")
write_json(specialties, "site/data/specialties.json")
write_json(funnels, "site/data/funnel.json")
write_json(targets, "site/data/target.json")
write_json(explore$FSA, "site/data/explore_fsa.json")
write_json(explore$Treatment, "site/data/explore_treatment.json")
write_json(findings, "site/data/findings.json")
write_json(ext_funnels, "site/data/funnel_extract.json")

dir.create("site/downloads", showWarnings = FALSE, recursive = TRUE)
for (f in c("espi_long.csv", "national_monthly.csv", "district_monthly.csv",
            "checks.csv", "flagged_cells.csv", "reconciliation.csv", "revisions.csv",
            "waitlist_monthly.csv", "extract_revisions.csv")) {
  file.copy(file.path("data/processed", f), file.path("site/downloads", f),
            overwrite = TRUE)
}

message("Done. Data version ", version)
