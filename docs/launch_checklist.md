# Launch checklist

Status as of 4 October 2026. Tick items off in the pull request or here.

## Done

- [x] Data pipeline: four quarterly health target extracts (vintages),
      OIA history, suppression as ranges, revisions log
- [x] 27 automatic data checks, including Health NZ's published June 2026
      health target results (national mismatch stops publishing)
- [x] 90 unit tests
- [x] Overview, Explore, Methods & data, and referral and prioritisation pages
- [x] Design system (palette checked for colour-vision separation, self-hosted
      fonts, light and dark)
- [x] Keyboard navigation: skip link, visible focus, all controls reachable;
      every chart has a text description and a data table
- [x] Chart annotation dates checked against sources
      (`config/annotations_sources.md`)
- [x] Workflow runs tests and builds the site on pull requests (no deploy)

## Decisions

Recorded in `docs/plan_review.md` as they are made.

- [ ] Data licence: confirm with Health NZ, or publish on the stated CC BY 4.0
      basis
- [ ] OIA response letter (requester's name) in the repository
- [ ] Repository name and web address
- [ ] Version 1 scope: district comparison, referral and prioritisation page
- [ ] Untested ESPI web tool download code
- [ ] Marking flagged data (for example Hawke's Bay, January 2025) on charts
- [ ] Visitor analytics
- [ ] Corrections and contact channel
- [ ] Launch date (election on 7 November 2026)
- [ ] Processed CSVs in git
- [ ] Ethnicity view for treatment waiting lists

## Before publishing

- [ ] First workflow run passes on GitHub (pull request check)
- [ ] Enable GitHub Pages: Settings → Pages → Source: GitHub Actions
- [ ] Merge and check the deployed site
- [ ] Email Health NZ (data-enquiries@health.govt.nz): licence; questions in
      `docs/nbrd_transition.md`; Hawke's Bay January 2025; exits without
      being seen
- [ ] Lighthouse catalogue search for existing waiting list products
- [ ] Read-through of findings and methods by you, a statistician and a
      non-specialist
- [ ] Screen reader (VoiceOver or NVDA), 200% zoom, Safari and iOS check
- [ ] User test with 3 or 4 people next to Health NZ's dashboard (stop/go)
- [ ] Soft launch to Health NZ's data team (definitions check)

## Launch

- [ ] Post with the three findings; health reporters; eHealthNews; NZ R and
      data visualisation groups

## Every quarter

1. Download the new waitlist detail extract into
   `data/raw/health_targets_extract/<YYYY-YY-Qn>/`.
2. Add the quarter's published national and district health target results
   to `config/reference/health_target_fsa.csv` and
   `config/reference/health_target_treatment.csv`, with the new vintage.
3. Push to a branch and open a pull request; check the workflow passes.
4. Read the warnings in `data/processed/checks.csv` and the revisions table.
5. Re-read the three generated findings for accuracy and neutral wording.
6. Add a change log entry on the methods page, then merge.

The Q1 2026/27 extract (expected around December 2026) will probably come from
NBRD. Before merging it, compare the overlapping months with the previous
extract and decide how to present any break.
