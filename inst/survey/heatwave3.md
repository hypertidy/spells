# heatwave3 1.5.0

- **Source read:** robwschlegel/heatwave3 at `8aff3e5` (2026-11-02), MIT.
  It's on GitHub and PyPI (`py-v1.5.0`), not on CRAN.
- **How:** read 2026-11-17 from source, tests and docs, then built and
  run the same day against heatwaveR 1.0.0 and 0.5.5. The four claims
  that needed a run are marked *(confirmed by running)*; the script and
  its output are in `checks/`, and the results are under "Checked by
  running" below.
- Paths below are relative to the heatwave3 repo at that commit.

## What it is

A C++17 core with R (Rcpp) and Python (pybind11) bindings over the same
code, parallel over pixels with `std::thread`. It reads NetCDF and writes
NetCDF, one product per file (`<name>_clim.nc`, `<name>_events.nc`, and so
on). `hw3_export()` reads any product back as a data frame or converts it
to CSV, RDS or Parquet, and to Zarr in Python.

**heatwaveR is its source of truth** (`CLAUDE.md`, decision 8): every
output must equal heatwaveR's. The two exceptions were the series end and
seasons, and heatwaveR 1.0.0 then fixed both ("Both fixes make the events
and categories identical to those of heatwave3", heatwaveR `NEWS.md`). So
on gap-free data, **heatwave3 1.5.0 and heatwaveR 1.0.0 are one target**
for the climatology, events and categories. They differ with missing data
(see "Missing data" below).

The parity test (`tests/testthat/test-heatwaveR-parity.R`):

- needs heatwaveR 1.0.0 or later;
- runs on the bundled `inst/extdata/sst_test.nc`, which has no gaps;
- still excludes series-end events. That exclusion is stale now that
  1.0.0 has the same fix.

## The grid columns

**Baseline.** A day-of-year climatology on 366 slots
(`src/climatology.cpp`, `compute_pixel_climatology()`):

- an 11-day window (`windowHalfWidth = 5`) pooled over the years;
- the mean gives `seas`, and the type-7 quantile gives `thresh`;
- both are smoothed with a 31-day circular rolling mean, then rounded to
  4 decimals (`roundClm`, in `src/hw3_api.cpp`).

At the new year the window takes its neighbours from the adjacent years,
so the first and last years get shorter windows. heatwaveR 1.0.0 does the
same. heatwaveR 0.5.5 and trend.sst `R/mhw.R` wrap within each year
instead.

- **Feb 29 in non-leap years:** `round(mean(28 Feb, 1 Mar), 2)`.
- **Length:** the climatology period must span at least 3 calendar
  years, counted from the years of its two endpoints. A period that runs
  past the data is quietly clipped to it (heatwaveR stops with an error).
- **Optional `detrend`:** not a detrended baseline at detection (see
  "Detrend" below).
- **Fixed-value threshold:** `exceedance3()`.
- **Not available:** shifting, covariate or per-season baselines.

**Threshold.** A percentile, `pctile` (90 for heatwaves, 10 for cold
spells). The optional `threshClim2` is a second, gridded logical
criterion applied in two passes (`src/event_detect.cpp`,
`detect_dense_events()`):

1. Events are found from the primary threshold.
2. Inside those events, runs where the criterion is true are found again,
   using `minDuration2` and `maxGap2`.

**Direction.** High (`temp > thresh`) or low (`coldSpells = TRUE`,
`temp < thresh`). Both comparisons are strict. Event categories count
days *at or beyond* each level (`>=`, or `<=` for cold spells). Daily
categories are strict.

**Persistence** (`proto_event()` in `src/event_detect.cpp`):

1. Runs shorter than `minDuration` (5) are dropped. This is the opening.
2. Gaps of `maxGap` (2) or fewer between the surviving runs are joined.
   This is the closing.
3. Duration is checked again after joining. That can't fail, because
   every run is already long enough.

The order is opening, then closing. Gaps are joined only between two
events, never before the first or after the last. There's no hysteresis.

**Missing data.** The climatology and detection treat it differently:

- **Climatology** (`src/climatology.cpp`):
  - runs of `maxPadLength` or fewer missing days are interpolated
    linearly. This is off by default;
  - a run at the very start or end of the series is filled with the
    nearest value. heatwaveR leaves those runs missing;
  - missing (day of year, year) cells are left out of the window.
    heatwaveR first fills each one with that day of year's mean across
    years (`R/clim_spread.R`, "plugs");
  - there's no minimum count: a single finite value in the window gives
    a baseline;
  - a missing `seas` before smoothing spreads to 31 slots, because the
    rolling mean is a plain sum.
- **Detection: no interpolation at all, even when `maxPadLength` is set.**
  `detect3()` passes `maxPadLength` only to `ts2clm3()`, and
  `detect_event3()` reads the raw SST. heatwaveR detects on the
  interpolated series that `ts2clm()` returns. *(confirmed by running)*
  - A missing day breaks a run of exceedances.
  - Inside a gap-joined event, a missing day counts as `seas`, so its
    intensity is 0.
- **No censoring flags.** An event that touches either end of the series
  is reported as if complete. `rate_onset` and `rate_decline` are NA at
  the edges.

**Time step.** Daily only:

- **Calendars:** only gregorian, standard and proleptic_gregorian are
  accepted. Any other CF calendar is an error (`src/netcdf_io.cpp`,
  `parse_cf_time`), so CMIP6 `noleap` and `360_day` output can't be read.
- **Sub-daily times** are floored to the calendar day.
- **Duplicate dates** across multi-file input keep the first file's
  value.
- **Sparse input** is expanded to a dense daily series, as heatwaveR's
  `make_whole()` does.

**Calendar and season year.**

- Only calendar years exist: `block_average3()` puts each event in the
  year of its `date_start`.
- Each event gets a season from its peak month: December to February is
  summer when `hemisphere = "south"`.
- There's no shifted year, such as an ice year starting 15 February.

**Metrics.** There are 19 per event:

- event number, plus the index and date of the start, peak and end;
- duration;
- mean, maximum, variance and cumulative intensity, each relative to
  `seas`, relative to `thresh`, and absolute;
- onset and decline rates.

The "var" columns are standard deviations (`r_sd`). For cold spells the
intensities and rates are negative. Everything is rounded to `roundRes`
(4) with ports of R's `round()`, `mean()`, `sum()` and `sd()`
(`src/hw3_round.h`), so the last digits match R.

**Categories.** Hobday 2018 levels are `thresh + k * round(thresh - seas,
4)` for k = 1, 2, 3, each level rounded to 4 decimals and built
cumulatively. Three outputs use them:

- **Per event:** the share of days in each band (`p_moderate` and the
  rest), and the category of the highest band any day reaches.
- **Per day:** on event days only (`category_daily3()`, or the daily file
  of `detect_event3()`).
- **Ice, for cold spells only:** an event day whose threshold is below
  `ice_thresh` (default -1.7) is labelled category 5, "ice", in
  `category_daily3()`.

There's no ice mask for heatwaves.

**Many series at once.** That's the point of the package. The region
read is held in memory as `double`, pixel by pixel, at 8 bytes per pixel
per day, and the threads run over pixels.

- **Depth:** with `depth_range`, each depth level is kept and each (lon,
  lat, depth) is its own series.
- **Regional runs from a global climatology:** `detect_event3()` picks a
  window of the climatology grid with `lon_range` and `lat_range`, and
  reads only that part of the SST. Because pixels are independent, the
  results equal those of a climatology made for the region alone.
- **The climatology itself** needs every pixel's whole series in memory.
  A global MUR climatology means tiling outside the package (`CLAUDE.md`,
  decision 9: one tile per SLURM job).

**Streaming.** No state is carried from one run to the next.

- `detect_event_array3()` gives the per-day event mask for a window of
  days, for forecast windows for example. Its docs say events are cut off
  at both ends, so earlier days should be prepended when that matters.
- There's no provisional tail.

**Outputs.**

- **NetCDF products:**
  - climatology: `seas`, `thresh` and optional `var`, on day of year x
    lat x lon (x depth);
  - events: a CF ragged array on an `event` dimension;
  - per-day: `temp`, `seas`, `thresh`, `intensity`, `event`, `event_no`
    and `category`, or a slim version with just `intensity` and
    `category`;
  - proto-events.
- **Global attributes** record `source_file` and the climatology period.
  They don't record whether the climatology was detrended, or any other
  baseline type.
- `hw3_export()` converts these to data frames, CSV, RDS or Parquet, and
  in Python to Zarr.
- `detect_blob3()` returns data frames (event, daily, voxel).
- `block_average3()` returns one row per (pixel, year).
- The row order of the event table isn't deterministic with more than one
  thread (`CLAUDE.md`, decision 6), so sort it before comparing.

## Blobs (`detect_blob3()`)

- **What is labelled:** connected components of the **raw exceedance
  mask** (`temp > thresh`), using union-find. It is *not* the mask after
  the minimum duration and gap joining. A one-day exceedance can be part
  of a blob, and the 5-day rule plays no part.
- **Connectivity:** 6, 10, 18 or 26 neighbours in the lon/lat/time cube,
  by grid index, so distances play no part. `wrapDateline` is optional.
  Depth levels join only straight up and down.
- **Filtering:** `minVoxels`, and `topN` ranked by `rankBy`.
- **Metrics:** per blob, per day and per voxel, including area in km²,
  centroid, bounding box and, with depth, volume.
- **Extent:** the region is labelled in memory, with no halos or tiling
  across region edges.

The brief's "events as objects" are connected components of the
**spell** mask. That's a different object, so heatwave3 blobs are prior
art for it, not an oracle.

## Zarr

Zarr is Python-only (`CLAUDE.md`, decision 9, and `python/heatwave3/_zarr.py`):

- xarray copies the needed region of the store into a temporary NetCDF,
  keeping the store's own packing;
- the C++ functions then run on that file unchanged;
- outputs go to Zarr v3 or Parquet.

R has no Zarr path. That waits for an R Zarr library with v3, remote
stores and parallel writes; Rarr was judged not enough. The source's
chunk layout is taken as given. Reading a region's full series from a
map-layout store (one day per chunk) touches every chunk in the period,
which is the brief's rechunk problem.

## Calling it from memory

- **`detect_event_array3(temp, seas, thresh, ...)`, exported:** per-day
  `event`, `event_no`, `intensity` and `category` arrays, with time on the
  first dimension, using the same rules as the file path. It gives no
  event metrics.
- **`heatwave3:::hw3_pixel_clim(temp, time_jd, ...)`, internal**
  (commented "Debug"): one pixel's climatology. It's unrounded (`roundClm`
  is 0 on this path) and has no variance.
- **Event metrics and categories are only available through files.**

## Detrend

`ts2clm3(detrend = TRUE)` does the following:

1. It fits a linear trend per pixel over the climatology period.
2. It removes that trend from the series, keeping the level at the
   period's midpoint.
3. It computes the climatology from the detrended series.

Nothing records it:

- The slope isn't stored in the climatology file.
- Nothing in that file says it was detrended.
- `detect_event3()` reads the raw SST.

So events are detected on **raw SST against a climatology estimated from
detrended data**. In effect that's a fixed baseline at the period's
midpoint, with a narrower spread (a lower `thresh` relative to `seas`). It
isn't the Jacox et al. 2020 approach of detecting on detrended anomalies.
*(confirmed by running)* So heatwave3 can't be the oracle for the Smith et al.
2025 detrended baseline type.

## Left to spells

This confirms the brief's "just use heatwave3" row and adds detail. The
items marked † are new or sharper than the brief:

- an I/O-free, matrix-first core (heatwave3 is file-first);
- non-daily steps; non-Gregorian calendars †; season years such as an
  ice year;
- fixed-value baselines beyond `exceedance3()`, per-season, shifting and
  covariate baselines; detection on a truly detrended baseline †;
- censoring flags; an eligibility mask for heatwaves (heatwave3 has ice
  only as a cold-spell category †); missing-data policies beyond "missing
  counts as `seas`"; a minimum count for the baseline (heatwave3 has
  none †); estimator support;
