# Phase 0 survey

The comparison grid from the brief's "Phase 0: survey": one row per
package, in `grid.csv`. The columns are baseline, threshold, direction,
persistence, missing data, time step, calendar and season year, metrics,
categories, many series at once, streaming and outputs, plus where each
row was read from and how it was checked. Each package also gets a notes
file with the detail and what it means for spells.

Every row names the exact source it was read from (a commit or a CRAN
tarball). The `checked` column says whether a claim comes from reading
the source or from running the code.

| package | status | notes |
|---|---|---|
| heatwave3 1.5.0 | source read 2026-11-17, not run | [heatwave3.md](heatwave3.md) |
| heatwaveR 1.0.0 vs 0.5.5 | source diff 2026-11-17, not run | [heatwaveR-versions.md](heatwaveR-versions.md) |
| MHW-MAD (DMI, ESSD 2026) | to do | |
| Ocetrac | to do | |
| climdex.pcic, ClimInd | to do | |
| lfstat, SPEI, SCI | to do | |
| hydroEvents, EflowStats | to do | |
| extRemes, evd, POT | to do | |
| anomaly (CAPA) | to do | |
| iglu | to do | |
| phenofit (land phenology) | to do | |
| xclim, marineHeatWaves, xmhw (Python) | to do | |
| estimators (DINEOF, DINCAE, 4DVarNet, L4 methods) | to do | separate short grid |

## Findings so far that change the brief

1. **heatwaveR 1.0.0 is on GitHub only.** CRAN still has 0.5.5, and 1.0.0
   has no tag, so pin it by commit (`e0ae30d`). heatwave3 is on GitHub
   and PyPI, not CRAN.
2. **1.0.0 changed the climatology window at the new year**: it takes
   neighbours from the adjacent years instead of wrapping within the
   year. `seas` and `thresh` move from 12 December to 20 January. The
   brief and the field summary didn't list this.
3. **The "0.5.3.x `>` to `>=`" change is already in 0.5.5**, so it makes
   no difference between the versions spells has to match.
4. **heatwave3 equals heatwaveR 1.0.0 on gap-free data, and the two come
   apart with gaps.** heatwaveR fills climatology gaps with the
   day-of-year mean and detects on the interpolated series. heatwave3
   leaves gaps out of the window and doesn't interpolate at detection.
5. **heatwave3's `detrend` affects the climatology only.** Detection still
   reads the raw SST, so it isn't the detrended baseline type at
   detection.
6. **heatwave3 blobs label the raw exceedance mask**, not the spell mask.
7. **heatwave3 reads only Gregorian calendars**, which rules out CMIP6
   `noleap` and `360_day` output.
8. **heatwave3 has no in-memory path to event metrics.** That favours an
   oracle over a backend.

## Running checks

Both "not run" rows list what to confirm by running. Install heatwave3
and heatwaveR 1.0.0 into a scratch library (`R CMD INSTALL -l <lib>`), so
the installed heatwaveR 0.5.5 that trend.sst depends on stays untouched.
