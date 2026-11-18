# spells 0.0.0.9000

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
