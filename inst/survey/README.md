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
| heatwave3 1.5.0 | source read and run 2026-11-17 | [heatwave3.md](heatwave3.md) |
| heatwaveR 1.0.0 vs 0.5.5 | source diff and run 2026-11-17 | [heatwaveR-versions.md](heatwaveR-versions.md) |
| MHW-MAD (DMI, ESSD 2026) | paper and data README read 2026-11-17; code under embargo | [mhw-mad.md](mhw-mad.md) |
| Ocetrac 0.1.7 | source read 2026-11-17, not run | [ocetrac.md](ocetrac.md) |
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
9. **"Detrended" is three different methods so far:**
   - heatwave3 fits one trend per pixel over the climatology period and
     changes only the climatology;
   - MHW-MAD fits one trend per pixel and calendar date over the whole
     record, and detects on the detrended SST;
   - Ocetrac fits a linear term inside a monthly harmonic regression over
     the whole record.

   The baseline def needs the trend model, the fitting period, and
   whether detection reads the detrended series.
10. **MHW-MAD's shifting baseline is a trailing 30-year window that
    includes the year being assessed**, moving one year at a time. The
    paper doesn't say how events across the new year meet the two
    climatologies.
11. **MHW-MAD ties the category unit to the detection percentile**: its
    95th and 99th percentile products use their own threshold minus the
    mean. So the category unit is a def parameter of its own.
12. **MHW-MAD is data with no code** (it's under embargo). It can be an
    oracle for per-day state on ESA CCI input, but not for event metrics.
    It has no ice mask, and no detrended category dataset is listed.
13. **Ocetrac tracks a cleaned exceedance mask, as heatwave3's blobs do**,
    with no minimum duration. It filters by area in grid cells, against a
    percentile of all blob areas. It links blobs either as 3-D
    components or by overlap between adjacent frames, with a
    containment threshold. Neither tool is an oracle for objects built
    from spells. Ocetrac's linking rules are worth offering, but its
    area filter is not, because it is unweighted and changes with the
    data.

Findings 2 to 5 were confirmed by running (`checks/heatwave3.R`, output
in `checks/heatwave3.out`). The details are in heatwave3.md, "Checked by
running".

## Running checks

`checks/` holds the scripts and their saved output. heatwaveR 1.0.0 goes
in a library of its own (`R CMD INSTALL -l ~/R/heatwaveR-1.0.0`), because
in the default library it would replace the 0.5.5 that trend.sst's
parity check (`validate/mhw_tasman_pixels.R`) uses. The script runs each
heatwaveR version in a separate R process.
