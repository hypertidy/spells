# lfstat 0.9.15

- **Source read:** the CRAN tarball `lfstat_0.9.15.tar.gz` (published
  2026-10-11). GitHub: mundl/lfstat.
- **How:** read 2026-11-17 from source. **Not run.**
- Paths below are relative to the package source.

## What it is

Low-flow and streamflow-drought statistics for daily discharge. The
event code is `find_droughts()` and the `pool_*()` functions, with
`summary.deficit()` for the event table (`R/pooling.R`). `streamdef()`
(`R/6streamdef.R`) is the older interface for the same ideas.

## The grid columns

- **Baseline / threshold:** a quantile of discharge over **the whole
  record**, with no reference period. The default is the 5th
  percentile; `"Q95"` and the like are a shortcut for `1 − 95/100`
  (`vary_threshold()`, `.quant_character()` in `R/misc.R`). It can vary
  by `varying`:
  - `"constant"`;
  - `"monthly"`, `"weekly"` or `"daily"`, grouped by `%m`, `%V` or `%j`
    with no window or smoothing. A code comment notes that "%j does not
    work properly for leap years": after 28 February, a leap year's days
    are compared with the next day's threshold.
  - seasonal, from start dates the user gives.
- **Direction:** below. A day is a deficit when `threshold − Q >= 0`, so
  it includes Q equal to the threshold.
- **Persistence and pooling, the richest set in the survey:**
  - **Runs:** consecutive deficit days. **A missing day always ends a
    run** (`group(new.group.na = TRUE)`).
  - **IT pooling** (`pool_it`, inter-event time): consecutive events are
    joined while the days between them are fewer than `tmin` (5 by
    default, so gaps of 4 days or less). Joins chain.
  - **IC pooling** (`pool_ic`, inter-event time and volume criterion):
    the same, and the **excess volume** between the events, divided by
    the deficit volume pooled so far, must also be below `ratio` (0.1).
    So joining depends on magnitude as well as time.
  - **MA pooling** (`pool_ma`): a 10-day centred moving average of the
    discharge, then detection again against the same threshold.
  - **SP, sequent peak** (`pool_sp`): an event starts on the first day
    the deficit increases. It runs until the cumulative deficit falls
    below zero again, so surplus days inside are allowed until the
    deficit is repaid. This is a storage rule, a kind of hysteresis.
  - **The minimum comes after pooling:** `summary(x, drop_minor = …)`
    drops events once they're pooled. So the order is closing, then
    opening, the reverse of Hobday's.
  - The default `drop_minor` is a volume below **0.5% of the largest
    event's volume**, or a duration below 5 days. The volume rule depends
    on the data set.
- **Missing data:**
  - missing days end events;
  - `pool_it()` can join two events separated only by a missing day;
  - `lfnainterpolate()` interpolates every gap linearly with no length
    limit (`approx`, so the ends stay missing);
  - `lfnacheck()` reports missing days by hydrological year and run
    length.
- **Time step:** daily (regularised xts, by `interval`). **Calendar:**
  gregorian.
- **Season year:** hydrological years (`water_year()`, `R/hyear.R`):
  - the start month can be given by name or number, or by convention:
    `"din"` November, `"usgs"` and `"swiss"` October, `"glacier"`
    September;
  - **the label is a choice**: `assign = "majority"`, `"start"` or
    `"end"`, meaning the calendar year that holds most of the months, or
    the start, or the end.
- **Metrics per event** (`summarize.drought()`):
  - `start`, `end`, and `time` (the time of maximum depletion, for SP);
  - `duration`, which includes the pooled gaps, and **`dbt`, the days
    below the threshold**;
  - `volume`, the pooled deficit, in which the excess volumes between
    pooled events count negatively, and **`vbt`, the volume below the
    threshold only**;
  - `qmin` and `tqmin`.

  Volumes are in m³, with units read from the data.
- **Categories:** none. **Many series:** one station per call, plus a
  multi-station report (`multistationsreport()`). **Streaming:** no.
- **Outputs:** a `deficit` xts with `event.no` per day, and a
  `summaryDrought` data frame per event.

## What this means for spells

1. **Joining gaps can depend on more than time.** The persistence model
   needs room for:
   - inter-event time alone (heatwaveR's `maxGap`, lfstat's IT);
   - a magnitude condition as well (IC: the excess between events,
     relative to the deficit so far);
   - smoothing and detecting again (MA);
   - a storage rule (SP), where a spell lasts until its cumulative
     deficit is repaid.

   These are different closings. The def names which one, with its
   parameters.
2. **The order of closing and opening is real here:** lfstat joins first
   and filters minor events after, where Hobday does the reverse. That
   confirms the brief's "order of the two" as a def parameter.
3. **Report both durations and both volumes.**
   - Duration with joined gaps, and the steps actually beyond the
     threshold (`dbt`).
   - Cumulative intensity with the joined gaps counted (negatively
     here), and the part beyond the threshold only (`vbt`).

   heatwaveR's cumulative intensity includes the joined days. Spells
   should say which it reports, and offer both.
4. **No minimum relative to the data set.** "0.5% of the largest event"
   changes past events as data is added, like Ocetrac's area
   percentile. Fixed thresholds only.
5. **The season-year label needs a rule:** lfstat's
   `assign = majority | start | end` is the most explicit version found.
6. **Slots:** grouping by `%j` misaligns leap years. That's one more
   reason the slot rule must be explicit (see climdex.pcic.md).
7. **Not an oracle** for the ocean presets. It is the reference if spells
   ever takes a streamflow-drought preset. The man page calls IC "Lena
   Tallaksen's inter event time and volume criterion"; the reference is
   Tallaksen and Van Lanen 2004, *Hydrological Drought*.
