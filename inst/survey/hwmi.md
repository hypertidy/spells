# HWMI and HWMId in extRemes 2.2-1

- **Source read:** `R/hwmi.R` and `R/hwmid.R` in the CRAN tarball
  `extRemes_2.2-1.tar.gz` (2025-05-16). The man pages name Simone Russo
  as the author of these functions.
- **How:** read 2026-11-18 from source, then checked by running the same
  day with extRemes 2.2-1 installed (`checks/hwmi.R` and `.out`). Points
  marked *(checked)* were confirmed by running.
- **References:** Russo et al. 2014, *J. Geophys. Res.*,
  doi:10.1002/2014JD022098 (HWMI); Russo, Sillmann and Fischer 2015,
  *Environ. Res. Lett.* 10, 124003, doi:10.1088/1748-9326/10/12/124003
  (HWMId).

## What they are

The Heat Wave Magnitude Index (HWMI) and its daily version (HWMId), for
daily maximum temperature on land. Each gives, per year, the magnitude
of that year's largest heatwave, with its duration and start day.
HWMId replaced HWMI in the 2015 paper.

## HWMId: the grid columns

- **Inputs:** `hwmid(yTref, Tref, yTemp, Temp)`. `Tref` must hold **32
  years**: the 30-year reference period plus one year either side, so
  the threshold window has data at both ends (e.g. 1980–2011 for a
  1981–2010 reference).
- **Leap days:** `cut366thDay()` drops the **366th day** of each leap
  year, which is 31 December, not 29 February. After 28 February, a
  leap year's days sit one slot later.
  - Leap years are every fourth year (`year %% 4 == 0`), with no century
    rule, so 2100 counts as a leap year.
  - A series whose length is a whole number of 365-day years is left
    alone, so `noleap` data passes through.
  - The series must start on 1 January.
- **Baseline / threshold:** per slot (365 of them), the 90th percentile
  (**type 8**) of the 30 reference years over a **31-day window**
  (±15 days), so 930 values. No smoothing.
  - At the ends of the reference period, the window takes days from the
    padding years, the adjacent real years. heatwaveR 0.5.5 wraps within
    the year there, and 1.0.0 shortens the window.
- **Direction:** above, strictly (`Ti > threshold`).
- **Persistence:** at least 3 consecutive days. No gap joining.
- **Season year:** each 365-day calendar year on its own. Runs are **cut
  at 1 January**, and the whole year is used, with no summer window and
  no hemisphere option. So a southern summer heatwave across the new
  year is split in two.
- **Missing data:** a missing day in `Temp` becomes -999.9, so it's
  below the threshold, breaks the heatwave and adds nothing. In `Tref`,
  missing values are dropped from the quantiles and maxima.
- **Magnitude:** for each heatwave day,
  `(T − T30y25p) / (T30y75p − T30y25p)` if T is above `T30y25p`, and 0
  otherwise. `T30y25p` and `T30y75p` are the 25th and 75th percentiles
  (type 7) of the 30 reference years' annual maxima. A heatwave's
  magnitude is the sum over its days.
- **Summary:** per year, the largest heatwave magnitude, with that
  heatwave's duration and start day (1–365). Ties go to the first. A
  year with no heatwave gives 0.
- **Categories:** none. **Many series:** one series per call.
  **Streaming:** no.
- **Outputs:** a matrix (year × magnitude, duration, start), the 365
  thresholds, and `T30y25p` and `T30y75p`.

## HWMI (2014), briefly

- The same threshold and heatwave definition.
- Magnitude: heatwaves are split into 3-day blocks, and each block's sum
  is scored by its probability under a kernel density (bandwidth
  `bw.SJ`) of the reference years' annual maximum 3-day sums.
- Heatwaves whose length isn't a multiple of 3 are padded or trimmed by
  rules written for 365-day years. One branch has a fixed 120 days
  (`Ts[1:120]`), and a comment mentions 122, which look like leftovers
  from a summer-only version.
