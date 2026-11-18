# MHW-MAD (DMI, ESSD 2026)

- **Sources read on 2026-11-17:**
  - the paper, Hayward et al. 2026, "Marine Heat Waves and Cold Spells –
    Multiple Analysis/Definitions (MHW-MAD)", *Earth Syst. Sci. Data*
    18:7181–7197, doi:10.5194/essd-18-7181-2026, read in full from the
    PDF;
  - the Zenodo record v1.0 (2026-08-07), doi:10.5281/zenodo.21835325:
    `README.md` and `manifest.csv`, which lists 49 datasets.
- **The code isn't public.** The paper says "We aim to make this code
  available as a python package ... as such the code is currently under
  embargo" (§6.2). The processing used Python with CDO 2.1.1 and NCO
  5.2.1 (§3). So the method comes from the paper and the README, and
  from the data itself.
- **Checked against the data on 2026-11-18** (`checks/mhw-mad.R` and
  `.out`): nine Tasman Sea pixels, 2° apart (150–154°E, 39–43°S), for
  2015–2016, the years of the 2015/16 Tasman Sea marine heatwave. The
  data came from DMI's ERDDAP (2.30) and was cached outside the repo.
  The check compares each product's categories with its own anomalies
  and thresholds. It can't test the climatology itself, because ERDDAP
  serves only the 49 MHW-MAD datasets, not the CCI SST behind them.
  Points marked *(checked)* come from this.
- **What it is:** a gridded data product, not a library. It covers ESA
  SST CCI L4 v3.0 (CDR plus interim CDR) at 0.05° (7200 × 3600), daily
  from 1982-01-01 to 2024-12-31. The input is gap-free; land is NaN.
- The section numbers below are the paper's.

## The grid columns

- **Baseline:** for each day-of-year slot (366, including 29 February), it
  pools every value in a ±5-day window across every year of the
  reference period. The mean and the percentiles are taken from that
  pool, then smoothed with a 31-day moving average "wrapped from 31
  December to 1 January, when required" (§3.2). In non-leap years, the
  values for DOY 60 are interpolated linearly between DOY 59 and 61
  (§3.3). The reference periods are:
  - **WMO**, 1991–2020;
  - **reanalysis**, 1993–2022;
  - **moving**: 14 30-year windows from 1982–2011 to 1995–2024, one year
    apart. Each window provides files "only for the last year of each
    window" (§5), so year Y is assessed against Y−29 to Y. That's a
    trailing window that includes the year itself, giving events from
    2011 on (Table 1);
  - **detrended**: WMO period, 90th percentile and 5 days only (§3.1).

  - *(checked)* **Slots follow a 366-day calendar**: in a non-leap
    year, 1 March is slot 61. With calendar day numbers (1 March = 60)
    4 days disagree, and with the 366-day calendar none do.
  - Slot 60 is within 0.0015 K of the mean of slots 59 and 61, where
    neighbouring slots differ by up to 0.03. So it's close to an
    interpolation, but not exact: perhaps interpolated before the 31-day
    smoothing.

  Not stated, and not checkable without the SST:
  - which percentile estimator;
  - whether the ±5-day window takes days from the adjacent years at the
    new year (the heatwaveR 0.5.5 and 1.0.0 difference) or wraps within
    the year;
  - any rounding.
