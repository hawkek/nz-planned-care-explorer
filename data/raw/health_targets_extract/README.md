# Health NZ waitlist detail extracts (health targets)

Quarterly Excel extracts published with Health NZ's health targets results
("Access current & historical detail data"). One folder per extract, named by
the extraction date stated in the file, holding the file unchanged.

`2026-09-02/waitlist-detail-extract-q4-2025-26.xlsx` (Q4 2025/26):

- **FSA Waitlist**: month end, region, district, specialty, waiting under 120
  days, total waiting. January 2015 to June 2026 (the contents sheet says July
  2015, but the data starts in January 2015). 37 specialties. No ethnicity.
- **Elective Waitlist**: the same, plus ethnicity (Asian, European/Other,
  Māori, Pacific). 25 specialties with different names from ESPI (for example
  "Orthopaedic Surgery", "Otorhinolaryngology (ENT)").
- "Data is sourced from live data in Te Whatu Ora national collections (NBRS)".
  It "may be different from previously published official figures due to
  ongoing data quality improvements". Values from 1 to 4 appear as "<5".

The pipeline does not read this file yet; see `docs/data_exploration.md` for
how it compares with the OIA release.
