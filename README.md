# spells

A spell is a run of a series beyond a threshold set relative to a
baseline, kept if it persists. A marine heatwave (Hobday et al. 2016) is
one; so are cold spells, sea ice seasons, blooms, dry spells and high
sea level spells. spells is a domain-neutral R engine for them, run over
a whole time x series matrix at once, for the trend.* family of
products.

**Status: early.** The design is in [BRIEF.md](BRIEF.md), and the survey
of other packages behind it in [inst/survey/](inst/survey/). Phase 1 has
started with parity: spells reproduces heatwaveR 0.5.5 and 1.0.0,
heatwave3 1.5.0, and the engine in trend.sst's `R/mhw.R`. spells' own
clean rules are the default; `parity` names a version to reproduce
instead.

```r
library(spells)
def <- hobday2018(c("1982-01-01", "2011-12-31"))   # clean rules; or parity = "heatwaveR-0.5.5"
b <- spell_baseline(x, time, def)  # x: time x series matrix, or one series
m <- spell_mask(x, time, b)        # event, category and anomaly per step
ev <- spell_events(x, time, b, m)  # one row per spell: dates, duration, intensities, rates, category
```

The presets are `hobday2016()` (marine heatwaves, detection only),
`hobday2018()` (with categories I to IV) and `schlegel2021()` (marine
cold spells, below the 10th percentile, with negative intensities). Each
takes a baseline type, `baseline_fixed()` (the default) or
`baseline_detrended()`.

## Parity

Other packages' behaviour is reproduced as named, versioned modes
(`parity_modes()`), each tested against that version's stored outputs
in `tests/testthat/fixtures/`, so the tests need none of them installed.
`data-raw/golden.R` regenerates the outputs.

| mode | status |
|---|---|
| `heatwaveR-0.5.5` | implemented: climatology, event days, daily categories, event metrics and categories |
| `heatwaveR-1.0.0` | implemented: climatology, event days, daily categories, event metrics and categories |
| `heatwave3-1.5.0` | implemented: climatology, event days, daily categories, event metrics and categories (heatwave3 is a test oracle only, not a dependency) |

Every mode is tested for heatwaves and for cold spells. The test series
are heatwaveR's `sst_WA`, `sst_Med` and `sst_NW_Atl` (NOAA OISST v2.1),
with gaps, shortened ends and stretches set on the category levels to
separate the rules.
