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
| Funnel: Poisson limits around the national rate per 100,000 | Funnel of share of waiting list, with binomial limits plus overdispersion (Spiegelhalter 2005); population version ready for when data arrives | With lists of thousands of patients, plain Poisson or binomial limits are so narrow that every district falls outside them. The estimated overdispersion factor is about 156 for ESPI 2 in the OIA data (December 2025) and about 207 for first specialist assessments in the June 2026 extract. Without an adjustment, the funnel plot would mislead. |
| Time to target: simple trend, prediction interval | Log-linear quasi-Poisson on 24 months, with simulated intervals; shown only if the fall is clear and counts average at least 10 | A log-linear model never reaches zero, so the target is "fewer than one expected patient". Under this model every falling district takes more than 10 years. A linear model would give shorter, and less defensible, times. This is a judgement call worth putting to your statistician reviewer. |

## 4. Smaller points on the plan

- **Neutral wording is enforced in code.** The same templates describe rises
  and falls ("X more than", "X fewer than"), and a unit test checks takeaways
  for blame words.
- **Suppression.** Ranges are shown everywhere. Headline figures are rounded
  with "about" only when the range is within 2% of the total.
- **Provider or residence district: resolved.** Both data dictionaries
  attribute patients to the district managing the waitlist entry, which is the
  provider (see `docs/nbrd_transition.md`). Rates per resident population would
  therefore be misleading for regional services. They stay off, and the
  district comparison uses the share of each district's own list.
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

## 5. The July 2026 change of data system

Health NZ replaced NBRS with NBRD from 1 July 2026. Its draft dictionary shows
different rules for ESPI 2 and 5, and no standard statistics for ESPI 1, 3 or 8.
A step in the series at July 2026 should therefore be expected until shown
otherwise. The analysis, its consequences and the questions for Health NZ are
in `docs/nbrd_transition.md`. The pipeline now fits trends and projections
within one system only, flags months from July 2026 onward, and marks the
change on charts.

## 6. Cross-checks and timing (added 4 October 2026)

- **The information gap is smaller than the plan assumed.** Health NZ's
  health target page publishes a quarterly Excel extract of the FSA and elective
  waitlists by district and specialty (elective also by ethnicity) from January
  2015 to June 2026. The tracker's value now rests on specialty-level
  exploration, ESPI 1, 3 and 8 history, plain-English presentation, and
  archiving and revision tracking, not on being the only source of history.
  See `docs/data_exploration.md`. The extract should probably become the
  primary source for the headline measures, with the ESPI web tool as a monthly
  supplement.

- **Health targets.** The published June 2025 first specialist assessment
  result (62.0% waiting under four months) equals 100% minus the ESPI 2 share
  of the list in the OIA data (62.0% to 62.1%). The tracker's headline measure
  is therefore the complement of an official, widely quoted figure. That makes
  it easier to explain, and a mismatch would be immediately visible. District
  results for June 2026 are stored and checked automatically.
- **A data quality issue in the release:** Hawke's Bay, January 2025, looks
  double-counted. Health NZ has since confirmed it is an error and expects to
  correct it by the December 2026 release.
- **Election timing.** Wait times are being quoted in the 2026 election
  campaign (for example, the Health Minister citing health target results on
  1News, 30 September 2026). Launching at the end of November, as planned,
  would most likely fall after the election, but I have not checked the
  election date. A launch during the campaign would raise the risk of the
  tracker being read as partisan, however neutral its wording.

## 7. Layout C and the second ChatGPT review (4 October 2026)

The site now follows layout C:

- a home page with three findings written by the pipeline;
- an explorer (list, area, specialty, compare with New Zealand or another
  district; count and share-under-four-months charts; breakdown; CSV of the
  selection);
- a district comparison;
- ESPI 1, 3 and 8 on a separate "More indicators" page.

The source is the four quarterly health target extracts, treated as vintages.
The latest drives the site, and the others feed a revisions log.

The second ChatGPT review recommends an explorer-only version 1. Most of its
brief was already in place:

- extracts as the source, kept unchanged, with quarterly updates;
- suppression as intervals;
- vintages and a revisions log;
- validation against the Q4 results;
- a static site with no Shiny server.

Points adopted from it:

- comparison against New Zealand or a selected district (on the share chart,
  where the units match);
- the highest value in the history;
- the source extract stated next to the charts;
- a national mismatch with the published health target is now an error that
  stops publishing (districts remain warnings, because two treatment districts
  differ by up to 0.2 points).

Points not adopted, and why:

- targets, renv, janitor and Plotly (see section 3; switching now would cost
  more than it returns);
- a long "wait_duration_category" table (the wide form with low and high
  bounds is equivalent and simpler);
- dropping the three findings and the district comparison (you chose C).

Still open for you to decide:

- whether to keep the district comparison and the More indicators page in
  version 1 (ChatGPT recommends dropping both);
