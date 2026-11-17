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
  5.2.1 (§3). So everything here comes from the paper and the README.
  No data was downloaded and nothing was run.
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

  Not stated:
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
  fall below the threshold.
- **Persistence:** a minimum of 5 days, with 10- and 30-day variants for
  the WMO 90th percentile only. The paper says "at least 10 consecutive
  days above the threshold" (§3.4) and doesn't mention gaps. The README
  says "Gaps of ≤2 days are bridged within an event". Not stated:
  - whether the minimum duration is tested before or after bridging;
  - what a bridged day's category is;
  - any rule at the ends of the series.
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
  is 4× or more. 0 means no event that day (§3.5). Two things to note:
  - **For the 95th and 99th percentile products the unit is that
    threshold minus the mean**: "We compute such categories for each
    threshold definition ... as separate files". So their category 2
    isn't Hobday's category 2.
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
   time. An event that crosses the new year meets two climatologies, and
   the paper doesn't say how that seam is handled. Spells' baseline is a
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
4. **An oracle in data only, per step.** The daily category and anomaly
   fields can test spells' per-step state for a Hobday def on CCI input,
   pixel by pixel. That needs the CCI series for the same pixels (from
   CEDA). They can't test event metrics, because there are none.
   Reproducing a few pixels would also settle what the paper leaves
   out: the percentile estimator, the window at the new year, and the
   order of the gap and duration rules. It's worth doing if MHW-MAD
   becomes a reference product for a trend.* member.
5. **Ice:** MHW-MAD doesn't mask ice and says so. That supports the
   brief's eligibility mask.
6. **Labels:** the dataset names `mhw_<detrend>_<baseline>_<pct>_<dur>_<type>`
   are prior art for labels generated from the def.

## To check by running (optional)

From ERDDAP, for a few pixels and a year or two: `_cat`, `_anom` and the
matching `_clim`.
- Does `cat_HW > 0` mean the anomaly is at least `threshHW` minus the
  mean? Are the runs at least 5 days long, with gaps of 2 days or less
  bridged? What is a bridged day's category?
- Are the category bands floors of the multiple, as in §3.5?
- Do the moving-window products change at 1 January?
