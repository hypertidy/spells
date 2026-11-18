# Runs declustering: extRemes 2.2-1, evd 2.3-7.1, POT 1.1-12

- **Sources read:** the CRAN tarballs
  - `extRemes_2.2-1.tar.gz` (2025-05-16), Eric Gilleland, GPL (>= 2);
  - `evd_2.3-7.1.tar.gz` (2024-09-21), Alec Stephenson, GPL-3;
  - `POT_1.1-12.tar.gz` (2026-09-18), Mathieu Ribatet, maintained by
    Christophe Dutang, GPL (>= 2).
- **How:** read 2026-11-18 from source, then the points first read from
  the code were **checked by running** the same day
  (`checks/declustering.R`, output in `checks/declustering.out`). Each
  is marked *(checked)* below, with the result.
- The functions: `extRemes::decluster()` and `extremalindex()`
  (`R/dependence.R`), `evd::clusters()` and `exi()` (`R/stocproc.R`,
  `src/pot.c`), and `POT::clust()` and `fitexi()` (`R/graph-clust.R`,
  `src/clust.c`, `R/exi-fit.R`).
- extRemes also has the heatwave magnitude indices HWMI and HWMId: see
  `hwmi.md`.

## What they are

Extreme-value packages decluster threshold exceedances so that a
generalised Pareto fit sees roughly independent cluster maxima. A
cluster is a spell under another name: a run of exceedances, with short
gaps joined. These three are the standard R implementations, and they
differ.

## The three side by side

| | extRemes `decluster()` | evd `clusters()` | POT `clust()` |
|---|---|---|---|
| exceedance | `x > threshold` | `data > u` | `obs > u` |
| threshold | constant or a vector along the series | constant or a vector (`u`), plus an optional lower threshold `ulow` | **one value**: the C code reads only the first element |
| gap rule | exceedances separated by fewer than `r` non-exceedances share a cluster (default `r = 1`: consecutive only) | the same with `r`, **and** a cluster also ends after `rlow` consecutive values at or below `ulow` | in time units (`tim.cond`), on a `time` column, so irregular steps work |
| what a cluster holds | the exceedances only | the whole span, joined sub-threshold steps included | the whole span |
| missing data | `na.fail` by default (stops); `na.omit` deletes the steps and closes up the series | missing is below `u` but above `ulow`, so it can be joined across and never triggers the lower rule | replaced by -1e6 with a warning, so below the threshold |
| groups | `groups` (e.g. years) restart clusters at each group boundary | none | none |
| output | the series with each cluster's non-maximum exceedances set to the threshold (`replace.with`), cluster ids as an attribute | a list of clusters, or their maxima (`cmax`); `acs`, the average cluster size | a list of clusters, or their maxima (`clust.max`); `exi`, clusters / exceedances |

There's no minimum cluster size in any of them: one exceedance is a
cluster.

## Details and discrepancies

- **extRemes and evd agree on the gap rule:** `r` consecutive values at or
  below the threshold end a cluster, so gaps of up to `r − 1` steps are
  joined. That's `maxGap = r − 1` in heatwaveR's terms, and hydroEvents'
  `min.diff` works the same way.
- **evd's lower threshold is a magnitude-aware closing.** A gap shorter
  than `r` is joined unless the series falls to `ulow` or below for
  `rlow` steps. With a large `r` it behaves like hysteresis: a cluster
  starts above `u` and ends after `rlow` steps at or below `ulow`. When
  the lower rule ends a cluster, the cluster can end on a step below
  `u`, because the steps before the `rlow` run are included.
- **extRemes' intervals declustering estimates `r` from the data**
  (Ferro and Segers 2003): `r` is the K-th largest interval between
  exceedances, with K from the extremal index estimate. So the closing
  changes as data is added.
  - *(checked)* `decluster.intervals()` computes `r` but doesn't pass it
    on: it calls `decluster()` without `r`, which declusters by runs with
    the default `r = 1`, and then records the estimated `r` as the run
    length. The docs say clusters are separated using the estimated `r`.
    On a test series the estimated `r` was 2 (8 clusters), but intervals
    declustering returned 15 clusters, the same as runs with `r = 1`.
