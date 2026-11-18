# xclim 1.0 (Python)

- **Source read:** Ouranosinc/xclim `main` at `c1f538c` (2026-11-12,
  1.0.1-beta.3). v1.0.0 was tagged on 2026-11-04 (`7c071e9`). Of the
  files read, only `compute/generic.py` changed between the two. Apache
  2.0. Ouranos.
- **How:** read 2026-11-18 from source: `compute/run_length.py`,
  `compute/helpers.py` (`spell_mask`), `compute/generic.py`
  (`spell_length_statistics`), `compute/_multivariate.py` (WSDI, heat
  wave frequency), `core/calendar.py` (`percentile_doy`,
  `resample_doy`) and `core/missing.py`. **Not run.**
- **1.0.0 renamed `xclim.indices` to `xclim.compute`**, among other
  breaking changes. Paths below are relative to `src/xclim/`.

## What it is

The climate-index library for xarray: ETCCDI and many other indices as
"indicators" with CF metadata, units and missing-value checks, over
gridded or station data, with dask. Spells come from a general
run-length module, not from a heatwave-specific engine.

## The grid columns

- **Baseline / threshold:** absolute values (with units), or percentiles
  per day of year from `percentile_doy()`:
  - the window is `window` (5) **time steps, centred, with
    `min_periods = 1`**, so it takes the adjacent real days across the
    new year, and is shorter at the ends of the data given;
  - **type-8 quantiles** by default (`alpha = beta = 1/3`; type 7 is
    available);
  - no smoothing;
  - **slots are calendar day-of-year numbers** (`dt.dayofyear`), so after
    28 February a leap year's days sit in the next slot. Slot 366 (only
    in leap years) is dropped, and **the 365 values are stretched onto
    366 days by linear interpolation** (`_interpolate_doy_calendar`:
    365 values placed at `linspace(1, 366, 365)` and read at 1…366), so
    every slot except the ends gets a slightly shifted value;
  - the reference period is whatever data the user passes, recorded in
    `climatology_bounds`;
  - bootstrapping (Zhang et al. 2005) is available for percentile
    indices with `bootstrap = True`.
- **Direction and comparison:** a parameter (`condition` or `op`). WSDI
  defaults to `>`.
- **Persistence, two layers:**
  - **`spell_mask()`**: a step is in a spell if it lies in any
    `window`-step period whose rolling statistic (`min`, `max`, `sum`,
    `mean`, optionally weighted) meets the condition. With `min` and `>`
    that's a run of at least `window`. With `sum` or `mean`, steps that
    don't meet the threshold themselves can be in a spell. Several
    variables can be combined with `all` or `any`. Then gaps shorter than
    `min_gap` are filled (so `maxGap = min_gap − 1`), after the minimum:
    Hobday's order.
  - **`find_events()` / `runs_with_holes()`**: an event starts with
    `window` consecutive steps of a start condition and ends with
    `window_stop` steps of a stop condition, which defaults to the
    opposite. That covers iglu's start and end rules and level
    hysteresis in one function. Its outputs include `event_length` and
    `event_effective_length` (the steps where the start condition holds:
    lfstat's `dbt`), and `event_sum` over those steps only.
  - `season()`: a single season per period, with a start and end
    condition, windows and a mid date (the GSL shape).
- **Season-year attribution is a parameter:**
  - `resample_before_rl = True` (the default for WSDI and the heat wave
    indices): the series is cut into periods first, then runs are found
    in each, so runs crossing the boundary are cut;
  - `False`: runs are found on the whole series and each run's length is
    stored at its **first** step (`index = "first"`, the default) or its
    **last** (`index = "last"`), then summed by period. So a run goes
    whole to the period it starts in, or ends in.
- **Missing data:** a missing value fails the comparison, so it breaks
  runs. Windows containing a missing value give NaN statistics, which
  fail too. Indicators then apply a **missing-value check per output
  period**, `"any"` by default: a period with any missing (or absent)
  input step is NaN. Other methods: WMO (11 or more missing days in a
  month, or 5 or more in a row), a percentage, or at least n valid.
- **Time step:** any frequency for run lengths; daily or coarser for
  `percentile_doy`. **Calendars:** all CF calendars through cftime, with
  day-of-year values converted between them (`convert_doy`,
  `adjust_doy_calendar`).
- **Metrics:** per period: counts, total and maximum lengths, sums,
  first and last run dates (`first_run`, `last_run`, `run_bounds`), and
  `rle_statistics` (min, max, mean, quantiles of run lengths). Per event
  with `find_events`.
- **Categories:** none. **Many series:** any array shape, with dask.
  **Streaming:** no.
- **Outputs:** CF-annotated xarray Datasets (indicators) or DataArrays
  (compute functions).

## What this means for spells

1. **xclim is the Python design to compare spells against**: a general
   run-length layer under many indices, with the attribution rule
   (`resample_before_rl`, `index`), the gap rule (`min_gap`), start and
   stop conditions with their own windows (`find_events`), and a
   missing-value policy per output period. Most of the brief's def
   parameters already exist there under other names.
2. **A rolling window statistic is another opening.** "Any 5-day period
   with total ≥ 20 mm" puts days into a spell that aren't individually
   beyond the threshold. Spells' min-duration opening is the `min` case;
   `sum` and `mean` belong with the cumulative-intensity opening already
   in the brief.
3. **Another slot convention:** day-of-year numbers, misaligned in leap
   years, with 365 values stretched onto 366. An xclim WSDI and a
   climdex.pcic WSDI won't agree exactly because of it, so the slot rule
   has to be part of any WSDI parity switch.
4. **Missing-value checks per output period** (any, WMO, percentage, at
   least n) are the "refuse the season" option in the brief, with
   concrete rules. The WMO rule is a named, citable default.
5. **Not an oracle for the Hobday presets** (no climatology smoothing,
   type-8 quantiles, different slots). It is a second implementation of
   WSDI and CSDI next to climdex.pcic, for the ETCCDI presets.
