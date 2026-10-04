# Health NZ waitlist detail extracts (health targets)

Quarterly Excel extracts published with Health NZ's health targets results
("Access current & historical detail data"). One folder per extract, named by
financial-year quarter (`2025-26-Q4`), holding the file unchanged. The pipeline
reads every folder: the latest quarter is used for the site, and earlier ones
are compared with it to log revisions.

| Folder | Months | Notes |
|---|---|---|
| 2025-26-Q1 | Jun 2015 to Sep 2025 | Extra "Quarter when Data Extracted" and "Rurality" columns; rurality filled for some recent rows; one district spelt "Hawkes Bay" |
| 2025-26-Q2 | Jul 2015 to Dec 2025 | Quarter label column; treatment sheet labelled "Treatment Waitlist" |
| 2025-26-Q3 | Jan 2015 to Mar 2026 | Extracted 28 May 2026 |
| 2025-26-Q4 | Jan 2015 to Jun 2026 | Extracted 2 September 2026 |

The Q4 file in detail:

- **FSA Waitlist**: month end, region, district, specialty, waiting under 120
  days, total waiting. January 2015 to June 2026 (the contents sheet says July
  2015, but the data starts in January 2015). 37 specialties. No ethnicity.
- **Elective Waitlist**: the same, plus ethnicity (Asian, European/Other,
  Māori, Pacific). 25 specialties with different names from ESPI (for example
  "Orthopaedic Surgery", "Otorhinolaryngology (ENT)").
- "Data is sourced from live data in Te Whatu Ora national collections (NBRS)".
  It "may be different from previously published official figures due to
  ongoing data quality improvements". Values from 1 to 4 appear as "<5".

Months before July 2015 are not used, because Health NZ describes the extracts
as starting in July 2015. See `docs/data_exploration.md` for how the extracts
compare with the OIA release.
