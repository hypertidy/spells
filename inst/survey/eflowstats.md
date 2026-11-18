# EflowStats 5.2.0

- **Source read:** DOI-USGS/EflowStats `main` at `84e78fc` (2023-09-22),
  tag v5.2.0. CC0. Mills, Blodgett, Smith and Kiesel. The DESCRIPTION
  date (2017-08-04) is out of date.
- **Not on CRAN**, and never has been (there's no CRAN archive). It
  installs from GitHub (`remotes::install_github("doi-usgs/EflowStats@v5.2.0")`).
  The README says USGS resources cover maintenance and questions; the
  last commit is from 2023.
- **How:** read 2026-11-18 from source, including the
  `packageDiscrepencies` vignette. **Not run.**
- Paths below are relative to the repo at that commit.

## What it is

A reimplementation of the USGS Hydrologic Index Tool (HIT, Henriksen et
al. 2006): 171 indices of daily streamflow, plus the "Magnificent
Seven" (Archfield et al. 2013). The event indices are the high and low
pulse counts and durations (FH, FL, DH, DL) and two timing indices
(TH3, TL3). All of them are built on one function, `find_events()`
(`R/find_events.R`), with `find_eventDuration()` on top.

## The grid columns

- **Baseline:** none, and no seasonal threshold. Every threshold is one
  number for the whole record:
  - quantiles of daily flow over **the whole record**, type 6 (25th,
    75th);
  - multiples of the median (1×, 3×, 7×), 5% of the mean, or the median
    of the annual minima;
  - a **flood threshold** from annual instantaneous peaks, another
    series (`get_peakThreshold()`). It's the 60th percentile (type 6) of
    the log peaks, converted to a daily flow by regressing the log daily
    flow on the log peak for the peak days.
    - The docs call the 60th percentile the 1.67-year flood and the 80th
      the 5-year flood. With T = 1/(1 − p) those would be 2.5 and 5
      years; with T = 1/p, 1.67 and 1.25. So the two labels don't follow
      one rule.
    - It assigns peaks to water years with the default `wyMonth` (10),
      whatever `wyMonth` the caller gave.
- **Direction:** strict: `>` for high flows, `<` for low.
- **Persistence:** runs of consecutive steps (`rle()`). **No minimum
  duration and no gap joining**: a one-day pulse is an event.
- **Missing data: refused.** `validate_data()` rejects any NA, and every
  year has to be complete (365 or 366 days). `cut_dataToWaterYear()`
  drops incomplete first and last years.
- **Censoring:** `find_eventDuration(trim = TRUE)` drops events that
  touch the start or end of the record, "because an accurate duration
  can't be calculated". It defaults to FALSE, and no index sets it
  (TH3 passes FALSE explicitly).
- **Time step:** daily. **Calendar:** gregorian.
- **Season year:** a water year starting in `wyMonth` (10 by default)
  or the calendar year.
  - **The label changed in 5.2.0** (`R/get_waterYear.R`, 2023): it's now
    the calendar year holding most of the months, so the start year if
    `wyMonth` < 7 and the end year otherwise. Before, it was always the
    end year, so `wyMonth = 1` labelled calendar 2000 as water year
    2001.
  - `get_waterYearDay()` counts days from the start of the water year,
    so after 29 February a leap year's days sit one slot later. TH3
    groups by that day (the same misalignment as lfstat's `%j`).
    `calc_timingAverage()` drops 29 February instead.
  - The vignette says HIT and EflowStats before 5.0 dropped the 366th
    day of a leap year, not 29 February.
- **Assigning events to years differs between indices in the same
  package:**
  - **FH1–FH11 and FL1–FL3** (counts) find events in each year's data
    separately, so an event that crosses the boundary is cut, and counts
    once in each year.
  - **DH15 and DL16** (pulse duration) find events on the whole record,
    then divide each year's event days by the number of distinct events
    touching the year. A crossing event's days are split between years,
    and it counts as an event in both.
  - **DH22–DH24** find events in each year's data, and the code says so:
    "the event duration gets artificially cut short at the beginning
    and end of the year".
  - **DH17–DH21** use the whole record with no years: the mean duration
    of all events. The 5.0 rewrite changed this from the mean of yearly
    means, to follow Henriksen et al.
- **Years with no events count differently:**
  - FL1 and FH1 set them to 0;
  - FL3 drops them (`na.omit`), so it averages over the years with an
    event only;
  - DH23 includes them as 0 (`find_eventDuration()` returns 0), though
    its docs say "for years in which floods occur". Its code also takes
    the longest flood of each year, where the docs speak of the number
    of flood days.
- **Smoothing:** centred rolling means (3, 7, 30 and 90 days,
  `RcppRoll::roll_mean`'s default alignment) for the annual maxima and
  minima. Since 5.0 they're computed on the whole record and then split
  by year; before, each year was smoothed separately, which added edges
  at every year boundary.
- **TH3 is a spell on a climatology:** the longest run below the flood
  threshold in the per-day maximum over all years, divided by 365. It
  doesn't wrap from the last day of the water year to the first.
- **Metrics:** none per event, apart from duration. The outputs are
  summaries: event counts per year, mean or median durations, the
  longest run, and their coefficients of variation. `pref` picks the
  mean or the median.
- **Categories:** none. **Many series:** one gauge per call.
  **Streaming:** no.
- **Outputs:** data frames of index names and values, rounded to
  `digits` (3).

## What this means for spells

1. **Not an oracle for spells.** It has no persistence rules, and its
   thresholds come from the whole record. It is the reference for HIT
   indices if spells ever takes a streamflow preset. Its tests compare
   against its own stored outputs (`tests/testthat/data`), not HIT's.
2. **"The whole record" is a reference period that moves.** EflowStats,
   lfstat and ClimInd all take thresholds from the whole record, so
   adding a year changes every past event. Spells can allow it for
   parity, but the def should record it as the reference period, and
   streaming needs a fixed one.
3. **A threshold can come from another series:** EflowStats' flood
   threshold is fitted on annual instantaneous peaks and applied to
   daily flow. The def records the probability, not a recurrence-
   interval label, because the conversions differ.
4. **The season-year rule is needed per summary, not per package.**
   Within EflowStats, counts cut events at the boundary and durations
   split them, so the same event is attributed differently by two
   indices. Spells' summaries should all follow the one rule in the def,
   and a crossing event counting once in each year it touches is a
   rule to name (WSDI with spans counts days, not events).
5. **Seasons with no spells: zero or excluded.** FL1 counts them as 0,
   FL3 leaves them out. Means of per-season summaries change with the
   choice, so it belongs in the def.
6. **Censoring by dropping** (`trim`) is the alternative to spells'
   flagging. Flagging keeps the information; a parity switch could
   drop.
7. **Centred smoothing doesn't stream without a delay.** A centred
   k-step mean needs k/2 steps after the one being assessed. That's
   another reason the analysis-space transforms record their alignment
   (SPEI's trailing sum streams; lfstat's MA pooling and these rolling
   means are centred).
8. **Slot rules change between versions here too:** HIT dropped day 366
   in leap years, EflowStats 5 drops 29 February, and TH3's water-year
   day misaligns leap years.
