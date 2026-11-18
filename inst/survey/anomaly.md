# anomaly 4.3.3 (CAPA)

- **Source read:** the CRAN tarball `anomaly_4.3.3.tar.gz` (published
  2024-08-19). GitHub: grosed/anomaly, branch 4.3. Fisch, Grose,
  Bardwell, Eckley and Fearnhead. GPL.
- **How:** read 2026-11-18 from the R source (`R/capa.R`), skimming the
  C++. The points first read from the code were then **checked by
  running** the same day (`checks/anomaly.R`, output in
  `checks/anomaly.out`).
- **References:**
  - Fisch, Eckley and Fearnhead 2022, *Stat. Anal. Data Min.*,
    doi:10.1002/sam.11586 (CAPA);
  - Fisch, Eckley and Fearnhead 2021, *J. Comput. Graph. Stat.*,
    doi:10.1080/10618600.2021.1987257 (MVCAPA);
  - Fisch et al. 2024, *J. Stat. Softw.* 110, doi:10.18637/jss.v110.i01
    (the package).
- CRAN checks were all OK on 2026-11-18.

## What it is

CAPA (Collective And Point Anomalies) finds **segments** whose mean, or
mean and variance, differ from a typical state, plus single-step
**point anomalies**. It works by **penalised cost segmentation**, an
optimal partition found by dynamic programming with pruning, not by a
threshold and a run rule.

MVCAPA, the same function on a matrix, finds segments that affect a
subset of the series, each with its own start and end lag. The package
also has PASS (Jeng, Cai and Li 2012) and BARD (Bardwell and Fearnhead,
doi:10.1214/16-BA998), which aren't covered here.

## The grid columns

- **Baseline:** assumed, not fitted. The docs say each series must be
  standardised so that its typical segments have mean 0 and variance 1,
  suggesting the median and the MAD. That's one value for the whole
  record, with no seasonal cycle: removing the cycle is the user's job.
- **Threshold:** none. A segment is anomalous when it lowers the total
  cost by more than its penalty `beta`.
  - `type = "mean"`: the reported test statistic is the segment length
    times its squared mean, so a long weak segment and a short strong
    one can both qualify. The decision weighs duration and intensity
    together.
  - `type = "meanvar"` (the default): a change in mean and variance;
    `type = "robustmean"`: the mean under Tukey's biweight loss, so
    outliers inside a segment don't break it.
  - **The default penalties depend on the series length:**
    `beta = 3 log(n)` (mean) or `4 log(n)` (meanvar), and
    `beta_tilde = 3 log(np)` for point anomalies. `beta` can also be a
    vector, one penalty per segment length.
- **Direction:** both. The statistic uses the squared mean, so raised
  and lowered segments are found together; the sign is in the data.
- **Persistence:** `min_seg_len` (default 10; at least 2 for meanvar) and
  `max_seg_len` (default no limit). There's no gap rule: a dip inside a
  segment is absorbed if the segment still pays for itself, and
  otherwise the segment splits. Segments don't overlap.
- **Missing data:** not handled. *(checked)* The input check
  `Reduce("|", x == Inf)` gives NA when `x` has a missing value, so
  `capa()` stops with "missing value where TRUE/FALSE needed".
- **Time step:** any, by index. **Calendar and season year:** none.
- **Metrics:** start, end, the series affected, start and end lags
  (MVCAPA), the mean change, and the variance change or test statistic.
  Point anomalies give a location and strength.
- **Many series:** MVCAPA. A segment affects a **subset** of the series,
  chosen by the penalty regimes in Fisch et al. (2022), and each
  affected series can start and end up to `max_lag` steps away from the
  others. That's co-occurrence across series, not spatial adjacency.
- **Streaming: sequential, with revisions.** The dynamic programme stores
  each step's best previous change point, and `epoch =` backtracks from
  any step. So the result at step t uses only the data up to t, and an
  earlier epoch can segment the same period differently from the final
  one. With the default penalties, though, `log(n)` uses the full
  length, so an epoch's result isn't what a run on the data to that step
  would give.
- **Outputs:** an S4 `capa.class`, read with `collective_anomalies()` and
  `point_anomalies()`.

Smaller points read from the code:
- *(checked)* The backtracking loop runs while `cursor > 1`, so a point
  anomaly at the first observation is never reported: an outlier of 50
  at t = 1 gave no point anomaly; the same outlier at t = 2 was found.
- From the code, not checked: for `robustmean`, the extra point anomalies
  within a segment use `start.lag` for both ends (`end - start.lag`).
  `robustmean` is univariate only, where the lags are 0, so it has no
  effect there.
- *Resolved by running:* `collective_anomalies()` uses magrittr's
  `%<>%`, which none of the package's imports export. It works only
  because it sits inside a `%>%` chain: magrittr's `%>%` (imported
  through tidyr) unrolls the whole chain and handles `%<>%` itself. With
  only `%>%` bound, `x %<>% rev() %>% identity()` works and `x %<>%
  rev()` alone fails with "could not find function".

## What this means for spells

1. **Not an oracle.** CAPA isn't a threshold-and-persistence method, so
   no spells def reproduces it.
2. **A segmentation detector could plug in after the baseline.** Spells'
   chain is baseline → threshold → exceedance → excursion → spell. CAPA
   replaces the middle steps with one segmentation on the standardised
   series (x minus the baseline, divided by the slot's spread). If the
   detector's interface is "anomalies in, (start, end) spells out", the
   metrics and summaries apply unchanged. Worth keeping that seam open,
   not building it now.
3. **An opening on evidence, not on duration alone.** CAPA keeps a
   segment when length × mean² beats a penalty. Spells could offer a
   minimum on cumulative intensity (or on length × mean²) next to the
   minimum duration and the minimum peak, as a fixed value in the def.
4. **Penalties from the series length are data-set-relative,** like the
   other whole-record settings: a fixed `beta` in the def is the
   reproducible form.
5. **Sequential results with revisions** are the brief's provisional
   tail, with a sharper edge: under CAPA, adding data can move a past
   segment's ends, or split it, with no fixed limit on how far back.
   Spells' rules keep revisions within a bounded tail; the streaming
   state should say how long it is.
6. **Co-occurrence across series with lags** (MVCAPA) is another way to
   define an event over many series, next to spatial components
   (Ocetrac, heatwave3's blobs) and lagged pairing (hydroEvents). It
   needs no adjacency, so it suits stations and regions.
