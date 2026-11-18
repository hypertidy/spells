# phenofit 0.3.11

- **Source read:** the CRAN tarball `phenofit_0.3.11.tar.gz` (published
  2026-01-23). GitHub: eco-hydro/phenofit. Dongdong Kong and others.
  GPL-2.
- **How:** read 2026-11-18 from source: `R/check_input.R`,
  `R/season_mov.R`, `R/season_tools.R`, `R/add_HeadTail.R`,
  `R/PhenoTrs.R` and `R/get_pheno.R`, with the curve fitting and the
  other phenology methods skimmed. **Not run.**
- **Reference:** Kong et al. 2022, *Methods Ecol. Evol.* (phenofit, per
  the NEWS for 0.3.5).

## What it is

Land surface phenology from vegetation-index series (MODIS EVI and NDVI,
flux-tower GPP): the start, peak and end of each growing season. The
pipeline:
1. **check the input** (`check_input()`): quality weights, spikes, gaps;
2. **divide the seasons** (`season_mov()`): a rough weighted smooth of
   each year, then peaks and troughs;
3. **fit curves** to each season (`curvefits()`): double logistic forms
   (Beck, Elmore, Zhang, Gu, Klosterman) or TIMESAT's asymmetric
   Gaussian;
4. **extract phenology** (`get_pheno()`): by threshold (TRS), by
   derivative (DER), and the Gu, Zhang and Klosterman methods.

Only the threshold method is close to spells.

## The grid columns

- **Input check** (`check_input()`):
  - `nptperyear`, the steps per year, defaults from the first interval;
  - `ylu`, the valid range, is the `alpha/2` and `1 − alpha_high/2`
    quantiles (default 1% and 99%) of the **good-quality values over the
    whole record**, with the lower bound at least 0;
  - values below `ylu[1]` become `missval`, which defaults to `ylu[1]`;
    high values with low weight do too;
  - **spikes**: a value more than 2 SD from the mean of its two
    neighbours, or from a moving mean of about 10 days, becomes NA;
  - quality flags (cloud, snow) **lower the weight** of a value rather
    than removing it (`wmin` 0.2, `wsnow` 0.8), and the fits use the
    weights.
- **Missing data:** gaps up to `maxgap` steps (default 1.5 months) are
  interpolated linearly. **Longer gaps are filled with the background
  value** (`ylu[1]`) at the minimum weight: the code comments that bad
  values occur mainly in winter. With `na.rm = TRUE`, missing and spike
  values are dropped instead.
- **Record edges** (`add_HeadTail()`): the series is padded at each end
  with a **copy of the adjacent year's data**, shifted in time, so the
  first and last seasons can be fitted. A series of one year or less is
  tripled.
- **Seasons, from the data:** peaks and troughs of the rough fit, kept
  when they stand out from their neighbours by fractions of the
  amplitude (`r_max` 0.2, `r_min` 0.05), at least `nptperyear/6` steps
  apart. A season runs from trough to trough, and is dropped when it's
  45 days or shorter, 650 days or longer, or its peak is below 0.1. If a
  year has too many peaks or troughs, the smoothing parameter doubles
  and the division runs again.
  - Each year's rough fit uses 12 months either side
    (`maxExtendMonth`), so it's two-sided.
  - The smoother's `lambda` comes from the V-curve per series unless
    given.
  - `calendarYear = TRUE` uses fixed seasons instead: 1 January to 31
    December, or 1 July to 30 June with `south = TRUE`.
- **Season year:** a season is labelled by **the calendar year of its
  peak**, and numbered within the year (`flag`, e.g. `2015_1`,
  `2015_2` for double cropping). Fixed southern seasons are labelled by
  their start year.
- **The threshold method** (`PhenoTrs()`, approach "White", the default):
  on each season's fitted curve,
  - the **base** is the minimum before the peak for the start, and the
    minimum after it for the end (`asymmetric = TRUE`), so the two
    thresholds differ;
  - the curve is scaled to 0–1 between base and peak, and the threshold
    `trs` is a **fraction of that season's amplitude** (0.2, 0.5 and 0.6
    by default in `get_pheno()`);
  - SOS is the median of the times, before the peak and while rising,
    when the scaled curve is within ±0.05 of `trs`; EOS likewise, after
    the peak and falling;
  - if there's no such time, the band widens to ±0.1, and **if there's
    still none, SOS is set to the midpoint between the season's start and
    its peak** (EOS likewise), with no flag.
  - The "Trs" approach uses an absolute threshold instead, with a band
    of 5% of the range.
- **Direction:** up for the start, down for the end.
- **Persistence:** none in the threshold sense: one crossing per side
  per season.
- **Time step:** any regular step (`nptperyear`), commonly 8 or 16 days.
  **Calendar:** dates.
- **Metrics per season:** start, peak and end dates (and the values
  there) for each method; season length.
- **Categories:** none. **Many series:** one per call. **Streaming:** no.
- **Outputs:** lists and data tables of seasons, fits and phenology
  dates.

## What this means for spells

1. **Not an oracle for spells**, but the closest prior art for the
   bloom-type presets, where the baseline is a statistic of each season.
   phenofit's threshold differs from Siegel et al. 2002 (first exceedance
   of that year's median + 5%): it's a fraction of the season's
   amplitude on a fitted curve, found as a median time near the crossing.
2. **"A fraction of the season's amplitude" is another threshold type**:
   base + `trs` × (peak − base), with the base taken separately before
   and after the peak. Separate start and end bases make it a kind of
   hysteresis.
3. **Seasons can be found from the data**, trough to trough, rather than
   set by the calendar. The def would then record the division rule, and
   spells' season-year label needs one more option: by the year of the
   peak (phenofit). Seasons can also be several per year, so summaries
   need a season index within the year.
4. **Never fill a date silently.** PhenoTrs's fallback date (the midpoint
   between season start and peak) looks like a detection. Spells
   returns NA with a reason.
5. **Don't fabricate edges.** Copying the adjacent year onto each end
   lets the first and last seasons be fitted, but part of what's fitted
   is made up. Spells censors instead.
6. **Long gaps as background** is the same choice as heatwaveR's "count
   as baseline after interpolation". It's a missing-data option the def
   can name, but not a default.
7. **Quality as weights** (cloud, snow) is a softer form of the brief's
   eligibility mask. Spells' masks are binary; a weight only makes sense
   with a fitted baseline, so it's out of scope for the core.
8. **Data-set-relative again:** the valid range, the smoothing parameter
   and the season division all depend on the whole record.