- the name ("NZ Planned Care Explorer" is more accurate than "NZ Waitlist
  Tracker");
- the stop/go test: put the explorer next to Health NZ's own reporting and ask
  a few target users whether it answers specialty-level history questions more
  easily.

### Rename and design (4 October 2026)

- The site is now "NZ Planned Care Explorer".
- The visual design follows your brief: warm off-white page, ink-blue text,
  teal primary series, slate comparison, terracotta for the target line,
  annotations and caveats only; Source Serif 4 headings and Inter body text,
  self-hosted (no third-party font requests).
- Fewer boxes: one white card for the main explorer chart, a strip of
  headline figures, and source, vintage and suppression in a visible "meta
  line".
- Lines carry direct end labels, and the target line is dashed, so
  comparisons do not rely on colour.
- One deviation from the brief: the comparison slate is #7E93A8 rather than
  #657F98, because #657F98 is too close to the teal to tell apart (validator:
  normal-vision delta E 9.6 against a floor of 15). The dark-mode equivalents
  were chosen and checked the same way.
- The Q4 2025/26 factsheet, data caveats and ethnicity/rurality results are
  kept in `docs/references/`. They confirm the treatment measure is "people
  given a commitment to treatment", and explain the small treatment district
  differences: different extraction dates (3 August for the published results,
  2 September for the extract), and unknown ethnicity being excluded from the
  breakdowns.

### UI refinements (4 October 2026)

- Explore is now its own page.
- Navigation: Overview, Explore, Methods & data. The ESPI 1, 3 and 8 page is
  linked from the methods page.
- Two measures: prose about 780px wide, charts and the explorer up to 1080px.
- Explorer order:
  1. the selection spelled out ("Canterbury · First specialist assessment ·
     All specialties");
  2. one dominant figure and its change (arrow and words, no colour);
  3. the main chart;
  4. a quiet source line;
  5. smaller secondary figures;
  6. the supporting chart, table, download and breakdown.
- Shorter repeat headings ("Monthly trend", "Share waiting under four
  months"). I used "waiting under" rather than the suggested "seen within":
  the measure counts people still waiting, not people seen.
- Orange is now limited to finding numbers, the target line and event
  shading.
- Darker, warmer dark mode (colours as suggested; the comparison slate was
  re-checked against the new teal).
- Smaller headings and taller charts on phones, legends stacked, year ticks
  every four years.
- Headline figures round to the nearest 100 (from 10,000) or 10, as
  suggested. The methods page says a rounded figure can fall just outside
  the exact range, which stays in the tables.

## 8. Decisions made (4 October 2026)

| # | Decision | Outcome | Done in the repo |
|---|---|---|---|
| 1 | Data licence | Asked Health NZ; they confirmed the data may be published (`docs/health_nz_correspondence.md`) | `DATA_LICENCE.md`, methods page; draft email in `docs/health_nz_email.md` |
| 2 | OIA response letter (names the requester) | Removed; link to the public FYI.org.nz request instead (it remains in git history) | `data/raw/oia_HNZ00201361/README.md`, methods sources |
| – | Repository name | Renamed to `hawkek/nz-planned-care-explorer` | Links updated |
| 3 | Web address | hawkek.github.io/nz-planned-care-explorer for now; custom domain later if needed | README |
| 4 | Version 1 scope | Keep the district comparison and the referral and prioritisation page; revisit after user testing | No change |
| 5 | ESPI web tool download | Removed (untested, replaced by the extracts); manual exports still readable | `R/read_espi_app.R`; workflow and DESCRIPTION simplified |
| 6 | Flagged data | Circle affected months on charts, with a tooltip and table note; values unchanged | `R/explorer.R`, `site/assets/app.js` |
| 7 | Analytics | GoatCounter (no cookies, no personal data) | Setting in `site/_quarto.yml`; privacy note appears when set |
| 8 | Contact | GitHub issues plus a dedicated email address | Setting in `site/_quarto.yml`; shown in footer and methods when set |
| 9 | Launch timing | Soft launch in October; public launch after the 7 November 2026 election (second half of November) | `docs/launch_checklist.md` |
| 10a | Processed CSVs in git | Stop committing them; rebuilt on every run | `.gitignore`, `data/processed/README.md` |
| 10b | Ethnicity view | After launch, if user testing supports the explorer | `docs/launch_checklist.md` |

## 9. What is left for version 1

1. Run `fetch_espi_app()` by hand, fix the selector or reader, and commit the
   first export. Then check `reconciliation.csv` for October to December 2025.
   That overlap is the only public measure of the NBRS to NBRD break.
2. Send the questions in `docs/nbrd_transition.md` to Health NZ.
3. Population rates: not needed for version 1 (patients are counted by
   provider district).
4. Confirm the licence and the ESPI 3 and 5 denominators with Health NZ. For
   ESPI 2, NBRD defines the denominator as the total waiting for a first
   assessment, which matches the inference for NBRD-era data.
5. Verify the annotation dates and add industrial action.
6. Enable GitHub Pages (Settings → Pages → Source: GitHub Actions) and merge to
   `main`.
7. Statistician and lay reviews (week 5), accessibility check (week 6).
