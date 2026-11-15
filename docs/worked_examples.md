# Worked examples: from the workbook to the published table

Three figures traced by hand from Health NZ's workbook to this site's output,
as a check that does not rely on the pipeline code. Redo them after any change
to `R/read_extract.R`, and for each new extract.

Workbook: `data/raw/health_targets_extract/2025-26-Q4/waitlist-detail-extract-q4-2025-26.xlsx`.
Published table: `waitlist_monthly.csv` (methods page, Downloads). Traced 15
November 2026 by filtering the workbook separately from the pipeline.

Rules being checked: a "<5" cell is a value from 1 to 4; "waited four months
or more" is total waiting minus waiting under 120 days, worked out row by row
and then added up; a result below zero is taken as zero when a cell is
suppressed.

## 1. National first specialist assessment list, June 2026

Sheet "FSA Waitlist", rows with Month End Date 30 June 2026: 460 rows.

| | Rows with "<5" | Sum of the other rows | Range |
|---|---:|---:|---|
| Total waiting | 12 | 196,648 | 196,648 + 12 × (1 to 4) = **196,660 to 196,696** |
| Waiting under 120 days | 15 | 130,003 | 130,003 + 15 × (1 to 4) = **130,018 to 130,063** |

Four months or more, row by row:

- 445 rows have no suppressed cell. Together with the 3 rows below, their
  totals minus their unsuppressed "under" counts come to 196,648 - 130,003 =
  66,645.
- 3 rows have a number for the total and "<5" for under 120 days. Each takes 1
  to 4 off: 3 to 12 less.
- 12 rows have "<5" in both columns. Each adds 0 to 3: 0 to 36 more.
- Lowest: 66,645 - 12 + 0 = **66,633**. Highest: 66,645 - 3 + 36 = **66,678**.

Published: waiting 196,660 to 196,696; four months or more 66,633 to 66,678
(headline "about 66,700"). Share under four months: 130,018 / 196,696 = 66.1%
to 130,063 / 196,660 = 66.1%. Health NZ's published figure: 66.1%.

## 2. A small suppressed cell: West Coast, Gynaecology, planned treatment, June 2026

Sheet "Elective Waitlist", spreadsheet rows 101301 to 101303:

| Ethnicity | Waiting under 120 days | Total waiting | Four months or more |
|---|---:|---:|---|
| Asian | <5 | <5 | 0 to 3 |
| European/Other | 22 | 23 | 1 |
| Māori | <5 | <5 | 0 to 3 |
| **Sum** | **24 to 30** | **25 to 31** | **1 to 7** |

Published row: waiting 25 to 31, under four months 24 to 30, four months or
more 1 to 7.

## 3. The flagged month: Hawke's Bay, Gynaecology, first specialist assessment, January 2025

Sheet "FSA Waitlist", spreadsheet row 53821:

| Waiting under 120 days | Total waiting |
|---:|---:|
| -204 | 1,043 |

The workbook itself holds a negative count. Four months or more = 1,043 -
(-204) = **1,247**, which is more than the 1,043 people on the list. Published
row: waiting 1,043, under four months -204, four months or more 1,247, shown
unchanged and circled on charts. Health NZ has confirmed that this month is an
error (`docs/health_nz_correspondence.md`).