- mergeable sums, streaming state, and a definition hash and labels in
  every output;
- events as objects on the spell mask †.

## What this means for spells

1. **One oracle target, not two, on gap-free data.** `heatwaveR-1.0.0`
   and `heatwave3` give the same climatology, events and categories. The
   golden outputs can come from either, stored in the repo so the tests
   don't need either package installed.
2. **They come apart with missing data.** heatwaveR fills climatology
   gaps with the day-of-year mean and detects on the interpolated series.
   heatwave3 leaves gaps out of the window and doesn't interpolate at
   detection. So `parity = "heatwave3-1.5.0"` and
   `parity = "heatwaveR-1.0.0"` are distinct with gaps, and the parity
   fixtures need series with gaps (in the climatology period, inside
   events, and at both ends) to pin each one.
3. **Oracle, not backend.** The only in-memory routes are the per-day
   mask and an internal one-pixel climatology. A backend for the Hobday
   presets would mean writing temporary NetCDF files, which goes against
   the I/O-free core. That points the brief's open question to "an
   oracle only (Suggests)", or to stored golden files with no dependency
   at all.
4. **trend.sst moving off 0.5.5:** to `heatwaveR-1.0.0` or `heatwave3`,
   `seas` and `thresh` change from 12 December to 20 January, and so does
   any event overlapping those days. The last event of a series changes
   if the series ends within `maxGap` days of it. This is the separate,
   visible step the brief plans.
