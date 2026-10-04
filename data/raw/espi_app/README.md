# ESPI web tool downloads

One folder per retrieval, named by the date of download (`YYYY-MM-DD`), holding
the files exactly as downloaded. Never edit these files; the pipeline reads
every folder and uses the most recent figures for each month.

Automatic route: `Rscript run_pipeline.R --fetch` (or the monthly GitHub
Action) calls `fetch_espi_app()` in `R/fetch.R`. That function is untested
against the live app; see the note at the top of the file.

Manual route: open https://tewhatuora.shinyapps.io/ESPI_app/, download the CSV
export for each indicator, and save the files here in a new dated folder.
The reader expects the same eight columns as the OIA appendices
(`REGION_NAME, DHB_NAME, SPECIALTY_NAME, MONTH_YEAR, NUMERATOR, DENOMINATOR,
ESPI_DEFINITION, PERCENTAGE`). If the export differs, the pipeline stops with
a clear error, and `read_espi_app_file()` needs adjusting.