- *(checked)* The loop over the reference years' 3-day maxima runs
  over years 2–32 of `Tref`, so 31 years, including the padding year
  after the reference period. HWMId's loop over annual maxima covers
  years 2–31.
  - With a spike put into year 32 only, `hwmi()`'s density is
    identical to one built from years 2–32, and its support reaches the
    spike. HWMId's percentiles of annual maxima match years 2–31 and are
    unaffected.
- *(checked)* Padding a heatwave of 3n + 2 days, the main branch
  adds `max(Ts[hwt - 1], Ts[hwt:(hwt + hwd)])`, the maximum over the day
  before, **the whole heatwave and the day after**, so in practice a
  copy of the hottest day. The edge branches use a neighbouring day
  instead.
  - For a 5-day heatwave, `hwmi()` gave 1.187, the value with the
    hottest day (36.6) as padding. With the larger of the days before
    and after (27.7) it would be 0.573.
- *(checked)* **A tie in a year's largest 3-day sum corrupts the
  density.** `consecDayMax()` returns `c(times, max)`, and `hwmi()` keeps
  element 2. With two tied maxima, element 2 is the second day number
  (251 in the check, not the sum, 60). The package's Carcassonne data
  has no tied year in 1981–2011, so this is rare in data recorded to
  0.1 °C, but not impossible.
- The 3-day sums are centred on days 2–364 of each year, so they don't
  cross 1 January.
- The leftover branches `Ts[1:120]` and `Ts[1:363]` can't be reached.
  They need a heatwave from day 2 to day 365 (363 days), and 363 is a
  multiple of 3, so neither remainder branch applies.

## Duplicated helpers

`hwmi.R` and `hwmid.R` both define `cut366thDay()`, `mvThreshold()` and
`hwyear()`, and the file collated last wins. The first two copies are
identical. `hwyear()` differs: hwmi.R's treats a year with **122 or
more** days above the threshold as one heatwave starting on day 1 (a
summer-only leftover: June to September is 122 days), and hwmid.R's
does that only at **365**. *(checked)* The live one is hwmid.R's (365),
so both indices use it. Read alone, hwmi.R would mislead about what
`hwmi()` does in a warm year.

## What this means for spells

1. **HWMId is a preset candidate**, a widely cited land heatwave
   magnitude index. A `russo2015` preset would need:
   - a 31-day window over 30 years with a padding year either side, and
     type-8 quantiles at the 90th percentile;
   - 365 slots with 31 December dropped in leap years;
   - a minimum of 3 days, a strict comparison, no gap joining;
   - runs cut at the calendar year;
   - the magnitude metric, and the per-year maximum.

   Store golden outputs from `extRemes::hwmid()`. The package example
   reproduces its man page (Carcassonne 2003: HWMI 3.68, 12 days, from
   day 214; HWMId 18.6 for the same heatwave).
   - A HWMI (2014) preset, if wanted, should not copy two code details:
     the padding year in the 3-day-maximum density, and tied maxima.
     Store them as a parity version, not the clean rule.
2. **A metric can have its own origin and unit, fitted on the reference
   period.** HWMId's daily magnitude is measured from the 25th
   percentile of the annual maxima, in units of their interquartile
   range, and isn't tied to the detection threshold. That generalises
   the brief's category unit: the def holds the metric's reference
   statistics with the baseline.
3. **A summary can pick a spell by one metric and report others:**
   "the year's largest heatwave, and its duration and start". The brief's
   summaries should include that form (the argmax spell), not only
   maxima of each metric separately.
4. **A third leap-day rule:** drop the 366th day (31 December). The
   survey now has 29 February filled (heatwaveR), sharing 28 February's
   slot (climdex.pcic), dropped (EflowStats), and the 366th day dropped
   (HWMId, HIT).
5. **The reference period needs data outside itself** when the window
   reaches across its ends. The def should say how the ends are handled:
   padding years (HWMId), a wrap within the year (heatwaveR 0.5.5,
   climdex.pcic), or a shorter window (heatwaveR 1.0.0).
