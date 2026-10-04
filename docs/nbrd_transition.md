# The NBRS to NBRD transition (July 2026)

Sources reviewed (4 October 2026):

- *NBRD Data Dictionary*, version 0.3 **draft**, 13 May 2026 (Health NZ).
- *National Booking Reporting System Data Dictionary*, version 4.6, 1 July 2023.
- Health NZ's data dictionaries page (last updated 22 July 2026). It states:
  "The National Booking Reporting Dataset (NBRD) will replace NBRS and NBRS DM
  from 1 July 2026."

The NBRD document is a draft with several items marked "tbd". Everything below
describes what it says as of May 2026, not what Health NZ finally implemented.

## Summary

The OIA history (January 2019 to December 2025) was produced from NBRS. From
July 2026, published waitlist reporting comes from NBRD, which is built from
patient-level submissions to the Rapid waitlist collection. The two systems use
different rules for ESPI 2 and ESPI 5, so **a step in the series at July 2026
should be expected until shown otherwise**. The NBRD dictionary also suggests
that ESPI 1, 3 and 8 may not continue in the same form.

On the other hand, the dictionaries settle the question of which district
patients are counted in, and they point to better measures that can be requested
from Health NZ.

## Findings

### 1. Patients are counted in the district that manages their waitlist entry (resolved)

- NBRS: `Agency code` is "the reporting agency responsible for the booking entry".
- NBRD: `DISTRICT_OF_SERVICE` is "the district managing the waitlist entry".
  Patient residence is held separately (`DOMICILE_CODE`).

So ESPI counts patients in the **district that provides the service**, not the
district where they live. This has two consequences:

- Rates per 100,000 *resident* population would divide a provider count by a
  resident population. For regional services (such as cardiothoracic surgery,
  neurosurgery and paediatric specialties), that is not a meaningful rate. The
  population view should stay switched off. A residence-based version would
  need a data request, since NBRD holds domicile.
