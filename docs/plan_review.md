# Review of the build plan (4 October 2026)

This reviews "NZ Waitlist Tracker: Build Plan" against the data actually
released and against what was built in this repository. Items are ordered by
how much they affect the project.

## 1. Corrections the data forces

**ESPI 1 is a service-level pass/fail, not a referral percentage.** The plan
describes ESPI 1 as "percentage of referrals acknowledged and processed within
15 days, against the 90% expectation". In Appendix One, each row is 0 or 1 of 0
or 1: whether a service met the expectation. The site therefore reports "% of
specialty services meeting the expectation". This is a weaker partial check on
the "fewer accepted referrals" caveat than the plan assumed, because it says
nothing about how many referrals were declined. Consider asking Health NZ
whether referral volumes, or acceptance and decline counts, can be released.
That is the measure that would actually address the plan's main caveat.

**There are no district totals.** The check "district totals equal the sum of
specialties" cannot run on the OIA data. It is implemented, and is skipped with
a note until a source supplies total rows.

**"No missing months" can only be checked nationally.** Individual specialty
series start and stop (55 of 421 ESPI 2 series are incomplete), so a
series-level check would always fail.

**ESPI 3 has a probable break in mid-2022** (from about 228 to about 30
nationally within three months). Ask Health NZ before drawing any conclusion
from ESPI 3 across 2022.

**Numerators above denominators** (13 ESPI 2 rows) and **district-months with
no ESPI 1 services** (12, including Auckland in December 2025) need handling.
Both are now handled and disclosed; see `docs/data_exploration.md`.

## 2. Things that could not be done from this environment

The build environment's network policy blocked these hosts, so the following
plan items are **not done** and need doing from your own machine:

- **Lighthouse search** for an existing waitlist history product
  (lighthouse.tewhatuora.govt.nz was blocked).
- **One current export from the ESPI web tool**, and checking it against the
  OIA columns (tewhatuora.shinyapps.io was blocked). As a result, `R/fetch.R`
  is written but **untested**. The export's columns, the download button's
  selector, and whether there is one file or one per indicator are all
  assumptions. Until this is checked, the monthly Action's fetch step will
  probably fail, and it is designed to fail loudly without publishing.
- **Comparing a month present in both sources** to measure revisions. The code
  is in place (`reconcile_overlap()` writes `data/processed/reconciliation.csv`)
  but has no live data to compare yet.
- **District population source** (Stats NZ and Health NZ sites were blocked).
  Rates per 100,000 are implemented but switched off until
  `data/raw/population/district_population.csv` is added.
- **Licence confirmation** for the web tool data and the OIA release.
- **Health target results** (secondary context in the plan) were not added.

## 3. Changes to the tech stack, and why

The plan's choices were kept where they fit, and changed where they would add
cost without benefit. All of these are easy to reverse.

| Plan | Built | Reason |
|---|---|---|
| R + targets | R, one script (`run_pipeline.R`) | The full pipeline runs in about 25 seconds, so targets' caching saves little and adds a dependency and a learning surface. The functions in `R/` are already split by step, so wrapping them in `_targets.R` later is a short job. |
| pointblank or validate | Base R checks (`R/checks.R`) | 12 checks, each a few lines. They are easier to test and have no extra dependency. Results are written to `checks.csv` and shown on the methods page. |
| ggplot2 + ggiraph/plotly charts | Observable Plot in the browser, data prepared in R | The district and specialty selectors need to run on a static site with no server. Rendering ggplot charts for every district, specialty and indicator would mean hundreds of images or a very large page. All statistics, takeaway sentences and wording stay in R. The browser only draws. The Plot and D3 libraries are vendored in `site/assets/`, so there are no CDN calls. |
| Quarto dashboard format | Quarto website format | Each of the six pages has its own URL, which is better for links from news stories. |
| renv | DESCRIPTION + r-lib/actions | The Action installs current CRAN binaries. This is less strictly reproducible than renv, but there is less to maintain. Add renv if exact versions matter, for example for a paper. |
| GAM or seasonal decomposition | GAM (negative binomial, REML) | As planned. Seasonality is not modelled separately. |
| Funnel: Poisson limits around the national rate per 100,000 | Funnel of share of waiting list, with binomial limits plus overdispersion (Spiegelhalter 2005); population version ready for when data arrives | With lists of thousands of patients, plain Poisson or binomial limits are so narrow that every district falls outside them. The estimated overdispersion factor is about 156 for ESPI 2. Without an adjustment, the funnel plot would mislead. |
| Time to target: simple trend, prediction interval | Log-linear quasi-Poisson on 24 months, with simulated intervals; shown only if the fall is clear and counts average at least 10 | A log-linear model never reaches zero, so the target is "fewer than one expected patient". Under this model every falling district takes more than 10 years. A linear model would give shorter, and less defensible, times. This is a judgement call worth putting to your statistician reviewer. |

## 4. Smaller points on the plan

- **Neutral wording is enforced in code.** The same templates describe rises
  and falls ("X more than", "X fewer than"), and a unit test checks takeaways
  for blame words.
- **Suppression.** Ranges are shown everywhere. Headline figures are rounded
  with "about" only when the range is within 2% of the total.
- **Provider or residence district.** The plan flags this; it is still
  unresolved, and it matters most for regional services (cardiothoracic,
  neurosurgery, paediatric specialties). The methods page says so.
- **Annotations.** COVID-19 Alert Level 4 periods are annotated from memory of
  the public record and marked `verified = no` in `config/annotations.csv`.
  Industrial action was left out rather than guessed. Verify both before
  launch.
- **Schedule.** The dates are consistent: 19 October 2026 is a Monday, and the
  weeks run Monday to Sunday. Digital Health Week dates (18 to 19 November)
  were not checked.
- **Privacy.** The OIA response letter is committed as a raw source. It shows
  the requester's name, as published on FYI.org.nz. Remove it from the repo if
  you would rather not republish that name.
- **The ESPI 2 and 5 denominators** are inferred, not stated. Ask about them in
  the soft-launch check with Health NZ.

## 5. What is left for version 1

1. Run `fetch_espi_app()` by hand, fix the selector or reader, and commit the
   first export. Then check `reconciliation.csv` for overlapping months.
2. Add the population file and confirm the source Health NZ uses.
3. Confirm the licence and the ESPI 2, 3 and 5 denominators with Health NZ.
4. Verify the annotation dates and add industrial action.
5. Enable GitHub Pages (Settings → Pages → Source: GitHub Actions) and merge to
   `main`.
6. Statistician and lay reviews (week 5), accessibility check (week 6).
