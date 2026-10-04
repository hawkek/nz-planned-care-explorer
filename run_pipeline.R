#!/usr/bin/env Rscript
# Run the whole pipeline: read sources, combine, check, model, export.
#
#   Rscript run_pipeline.R            # use whatever raw files are present
#   Rscript run_pipeline.R --fetch    # first try to download from the web tool
#
# Stops before writing any published output if a data check fails.

suppressPackageStartupMessages({
  library(dplyr)
})
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)

args <- commandArgs(trailingOnly = TRUE)
run_date <- Sys.Date()

if ("--fetch" %in% args) {
  message("Fetching from the ESPI web tool")
  files <- fetch_espi_app()
  message("Saved: ", paste(basename(files), collapse = ", "))
}

message("Reading OIA history")
oia <- read_oia_dir()
reference <- build_reference(oia)
definition_map <- distinct(oia, indicator, definition)

message("Reading web tool downloads")
live <- read_espi_app_dir(definition_map)
message(sprintf("  %d rows from %d retrieval(s)", NROW(live),
                length(unique(live$retrieved))))

long_all <- bind_rows(oia, live)
long <- combine_sources(oia, live)
reconciliation <- reconcile_overlap(oia, live)

message("Running checks")
checks <- run_checks(long, reference)
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
readr::write_csv(reconciliation, "data/processed/reconciliation.csv", na = "")
if (!file.exists("data/processed/revisions.csv")) {
  readr::write_csv(mutate(empty_revisions(), detected = as.Date(character())),
                   "data/processed/revisions.csv")
}

version <- data_version("data/processed/espi_long.csv")
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

dir.create("site/downloads", showWarnings = FALSE, recursive = TRUE)
for (f in c("espi_long.csv", "national_monthly.csv", "district_monthly.csv",
            "checks.csv", "reconciliation.csv", "revisions.csv")) {
  file.copy(file.path("data/processed", f), file.path("site/downloads", f),
            overwrite = TRUE)
}

message("Done. Data version ", version)
