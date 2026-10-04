# ESPI web tool exports (optional)

The site's main source is the quarterly health target extracts in
`data/raw/health_targets_extract/`. Exports from the ESPI web tool
(https://tewhatuora.shinyapps.io/ESPI_app/) can be added by hand as a
supplement: save the CSV(s) here in a new folder named by the download date
(`YYYY-MM-DD`), unchanged, and rerun the pipeline. Where a month appears in
more than one source, the most recent retrieval is used and the differences
are written to `data/processed/reconciliation.csv`.

The reader (`R/read_espi_app.R`) expects the same eight columns as the OIA
appendices (`REGION_NAME, DHB_NAME, SPECIALTY_NAME, MONTH_YEAR, NUMERATOR,
DENOMINATOR, ESPI_DEFINITION, PERCENTAGE`). If an export differs, the pipeline
stops with a clear error.

An automated headless-browser download was removed in October 2026: it could
not be tested, and the quarterly extracts replace it. It is in the git history
(`R/fetch.R`) if needed.