5. **NCI projections** (`fs38`, `oi10`): models on `noleap` or `360_day`
   calendars can't go through heatwave3, so spells' slot definition has
   to handle calendars itself.
6. **Blobs** are prior art for events as objects, but on a different
   mask. The test for spells' version is a component labelling of the
   spell mask, not agreement with `detect_blob3()`.

## Checked by running

`checks/heatwave3.R`, on 2026-11-17, with heatwave3 1.5.0, heatwaveR
1.0.0 (in a library of its own) and heatwaveR 0.5.5, all on `sst_WA`
with the climatology period 1982-2011 and the defaults otherwise. The
output is in `checks/heatwave3.out`.

1. **Gap-free, heatwave3 equals heatwaveR 1.0.0 exactly.** The
   climatologies are identical on all 366 days of the year, and so are
   all 90 events, in dates and metrics.
   - 1.0.0 differs from 0.5.5 on 39 days of the year, 12 December to 19
     January. That's the reach of the 11-day window plus the 31-day
     smoothing; 20 January rounds the same at 4 decimals. The largest
     changes are 0.0015 °C in `seas` and 0.0007 °C in `thresh`, smaller
     than the 0.0044 and 0.0089 °C heatwaveR's NEWS gives for `sst_WA`,
     which doesn't say what period it used.
   - The event dates are the same in both, and the metrics of events
     over those days differ by up to 0.026 °C·days in cumulative
     intensity.
   - With the series cut to end one day after an event, 0.5.5 joins that
     day into the event (22 days rather than 21). 1.0.0 and heatwave3
     don't.
