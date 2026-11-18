# marineHeatWaves and xmhw (Python)

- **Sources read:**
  - **marineHeatWaves**: ecjoliver/marineHeatWaves at `d7292bf`
    (2022-05-19; last push 2024-07-16), Eric Oliver. The original
    Python implementation of Hobday et al. 2016, which heatwaveR follows.
    One module, `marineHeatWaves.py`.
  - **xmhw**: coecms/xmhw at `1006312` (2025-09-02), version 1.0.0
    (`conda/meta.yaml`), Apache-2.0, from the ARC Centre of Excellence for
    Climate Extremes (Paola Petrelli). An xarray/dask rewrite of
    marineHeatWaves.
- **How:** read 2026-11-18 from source. xmhw was then checked by running
  the same day (`checks/xmhw.py` and `.out`). xmhw 1.0.0 was installed by
  the user into the system Python, and its files are identical to the
  source read. The libraries were xarray 2026.9.0, pandas 2.3.3 and numpy
  2.5.1. One xarray behaviour that xmhw relies on was checked too
  (`checks/xarray-maxgap.py`). marineHeatWaves was **not run**: its
  values below are worked from its code. Points marked *(checked)* were
  confirmed by running xmhw; *(to confirm)* ones are read from the code.

## marineHeatWaves `detect()`

- **Slots:** 366, through a 2012 calendar. 29 February is skipped when
  pooling; its threshold and climatology are then the mean of 28
  February's and 1 March's. No rounding.
- **Window:** ±5 days (`windowHalfWidth`) **in the time index**, around
  every occurrence of the slot in the climatology period. Indices are
  limited only by the ends of the input series, so **at the ends of the
  climatology period the window takes days from outside it** when the
  series extends further. heatwaveR 1.0.0 shortens the window there
  instead, and 0.5.5 wraps within the year.
- **Statistics:** `np.nanpercentile` (linear, type 7) and `np.nanmean`, so
  missing values drop out of the pool.
- **Smoothing:** a 31-day running mean that treats the 366-slot year as
  periodic (`runavg()`).
- **Climatology period:** defaults to the whole record;
  `alternateClimatology` takes another series for the baseline.
- **Missing data, and a doc mismatch:** the docstring says the default
  `maxPadLength = False` "interpolates over all missing values". The code
  only calls `pad()` when `maxPadLength` is truthy, so **by default
  nothing is interpolated**. Missing values are then set to the seasonal
  climatology, so they break events. With `maxPadLength = n`, runs of up
  to n are interpolated linearly, and `np.interp` fills leading and
  trailing runs with the nearest valid value.
- **Exceedance:** `temp − thresh > 0`, strict. Runs by `ndimage.label`.
- **Persistence:** runs of at least `minDuration` (5) first, then joining
  of gaps up to `maxGap` (2) between them. No special case at the end of
  the series, so heatwaveR 0.5.5's trailing-gap join isn't here.
- **Metrics:** duration (with the joined gaps), intensities relative to
  the climatology, to the threshold and absolute (max, mean, variance,
  cumulative), the peak by the anomaly, and onset and decline rates that
  assume the event starts and ends half a day beyond its first and last
  days.
  - **The decline period at the series end tests the wrong thing.** The
    comment says that if the peak is on the series' last day, the
    period is 1 day. The code tests `tt_peak == T − 1`, but `tt_peak`
    counts from the event's start, so it's almost never true. An event
    that ends on the last day and peaks there gets a period of 0, so a
    rate of 0/0. xmhw copied the test and gives NaN *(checked in xmhw)*.
