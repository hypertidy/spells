# spells 0.0.0.9000

* Baseline types: `baseline_fixed()` (the default) and
  `baseline_detrended()`, given to a preset's `baseline`. The detrended
  baseline removes one linear trend per series, fitted over the
  reference period to the anomalies (least squares with a mean per
  slot) and extrapolated beyond it; detection reads the detrended
  series. With `parity = "heatwave3-1.5.0"` it reproduces heatwave3's
  `detect3(detrend = TRUE)`, which fits the climatology only and detects
  on the raw series; heatwave3's fit to the daily values picks up the
  seasonal cycle. `spell_baseline()` returns the `trend`.

* The eligibility mask: `eligible =` on `spell_baseline()` and
  `spell_mask()`, a logical matrix like `x` or one value per series, for
  steps where the series means nothing (SST under ice). Ineligible
  reference days drop out of the baseline and count against coverage.
  With the clean rules an ineligible step is never interpolated nor
  interpolated across, and cuts the spells beside it; with a parity mode
  it's the engine's answer on the series masked to `NA`. `spell_mask()`
  returns each step's `state`, and `spell_events()` gains `n_ineligible`
  and the reason a spell is cut on each side (`cut_start_by`,
  `cut_end_by`).

* The presets: `hobday2016()` detects marine heatwaves and now has no
  categories; `hobday2018()` adds Hobday et al. (2018)'s categories;
  `schlegel2021()` detects marine cold spells, below the 10th
  percentile, with negative intensities and rates and categories I to
  IV counting down from the threshold (no freezing correction, no ice
  category). All three take a parity mode: the cold-spell modes
  reproduce heatwaveR's and heatwave3's `coldSpells` on stored outputs
  for every test case. With no categories, `spell_mask()` and
  `spell_events()` leave them out.

* spells' clean rules: `hobday2016()` without `parity` runs them. The
  climatology window is shorter at the ends of the reference period;
  missing days in it, and slot 60 in non-leap years, drop out of the
  window; a slot needs half its window's possible days for a baseline;
  nothing is rounded; in detection, runs of 3 or fewer missing steps are
  interpolated, and a longer run, or a slot without a baseline, cuts the
  spells beside it (`cut_start`, `cut_end`) and is never joined across.
  `categories()` now defaults to the clean rule: the floor of the
  multiple, no category for a step that isn't beyond the threshold, and
  a spell's category its highest step's (`categories(gap_days = "I")`
  is trend.sst's).

* `spell_events()`: one row per spell, with its start, peak and end,
  duration (and the steps beyond the threshold and missing), whether
  either end of the series cuts it, its intensities relative to the
  baseline, the threshold and in the series' own units, its rates of
  onset and decline, and its category with the steps in each. It
  reproduces the event tables of heatwaveR 0.5.5 and 1.0.0 and
  heatwave3 1.5.0, and their event categories. `categories()` gains
  `event` and `event_compare`, for heatwaveR's event category (the
  highest whose share of the spell's days, rounded to a whole percent,
  is above zero, counting days at or above each level). heatwave3's mode
  gives no rate when the day outside the spell is missing, where
  heatwaveR counts it as the baseline. A ninth test case has stretches
  set on the category levels.

* `hobday2016(parity = "heatwave3-1.5.0")`: heatwaveR 1.0.0's rules,
  except that a missing day in the reference period is left out of the
  window. The heatwaveR modes now fill it with that day of year's mean
  across the reference years, as heatwaveR does, instead of stopping.
  Slot 60 is filled from whichever of 28 February and 1 March is there.
  An eighth test case has gaps in the reference period, and heatwave3's
  stored outputs include its daily event days and categories.

* `hobday2016(parity = "heatwaveR-1.0.0")`: the climatology window runs
  on through the adjacent years at the new year and is shorter at the
  ends of the reference period, and a gap after the last spell isn't
  joined. It reproduces heatwaveR 1.0.0's stored outputs on the same
  seven cases.

* First parity milestone: `hobday2016(parity = "heatwaveR-0.5.5")`,
  `spell_baseline()`, `spell_mask()`, `categories()`, `slot_366()` and
  `parity_modes()`, ported from trend.sst's `R/mhw.R`. They reproduce
  heatwaveR 0.5.5's climatology, event days and daily categories, and
  `R/mhw.R` exactly, on stored outputs for seven cases. Outputs from
  heatwaveR 1.0.0 and heatwave3 1.5.0 for the same cases are stored for
  the modes to come.
