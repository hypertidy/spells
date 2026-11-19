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
heatwave3 1.5.0, the engine in trend.sst's `R/mhw.R` (which now runs on
spells), and trend.ice's published sea ice seasons. spells' own clean
rules are the default; `parity` names a version to reproduce instead.

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
`baseline_detrended()`. `massom2013()` is the Antarctic sea ice season:
a fixed 15% threshold, one spell per ice year from 15 February, and
advance and retreat as its season summaries:

```r
def <- massom2013()                       # or parity = "trend.ice-d5be6df"
b <- spell_baseline(x, time, def)         # x: daily ice concentration (%), time x pixel
s <- spell_summary(x, time, b, spell_mask(x, time, b))   # one row per pixel and ice year
advance <- as.integer(s$first_start - s$season_start) + 1L
```

`spell_def()` builds other definitions from the same parts (threshold
type, comparison, persistence order, seasons); it is experimental.

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
| `trend.ice-d5be6df` | implemented: trend.ice's `R/ice_season.R` for `massom2013()`, every pixel of its 46 published ice season COGs |

Every mode is tested for heatwaves and for cold spells. The test series
are heatwaveR's `sst_WA`, `sst_Med` and `sst_NW_Atl` (NOAA OISST v2.1),
with gaps, shortened ends and stretches set on the category levels to
separate the rules.

The ice season is tested against a subset of trend.ice's published
COGs: 230 pixels in three ice years, with their input from the
NOAA-NSIDC Climate Data Record of Passive Microwave Sea Ice
Concentration, Version 6 (doi:10.7265/b18j-z797; no constraints on
use), in `tests/testthat/fixtures/massom2013.rds`, made by
`data-raw/massom2013.R`, which also checks every published pixel.

The join-first rule order is tested against a small subset of MHW-MAD
(Hayward et al. 2026, Earth Syst. Sci. Data 18, 7181-7197; data
doi:10.5281/zenodo.21835325, Danish Meteorological Institute, CC-BY
4.0): nine Tasman Sea pixels for 2015-2016, in
`tests/testthat/fixtures/mhw-mad.rds`, made by `data-raw/mhw-mad.R`.
