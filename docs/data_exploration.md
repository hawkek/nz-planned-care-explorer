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
| ESPI 2, patients waiting more than 4 months for a first specialist assessment | 10,250 | 85,960 (Jan 2025) | 77,770 | 75,160 |
| ESPI 2, share of the waiting list | 8.6% | 41.8% (Mar 2025) | | 37.8% |
| ESPI 5, patients waiting more than 4 months after a commitment to treatment | 4,400 | 35,900 (Jan 2025) | 33,050 | 27,740 |
| ESPI 5, share of those with a commitment | 10.2% | 44.1% (Feb 2023) | | 35.3% |

Suppression adds a range of a few hundred to the national totals (for example,
75,039 to 75,285 for ESPI 2 in December 2025), which is under 0.5% of the
total. The ranges matter more at district and specialty level.
