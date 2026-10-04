# Data exploration: OIA release HNZ00201361

This profiles the five appendices as released (January 2019 to December 2025).
All figures come from the files in `data/raw/oia_HNZ00201361/` and the
pipeline outputs in `data/processed/`. Counts with suppressed cells are given
as the midpoint of their range unless stated.

## Structure

All five workbooks have one sheet and the same eight columns:
`REGION_NAME, DHB_NAME, SPECIALTY_NAME, MONTH_YEAR, NUMERATOR, DENOMINATOR,
ESPI_DEFINITION, PERCENTAGE`. One reader handles all of them.

| ESPI | Rows | Specialties | Numerator "<5" | Denominator "<5" |
|---|---:|---:|---:|---:|
| 1 | 34,879 | 37 | 0% | 0% |
| 2 | 33,667 | 36 | 16.7% | 2.4% |
| 3 | 14,758 | 12 | 4.9% | 0.7% |
| 5 | 16,505 | 19 | 13.7% | 3.1% |
| 8 | 14,381 | 12 | 5.4% | 5.2% |

- 84 months in every appendix, with no national-level gaps.
- 20 districts (the former DHBs) in 4 regions, with each district always in
  the same region.
- No duplicate month, district and specialty rows. No negative counts. No
  values other than integers and "<5".
- `PERCENTAGE` equals numerator divided by denominator wherever both are
  numbers, and is empty wherever either is "<5" or the denominator is 0. The
  pipeline recomputes percentages from the counts and ignores this column.
- `MONTH_YEAR` is a date (the first of the month).

## Findings that change how the data must be used

1. **ESPI 1 counts services, not referrals.** Every ESPI 1 row has a
   denominator of 0 or 1 and a numerator of 0 or 1: it records whether that
   specialty service in that district met the "more than 90% within 15 days"
   expectation. The build plan describes ESPI 1 as "percentage of referrals
   acknowledged and processed within 15 days". With this data, the only
   possible national figure is the **percentage of services meeting the
   expectation**, and large and small services count equally.

2. **Some district-months have no ESPI 1 services at all.** There are 12 such
   cases, including **Auckland in December 2025** and Hawke's Bay in September
   and October 2025. The national ESPI 1 figure for December 2025 (86%)
   therefore covers 395 services rather than the usual 427 to 432. The site's
   takeaway sentence says so automatically whenever the reporting base drops by
   more than 5%.

3. **ESPI 2 has 13 rows where the numerator is larger than the denominator**
   (for example, Hawke's Bay Gynaecology in January 2025: 1,247 waiting over
   four months, of 1,043 on the list). Five of these rows have a denominator of
   0. They are kept in the counts but excluded from the share-of-list figures,
   and are listed by the "Numerator is not larger than denominator" check. They
   are worth raising with Health NZ.

4. **ESPI 3 drops sharply between June and September 2022**, from about 228
   to about 30 patients nationally, and stays between about 10 and 30
   afterwards. A fall that large and that fast looks more like a change in
   method or recording than a change in practice, but the data alone cannot
   tell. Treat ESPI 3 before and after mid-2022 as possibly not comparable
   until Health NZ confirms otherwise.

5. **Specialty series start and stop.** 55 of the 421 district and specialty
   series in ESPI 2, and 29 of the 212 in ESPI 5, have fewer than 84 months:
   services were added, removed or renamed. A missing row is not the same as
   zero, so district totals are sums of the rows present. Any check for "no
   missing months" must therefore be at national level, which is what the
   pipeline does.

6. **There are no district total rows.** The plan's check that "district totals
   equal the sum of specialties" cannot run on the OIA data. It is implemented
   and will run automatically if a web tool export includes totals.

7. **Denominators are not defined in the OIA letter.** Their meaning is
   inferred from their size: for ESPI 2, about 199,000 in December 2025, which
   is consistent with all patients waiting for a first specialist assessment.
   This needs confirming before share-of-list figures are relied on.

## National picture

