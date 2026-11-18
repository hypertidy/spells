# iglu 4.2.2

- **Source read:** the CRAN tarball `iglu_4.2.2.tar.gz` (published
  2025-01-14). GitHub: irinagain/iglu. Elizabeth Chun and others;
  maintained by Irina Gaynanova. GPL-2.
- **How:** read 2026-11-18 from source: `R/episode_calculation.R`,
  `CGMS2DayByDay()` in `R/utils.R`, and skims of `R/mage_ma_single.R`
  and `R/above_percent.R`. **Not run.**
- **Reference:** Battelino et al. 2023, *Lancet Diabetes Endocrinol.*
  11(1), 42–57, doi:10.1016/s2213-8587(22)00319-9 (the international
  consensus on CGM metrics for clinical trials).

## What it is

Metrics for continuous glucose monitoring (CGM): one glucose reading
every few minutes per patient. The spell-like part is
`episode_calculation()`: hypo- and hyperglycaemic episodes as the 2023
consensus defines them. It's the brief's "a series can be a patient"
case, with irregular timestamps.

## The grid columns

- **Regular grid first** (`CGMS2DayByDay()`):
  - rows with any missing field are dropped (`complete.cases`);
  - times are sorted, and of repeated timestamps only the last reading
    is kept;
  - the grid step `dt0` defaults to the median interval between
    readings, rounded to a minute. If a day isn't a whole number of
    steps, it becomes 20 minutes (above 20) or the nearest multiple of 5;
  - readings are interpolated linearly onto the grid, which starts at
    00:00 of the first day (the first point is at `dt0` past midnight);
  - **gaps longer than `inter_gap` (45 minutes) aren't interpolated**
    and stay missing.
- **Baseline:** none. **Thresholds:** fixed clinical levels in mg/dL:
  hypo below 70 (level 1) and 54 (level 2), hyper above 180 (level 1)
  and 250 (level 2).
- **Direction:** strict on both sides (`gl < threshold` for hypo,
  `gl > threshold` for hyper).
- **Persistence, a start rule and an end rule** (`event_class()`):
  - an episode **starts** at a run of at least `dur_length` (15 minutes,
    so 3 steps at 5 minutes) beyond the threshold;
  - it **ends** only at the first run of at least `end_length` (15
    minutes) back on the other side, and the end is the step before that
    run;
  - everything in between belongs to the episode: short excursions back
    across the threshold, and later runs beyond it, however short.

  So only the starting run has to meet the minimum. heatwaveR joins a
  gap only when the spells on both sides meet the minimum each.
  - **Extended hypoglycaemia:** a single run of more than 120 minutes
    below level 1 (`120/dt0 + 1` steps), with the same end rule.
  - Durations that aren't a multiple of `dt0` are rounded up, with a
    warning.
- **Levels:** level 2 episodes are detected separately, with the same
  duration rules, so they're a subset of level 1 in time.
  `lv1_*_excl` counts the level 1 episodes that contain no level 2
  episode. A brief dip below level 2 that doesn't make a 15-minute
  level 2 episode leaves a level 1 episode "exclusive".
- **Missing data:** gaps of 45 minutes or less are interpolated; longer
  ones split the trace into **segments**, and episodes are found in
  each segment separately. An episode running into a gap ends at the
  gap, with its shortened duration, and isn't flagged. A warning is
  given when `dur_length > inter_gap`.
- **Time step:** minutes, irregular in, regular after interpolation.
  **Calendar:** POSIXct with a time zone (`tz`). The grid is built by
  adding minutes, then reshaped into rows of 24 hours.
- **Season year:** none for episodes; some metrics split by day or by
  sleep and wake time.
- **Metrics per episode:** duration (steps × `dt0`) and mean glucose.
- **Summaries per subject and level:** total episodes, mean duration,
  mean glucose, and **episodes per day of recording**, where the
  denominator excludes the gaps.
- **Other summaries use another time base:** `above_percent()` and the
  like take the share of **readings** above a level, from the raw data
  with no interpolation, so irregular sampling weights them. Episodes use
  time on the interpolated grid.
- **MAGE** (`mage_ma_single()`), skimmed: excursions between peaks and
  nadirs, found where a short (5) and a long (32) trailing moving average
  cross, counted when larger than one SD. It splits the trace at gaps
  over 180 minutes. Shape-based, like hydroEvents' `eventMaxima()`.
- **Categories:** levels 1 and 2 as above. **Many series:** one subject
  per group (`id`). **Streaming:** no.
- **Outputs:** a data frame per subject and level, and optionally the
  interpolated data with episode labels.

## What this means for spells

1. **An oracle for a CGM preset** (`battelino2023`): fixed thresholds,
   strict comparisons, a 15-minute start run and a 15-minute end run, a
   45-minute interpolation limit, and the level 2 and extended rules.
   iglu is on CRAN, so it can be a Suggests check as well as stored
   outputs.
2. **Start and end rules are another persistence model.** A spell starts
   with `d` steps beyond and ends only after `e` steps back. Only the
   first run needs the minimum; later short runs are absorbed. That's
   evd's `r` closing combined with a minimum on the first run alone, and
   it differs from heatwaveR's join. The def needs to say which runs the
   minimum applies to.
3. **Levels by episode, not by step.** iglu counts a higher level only if
   it forms its own episode with its own duration rule. Hobday's
   categories are per step, and the highest step counts. Both are
   reasonable; the category rule in the def should name which.
4. **Gaps measured in time for irregular data:** iglu interpolates up to
   45 minutes and splits beyond. That's the brief's "interpolate up to n
   steps, then break", with n as a duration, as POT's `tim.cond` does for
   the gap rule.
5. **Irregular input needs a regularisation step** whose rule the def
   records: the grid step and how it's chosen, the alignment, how
   duplicates are resolved, and the interpolation limit. iglu shows each
   choice.
6. **Rates per observed time.** Episodes per day of recording, with gaps
   excluded from the denominator, is the summary that stays comparable
   when coverage differs. And shares should say whether they're of steps
   or of time: iglu mixes readings and grid time.
7. **Censoring at gaps is missing here too:** episodes cut by a gap
   count with their shortened duration. Spells' censored flags fix that.