- **Categories:** `floor(1 + (temp − thresh) / (thresh − seas))` per
  day; the event's category is the highest, capped at 4. **Joined gap
  days below the threshold fall in no category**, so with gaps joined,
  `duration_moderate` + … + `duration_extreme` is less than `duration`.
  (The brief's trend.sst rule counts them as category I.)
- **Cold spells:** the series is negated, so the threshold is the 10th
  percentile under linear interpolation.
- **`blockAverage()`**, yearly by default:
  - counts, durations, intensities and rates go to **the start year**;
  - `total_days` is split by year;
  - category days count by the year of each day;
  - *(to confirm)* `total_icum`: the comment says "assigned to its start
    year", but for an event that spans years, `iBlock` has just been
    reused in the loop over years, so it goes to **the last year** of
    the event;
  - blocks with no events get NaN means and a count of 0;
  - `removeMissing` sets blocks with any missing day to NaN.

## xmhw: where it differs from marineHeatWaves

- **The climatology period is cut out first** (`temp.sel()`), so the
  window is shorter at its ends, as in heatwaveR 1.0.0, rather than
  reaching outside it.
- **29 February** is computed from its own window, then replaced by the
  mean of slots 59, 60 and 61, so the result includes 29 February's own
  value. marineHeatWaves averages 28 February and 1 March only.
- **Calendars:** `360_day` uses the time step as the slot (complete years
  required); `noleap` simply has no slot 60.
- **Missing data:** missing values drop out of the pooled windows
  (`dropna`), and fail `ts > thresh`, so they break events.
  - **`maxPadLength`** is passed to xarray's
    `interpolate_na(max_gap=...)`. **Checked:** with xarray 2026.9.0, an
    integer `max_gap` on a date axis raises `TypeError`, so the
    documented integer form fails (`checks/xarray-maxgap.out`).
  - Per xarray's docs, a gap's length runs from the last valid value to
    the next one, so a timedelta of n days fills up to n − 1 missing
    days, where marineHeatWaves' `maxPadLength = n` fills n.
- **Gap joining** is the same (gaps of up to `maxGap`, after the minimum
  duration).
- *(checked)* **An event that starts on the series' first day loses
  that day.** `mhw_filter()` counts run positions from 0, so a leading
  run of k days is measured as k − 1 and starts one step late. A 7-day
  event on days 0–6 came back as starting at index 1 with duration 6. A
  5-day event at the very start is dropped.
- *(checked)* **Onset rate:** for an event that peaks on its first
  day, not at the series start, xmhw divides by 1.5 days and
  marineHeatWaves by 0.5. A peak anomaly of 4, after a day with anomaly
  0, gave 1.333 in xmhw. marineHeatWaves' code gives 4.
- **Blocks** (`block_average()`): events go to blocks by `time_start`
  (default) or `time_peak`. Category days count by day.
  - *(checked)* **`block_average()` doesn't run with these library
    versions**, called as xmhw's docs show it,
    `block_average(mhw, dstime=intermediate)`:
    - on a lat × lon grid it fails in `pd.cut` ("Input array must be 1
      dimensional"), because the years are taken from `time_start`
      before the cells are stacked;
    - on a single series it fails with "'Dataset' object has no
      attribute 'time'", because the intermediate dataset's time axis is
      named `index` there.

    xmhw's own `test_block_average()` is an empty `pass`. The two
    points below were checked by calling the aggregation functions it
    uses (`agg_mhw`, `agg_cats`) directly.
  - *(checked)* `extreme_days` counts category 4 only, not 4 and
    above, so days past 4× are dropped from it and from `total_days`.
    The per-event `duration_extreme` uses ≥ 4. With 3 days at category 4
    and 4 at category 5, the event had `duration_extreme` 7, and the
    block had `extreme_days` 3 and `total_days` 10, not 14.
  - *(checked)* the block `intensity_mean_abs` and
    `intensity_cumulative_abs` aggregate `intensity_mean` and
    `intensity_cumulative` (relative to the climatology), not the
    absolute values. The block gave 3.536 and 24.75, the same as the
    relative fields, where the absolute ones would be 23.54 and 164.75.
  - `split_event()`, for events across years, is a stub that returns its
    input.
- **Severity**, `−(temp − seas) / (thresh − seas)` per day, is an extra
  per-event metric (with its mean and cumulative).
- Many series: cells are stacked and processed in parallel with dask;
  land cells (all missing) are dropped.

## What this means for spells

1. **marineHeatWaves is the reference behind the Hobday presets,** and a
   third parity target next to heatwaveR 0.5.5 and 1.0.0. Its switches:
   - the window reaching outside the climatology period;
   - the 29 February rule (mean of 28 February and 1 March, unrounded);
   - no padding by default, missing set to the climatology;
   - no trailing-gap join;
   - gap days outside every category.

   Storing its outputs on a few pixels would pin down which of heatwaveR's
   behaviours are inherited and which are heatwaveR's own.
2. **The window at the ends of the climatology period now has three
   implementations:** outside data (marineHeatWaves), shorter (heatwaveR
   1.0.0, xmhw), and a wrap (heatwaveR 0.5.5). The brief lists the
   options; this confirms they're all in use.
3. **The category rule for joined gap days needs naming:** none
   (marineHeatWaves, xmhw), or category I (trend.sst). It changes the
   days-per-category summaries.
4. **Gap lengths need one definition in the def:** the number of missing
   steps. xarray measures from valid value to valid value, one more. Any
   spells code built on xarray (or a Python port) has to convert.
5. **xmhw isn't an oracle.** It's useful as gridded prior art in xarray,
   but it differs from marineHeatWaves in the places above, now
   confirmed by running, and its block summaries don't run with current
   pandas and xarray.
6. **Rates at the series ends need a stated rule and a test.** Both
   Python codes divide by zero for an event that peaks on the series'
   last day. Spells' onset and decline rates should have tests at both
   ends of the series, and should mark an event cut by the series end
   (a provisional tail) rather than give a rate for it.
