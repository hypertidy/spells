# heatwaveR 0.5.5 and 1.0.0

**Sources:**

- **0.5.5:** the CRAN tarball `heatwaveR_0.5.5.tar.gz`, published
  2026-01-13.
- **1.0.0:** robwschlegel/heatwaveR `master` at `e0ae30d` (2026-10-20),
  whose DESCRIPTION says Version 1.0.0, Date 2026-10-19.

**1.0.0 is not on CRAN.** CRAN still has 0.5.5 as of 2026-11-17, and
there's no git tag or GitHub release for 1.0.0. Pin it by commit:
`remotes::install_github("robwschlegel/heatwaveR@e0ae30d")`.

**How this was compared:** `diff` of `R/` and `src/` between the two
sources, plus the 1.0.0 `NEWS.md`. The new-year window and the
trailing gap were then confirmed by running both versions on `sst_WA`
(`checks/heatwave3.R`; results in `heatwave3.md`, "Checked by
running").

**Name clash:** heatwaveR has its own `ts2clm3()` and `detect_event3()`
(data.table versions). They are not the functions of the same names in
the heatwave3 package.

## What changes the numbers

| change | 0.5.5 | 1.0.0 | effect | where |
|---|---|---|---|---|
| window at the new year | wraps within each year: 1 Jan is pooled with 27-31 Dec of the same year | days before 1 Jan come from the previous year, days after 31 Dec from the next; the first and last years get shorter windows | `seas`/`thresh` change from 12 Dec to 20 Jan with the defaults, and so do the metrics of events overlapping those days. Run on `sst_WA` (1982-2011): 39 days differ, 12 Dec to 19 Jan, by up to 0.0015 / 0.0007 °C (NEWS says 0.0044 / 0.0089 °C); event dates don't change | `R/clim_spread.R` |
| quantile rank with gaps in the window | rank from the full window size | rank from the number of finite values | only when a window has missing values. After the fills below, that happens in 1.0.0 only through the new padding (first and last years) | `src/clim_calc.cpp`; `R/ts2clm.R` picks the R or C++ path |
| trailing gap | a gap of `maxGap` or less after the last event is joined into it | not joined | the last event's `date_end`, duration, intensities and `rate_decline` | `R/proto_event.R` |
| seasons in `category()` | calendar quarters | meteorological seasons by month | labels only | `R/category.R` |
| `category(season = "range")` | duration cut-offs, NA for some 6-9 month events | number of seasons touched | labels only | `R/category.R` |
| `exceedance(below = TRUE)` rates | positive | negative | sign | `R/exceedance.R` |
| `exceedance(roundRes = FALSE)` | rounded to whole numbers | not rounded | | `R/exceedance.R` |
| `detect_event(categories = TRUE)` with `roundRes` FALSE or more than 4 | fails or returns no events | works | | `R/detect_event.R` |
| heatwaveR's own `detect_event3()` with `threshClim2` | `minDuration2`/`maxGap2` ignored | used | | `R/detect_event3.R`, `R/proto_event3.R` |
| heatwaveR's own `ts2clm3(var = TRUE)` | a different variance | the same as `ts2clm()` | | `R/ts2clm3.R` |

## What stays the same in both

- **Detection:** a missing temperature is set to `seas`, so it breaks a
  run and adds zero intensity inside a joined gap.
- **Leading gap:** the gap before the first event is never joined.
- **Rounding:** `seas` and `thresh` are rounded to 4 decimals.
- **Feb 29 in non-leap years:** the rounded mean of 28 Feb and 1 Mar
  (`.NA2mean`).
- **Climatology gaps:** each missing (day of year, year) cell in the
  climatology period is filled with that day of year's mean across years
  (`R/clim_spread.R`, "plugs").
- **Interpolation** (`na_interp`, with `maxPadLength`): only gaps with
  values on both sides are filled, using `approx(rule = 1)`, so leading
  and trailing gaps stay missing. `ts2clm()` returns the interpolated
  series, so **detection runs on interpolated temperatures**.
- **The Moderate category counts days with `>=`** in both. The summary's
  "0.5.3.x changed `>` to `>=`" is already in 0.5.5, so it makes no
  difference between these two versions.
- **Daily categories are a different rule from the event counts.**
  `category(climatology = TRUE)` is strict (`>`), against levels built
  as `diff = round(thresh - seas, 4)`, `thresh_2x = round(thresh +
  diff, 4)`, and so on up to 4x. Joined gap days below the threshold,
  and missing days, get no category. Checked for 0.5.5: spells' parity
  mode reproduces it on every case of its parity tests
  (`tests/testthat/test-parity-heatwaveR.R`).
- **Climatology length:** at least 1095 days, and the period must lie
  inside the data. Otherwise `ts2clm()` stops with an error.

## The parity switches each version needs

The brief's `heatwaveR-0.5.5` list comes from trend.sst `R/mhw.R`. This
comparison adds two items to it (marked †):

| switch | heatwaveR-0.5.5 | heatwaveR-1.0.0 | heatwave3-1.5.0 |
|---|---|---|---|
| window at the new year | wrap within the year † | adjacent years | adjacent years |
| trailing gap joined at the series end | yes | no | no |
| leading gap joined | no | no | no |
| missing temperature in detection | set to `seas` | set to `seas` | set to `seas` |
| climatology cell missing | filled with the day-of-year mean † | filled with the day-of-year mean | left out of the window |
| `maxPadLength` interpolation | climatology and detection; no edge fill | climatology and detection; no edge fill | climatology only; edges filled with the nearest value |
| `seas`/`thresh` rounding | 4 | 4 | 4 |
| Feb 29 fill | `round(mean, 2)` | `round(mean, 2)` | `round(mean, 2)` |
| Moderate category | `>=` | `>=` | `>=` |

Both heatwaveR columns are now spells parity modes, reproduced on
stored outputs (`tests/testthat/test-parity-heatwaveR.R`): on gap-free
reference periods, the window and trailing-gap rows are the only
differences between them.

trend.sst `R/mhw.R` wraps within the year (its header and the `pad`
index in `mhw_clim()`), as 0.5.5 does. It also stops on any missing
value. So the climatology-fill row hasn't mattered for it so far. It
will for any source with gaps in the climatology period.
