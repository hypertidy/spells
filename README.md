# spells

A spell is a run of a series beyond a threshold set relative to a
baseline, kept if it persists. A marine heatwave (Hobday et al. 2016) is
one; so are cold spells, sea ice seasons, blooms, dry spells and high
sea level spells. spells is a domain-neutral R engine for them, run over
a whole time x series matrix at once, for the trend.* family of
products.

**Status: early.** The design is in [BRIEF.md](BRIEF.md), and the survey
of other packages behind it in [inst/survey/](inst/survey/). Phase 1 has
started with parity: spells reproduces heatwaveR 0.5.5 and the engine in
trend.sst's `R/mhw.R`. spells' own clean rules aren't implemented yet.

```r
library(spells)
def <- hobday2016(c("1982-01-01", "2011-12-31"), parity = "heatwaveR-0.5.5")
b <- spell_baseline(x, time, def)  # x: time x series matrix, or one series
m <- spell_mask(x, time, b)        # event, category and anomaly per step
```

## Parity

Other packages' behaviour is reproduced as named, versioned modes
(`parity_modes()`), each tested against that version's stored outputs
in `tests/testthat/fixtures/`, so the tests need none of them installed.
`data-raw/golden.R` regenerates the outputs.

| mode | status |
|---|---|
| `heatwaveR-0.5.5` | implemented: climatology, event days, daily categories |
| `heatwaveR-1.0.0` | outputs stored, mode planned |
| `heatwave3-1.5.0` | outputs stored, mode planned (heatwave3 is a test oracle only) |

The test series are heatwaveR's `sst_WA`, `sst_Med` and `sst_NW_Atl`
(NOAA OISST v2.1).
