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
| climdex.pcic 1.2-0 | source read 2026-11-17, not run | [climdex.pcic.md](climdex.pcic.md) |
| ClimInd 0.1-3 | source read 2026-11-17, not run | [climind.md](climind.md) |
| lfstat 0.9.15 | source read 2026-11-17, not run | [lfstat.md](lfstat.md) |
| SPEI 1.8.1, SCI 1.0-3 | source read 2026-11-17, not run | [spei-sci.md](spei-sci.md) |
| hydroEvents 0.13.0 | source read 2026-11-18, not run | [hydroEvents.md](hydroEvents.md) |
| EflowStats 5.2.0 | source read 2026-11-18, not run | [eflowstats.md](eflowstats.md) |
| extRemes 2.2-1 | source read 2026-11-18, not run | [declustering.md](declustering.md), [hwmi.md](hwmi.md) |
| evd 2.3-7.1, POT 1.1-12 | source read 2026-11-18, not run | [declustering.md](declustering.md) |
| anomaly 4.3.3 (CAPA) | source read 2026-11-18, not run | [anomaly.md](anomaly.md) |
| iglu 4.2.2 | source read 2026-11-18, not run | [iglu.md](iglu.md) |
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
14. **climdex.pcic, the ETCCDI reference, is off CRAN** (archived in
    2023), and so is its PCICt dependency (2025). Store golden WSDI and
    CSDI outputs. Its percentile window wraps within the year, as
    heatwaveR 0.5.5's does. It uses 365 slots with 29 February in 28
    February's slot, type-8 quantiles and no smoothing. WSDI uses the
    out-of-base thresholds in every year: the in-base bootstrap is only
    for the percentage indices.
