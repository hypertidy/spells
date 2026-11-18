# climdex.pcic 1.2-0

- **Source read:** pacificclimate/climdex.pcic `master` at `011cb78`
  (2026-11-05; `git describe`: 1.1-9-15). DESCRIPTION says Version 1.2-0,
  Date 2024-10-07. GPL-3.
- **Not on CRAN.** It was archived on 2023-05-15 ("deadlines were
  repeatedly missed"); the last CRAN version is 1.1-9.1. Its dependency
  **PCICt** (calendars) was archived on 2025-05-03. The November 2026
  commits make CI use a vendored PCICt tarball. So both are GitHub-only,
  and spells can't list climdex.pcic in Suggests for CRAN checks.
- **How:** read 2026-11-17 from source. The two checks below were run on
  2026-11-18 (`checks/climdex.R`, output in `checks/climdex.out`), with
  PCICt 0.5-4.4 from the CRAN archive and climdex.pcic installed from
  GitHub at `011cb78`.
- Paths below are relative to the repo at that commit.

## The spell indices

ETCCDI defines **WSDI** (warm spell duration) and **CSDI** (cold spell
duration) as the annual count of days in runs of at least 6 days with
TX above its 90th percentile (TN below its 10th, for CSDI).
`climdex.wsdi()` and `climdex.csdi()` (`R/threshold_indices.R`) call
`threshold.exceedance.duration.index()` (`R/threshold_utils.R`).

Related indices: **CDD/CWD** (the longest dry or wet run, through
`spell.length.max()`) and **GSL** (growing season length, through
`growing.season.length()`).

## The grid columns

- **Baseline / threshold:** percentiles per day-of-year slot, with
  `base.range` defaulting to 1961–1990 (`R/climdexInput_class.R`,
  `src/zhang_running_quantile.cc`).
  - **The window is 5 days (±2) and wraps within each year at the new
    year:** `wday = (day_idx + dpy) % dpy` in the same year. That's the
    heatwaveR 0.5.5 behaviour, not 1.0.0's.
  - It uses **R's type-8 quantile**, reimplemented in C++, with **no
    smoothing**.
  - A slot is NA when fewer than 10% of its window values are present
    (`min.base.data.fraction.present = 0.1`).
  - **365 slots**: in leap years, 29 February takes 28 February's slot
    (`get.jdays.replaced.feb29()`), and it's left out of the base
    sample. 360-day calendars get 360 slots.
- **The bootstrap applies to the percentage indices only.** Following
  Zhang et al. 2005, TX90p, TN10p and so on use in-base thresholds for
  years inside the base period: for each base year, the average over
  the thresholds recomputed with that year replaced by each of the
  others (`percent.days.op.threshold()`). **WSDI and CSDI use the
  out-of-base thresholds for every year**, the base period included.
- **Direction:** strict comparisons: `>` for WSDI, `<` for CSDI.
- **Persistence:** runs longer than 5 days, so at least 6
  (`select.blocks.gt.length(x, 5)`). No gap joining, no hysteresis.
- **Missing data:** a missing day counts as not exceeding, so it breaks
  the run (`na.value = FALSE`). A year's index is NA if it has more than
  15 missing days or any month has more than 3. A season is NA with more
  than 6, which is new in 1.2-0. There's no interpolation.
- **Season-year attribution is a switch, and the indices differ:**
  - WSDI/CSDI with `spells.can.span.years = FALSE` (the `climdex.wsdi()`
    default, which copies fclimdex): runs are cut at 1 January, and each
    piece has to reach 6 days within its own year.
  - With `TRUE`: runs are found on the whole series, and each day counts
    in the year it falls in, even if that year's part is shorter than 6
    days.
  - CDD/CWD with spans: a run's whole length goes to the year it **ends**
    in. A year that lies entirely inside a run is NA.
- **GSL is a two-condition season:**
  - In the Northern Hemisphere, it starts at the first run of at least 6
    days with Tmean > 5 °C before July, and ends the day before the first
    run of at least 6 days with Tmean < 5 °C from 1 July.
  - In the Southern Hemisphere, the year runs from July to June, the
    split moves to 1 January, and the last year is NA.
  - With no start, the length is 0; with no end, the season runs to the
    end of the year.
  - The experimental `GSL_first`/`GSL_max`/`GSL_sum` modes apply an
    opening and then a closing to `Tmean >= 5`, so the order of the two
    matters, and the comparison is `>=`, not `>`.
- **Time step:** daily. **Calendars:** gregorian, `365_day`/`noleap` and
  `360_day`, through PCICt. That makes it **the one tool in the survey so
  far that reads CMIP `noleap` and `360_day` output**.
- **Metrics:** annual (and for some indices monthly or seasonal)
  aggregates, not per-spell records. Since 1.2-0, `include.exact.dates`
  returns the start and end of the longest CDD/CWD run and of the
  growing season.
- **Categories:** none.
- **Many series:** one station per `climdexInput`. **Streaming:** no.
- **Outputs:** numeric vectors per year, month or season, or data frames
  with `include.exact.dates`.

## What this means for spells

1. **A WSDI/CSDI parity switch** needs:
   - 365 slots, with 29 February in 28 February's slot;
   - a 5-day window that wraps within the year;
   - type-8 quantiles, with no smoothing;
   - a slot that is NA below 10% presence;
   - out-of-base thresholds for every year;
   - strict comparisons, a minimum of 6 and no gap joining;
   - missing days that break the run;
   - the year cut by default, with `spells.can.span.years` as an option;
   - the annual NA rules (more than 15 missing days, or any month with
     more than 3).

   Store the golden outputs, because the package is off CRAN.
2. **Attributing a spell to a season year is part of the def.** The
   survey has four rules so far:
   - by start (heatwaveR and heatwave3 block averages use `date_start`);
   - by end (CDD/CWD);
   - splitting the days by year (WSDI with spans);
   - cutting at the boundary, so each piece must pass the minimum
     (WSDI's default).

   Counts and durations change with the rule.
3. **Slot conventions differ:**
   - heatwaveR: 366 slots, with 29 February filled from its neighbours;
   - MHW-MAD: 366 slots, interpolated;
   - climdex.pcic: 365 slots, 29 February sharing 28 February's slot, or
     360 slots.

   The slot rule belongs in the time-axis definition, and climdex.pcic is
   the prior art for 365- and 360-day calendars.
4. **In-base bootstrap** (Zhang et al. 2005) is a way to estimate the
   baseline for counting indices. It isn't needed for any spell parity
   seen so far.
5. **GSL** is the standard two-condition season with a season year that
   depends on hemisphere: the same shape as ice advance and retreat
   (`massom2013`), with different start and end rules.
6. **Season completeness rules** (at most 15 missing days a year and 3 a
   month) are prior art for the brief's "refuse the season" missing-data
   option.

## Checked by running

On a smooth seasonal series for 1961–1992 (base 1961–1990), with a 9-day
hot spell from 28 December 1991 to 5 January 1992 and a 7-day one in
July 1975:
- **`spells.can.span.years`:** with FALSE (the default), the cross-year
  spell adds nothing to 1991 or 1992, because its pieces are 4 and 5
  days. With TRUE it adds 4 to 1991 and 5 to 1992. Confirmed.
- **Out-of-base thresholds in base years:** `climdex.wsdi()` passes
  `ci@quantiles$tmax$outbase$q90` for every year, and the `inbase`
  thresholds exist but aren't used. The 1975 spell counts its 7 days.
  Confirmed.
