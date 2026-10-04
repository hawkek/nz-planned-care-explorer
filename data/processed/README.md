# Processed data (generated, not stored in git)

`Rscript run_pipeline.R` writes the tidy tables here on every build, and the
site publishes copies under `downloads/` (listed on the methods page). They are
not committed: the unchanged source files in `data/raw/` are the archive, and
every published version can be rebuilt from them with the code at that commit.

| File | Contents |
|---|---|
| `waitlist_monthly.csv` | Latest health target extract by month, district and specialty, with ranges for suppressed counts |
| `extract_revisions.csv` | Cells that changed between consecutive extracts |
| `espi_long.csv`, `national_monthly.csv`, `district_monthly.csv` | OIA ESPI data |
| `checks.csv` | Results of the data checks |
| `flagged_cells.csv` | One-month spikes and dips (likely reporting errors), published unchanged |
| `reconciliation.csv`, `revisions.csv` | Differences between overlapping ESPI sources and versions |
| `data_version.json` | Hash of the published data |