15. **Assigning a spell to a season year varies by package:**
    - by start (heatwaveR and heatwave3);
    - by end (climdex.pcic CDD/CWD);
    - days split by year (WSDI with `spells.can.span.years`);
    - cut at the boundary, with each piece having to pass the minimum
      (WSDI's default).

    The rule belongs in the def.
16. **climdex.pcic reads `noleap` and `360_day` calendars** (through
    PCICt). It's the prior art for spells' slot definition beyond
    Gregorian.
17. **ClimInd isn't an ETCCDI oracle.** Its WSDI and CSDI take one
    threshold from the whole record, and runs can't cross the end of a
    year. Its CSDI comparison and GSL minimum differ from its own docs.
    It labels winter by its January year, where climdex.pcic uses the
    December year.
18. **lfstat has the widest range of closings:**
    - inter-event time (IT);
    - inter-event time and the excess volume relative to the deficit so
      far (IC);
    - smoothing and detecting again (MA);
    - sequent peak, a storage rule that lasts until the deficit is repaid
      (SP).

    It joins first and drops minor events after: closing, then opening.
19. **lfstat reports two durations and two volumes.** Duration with the
    pooled gaps and the days below the threshold. The pooled volume, in
    which the excess between events counts negatively, and the volume
    below the threshold only. Its default minor-event rule (0.5% of the
    largest event's volume) depends on the data set.
20. **SPEI and SCI detect no events.** They define a standardized
    threshold type: a z value under a distribution fitted per slot over
    the reference period, after a trailing accumulation. Fitting is
    separate from applying (`fitSCI`/`transformSCI`, `params =`), which
    is the stored-baseline pattern.
21. **CRAN SPEI 1.8.1 returns `-Inf` SPI for zero-precipitation
    periods.** Its zero-probability adjustment is overwritten
    (sbegueria/SPEI#87). The fix is on GitHub (1.9.0) but not on CRAN.
22. **A filter along time is a baseline type, and the usual one isn't
    causal.** hydroEvents finds streamflow events on quickflow, after
    removing baseflow with a Lyne and Hollick filter run forwards,
    backwards and forwards again. Each step's baseflow depends on later
    steps, so it can't stream.
23. **A minimum on the peak is another opening.** hydroEvents'
    `eventMaxima()` keeps an event only if its peak reaches the
    threshold, which is applied after the events are separated.
24. **Matching events across two series needs its own rule.**
    hydroEvents' `pairEvents()` pairs by start, peak or end within a lag,
    forwards, backwards or centred, and not one-to-one. That's prior art
    for compound spells where one follows the other.
25. **Attribution to years can differ between indices of one package.**
    In EflowStats, the counts (FH, FL) cut events at the year boundary
    and the pulse durations (DH15, DL16) split them, so one event is
    counted in both years. Years with no events count as 0 in FL1 and
    are dropped in FL3.
26. **"The whole record" is a moving reference period.** EflowStats,
    lfstat and ClimInd take thresholds from all the data, so adding a
    year changes past events. EflowStats' flood threshold also comes
    from another series (annual instantaneous peaks), and its
    recurrence-interval labels don't follow one convention.
27. **EflowStats changed its water-year label in 5.2.0** (2023): the
    calendar year with most of the months, where before it was always
    the end year. HIT and EflowStats before 5.0 dropped day 366 in leap
    years, not 29 February.
28. **Runs declustering is a spell with no minimum**, and gaps of up to
    `r − 1` steps joined (extRemes, evd). extRemes counts only the
    exceedances in a cluster, where evd and POT include the joined
    steps.
29. **evd's lower threshold is a closing with magnitude in it:** a
    cluster also ends after `rlow` steps at or below `ulow`. With a long
    `r`, that's hysteresis.
30. **Read from the code, to confirm by running:**
    - extRemes' intervals declustering estimates a run length but
      declusters with `r = 1`;
    - POT measures its time condition from the cluster's running
      maximum, started on the step after the first exceedance, not from
      the last exceedance as documented;
    - POT's intervals estimator has its two cases the other way round
      from evd's and extRemes'.
31. **Estimated closings are data-set-relative** (intervals
    declustering, POT's `fitexi()`). Spells can offer them as fitted
    once and stored in the def, like a baseline.
32. **extRemes carries HWMId** (Russo et al. 2015), a candidate preset.
    Its magnitude has its own origin and unit (the 25th percentile and
    interquartile range of the reference period's annual maxima), its
    yearly summary is the largest heatwave with its duration and start,
    it drops 31 December in leap years, and it cuts heatwaves at
    1 January.
33. **CAPA (anomaly) finds anomalous segments by penalised cost, not
    by threshold and persistence.** It keeps a segment when length ×
    mean² beats a penalty, finds raised and lowered segments together,
    and assumes the series is already standardised with no seasonal
    cycle. Not an oracle, but a detector that could plug in after
    spells' baseline, and the source of an evidence-based opening.
34. **CAPA's results are sequential and revise** (`epoch =`), and its
    default penalties grow with the series length. MVCAPA defines an
    event over many series as co-occurrence with lags, with no
    adjacency.
35. **iglu's episodes start and end by duration:** at least 15 minutes
    beyond the threshold to start, at least 15 minutes back to end, and
    everything between belongs to the episode. Only the first run needs
    the minimum, unlike heatwaveR's join. It's the oracle for a CGM
    consensus preset (Battelino et al. 2023).
36. **iglu counts levels by episode:** a level 2 episode needs its own
    15 minutes, and "level 1 exclusive" episodes contain none. Hobday's
    categories are per step.
37. **Irregular data, in time units:** iglu interpolates readings onto a
    grid, fills gaps of up to 45 minutes, and splits the trace at longer
    ones. Episodes per day of recording exclude the gaps, but its
    time-above shares count raw readings.

Findings 2 to 5 were confirmed by running (`checks/heatwave3.R`, output
in `checks/heatwave3.out`). The details are in heatwave3.md, "Checked by
running".

## Running checks

`checks/` holds the scripts and their saved output. heatwaveR 1.0.0 goes
in a library of its own (`R CMD INSTALL -l ~/R/heatwaveR-1.0.0`), because
in the default library it would replace the 0.5.5 that trend.sst's
parity check (`validate/mhw_tasman_pixels.R`) uses. The script runs each
heatwaveR version in a separate R process.
