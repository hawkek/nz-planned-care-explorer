# NZ Waitlist Tracker

A free, open-source tracker of New Zealand hospital waitlists since January
2019, by district and specialty, built on Health NZ's elective services patient
flow indicators (ESPI).

Health NZ's ESPI web tool shows only the latest 12 months. In March 2026 Health
NZ released the history from January 2019 to December 2025 under the Official
Information Act (HNZ00201361). This project joins the two into one continuous,
checked and documented record, and publishes it as a static website with open
data downloads.

**Independent project, not endorsed by Health NZ. Not medical advice.** The data
counts patients accepted onto waitlists; it cannot tell anyone how long they
will wait.

## What it shows

| Page | Question |
|---|---|
| National | Are waits getting better or worse? (ESPI 2 and 5, with ESPI 1, 3 and 8 for context) |
| My district | How is my district doing, and which specialties have the most people waiting? |
| Specialties | Where in the country is the wait for this specialty longest? |
| Fair comparisons | Which districts differ from the national pattern by more than chance? (funnel plot) |
| Time to target | If the recent trend continued, when would no one wait over four months? (illustrative) |
| Methods and data | Definitions, caveats, data checks, downloads, change log |

## How it works

```
data/raw/            OIA appendices and dated web tool downloads, never edited
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
3. On the 15th of each month the workflow also fetches new data and commits it.
   If the fetch or a data check fails, the run fails, GitHub emails the owner,
   and the last good site stays live.

## Status

See `docs/plan_review.md` for what is done and what is open. In short: the OIA
history is fully loaded, checked and published. The live web tool fetch, the
population denominators and the licence confirmation are still to do.

## Licence

Code: MIT (`LICENSE`). Data: Health New Zealand | Te Whatu Ora; see
`DATA_LICENCE.md`. Vendored chart libraries: Observable Plot and D3 (ISC),
licences in `site/assets/`.
