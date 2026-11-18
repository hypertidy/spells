# spells 0.0.0.9000

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