- **extRemes with a varying threshold and `na.omit`** *(checked)*:
  `if(length(threshold==1))` is always TRUE, so `na.action` is applied to
  `x` alone and the threshold vector isn't shortened to match. With five
  steps, one missing, the comparison recycled the five thresholds over
  four values (R's length warning), and the output had five values for
  four inputs. (The default, `na.fail`, stops on NA.)
- **extRemes with `groups` and a varying threshold** *(checked,
  harmless)*: it passes `clusterfun = cluster`, the vector of cluster
  ids, where it means `clusterfun`, but it runs: R's function lookup
  skips the numeric argument and finds the right function.
- **POT measures its time condition from the cluster's running maximum,
  not from the last exceedance** *(checked)*. The docs say "two
  events are considered independent if the inter-arrival time is
  greater than a fixed duration". In `do_clust()`, a sub-threshold step
  stays in the cluster while it's within `tim.cond` of the largest value
  seen since **the step after** the cluster's start. Because that
  running maximum starts on the step after the first exceedance, and
  can be a sub-threshold value:
  - the step after the first exceedance is always in the cluster;
  - a run of non-decreasing sub-threshold values keeps moving the
    maximum forward, so the cluster can run on, and join an exceedance
    much more than `tim.cond` later;
  - clusters can end on sub-threshold steps within `tim.cond` of the
    maximum.

  *Checked:* with `u = 10`, `tim.cond = 1` and exceedances at times 2
  and 8, the five values between them rising from 9 to 9.9, `clust()`
  returned **one** cluster (times 2–9). evd's `clusters(r = 2)` returned
  two.

  A cluster that reaches the end of the series also loses its last step
  *(checked)*: the end index is decremented before it's stored. For
  values 0, 0, 12, 13, 14 the cluster maximum came back as 13 at time 4,
  not 14 at time 5.
- **The intervals estimator of the extremal index:** evd (`exi()` with
  `r = 0`) and extRemes use the form with T and T² when the largest
  interval is at most 2, and the form with T − 1 and (T − 1)(T − 2)
  above that. POT's `fitexi()` has them the other way round
  *(checked)*, and returns 0 when all exceedances are consecutive. On an
  AR(1) series with the largest interval 174, evd and extRemes gave
  0.5413 (the T − 1 form) and POT 0.5756 (the T form).
  `fitexi()` also returns a `tim.cond` estimate, the run length from the
  data.
- **POT's `ts2tsd()`** is a centred moving average over a duration `d`,
  on interpolated irregular times (for flow-duration analysis). Missing
  values and the windows past the record ends are filled with -1e6
  before averaging.

## What this means for spells

1. **A declustering parity preset is cheap.** For a constant or varying
   threshold, extRemes' and evd's runs declustering are spells with no
   minimum duration, `maxGap = r − 1`, and either the exceedances only
   (extRemes) or the whole span (evd) as the cluster. Spells should
   reproduce both, with stored golden outputs as for the other
   references.
2. **A spell's members need a rule: exceedances only, or the whole
   span.** extRemes counts only the exceedances; evd and POT include the
   joined steps. It matters for the cluster sum and for the extremal
   index. It's the same split as lfstat's `dbt` against `duration`, and
   the def records which one each metric uses.
3. **evd's `ulow`/`rlow` is a closing to offer:** join gaps shorter than
   `r` unless the series falls below a lower threshold for `rlow` steps.
   It sits between a plain gap rule and hysteresis.
4. **Estimated closings are data-set-relative.** Intervals declustering
   and POT's `fitexi()` choose the run length from the data. Spells can
   offer that only the way it offers a baseline: estimate once, store
   the value in the def, and apply it unchanged.
5. **Gaps measured in time, not steps** (POT's `tim.cond`) suit irregular
   series. Spells' gap rule counts steps; the def could allow a duration
   too, for irregular data.
6. **Missing data, three more ways:**
   - stop (extRemes' default);
   - delete the step and close up the series (extRemes with `na.omit`),
     which joins runs across the gap;
   - count as below the main threshold but above the lower one (evd).

   Closing up is the one to avoid: a missing step then neither breaks
   nor counts.
7. **These implementations disagree with their own docs in places**
   (POT's time condition, extRemes' intervals run length). For spells'
   parity tests, check against the written definition and the code, as
   the ClimInd notes say.