2. **Gaps inside events, with `maxPadLength = 2`.** One or two days were
   removed from each of the 41 events of 10 days or more. heatwaveR
   1.0.0 interpolates them and keeps all 41 events as they were.
   heatwave3 keeps only 15 of them:
   - a gap near the start leaves a run shorter than 5 days, which is
     dropped, so the event starts later;
   - a gap next to a day that was already below the threshold makes a
     non-exceeding stretch longer than `maxGap`, which splits the event;
   - a gap that is joined adds zero intensity, so cumulative intensity
     differs by up to 4.8 °C·days.

   The climatologies are identical, and heatwaveR detecting on the same
   gapped series without interpolation gives heatwave3's events exactly.
   So the whole difference is that heatwave3 doesn't interpolate at
   detection.
3. **Gaps in the climatology period, no interpolation.** 358 days (3.3%
   of the period) were removed, in runs of 1 to 5. The climatologies
   differ on every day of the year, by up to 0.002 °C in `seas` and
   0.038 °C in `thresh`, from leaving the gaps out of the window against
   filling them with the day-of-year mean. heatwave3 finds 90 events and
   heatwaveR 93, and 77 of them have the same dates in both.
4. **`detrend = TRUE` changes the climatology only.** 0.04 °C per year
   was added to `sst_WA`; the fitted slope over 1982-2011 is 0.053 °C
   per year.
   - The climatology equals heatwaveR's on the series detrended by least
     squares over the climatology period and centred at its midpoint.
   - The events equal heatwaveR's detection on the **raw** series
     against that climatology, all 98.
   - Detecting on the detrended series instead gives 75 events, only 6
     with the same dates.
   - Event days by start decade rise with `detrend = TRUE` as they do
     with a fixed baseline. On the detrended series they stay flat:

     | | 1982-91 | 1992-01 | 2002-11 | 2012-22 |
     |---|---|---|---|---|
     | heatwave3, `detrend = TRUE` | 26 | 268 | 852 | 1248 |
     | heatwave3, `detrend = FALSE` | 21 | 244 | 751 | 1123 |
     | detected on the detrended series | 231 | 258 | 351 | 253 |