| | Jan 2019 | Peak | Dec 2024 | Dec 2025 |
|---|---:|---:|---:|---:|
| ESPI 2, patients waiting more than 4 months for a first specialist assessment | 10,250 | 85,960 (Jan 2025; about 3,400 of this looks like a Hawke's Bay double count, see below) | 77,770 | 75,160 |
| ESPI 2, share of the waiting list | 8.6% | 41.8% (Mar 2025) | | 37.8% |
| ESPI 5, patients waiting more than 4 months after a commitment to treatment | 4,400 | 35,900 (Jan 2025) | 33,050 | 27,740 |
| ESPI 5, share of those with a commitment | 10.2% | 44.1% (Feb 2023) | | 35.3% |

Suppression adds a range of a few hundred to the national totals (for example,
75,039 to 75,285 for ESPI 2 in December 2025), which is under 0.5% of the
total. The ranges matter more at district and specialty level.

## Cross-checks against figures published elsewhere (added 4 October 2026)

### Health target dashboard: a direct match

Health NZ's health target for first specialist assessment is "the number of
patients waiting at the end of the period and of those how many have been
waiting less than 4 months". That is 100% minus the ESPI 2 share of the list.

| Month | Published | OIA data |
|---|---:|---:|
| June 2025 (Q4 2024/25) | 62.0% | 62.0% to 62.1% |

This match supports three things:

- the ESPI 2 denominator is the total waiting for a first assessment, as
  inferred;
- the quarterly health target is the end-of-quarter snapshot;
- the OIA history agrees with what Health NZ itself publishes, at least for
  that month.

The dashboard also gives district values for June 2026 (Q4 2025/26). They are
stored in `config/reference/health_target_fsa.csv`, and checked automatically
once a live download covers June 2026. June 2026 is also the last month before
NBRD, so it is the best available benchmark for the NBRS-era data.

*Correction (4 October 2026):* an earlier version of this note said the
treatment health target was not comparable with ESPI 5. That compared June
2026 (72.6%) with December 2025 (64.6%), which are different months. Health
NZ's detail extract (below) shows the elective waitlist measure closely tracks
ESPI 5. The two are closely aligned but not identical.

### A secondary source: a Policywise article (insurance broker)

The article quotes January figures from an OIA response (May 2024) and from
Ministry of Health ESPI reports, apparently as published at the time. It is a
commercial site with an interest in long waits, so its numbers are treated as
secondary. Even so, they are useful for checking revisions.

| January | ESPI 2, article | ESPI 2, OIA 2026 | ESPI 5, article | ESPI 5, OIA 2026 |
|---|---:|---:|---:|---:|
| 2019 | 10,208 | 10,155 to 10,344 | 4,368 | 4,331 to 4,478 |
| 2020 | 14,721 | 14,653 to 14,851 | 7,732 | 7,712 to 7,835 |
| 2021 | 20,185 | 19,884 to 20,088 | 11,922 | 11,892 to 11,985 |
| 2022 | 36,183 | 35,710 to 35,923 | 21,783 | 21,655 to 21,691 |
| 2023 | 51,849 | 51,417 to 51,597 | 32,260 | 31,541 to 31,613 |
| 2024 | 74,450 | 74,381 to 74,552 | 32,507 | 30,048 to 30,096 |
| 2025 | 77,972 | **85,873 to 86,047** | 37,337 | 35,863 to 35,941 |

- For 2019 to 2024, ESPI 2 agrees within about 1%. ESPI 5 is lower in the 2026
  release for 2023 to 2025, by up to 2,400 (7%) in January 2024. This is
  consistent with later revisions to provisional data, but the article cannot
  show which version is right.
- **January 2025 ESPI 2 is about 8,000 higher in the OIA release.** About 3,400
  of that is a **Hawke's Bay anomaly**: almost every Hawke's Bay specialty
  roughly doubled in January 2025 and returned to normal in February. For
  example, Gynaecology went 616, 1,247, 619; Ophthalmology 569, 1,142, 596;
  Urology 243, 501, 240. That pattern looks like a duplicated data load. For
  February 2025, the article's specialty figures are also lower than the OIA's,
  most of all for Ophthalmology (5,866 against about 8,640). Much of that gap
  is Auckland, whose Ophthalmology count rose from 2,100 in December 2024 to
  3,600 in March 2025. Whether this is a real rise, late reporting, or a revision
  cannot be told from the data.

### Consequences

1. The **January 2025 "peak" of about 86,000 is partly an artefact.** Without
   the Hawke's Bay doubling, January 2025 would be about 82,800, and the
   highest month would be February 2025 (about 83,000). `docs/findings.md` has
   been corrected.
2. A new warning-level check flags one-month spikes and dips (more than 300
   patients and 40% away from the surrounding five-month median). It finds 6
   cells: the 4 Hawke's Bay cells above, Canterbury General Surgery in February
   2019 (11, against about 406), and Southern Orthopaedics in February 2020
   (117, against about 466). They are published unchanged and listed in
   `data/processed/flagged_cells.csv`.
3. Revisions of a few percent to provisional figures are normal for this data,
   which is a further reason to log every revision (`revisions.csv`).

## Health NZ's waitlist detail extract (Q4 2025/26, extracted 2 September 2026)

Health NZ publishes, alongside the health target results, an Excel extract of
the first specialist assessment (FSA) and elective treatment waitlists by
month, district and specialty. For elective treatment it also includes
ethnicity. The extract covers **January 2015 to June 2026** and is sourced from
NBRS. It is stored unchanged in `data/raw/health_targets_extract/`.

### How it compares

Waiting more than four months is total waiting minus waiting under 120 days.
Suppressed cells are taken at their midpoint.

| Month | FSA, extract | ESPI 2, OIA | Elective, extract | ESPI 5, OIA |
|---|---:|---:|---:|---:|
| Jan 2019 | 10,201 | 10,250 | 4,358 | 4,404 |
| Jan 2022 | 35,780 | 35,816 | 21,638 | 21,673 |
| Jan 2024 | 74,451 | 74,466 | 30,001 | 30,072 |
| Jan 2025 | 85,945 | 85,960 | 35,728 | 35,902 |
| Feb 2025 | 86,126 | 83,042 | 34,982 | 35,172 |
| Jun 2025 | 74,538 | 73,154 | 26,645 | 26,919 |
| Dec 2025 | 74,878 | 75,162 | 27,082 | 27,742 |
| Jun 2026 | 66,638 | (not in OIA) | 20,283 | (not in OIA) |

- **FSA matches ESPI 2** almost exactly for most months, as you would expect
  from the same NBRS source. In December 2025, 406 of 418 district and
  specialty cells agree to within 3 patients. The largest difference is
  Auckland Ophthalmology (3,685 in the OIA release, 3,449 in the extract).
  February and June 2025 differ by 1,400 to 3,100, which looks like later
  revisions.
- **The Hawke's Bay January 2025 doubling is in the extract too**, so it is
  in Health NZ's live data, not an OIA processing error.
- **The extract reproduces the health target dashboard.** All 20 district FSA
  results for June 2026 match the dashboard to 0.1 percentage points, and so
  does the national 66.1%. That also confirms the values transcribed in
  `config/reference/health_target_fsa.csv`.
- **Elective treatment is close to ESPI 5** (within about 1% to 3%), but not
  identical. The specialty names and groupings differ (25 against 19).

### What the extract means for the project

The plan's premise was that only the latest 12 months are public. **That is
no longer true:** Health NZ publishes the FSA and elective waitlists by
district and specialty back to 2015, updated quarterly, together with an
interactive dashboard of district, region and ethnicity results. What remains
distinctive about the explorer:

- **ESPI 1, 3 and 8** history, which is only in the OIA release.
- **Specialty-level exploration.** The health target dashboard shows district,
  region and ethnicity, but (in the pages seen) no specialty view.
- **Plain-English, mobile-first, neutral presentation** with counts as well as
  percentages, and trends since 2015 or 2019.
- **Archiving and revision tracking** of each release, which the official
  tools do not offer.
- Reconciliation across sources, and handling of the NBRD transition.

The extract is also a **better primary source** than the ESPI web tool for
ESPI 2 and 5-type measures. It is an official file download rather than a
Shiny app to scrape, it goes back further, and it is updated quarterly.