- **Detrending is per pixel and per calendar date, over the whole
  record.** For each pixel and each calendar date, it fits SST against
  year by ordinary least squares over 1982–2024, "regardless of
  statistical significance", and subtracts "the linear trend component"
  (§3.1). The climatology and the anomalies are then built from the
  detrended SST (§3.3; §4.1: "Removing each grid-cell's linear trend
  before building the climatology"). So detection reads detrended data,
  unlike heatwave3's `detrend` (see heatwave3.md). The paper doesn't say
  whether the intercept or only the slope term is removed; Fig. 2 shows
  both.
- **Threshold:** percentiles of SST in the window: 90th, 95th and 99th
  for heatwaves; 10th, 5th and 1st for cold spells (§3.2, §3.6).
- **Direction:** the SST anomaly "exceeds" the threshold (§3.4). Category
  1 starts at "anomaly ≥ threshold" (§3.5), which is `>=`. Cold spells
  fall below the threshold. No anomaly in the check equals its threshold
  exactly, so `>=` and `>` couldn't be told apart.
- **Persistence:** a minimum of 5 days, with 10- and 30-day variants for
  the WMO 90th percentile only. The paper says "at least 10 consecutive
  days above the threshold" (§3.4) and doesn't mention gaps. The README
  says "Gaps of ≤2 days are bridged within an event".
  - *(checked)* **Gaps are bridged first, then the minimum is tested on
    the bridged span**, gap days included. So a 3-day run next to a
    4-day run, 1 day apart, is an 8-day event, and a short run joins a
    long one across a gap. This rule matches every flagged day in the
    5-, 10- and 30-day products, leaving out runs that touch the ends of
    the two years fetched.
  - That's the reverse of Hobday and marineHeatWaves, which keep runs
    of at least 5 days first and then join them. Their order differs on
    88 of the 1942 event days here (4.5%) for 5 days, and 146 and 104
    days for 10 and 30.
  - Counting only the days above the threshold toward the minimum
    doesn't match either (12, 27 and 0 days off).
  - *(checked)* **Bridged gap days get category 0** ("none"), so the
    files can't show where an event's gaps are, only its days above the
    threshold.
  - Not checked: any rule at the ends of the series (1982 and 2024).
- **Missing data:** not needed, because the input is gap-free.
- **Ice: no mask.** CCI gives about −1.8 °C under ice, so the thresholds
  under multi-year ice are 0. Newly open water then reads as heatwave
  hot spots. The paper points to SST/IST products for polar work (§3.4).
- **Time step:** daily. **Calendar:** Gregorian, with time in seconds
  since 1970. **Season year:** none, because the fields are daily.
- **Metrics:** none per event. The paper says "we do not assign spatial
  extents or track contiguous areas of MHW" (§3.4).
- **Categories:** Hobday 2018 bands of the anomaly in units of threshold
  minus mean: 1 is below 2×, 2 runs from 2× to 3×, 3 from 3× to 4×, and 4
  is 4× or more. 0 means no event that day (§3.5). *(checked: every
  event day's category is `floor(anom / threshHW)`, for categories 1–3;
  no day here reached 4×, so the cap at 4 is untested.)* Two things to
  note:
  - **For the 95th and 99th percentile products the unit is that
    threshold minus the mean**: "We compute such categories for each
    threshold definition ... as separate files". So their category 2
    isn't Hobday's category 2. *(checked: the 95th percentile categories
    all match `floor(anom / (p95 − mean))`; in units of p90 minus the
    mean, 321 of the 972 event days would get a different category.)*
  - Cold-spell categories are stored as positive magnitudes. The README
    cites Hobday 2016 for the categories; the paper cites 2018.
- **Outputs:** CF-1.8 NetCDF-4, from download.dmi.dk and ERDDAP
  (`erddap.dmi.dk`), which serve the same files.
  - One file per date for anomalies (`anom`) and categories (`cat_HW`,
    `cat_CS`), and one per day of year for climatologies (mean,
    percentiles, `threshHW`, `threshCS`).
  - The manifest has 21 anomaly, 21 category and 7 climatology datasets,
    named `mhw_<raw|detr>_<baseline>_<pct>_<dur>_<anom|cat|clim>`.
  - **No detrended category dataset is listed.** There are only
    `mhw_detr_wmoClim_90p_5d_anom` and `mhw_detr_wmoClim_90p_clim`, though
    the paper's Fig. 7E maps detrended categories.
  - ERDDAP serves exactly the manifest's 49 datasets *(checked)*. That
    leaves gaps:
    - there's no 5-day anomaly dataset for the raw WMO 90th percentile,
      but anomalies don't depend on the duration or the percentile (the
      90p 10-day and 95p 5-day WMO anomalies are identical), so another
      WMO one stands in;
    - only 3 of the 14 moving windows have a climatology dataset
      (1983–2012, 1987–2016 and 1995–2024).
  - *(checked)* **Categories aren't stored as whole numbers**: 1 is
    0.9999843, 2 is 1.999969, 3 is 3.000015, and 0 is −4.7 × 10⁻⁷, so
    readers must round. ERDDAP serves them as doubles with
    `flag_values` 0–4.
  - **Access by pixel is slow**: about 10–25 days per second, because
    each day is a file. A strided request for several pixels costs about
    the same as one pixel. Two years at nine pixels took 20 s to 5
    minutes per dataset, so the whole record (15,706 days) at a pixel
    would take 10–25 minutes per variable.