- The current district comparison (the share of each district's **own** list)
  is consistent with provider attribution. It remains valid.

### 2. ESPI 2 is now derived from patient-level data with explicit rules

Under NBRS, first specialist assessment (FSA) figures were **aggregate**
submissions by district and specialty. NBRD Appendix 1 says: "All NBRS FSA
statistics are aggregate by district and specialty." NBRD derives FSA figures
from patient-level Rapid records, with these rules:

- Waiting more than four months means `DAYS_SINCE_REFERRAL > 120` days.
  NBRD statistic 522 maps to NBRS statistic 67.
- Included: publicly funded purchasers (`20, 33, 34, 35`, plus null and some
  legacy values) and normal procedures (not staged, planned or surveillance).
- Excluded specialties: `D81, M05, M85, M86, N01, S20`, and any code starting
  with `D, P, Y` or `R`.

The NBRS-era ESPI 2 data includes seven paediatric specialties. If health
specialty codes starting with `P` are the paediatric ones (**not verified**:
this needs Health NZ's health specialty code table), those specialties would
leave ESPI 2 from July 2026. In December 2025 they accounted for about 3,550 of
the 75,160 patients waiting over four months (4.7%), and about 6% of the list.

### 3. ESPI 5's rules change too

| | NBRS-era ESPI 5 | NBRD ESPI 5 |
|---|---|---|
| Clock starts | "assured start date" (commitment to treatment) | `WAITLISTED_DATE` from Rapid. The NBRS assured start date is mapped to this field for history |
| Excluded specialties | `M25, N01, P70` | `M25, N01, P70, M15, M00` |
| Staged, planned, surveillance | excluded | excluded |
| Publicly funded | NBRS flag | Recomputed from purchaser codes. A working group decided on 2 December 2025 not to use the NBRS flag |
| Count of waiting patients | NBRS assured event count | Derived from dates. The same decision says not to use `ASSURED_EVENT_CNT` |

Two specialty codes are added to the exclusions. `M00` may be General Medicine
(**not verified**), which in December 2025 contributed only about 3 patients to
ESPI 5. More important is that the clock may now start when a patient is
**added to the waitlist**, rather than when they were **given a commitment to
treatment**. Whether these are the same date in practice is not stated.

### 4. NBRD's standard statistics cover ESPI 2 and 5 only

The NBRD statistics table lists additions, exits, totals waiting, and counts
waiting more than 4, 6, 9, 12, 24 and 36 months, for FSA and for treatment.
There is nothing equivalent to:

- **ESPI 1** (referrals processed within 15 days). The FSA table has no
  "acknowledged" or "processed" date.
- **ESPI 3** (above the actual treatment threshold without a commitment). The
  treatment table holds CPAC scores, so it could perhaps be derived, but no
  statistic is defined.
- **ESPI 8** (prioritised with national tools). The treatment table holds the
  CPAC scoring system code, so it could perhaps be derived, but again no
  statistic is defined.

These indicators may continue to be produced some other way, or may stop. That
needs asking.

### 5. The history in NBRD is not settled

As of May 2026, "a final decision is yet to be made for inclusion of NBRS
history in NBRD". The planned combined treatment table (NBRS to June 2026,
Rapid from July 2026) "is not produced as yet". For FSA, NBRS history "can only
be incorporated in the KPI table" and was not included. During a parallel-run
period (January to October 2026), NBRS-based and Rapid-based snapshots exist
side by side from 2022 or 2024. That parallel run is exactly the evidence
needed to measure the break. It is internal to Health NZ, so it would have to
be requested.

### 6. Useful new measures (on request)

NBRD defines several measures that NBRS did not have, or that ESPI does not
publish:

- **Exited from the FSA list without being seen** (statistic 513, new). This is
  the closest available measure to the "a district that declines more
  referrals can look better" caveat. It is the most valuable item to request.
- Waiting at or under four months (521 and 621, new). This aligns with the
  health targets' "95% within four months" framing.
- Longer waits: more than 6, 9, 12, 24 and 36 months.
- Additions to and exits from each list.
- Ethnicity and age group. The plan says these are not in ESPI, which is true
  of ESPI itself, but NBRD's statistics table includes both.
- Weekly snapshots.

The NBRS dictionary says, "Customised datasets or summary reports are available
on request" (data-enquiries@health.govt.nz), and charges may apply.

### 7. Licence wording is inconsistent

The NBRD dictionary cover carries a CC BY 4.0 notice. Its Appendix 2 also says
reproduction is allowed only if "the information must not be used for
commercial gain, must not be distorted or changed". The two are not compatible.
This makes confirming the licence for the data itself more important, not less.

## What this means for the tracker

1. **The first live download matters more than before.** The web tool's latest
   12 months will cover roughly October 2025 to August or September 2026. If
   the tool has restated the whole window from NBRD, the overlap with the OIA
   history (October to December 2025) gives a direct, cell-by-cell measure of
   the break. The pipeline already writes this to `reconciliation.csv`. If it
   has not restated them, the step will fall at July 2026 and cannot be
   measured from public data.
2. **Mark the change in the data source** on every chart, and in the data,
   from July 2026 onward. The pipeline now has a warning-level check that fires
   when live data reaches July 2026, and a chart annotation for the change.
3. **Do not join the two systems into one unbroken trend line** until the size
   of the break is known. Smoothed trends and the 24-month projections fitted
   across July 2026 would mix two definitions.
4. **Plan for ESPI 1, 3 and 8 possibly ending in December 2025** in this
   tracker. Keep them as historical context.
5. **Population rates:** keep them off (see finding 1).

## Questions for Health NZ (data-enquiries@health.govt.nz)

1. Does the ESPI web tool now draw on NBRD? If so, from which month, and were
   earlier months restated?
2. Will ESPI 1, 3 and 8 continue to be published after July 2026, and from
   which source?
3. Which health specialty codes are excluded from NBRD ESPI 2 and ESPI 5? In
   particular, are paediatric specialties excluded from ESPI 2, and is `M00`
   General Medicine?
4. Is there a published comparison of NBRS and NBRD figures for the
   parallel-run months, by district and specialty?
5. Could monthly counts of FSA exits without being seen (statistic 513) be
   released by district and specialty from 2022?
6. Which licence applies to ESPI and NBRD data: CC BY 4.0, or the
   non-commercial, no-changes terms in the dictionary's appendix?
