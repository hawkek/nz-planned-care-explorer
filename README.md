# NZ Waitlist Tracker

A free, open-source tracker of New Zealand hospital waitlists since January
2019, by district and specialty, built on Health NZ's elective services patient
flow indicators (ESPI).

Health NZ's ESPI web tool shows the latest 12 months. In March 2026 Health NZ
released the ESPI history from January 2019 to December 2025 under the Official
Information Act (HNZ00201361). Health NZ also publishes a quarterly health
target extract of the first specialist assessment and elective waitlists by
district and specialty since 2015. This project brings these together into one
checked, documented and archived record, and presents it in plain English with
open data downloads.

**Independent project, not endorsed by Health NZ. Not medical advice.** The data
counts patients accepted onto waitlists; it cannot tell anyone how long they
will wait.

## What it shows

| Page | What it does |
|---|---|
| Waiting lists (home) | Three automatically written findings; an explorer of first specialist assessment and planned treatment waitlists by district and specialty since July 2015, with comparison against New Zealand or another district; and a district comparison |
| More indicators | ESPI 1, 3 and 8 (referral processing, treatment threshold, prioritisation tools), 2019 to 2025, from the OIA release |
| Methods and data | Definitions, caveats, revisions between extracts, data checks, downloads, change log |

## How it works

```
data/raw/            health target extracts (one folder per quarter), OIA appendices
                     and web tool downloads, never edited
R/read_extract.R     read the quarterly extracts; vintages and revisions
R/explorer.R         explorer series, findings, district comparison
R/checks_extract.R   checks for the extracts, including against published results
R/read_oia.R         read ESPI tables; "<5" becomes the range 1 to 4
R/fetch.R            download from the web tool (headless Chrome; untested, see file)
R/clean.R            combine sources (latest retrieval wins), log revisions
R/checks.R           data checks; any error stops publishing
R/models.R           aggregates with ranges, GAM trends, funnel limits, projections
R/text.R             neutral plain-English takeaway sentences
R/export.R           JSON for the site
run_pipeline.R       runs all of the above
data/processed/      tidy CSVs (published as downloads) and the revisions log
site/                Quarto website; charts drawn in the browser with Observable Plot
tests/testthat/      unit tests
.github/workflows/   monthly fetch, check, build and publish to GitHub Pages
docs/                data exploration, plan review, draft findings
```

## Running it

Requirements: R 4.3 or later with `dplyr, jsonlite, lubridate, MASS, mgcv, readr,
readxl, tibble` (plus `testthat` for tests and `chromote` for fetching), and
[Quarto](https://quarto.org) 1.6 or later.

```sh
Rscript tests/testthat.R          # unit tests
Rscript run_pipeline.R            # read, check, model, export
Rscript run_pipeline.R --fetch    # also try to download from the web tool
quarto preview site               # view the site locally
```

To add a month by hand, save the web tool export in
`data/raw/espi_app/<YYYY-MM-DD>/` and rerun the pipeline.

## Publishing

1. In the GitHub repository settings, set Pages → Source to "GitHub Actions".
2. Push to `main`. The workflow tests, rebuilds and deploys the site.
3. Each quarter, add Health NZ's new waitlist detail extract to
   `data/raw/health_targets_extract/<YYYY-YY-Qn>/` and push. If a data check
   fails, the run fails, GitHub emails the owner, and the last good site stays
   live. Add the quarter's published national and district health target
   results to `config/reference/` so the check against them runs.

## Status

See `docs/plan_review.md` for what is done and what is open. In short: four
quarterly extracts and the OIA history are loaded, checked and published, and
the latest extract reproduces Health NZ's published June 2026 health target
results. The licence confirmation and user testing are still to do.

## Licence

Code: MIT (`LICENSE`). Data: Health New Zealand | Te Whatu Ora; see
`DATA_LICENCE.md`. Vendored chart libraries: Observable Plot and D3 (ISC),
licences in `site/assets/`.
