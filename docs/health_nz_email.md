# Draft email to Health NZ

To: data-enquiries@health.govt.nz
Subject: Reuse of health target waitlist extracts and ESPI data in an independent public explorer

---

Kia ora,

I am building NZ Planned Care Explorer, an independent, non-commercial, open
source website that makes Health NZ's published waiting list data easier to
explore by district and specialty over time. It uses the quarterly health
target waitlist detail extracts (July 2015 to June 2026) and the ESPI data
released under OIA HNZ00201361. The code and methods are public at
https://github.com/hawkek/nz-planned-care-explorer, and I plan to launch
publicly in the second half of November. It credits Health NZ on every page
and states that it is not endorsed by Health NZ.

I have a few questions. Answers to any of them would help.

**Reuse**

1. May I republish the waitlist detail extracts and the OIA ESPI data, and
   tidy tables derived from them, under the Creative Commons Attribution 4.0
   licence that covers Health NZ's website content? I ask because the NBRD
   data dictionary also includes wording that restricts commercial use and
   changes, and I want to get this right. The site is non-commercial.

**Data quality**

2. In the extracts and the OIA release, almost every Hawke's Bay first
   specialist assessment specialty roughly doubles in January 2025 and
   returns to normal in February (for example Gynaecology 616, 1,247, 619).
   Is this a known data issue? The site shows the values as released, marked
   as a possible reporting error.

**The move from NBRS to NBRD (July 2026)**

3. Will the Q1 2026/27 waitlist extract come from NBRD, and will earlier
   months be restated on the new basis?
4. Which health specialty codes are excluded from the NBRD first specialist
   assessment and elective measures? In particular, are paediatric
   specialties excluded from the first specialist assessment measure?
5. Is there a published comparison of NBRS and NBRD figures for the months
   when both ran in parallel?
6. Will ESPI 1 (referral processing), ESPI 3 and ESPI 8 continue to be
   published after July 2026?

**Data request**

7. Could monthly counts of people removed from the first specialist
   assessment list without being seen (NBRD statistic 513) be released by
   district and specialty, from 2022? This would help readers interpret
   waiting list changes, since a list can shrink when referrals are declined
   as well as when people are seen.

**Definitions check**

8. Before launch, would someone in the data or elective services team be
   willing to look over the definitions on the methods page? I am asking for
   a check of accuracy, not an endorsement.

Ngā mihi,

[Your name]
[Contact email]

---

Notes for sending:

- Questions 3 to 6 come from `docs/nbrd_transition.md`; question 7 is the most
  useful data request identified so far.
- Record the reply in `DATA_LICENCE.md` (question 1) and in
  `docs/plan_review.md`.
- If Health NZ asks for the downloads to be removed, delete the download links
  on the methods page and the copy step in `run_pipeline.R`; the charts can
  stay, as they reproduce published figures.
