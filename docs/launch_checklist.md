# Launch checklist

Status as of 4 October 2026. Decisions are recorded in
`docs/plan_review.md`, section 8.

## Done

- [x] Data pipeline: four quarterly health target extracts (vintages),
      OIA history, suppression as ranges, revisions log
- [x] 27 automatic data checks, including Health NZ's published June 2026
      health target results (national mismatch stops publishing)
- [x] 96 unit tests
- [x] Overview, Explore, Methods & data, and referral and prioritisation pages
- [x] Design system (palette checked for colour-vision separation, self-hosted
      fonts, light and dark)
- [x] Keyboard navigation: skip link, visible focus, all controls reachable;
      every chart has a text description and a data table
- [x] Likely reporting errors circled on charts, values unchanged
- [x] Chart annotation dates checked against sources
      (`config/annotations_sources.md`)
- [x] Workflow tests and builds pull requests without publishing
- [x] All ten launch decisions made (see `docs/plan_review.md`)

## Your actions before the soft launch (October)

- [x] Check the pull request's workflow run passes on GitHub (#2, 4 October)
- [x] Enable GitHub Pages: Settings → Pages → Source: GitHub Actions
- [x] Create a GoatCounter account and put the site code in
      `site/_quarto.yml` (`goatcounter`: nz-planned-care-explorer)
- [ ] Create a project email address and put it in `site/_quarto.yml`
      (`contact-email`)
- [x] Merge the pull request; site live at
      https://hawkek.github.io/nz-planned-care-explorer/ (4 October)
- [ ] Send `docs/health_nz_email.md` to data-enquiries@health.govt.nz
- [ ] Lighthouse catalogue search for existing waiting list products
- [ ] Read-through of findings and methods by you, a statistician and a
      non-specialist
- [ ] Screen reader (VoiceOver or NVDA), 200% zoom, Safari and iOS check
- [ ] User test with 3 or 4 people (journalist, clinician or planner, data
      person, member of the public) next to Health NZ's dashboard: stop/go
- [ ] Soft launch: share with testers and Health NZ's data team

## Public launch (second half of November, after the 7 November election)

- [ ] Re-check findings and figures against the latest Health NZ factsheet
- [ ] Post with the three findings; health reporters (RNZ, Stuff, The Post,
      NZ Herald); eHealthNews; NZ R and data visualisation groups
- [ ] Track page views (GoatCounter), stars, mentions and contacts

## After launch

- [ ] Decide on a treatment ethnicity view, informed by user testing
- [ ] Custom domain, if media use warrants it

## Every quarter

1. Download the new waitlist detail extract into
   `data/raw/health_targets_extract/<YYYY-YY-Qn>/`.
2. Add the quarter's published national and district health target results
   to `config/reference/health_target_fsa.csv` and
   `config/reference/health_target_treatment.csv`, with the new vintage.
3. Push to a branch and open a pull request; check the workflow passes.
4. Read the warnings in the checks table and the revisions table (methods page
   of the `site-preview` artifact).
5. Re-read the three generated findings for accuracy and neutral wording.
6. Add a change log entry on the methods page, then merge.

The Q1 2026/27 extract (expected around December 2026) will probably come from
NBRD. Before merging it, compare the overlapping months with the previous
extract and decide how to present any break.