- **Streaming:** no NRT. Annual updates and more SST products are planned
  (§7).

**Inconsistencies in the sources:**
- The period of the record is given as 1982–2021 plus 2022–2024 (the
  abstract), 1982–2025 (§2) and 1982–2024 (§3.1 and the README).
- Gap bridging is in the README but not in the paper.

## What this means for spells

1. **"Detrended" is three different things so far:**
   - heatwave3 fits one trend per pixel over the climatology period and
     changes only the climatology. Detection reads raw SST.
   - MHW-MAD fits one trend per pixel and calendar date over the whole
     record, and detects on the detrended SST.
   - Ocetrac fits a linear term inside a harmonic regression over the
     whole record (see ocetrac.md).

   So a `detrended()` baseline needs parameters: the trend model (per
   series or per slot), the fitting period (the record or the reference
   period), and detection on the detrended series. Without the last it's
   really a fixed baseline with a narrower spread. The label has to
   carry all three.
2. **A shifting baseline needs a window rule.** MHW-MAD's window is
   trailing, includes the year being assessed, and moves one year at a
   time. An event that crosses the new year meets two climatologies. The
   paper doesn't say how that seam is handled, but the data shows that
   **detection doesn't restart on 1 January** *(checked)*: a 2-day run on
   1–2 January 2016 is flagged in the 1987–2016 product, because it
   continues an event from December 2015. Whether December 2015 was
   judged against the 1986–2015 or the 1987–2016 climatology can't be
   told here, because both put those days above the threshold. Spells' baseline is a
   value per step, not per slot, so a shifting baseline is a threshold
   that varies over a continuous series. The def needs:
   - the window length;
   - its alignment: trailing with or without the current year, or
     centred;
   - the update step;
   - what happens before a full window exists.
3. **The category unit is a separate parameter from the detection
   threshold.** The Hobday presets fix it at p90 minus the mean; MHW-MAD
   uses the detection percentile. The def should name it, with the
   threshold as the default.
4. **An oracle in data only, per step, and now with its rules known.**
   Given MHW-MAD's own anomalies and thresholds, spells can reproduce its
   daily categories exactly with:
   - 366 slots;
   - gaps of up to 2 bridged before the minimum;
   - bridged days in category 0;
   - categories as floors of the anomaly over the product's own
     threshold anomaly.

   So the gap-and-duration order is a def parameter, not a constant
   (Hobday: the minimum first; MHW-MAD and lfstat: join first). Testing
   the climatology too (the percentile estimator, the window at the new
   year) needs the CCI SST for the same pixels, from CEDA or Copernicus
   Marine. There are still no event metrics to test. It's worth doing if
   MHW-MAD becomes a reference product for a trend.* member.
5. **Ice:** MHW-MAD doesn't mask ice and says so. That supports the
   brief's eligibility mask.
6. **Labels:** the dataset names `mhw_<detrend>_<baseline>_<pct>_<dur>_<type>`
   are prior art for labels generated from the def.

## Checked by running

`checks/mhw-mad.R` fetched the WMO 90p anomalies, climatology and 5-,
10- and 30-day categories, the WMO 95p set, and the 1986–2015 and
1987–2016 moving products, all for the nine pixels and for 2015–2016
(13 requests, about 15 minutes in all; the saved `.out` is a rerun from
the cache, so it doesn't show the download times). The answers to the
questions listed here before:
- Does `cat_HW > 0` mean the anomaly is at least `threshHW`? Yes, on
  days in an event, with 366-day slots. Whether it's `>=` or `>` can't
  be told: no anomaly equals its threshold.
- Are runs at least 5 days, with gaps of 2 days or less bridged? Yes,
  but the bridging comes first and the gap days count toward the 5.
  Bridged days are category 0.
- Are the category bands floors of the multiple? Yes, for categories
  1–3, in units of each product's own threshold.
- Do the moving-window products change at 1 January? Their
  climatologies do, so the anomalies jump at the seam: by up to 0.08 K
  more than the WMO product's change from 31 December to 1 January.
  Event detection carries across the seam.
