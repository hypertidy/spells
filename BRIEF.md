# spells: brief

Draft 2026-11-17; Phase 1 started 2026-11-18 (the heatwaveR 0.5.5
parity engine, below). This is the design brief for hypertidy/spells. It sits at the repo root, and `.Rbuildignore` keeps
it out of package builds.

A **spell** is a persistent excursion of a series beyond a threshold set
relative to a baseline. A marine heatwave (Hobday et al. 2016) is one
preset. So is a cold spell, a sea ice season (Massom et al. 2013), a
phytoplankton bloom (Siegel et al. 2002), a high sea level spell, a dry
spell, or a run of high glucose. The plan: a domain-neutral R engine, with
the products kept where their data already lives, in the trend.* family.


## What exists already

The engine is already half-written. It's spread over the family:

- **trend.sst `R/mhw.R`**: a heatwaveR 0.5.5-exact reimplementation of
  `ts2clm()` + `detect_event()`, vectorised over a time x pixel matrix
  (one shared set of day-of-year window indices), with parity checked in
  `validate/mhw_parity.R`. Around it is a regional MUR pipeline: fetch
  native windows, transpose them to a series-layout Zarr (50 x 50 x ntime),
  run per-pixel events, write additive daily area-in-MHW sums by category
  (`pixel_daily.csv`), and feed `docs/heatwaves.html`. The site already
  compares *spells of the box mean* with *pixel spells*. heatwaveR's
  quirks are documented: NA is set to seas, the leading gap isn't joined,
  and a trailing gap of 2 days or fewer is joined at the end of the series.
- **trend.ice `R/ice_season.R`**: Massom 2013. Advance is the start of
  the first run of 5 or more days at or above 15%. Retreat is the day
  after the last day at or above the threshold. Day count is the number
  of exceedance days. Observation gaps of 5 days or fewer are
  interpolated, a season with a longer gap isn't computed, and the ice
  year starts on 15 Feb. That's a spell calculation with a fixed
  threshold, a shifted year and a missing-data policy, so it's a second
  consumer of the same engine.
- **trend.chl**: 5-day composites in log10 space, with heavy missingness
  (cloud, polar night). Bloom phenology hasn't been done yet, but it's a
  threshold plus persistence (median + 5% per pixel-year). trend.ice's
  chl-vs-days-since-retreat analysis is already "time since a spell ended".
- **trend.sla**: daily CMEMS DUACS from ARCO Zarr. grist reads the map
  layout (`timeChunked.zarr`). The series layout (`geoChunked.zarr`) is
  published too (see hypertidy/cmemsarco), so SLA spells need no
  rechunk. A high sea level spell is the obvious product (coastal
  relevance, Kelvin wave arrival).
- **grist**: date-at-a-time mergeable sufficient statistics on S2
  level 5. Its catalog contract (`date`, `dsn`, `band` or mdim) is the
  integration point.
- **ghrsst-cogger**: SQS + Lambda + Docker + Terraform, producing MUR COGs
  and a STAC GeoParquet index on source.coop. This is the AWS pattern we
  have already proven.
- **Infrastructure**: Setonix scrontab (`trend/tools/scron`), Acacia
  `aad-derived/` as the publication bucket, Gadi for BRAN (trend.ice
  `gadi/`), and Nectar for the ice season run and raadtools access.

That makes three consumers already (sst, ice, chl). grist was extracted
for the same reason, so extracting now is justified.


## State of the field (late 2026)

There's a fuller summary in `trend.ice/reports/spells-summary.md`. Full
citations are in `trend.ice/research_notes/Marine heatwave presentation
and regions/`. What it means for the engine:

- **heatwaveR 1.0.0 (2026-10-19) is the final release**, on GitHub only
  (CRAN still has 0.5.5). heatwave3 (v1.5.0, GitHub and PyPI) succeeds
  it:
  - multi-threaded C++ for R and Python, reading NetCDF (and Zarr, in
    Python only);
  - daily categories, 4D depth-resolved detection and blob detection;
  - regional runs from a global climatology.

  The Marine Heatwave Tracker moved to heatwave3 in mid-2026. Two
  consequences: parity has to name a version, and spells has to justify
  itself next to heatwave3 (see "Where it lives").
- **Baselines have a protocol now, though not a single answer** (Smith
  et al. 2025). There are five types: fixed, detrended, shifting,
  adaptation-adjusted and periodically updated. Always state the type
  and period. Report detrended or shifting results as best and worst
  cases. A full-record MUR baseline (2003-2025) is acceptable if it's
  labelled.
- **The standard area metrics** are:
  - daily % of area by category;
  - the annual % of area that reached at least moderate, or at least
    strong;
  - a highest-category map;
  - strong-or-higher days;
  - area-integrated cumulative intensity (degrees C x days x km^2).

  All of them are additive over pixels (see "Two scales").
- **Events are tracked as objects** (Ocetrac, heatwave3 blobs, NOAA's
  named NEP25A/NEP26A). The region becomes a viewport, not the
  definition of the event.
- **Products disagree by up to about 2x** on heatwave metrics
  (Chevillard 2026): smoother series give fewer, longer, weaker events,
  and maximum intensity is the most robust metric. That supports never
  pooling, using several products, and the estimator guardrails below.
- **Ice**: above about 50% ice concentration, SST collapses toward
  -1.8 degrees C (Zhang et al. 2025). Practice is to mask ice
  concentration of 0.15 or more per step, and drop pixels with mean
  concentration above 0.2. So spells needs an eligibility mask (below),
  and polar SST spells depend on ice data. That's the first input that
  crosses members.
- **In scope as presets or products**: cold spells, subsurface
  heatwaves (often strongest at 50-200 m), compound events, and Arctic
  heatwaves tied to ice loss.


## Where it lives: recommendation

| option | for | against |
|---|---|---|
| inside **trend** (AAD) | no new repo; it's the family home | trend is presentation and ops (kit, scron) with no R; an engine there is buried and not reusable |
| inside **grist** | already a shared engine | different access pattern: spells need contiguous time per series, keep state and take two passes (baseline, then detect), while grist is date-at-a-time and mergeable; spells don't need grist's dependencies (s2, vapour, arrow) |
| new **trend.mhw** deployment | gives "heatwaves" its own site | duplicates trend.sst's catalogs, baselines and regions; MHW is SST product knowledge |
| new **spells** package, products in members | the grist pattern again: an invariant engine plus host repos that own product knowledge; useful outside the family | one more repo, but an engine, not a deployment |
| just use **heatwave3** | fast, maintained, gridded, already the community engine for MHWs | specific to MHW and cold spells; reads files itself; nothing for ice seasons, blooms, non-daily steps, censoring, estimators, mergeable indicator sums or streaming state |

**Why spells when heatwave3 exists.** If heatwaves were the only goal,
the answer would be heatwave3. spells is justified by the other
consumers:

- the ice season, blooms and sea level, plus 5-day steps;
- composition with sums;
- the estimator contract;
- clean, censored semantics.

For the Hobday presets, heatwave3 is an oracle, and possibly a backend
behind the same `spell_def`. The survey must confirm what heatwave3
actually exposes, because the summary describes it from its docs.

**Recommended:**

1. **`spells`**, an R package at `~/Git/spells`. Decided: hypertidy,
   alongside grist. It's I/O-free computation. The name is free on CRAN
   and GitHub (hypertidy, mdsumner) as of 2026-11-17. Avoid
   "excursions": CRAN has it already (excursion sets for latent Gaussian
   models).
2. **No new deployment repo.** MHW and cold spells stay in trend.sst, the
   ice season in trend.ice, blooms in trend.chl, and high or low sea
   level spells in trend.sla. Each gets a `spells/` (or `data-raw/spell_*`)
   recipe set.
3. **The family layer goes in AustralianAntarcticDivision/trend**: a
   Spells kit module (shared page and data contract, synced by
   `kit-sync`) and a landing-page card. **"Heatwaves" stays the product
   name** on trend.sst and the card, because that's where the momentum
   is. The engine doesn't need the name. The kit's data contract carries:
   - the de facto category palettes, from heatwaveR: MHW `#ffc866`
     `#ff6900` `#9e0000` `#2d0000`, MCS `#C7ECF2` `#85B7CC` `#4A6A94`
     `#111433`;
   - labels generated from the def hash: product, baseline type and
     period, and the engine and parity version, on every title, as the
     Tracker does.
4. **A region registry, proposed for the family home.** Every member
   uses the same regions, so this meets the "second member needs it" rule
   from day one. Each region is a polygon, its cell sets per S2 level,
   and a citation of the closest published box. Candidate sets:
   - IPCC AR6 ocean regions, plus the Mediterranean and Caribbean;
   - Large Marine Ecosystems;
   - the Nino boxes;
   - Kajtar 2021's Australian boxes;
   - Coral Reef Watch virtual stations;
   - MEASO sectors and CCAMLR divisions;
   - trend.ice's sectors.


## The model: vocabulary as objects

```
baseline -> threshold -> exceedance -> excursion -> spell -> metrics -> summaries
```

- **time axis**: an index plus a *slot* (the climatological position:
  day of year on a 366 calendar, ice-year day, 5-day composite number)
  and a *season year* (calendar year, ice year from 15 Feb, or an austral
  bloom year). Don't assume daily data: chl is 5-day. Don't assume the
  Gregorian calendar either: some CMIP6 models in `oi10` use `noleap`
  (e.g. CESM2) or `360_day` (e.g. UKESM1), which heatwave3 can't read.
  climdex.pcic reads them, through PCICt. Don't assume regular steps:
  CGM readings are irregular, and iglu interpolates them onto a grid
  first. Regularisation is an input step, and the def records its rule
  (the grid step and alignment, duplicates, the interpolation limit).
  - The slot rule is part of the def, because conventions differ:
    heatwaveR uses 366 slots with 29 February filled from its
    neighbours, and climdex.pcic uses 365 slots, with 29 February
    sharing 28 February's slot, or 360 slots. EflowStats 5 drops 29
    February, where HIT and extRemes' HWMId drop day 366 (31
    December). xclim uses day-of-year numbers, so leap years are a slot
    out after 28 February, and stretches its 365 values onto 366.
  - So is the season-year label: winter is labelled by its December
    year in climdex.pcic and by its January year in ClimInd. lfstat
    makes it explicit for hydrological years: `assign = "majority"`,
    `"start"` or `"end"`. EflowStats changed its label in 5.2.0, from
    the end year to the majority. Seasons found from the data (phenofit
    divides trough to trough) are labelled by the year of their peak,
    and can be several to a year, so summaries need a season index
    within the year.
- **baseline**: the expected value per slot. The options are a
  climatology (windowed and smoothed, heatwaveR style), a fixed value, a
  per-season statistic (bloom: the median of that year), a trend-aware or
  shifting baseline, a covariate model, or a filter along the series
  (hydroEvents' baseflow separation). The usual filter runs forwards
  and backwards, so it doesn't stream; a filter baseline has to be
  one-sided to stream.
  - A baseline is fitted once over the reference period, then applied to
    new steps, as SCI's `fitSCI()`/`transformSCI()` and SPEI's
    `params =` do. That's the baseline object, stored with the def, for
    batch and streaming alike. A trailing k-step accumulation (SPEI's
    `scale`) can come before it, as part of the analysis space. It
    streams because it uses only the past. A centred window (lfstat's MA
    pooling, EflowStats' rolling means) streams only with a delay of
    half the window, so the def records the alignment.
  - The baseline **type** (Smith et al. 2025: fixed, detrended, shifting,
    adaptation-adjusted, periodically updated) and **reference period**
    are part of the def. Every label is generated from them, never typed
    by hand. "The whole record" (lfstat, ClimInd, EflowStats) is a
    reference period that moves: adding data changes past events.
    Allow it for parity, record it as such, and use a fixed period for
    streaming.
  - The type's name alone doesn't pin a baseline down (see the survey):
    - **detrended** needs the trend model (one per series, as heatwave3
      fits it, or one per slot, as MHW-MAD fits it per calendar date),
      the fitting period (the reference period or the whole record), and
      detection on the detrended series. Without detection on it, it's a
      fixed baseline with a narrower spread, as in heatwave3.
    - **percentile** baselines need the order as well as the estimator:
      pool a window and take the percentile (Hobday), or take the
      percentile per day and smooth it with running means (what
      MHW-MAD's data shows, against its paper). The mean is the same
      either way; the p90 differs by about 0.1 K on the same SST.
    - **shifting** needs the window length, its alignment (MHW-MAD's is
      trailing and includes the year being assessed; centred is the
      other choice), the update step, and the start before a full window
      exists. The baseline is a value per step, so a shifting baseline
      is a threshold that varies along one continuous series. Where the
      window steps at the new year, the threshold steps too, but spells
      run across it rather than restarting.
  - Where the window reaches past the ends of the reference period, the
    def says what fills it: data from outside the period
    (marineHeatWaves, where the series has it; HWMId needs a padding
    year either side), a wrap within the year (heatwaveR 0.5.5,
    climdex.pcic), or a shorter window (heatwaveR 1.0.0, xmhw, xclim).
  - For comparisons, use a fixed baseline on an earlier work's period,
    with detrended or shifting results as best and worst cases.
  - The choice matters most for long records and for projections (Amaya
    et al. 2023, Nature).
- **threshold**: the level relative to the baseline: a percentile (in the
  same window), baseline + k, baseline x (1 + p), an absolute value, a
  multiple of the standard deviation, or a probability (z value) under a
  distribution fitted per slot (SPI, SPEI, SCI). The last can
  extrapolate beyond the sample and handles zero inflation.
  - A fraction of the season's amplitude, base + f × (peak − base), with
    the base taken separately before and after the peak (phenofit's TRS,
    from TIMESAT). Separate bases give different start and end levels.
  - A threshold can come from another series: EflowStats' flood
    threshold is a percentile of annual instantaneous peaks, converted
    to daily flow. The def records the probability, not a
    recurrence-interval label, because packages convert between the two
    differently.
- **exceedance**: a logical per step, with a direction (high or low) and
  a comparison (`>` vs `>=`: trend.ice found old code mixing the two).
- **excursion**: a maximal contiguous run of exceedances.
- **spell**: an excursion that passes the persistence rules:
  minimum duration (an *opening*), maximum gap joined (a *closing*), the
  **order** of the two, and optionally hysteresis (separate start and end
  thresholds). ETCCDI's GSL is the standard example of the last. It
  starts with 6 days above 5 °C before July and ends with 6 days below 5
  °C from 1 July. In the south the year runs from July to June and the
  split is at 1 January. That's the same shape as ice advance and
  retreat.
  - **Closings differ** (lfstat and evd, see the survey):
    - inter-event time only (`maxGap`; lfstat's IT);
    - time and a magnitude condition (IC: the excess between events,
      relative to the deficit so far);
    - smoothing and detecting again (MA);
    - a storage rule (sequent peak: the spell lasts until its cumulative
      deficit is repaid);
    - a lower threshold: a gap is joined unless the series falls to a
      lower level for `rlow` steps (evd's `ulow`; with a long gap
      allowance, that's hysteresis).

    The def names the closing and its parameters. lfstat joins first and
    drops minor events after, the reverse of Hobday's order. So does
    MHW-MAD (checked against its data), counting the gap days toward its
    minimum. The two orders differ on about 4.5% of event days at Tasman
    pixels, so the order is a def parameter. A closing
    estimated from the data (intervals declustering, POT's `fitexi()`)
    is fitted once and stored in the def, like a baseline. Gaps count
    steps; for irregular series the def could give a duration instead
    (POT's `tim.cond`, iglu's 45-minute interpolation limit).
  - **Start and end rules** are another persistence model (iglu, from
    the CGM consensus): a spell starts with `d` steps beyond and ends
    only after `e` steps back, and everything between belongs to it.
    Only the first run has to meet the minimum, where heatwaveR joins a
    gap only between two runs that each meet it. The def says which runs
    the minimum applies to. xclim's `find_events()` is the general form:
    separate start and stop conditions, each with its own window.
  - **A minimum on the peak** is another opening: detect at one level
    and keep the spells whose peak reaches another (hydroEvents'
    `eventMaxima()`). Unlike hysteresis, the start and end stay at the
    detection level. A minimum on cumulative intensity, or on length ×
    mean² as CAPA's segment test has it, weighs duration and intensity
    together. So does xclim's rolling-window spell: a step is in a spell
    if any `window`-step period containing it has a sum or mean beyond
    the threshold (with `min`, that's the plain minimum duration).
  - **Minimum sizes are fixed values**, never relative to the data set,
    such as lfstat's default of 0.5% of the largest event's volume,
    Ocetrac's area percentile, or a penalty that grows with the series
    length (CAPA's 3 log n). Relative values change past events as data
    is added.
  - **Other detectors could plug in after the baseline.** CAPA (the
    anomaly package) replaces threshold → spell with a penalised
    segmentation of the standardised series. If a detector only has to
    return (start, end) spells, metrics and summaries apply unchanged.
    Keep that seam open; don't build it now.
- **missing data** is a separate policy from sub-threshold gaps, because
  an observation gap isn't a sub-threshold gap. The options are:
  interpolate up to n steps, then count as baseline (heatwaveR); break
  the spell; or refuse the season (trend.ice). Deleting missing steps
  and closing up the series (extRemes with `na.omit`) isn't an option:
  the gap then neither breaks nor counts. Filling long gaps with the
  background value (phenofit) is "count as baseline" by another name.
  - "Refuse the season" has named rules: xclim's per-period checks (any
    missing step, the default; WMO's 11 or more missing days in a month
    or 5 in a row; a percentage; at least n valid), and climdex.pcic's
    15 a year or 3 a month.
  - A gap's length is the number of missing steps. xarray's `max_gap`
    measures from valid value to valid value, one more, so a Python
    port has to convert (xmhw doesn't).
- **censoring**: a spell that touches the start or end of the series,
  or a missing run it can't cross, is flagged as left- or right-censored
  instead of being silently cut short. These are the same flags as
  trend.ice's `ice_at_start` and `ice_at_end`. EflowStats' `trim`
  drops such spells instead, which a parity switch could copy. Two
  things spells never does: pad the record ends with copies of the
  adjacent year (phenofit's `add_HeadTail()`), or fill an undetected
  date with a guess (phenofit's fallback to the midpoint between season
  start and peak). Those come back NA, with a reason.
- **eligibility**: a mask of steps where the variable means nothing,
  such as SST under ice. Ineligible isn't missing:
  - it's never interpolated across;
  - it breaks and censors a spell;
  - it's counted separately from data gaps.

  A whole series can be ineligible (e.g. mean ice concentration above
  0.2). The mask is an input from another source: MUR's
  `sea_ice_fraction`, or trend.ice.
- **metrics** per spell: start, end, peak, duration, intensity (max,
  mean, cumulative, variance), onset and decline rates, the highest
  category reached, and the steps interpolated.
  - Onset and decline rates need a stated rule at the ends of the
    series, and tests there. marineHeatWaves and xmhw both divide by
    zero for an event that peaks on the series' last day (both checked
    by running). Spells marks a spell cut by either end of the series
    (at the end, the provisional tail) and gives no rate on that side.
  - Duration counts the joined gaps, so spells also report the steps
    actually beyond the threshold (lfstat's `dbt`). Cumulative intensity
    comes two ways too: with the joined gaps counted, as heatwaveR does,
    and beyond the threshold only (lfstat's `vbt`). Declustering splits
    the same way: extRemes' clusters hold only the exceedances, evd's
    and POT's the whole span.
  - Categories are Hobday 2018 multiples of threshold minus baseline,
    computed per step. The rule is part of the def: floor of the
    multiple, with event days below 1x counted as I. That's what
    trend.sst does now. The other way is levels by episode: a higher
    level counts only if it forms its own spell, with its own duration
    rule (iglu's level 2 and "level 1 exclusive" episodes). The def names
    which. It also names the category of joined gap days below the
    threshold: none in heatwaveR's daily categories, marineHeatWaves and
    xmhw, so their category durations sum to less than the spell's;
    category I in trend.sst. heatwaveR's daily categories are strict
    (`>`), against levels it builds by adding the rounded distance to
    the threshold and rounding again, where trend.sst takes the floor
    of the ratio (`>=`). spells' `categories()` has both.
  - A spell's own category is a rule too. heatwaveR and heatwave3 count
    its days at or above each level (`>=`, though their daily
    categories use `>`) and give the highest category whose share of
    the duration, rounded to a whole percent, is above zero: a 250-day
    event with one day in IV is I. `categories(event = "max")` gives
    the highest daily category instead.
  - The category **unit** is its own parameter, defaulting to the
    detection threshold. The Hobday presets fix it at p90 minus the
    baseline. MHW-MAD's 95th and 99th percentile products use their own
    threshold, so their categories aren't Hobday's.
  - More generally, a metric can have its own origin and unit, fitted
    on the reference period and stored with the baseline. HWMId
    measures each day from the 25th percentile of the annual maxima, in
    units of their interquartile range.
- **summaries** per season year: spell count, days in spell, days at or
  above each category, first start, last end (ice advance and retreat
  are summaries, not new algorithms), the longest spell, maximum
  intensity and the highest category. A summary can also pick one spell
  by a metric and report its other metrics: HWMId's yearly value is the
  largest heatwave, with its duration and start.
  - **Rates per observed time** (iglu's episodes per day of recording,
    with gaps excluded) stay comparable when coverage differs. Shares
    say whether they're of steps or of time; for irregular series these
    differ (iglu's time-above shares count readings).
  - **How a spell that crosses the season-year boundary is assigned** is
    part of the def. The survey found five rules:
    - by start (heatwaveR, heatwave3);
    - by end (climdex.pcic's CDD/CWD);
    - days split by year (WSDI with `spells.can.span.years`);
    - cut at the boundary, with each piece having to pass the minimum
      (WSDI's default, from fclimdex);
    - days split by year, with the spell counted once in each year it
      touches (EflowStats' DH15 and DL16).

    Counts and durations change with the rule. Every summary follows
    the def's one rule: EflowStats mixes them, cutting events for its
    counts and splitting them for its durations. xclim has three of
    these as parameters (`resample_before_rl` to cut; `index = "first"`
    or `"last"` for by start or by end), and xmhw adds by peak.
  - **Seasons with no spells** count as zero or are left out of means
    across seasons (EflowStats does both: FL1 and FL3). That's part of
    the def too.

**Default semantics are clean rules. heatwaveR matching is an option**
(`parity = "heatwaveR-<version>"`, below). Clean means:

- gaps are joined wherever there's a spell on both sides, and nowhere
  else;
- spells at the edges are censored, not gap-joined;
- the baseline isn't rounded;
- missing steps: a run of n or fewer missing steps is interpolated
  linearly. This happens in the analysis space (log10 for chl, following
  grist's transform), and the threshold is then tested on the filled
  values. A longer run breaks the spell, and the spells on either side
  are censored at the break. n counts steps, not days (5-day composites
  count as one step each). Each preset sets its own n:
  - `massom2013` uses 5, as trend.ice does now;
  - `hobday2016` uses 3, as trend.sst's masked sensitivity run does.

  Every spell records how many of its steps were interpolated, so users
  can filter on it. Missing steps at the very start or end can't be
  interpolated (there's nothing to bracket them), so they censor the
  spell instead.
- the climatology window is shorter at the ends of the reference
  period: it uses only the period's own days (heatwaveR 1.0.0,
  heatwave3, xmhw, xclim);
- nothing is invented for the baseline: a missing day in the reference
  period, and slot 60 in a non-leap year, just drop out of the pooled
  window (heatwave3 for gaps, marineHeatWaves for 29 February). The
  interpolation of short runs is for detection only;
- a slot gets a baseline only if at least half of the reference
  period's days that fall in its window are there. Otherwise it has no
  baseline, and steps in that slot count as missing. Each preset sets
  its own share; `hobday2016` uses half. The 31-slot smoothing then
  uses the slots around it that have a baseline, and the slot itself
  stays without one;
- categories are the floor of (x - seas) / (thresh - seas), capped at 4
  (Hobday 2018, marineHeatWaves, xmhw). Joined gap days get no
  category, and a spell's category is its highest daily category
  (`categories(">=", NULL, "none", event = "max")`). A gap day exactly
  at the threshold gets none too, though the floor of its multiple is 1
  (marineHeatWaves' formula gives it I), so the steps with a category
  are exactly the steps beyond the threshold;
- the rest carries over from the parity work unchanged: a pooled window
  with the type-7 percentile and the mean, a 31-slot running mean that
  is periodic over the 366 slots, exceedance as `x > thresh`, the
  minimum before the join, and no rate on a side the spell is cut on
  (by the series' end or by a missing run it can't cross). A rate next
  to an interpolated step uses the interpolated value. The minimum
  applies to the run as observed: a shorter run beside a cut is
  dropped, not kept as a censored spell.

**Parity names a version**: `parity = "heatwaveR-0.5.5"`,
`"heatwaveR-1.0.0"` or `"heatwave3-1.5.0"`. The survey has the full table
of switches for each version (`inst/survey/heatwaveR-versions.md`).
marineHeatWaves (`d7292bf`, the original Python code) is a candidate
fourth: stored outputs on a few pixels would show which of heatwaveR's
behaviours are inherited (see `inst/survey/python-mhw.md`). It runs
only under NumPy below 2, or with a two-line patch (checked), and a
golden-output script must pass `climatologyPeriod` and a copy of the
series on every call: the default period is written back after the
first call, and by default NaNs in the input are overwritten.

`heatwaveR-0.5.5` is what trend.sst matches now (from `R/mhw.R`):
- NA is set to seas after `maxPadLength` interpolation;
- the leading gap isn't joined;
- a trailing gap of `max_gap` or less is joined at the end of the
  series;
- the climatology window wraps within each year at the new year;
- seas and thresh are rounded to 4 decimals;
- Feb 29 in non-leap years is filled with the rounded mean of 28 Feb and
  1 Mar;
- missing (doy, year) cells in the climatology period are filled with
  that doy's mean across years. That's in heatwaveR but not in
  `R/mhw.R`, which stops on any NA. spells' heatwaveR modes fill them
  (`reference_missing = "plug"`), so where `R/mhw.R` stops, the parity
  mode gives heatwaveR's answer.

1.0.0 drops two of these. The window takes the days across the new year
from the adjacent years, so seas and thresh change from 12 Dec to 20
Jan, and the trailing gap isn't joined. The summary's "0.5.3.x" change
to the moderate-category comparison (`>` to `>=`) is already in 0.5.5,
so it changes nothing here. heatwave3 1.5.0 equals 1.0.0 on gap-free
data, but not with gaps: it leaves missing cells out of the window
instead of filling them (`reference_missing = "omit"`, the one switch
between the `heatwaveR-1.0.0` and `heatwave3-1.5.0` modes), and doesn't
interpolate at detection. Every
quirk is a named, documented switch, tested against the version it
names.

API sketch (not a commitment):

```r
def <- spell_def(baseline = clim_window(11, smooth = 31), threshold = pctile(90),
                 direction = "high", min_duration = 5, max_gap = 2,
                 missing = interp(3, then = "break"))      # clean by default
hobday2016()                       # presets return a spell_def
hobday2016(parity = "heatwaveR-0.5.5")   # the same definition, that version's quirks
hobday2016(baseline = detrended())       # baseline type and period go into every label
b  <- spell_baseline(x, time, def) # x: time x series matrix; vector = 1 column
m  <- spell_mask(x, time, b, def)  # logical / category matrix, same shape as x
ev <- spell_events(x, time, b, m)  # one row per (series, spell)
s  <- spell_summary(ev, by = season_year(time, start = "02-15"))
st <- spell_state(...); spell_step(st, x_today, b, def)   # streaming
```


## Design principles

- **The core is I/O-free and matrix-first**: a time x series matrix in,
  and arrays or tables out. A series can be a pixel, an S2 cell, a
  station or a patient, and the shape is the same. Data frames are a
  convenience layer. I/O adapters (Zarr, COG, grist sums) live in the
  deployments.
- **Definitions are data**: a `spell_def` serialises to JSON and is
  hashed, and the hash is stamped into every output (Parquet metadata,
  COG tags). That's how grist stamps transforms.
- **Every preset gets an oracle**:
  - `hobday2016` / `hobday2018`: parity with each named version (reuse
    `validate/mhw_parity.R`). Published events are reproduced on OISST
    pixels in the exact box, not S2 cells selected by centre:
    - Oliver 2017 SEAus (147-155 E, 37-45 S): 251 days, 2.9 C;
    - Kajtar 2021 (147-157 E, 37-46 S, 1983-2012): 318 days, 2.8 C;
    - WA 2010/11, from Pearce & Feng 2013.

    trend.sst's 318 days matches Kajtar, not Oliver as its method page
    says.
  - The detrended baseline type has no heatwave3 oracle:
    `ts2clm3(detrend = TRUE)` changes the climatology only, and
    detection still reads the raw SST (see the survey). MHW-MAD's
    detrended products are data with no code, giving per-day anomalies
    for one trend model (per calendar date over 1982–2024).
  - MHW-MAD's per-day categories are reproduced exactly from its own
    anomalies and thresholds (checked at nine Tasman pixels): 366-day
    slots, join-first order, bridged days in category 0, floors of the
    product's own threshold unit. A `hayward2026` per-step parity test
    can use them as stored data. Its climatology is reproduced too, from
    the CCI SST (Copernicus Marine ARCO, no login): per-day mean and
    nearest-rank percentile of the 30 reference years, slot 60
    interpolated, then 11- and 31-day periodic running means.
  - `schlegel2021` (cold spells): parity, as for Hobday.
  - `massom2013`: trend.ice's current COGs, exactly.
  - `siegel2002`: published bloom timing.
  - ETCCDI WSDI/CSDI: climdex.pcic. It's off CRAN (archived 2023, with
    PCICt archived 2025), so store its outputs. The parity switch needs:
    - 365 slots and a 5-day window that wraps within the year;
    - type-8 quantiles, with no smoothing;
    - out-of-base thresholds in every year (the in-base bootstrap is
      only for the percentage indices);
    - strict comparisons, a minimum of 6 and no gap joining;
    - missing days that break the run;
    - the year cut by default;
    - the annual NA rule (more than 15 missing days, or any month with
      more than 3).

    ClimInd's WSDI isn't ETCCDI's, so it isn't an oracle.
  - A `russo2015` (HWMId) preset, if wanted: `extRemes::hwmid()`, with
    its quirks as the parity switch (31 December dropped in leap years,
    heatwaves cut at 1 January, the whole year, type-8 quantiles over a
    31-day window).
  - Runs declustering: extRemes' `decluster()` and evd's `clusters()`,
    as spells with no minimum and `max_gap = r - 1`.
  - A `battelino2023` (CGM episodes) preset, if wanted, shows the core
    is domain-neutral: iglu's `episode_calculation()` is the oracle,
    with its start and end rules, levels by episode and 45-minute
    interpolation limit.
- **Batch and streaming agree**: the online `state + step` form must
  reproduce the batch mask except for a declared **provisional tail**
  (about `max(min_duration, max_gap + 1)` steps), the same idea as
  trend.sst's daily run recomputing GHRSST's provisional dates.
  Segmentation methods (CAPA's `epoch =`) revise with no fixed bound,
  which is another reason they stay outside the core.
- **The baseline is the expensive, reusable artefact**: build and publish
  it once per (source, period, def), then read it many times.
- **Family rules carry over**:
  - Never pool sources: a baseline belongs to one source, and sources
    are compared at the event level.
  - Raw stores in; flagging happens at analysis time.
  - Recipes live in git, artefacts in the bucket, and scratch is
    disposable.
- **Performance**: vectorise over columns in R first (the `mhw.R`
  pattern). Write a C or Rust kernel for run assembly only if profiling
  asks for one.


## Two scales, kept apart

Spells are nonlinear. Sums are mergeable but spells aren't, so the spell
of a mean isn't the mean of the spells.

- **Spells of cell means** are cheap and come from published grist sums
  alone (`series_stats()`, then spells). They run anywhere, including
  GitHub Actions.
- **The cell share of pixel spells** is expensive. Per-pixel spells give
  daily category rasters, and those become grist sums of weight in a
  spell by category: a mergeable area fraction for any region. That
  composes through the catalog contract (spells writes per-date COGs plus
  a catalog, grist reads it), the same as `pixel_daily.csv` but global
  and on S2 cells.

The sites must always say which of the two they're showing.

**Every standard area metric is an additive sum of per-pixel
indicators**, so the pixel tier can be stored as sums too. Per (cell,
step), or (cell, season year):

| metric | per-pixel indicator, summed as w x indicator |
|---|---|
| daily % of area by category | in a spell at category k today |
| annual % of area that reached at least category k | reached k at some point this year |
| highest-category map / area fractions | one indicator per highest category (a histogram) |
| days at or above category k | count of days at k or more |
| area-integrated cumulative intensity | sum over spell days of (x - baseline), times area |

**So regions become queries.** Per-pixel spells depend only on each
pixel's own baseline, never on the region. Compute them once per tile,
accumulate the indicators to S2 cells, and every published box or
framework in the registry is a cell selection after the fact. Most of
the region-boundary debate goes away, for the pixel tier at least.

- The box-mean tier still depends on the box, unavoidably, but it's
  cheap.
- Level 5 (about 290 km) is too coarse for coastal boxes such as the
  Leeuwin (112-115 E). The indicator sums want level 8 to 10 (about 36
  to 9 km). grist's level is a deployment choice.
- Deep-dive boxes become compute tiles feeding one global indicator
  store. Their order is a schedule: Nino-1+2 first, given the El Nino
  under way, then NW Australia 2024/25 and so on.

**Events as objects** are connected components of the space-time spell
mask. Use the same neighbour table as the kernel estimator (below).
Unlike per-pixel spells, components cross tile boundaries, so they need
halos or a union-find merge across edges. That's a later pass over the
published daily category COGs, not part of the core. heatwave3's
`detect_blob3()` and Ocetrac are prior art, but both label an
exceedance mask with no minimum duration or gap joining, so neither is
an oracle for this. From Ocetrac (see the survey):
- **Linking rules:** Ocetrac offers 3-D components (26 neighbours) or
  overlap between adjacent frames with a containment threshold, which
  limits how far chains of merges can run. The def names the rule and
  its connectivity.
- **Without adjacency:** MVCAPA (the anomaly package) treats an event over
  many series as a segment shared by a subset of them, each with its own
  start and end lag. That suits stations and regions, where there's no
  neighbour table.
- **Weighted area:** area filters and sums use cell area (grist weights),
  not cell counts, which is what Ocetrac uses.
- **No dataset-relative thresholds:** Ocetrac's minimum area is a
  percentile of all blob areas, so past events change whenever data is
  added. That breaks "batch and streaming agree".
- **Morphological cleaning** (Ocetrac closes and then opens each frame)
  adds pixels that don't exceed and drops some that do. If spells offers
  it, it's a separate step that the def records, periodic in longitude
  only.


## Estimation: beyond pixel series

The missing-data rule is the narrowest case of an *estimator*, meaning
whatever supplies the value used for a (series, step). Interpolating
n steps or fewer is a 1D time kernel on one pixel's series. The general
form uses every observation in a space-time window of interest, weighted
by distance:

    x_hat(c0, t0) = sum K(c, t) * sumwx(c, t) / sum K(c, t) * sumw(c, t)

The kernel weight is constant per (bin, step), so this is exact
arithmetic on stored sums, with no return to the pixels. The bin size
sets the kernel's granularity, so this is for fine bins (L3bin ISIN
4.6 km, OC-CCI 4 km, or a finer S2 level), not S2 level 5. Ocean colour
is the first case.

- **Kernels are applied at analysis time, never in the store** (the same
  rule as flags). The kernel spec is part of the spell def and its hash.
- **Weight** = area x quality (OC-CCI `rmsd` as inverse variance,
  L3bin's per-bin weights) x K_space x K_time.
- **Every estimate carries its support**: effective n (Kish:
  (sum w)^2 / sum w^2) and the distance to the nearest observation in
  space and in time. Below a declared minimum, the step is missing, and
  the agreed rule applies (break and censor).
  - Kish needs sum w^2 per bin, a fifth statistic (`sumww`) for the
    grist schema. Add it while each record is still one rerun away;
    `sumw^2 / n` stands in where weights within a bin are near-constant.
- **The baseline and detection use the same estimator.** If the
  threshold comes from raw values and detection runs on smoothed values,
  the smoothed series has less variance and exceedances are undercounted.
- **The costs are stated, not hidden**:
  - smoothing lowers peak intensity and can lengthen spells;
  - neighbouring series share data, which inflates the apparent
    spatial extent of events;
  - ocean colour missingness isn't random (cloud, sun angle, ice, polar
    night), and no kernel fixes that, though the support columns make it
    visible.
- **Later**: with a variance per estimate, an exceedance becomes a
  probability, and a spell can be defined on P(x > threshold).

Shape: a neighbour table per grid and bandwidth (bin, neighbour,
distance), built once like grist's mapping. The estimate is a join of
the sums on (neighbour, step +- h) and a grouped sum in arrow or duckdb.
spells stays I/O-free and takes estimates plus support. The estimator
is a query on sums, so it belongs with the sums (grist, or an
L3bin-aware sibling).

**The estimator is a contract, not a method.** It gives an estimate,
its support and, ideally, a variance per (bin, step), and the def hash
names the estimator. Several estimators satisfy that contract:

- `interp(n)`;
- the space-time kernel;
- the provider's own L4 analysis (OISST is an optimal interpolation,
  MUR a multi-resolution variational analysis, and DUACS SLA is mapped
  by OI, so spells on them already run on someone else's estimator).
  Their error fields are the variance in the contract: OISST's error
  field, MUR's `analysis_error`, DUACS's formal mapping error.
  GlobColour's gap-free chlorophyll flags interpolated pixels. The def
  records the estimator's version and its known processing breaks
  (OISST v2.1 from 2016, the SLA constellation, GlobColour's 2018
  change; see `inst/survey/estimators.md`);
- learned estimators.

The kernel formula is Nadaraya-Watson regression, and transformer
attention is the same weighted average with a *learned* K. What
embeddings and foundation models can offer here is similarity learned
from the data instead of distance. For example, pixels in the same
water mass are near each other, and pixels on either side of a front
aren't, even when they're adjacent. The concrete forms:

- a kernel on embedding distance, or on embedding and space-time
  distance combined. This keeps the estimate-plus-support structure, and
  Kish's effective n still works with learned weights;
- a learned gap-filler. The ocean lineage is DINEOF (EOF
  reconstruction), DINCAE (a convolutional autoencoder that outputs a
  mean and an error variance) and 4DVarNet;
- embeddings as covariates for a covariate baseline ("what's usual for
  this kind of place at this time").

The guardrails for learned estimators:

- **Judge on extremes, not RMSE.** Models trained on mean-type losses
  shrink toward the mean, and spells measure exactly the tails. Score
  against withheld real observations (artificial clouds) on peak
  intensity, duration and spell count. No gap-filler or provider L4 in
  the survey reports this, so the test applies to the providers' L4s
  as well. The one extremes test found (Schlegel et al. 2019) is of
  linear interpolation of random single days in OISST: duration moves
  most, and under 25% missing barely matters.
- **Stationarity over the record.** If the estimator's skill or
  smoothness drifts as inputs change, which MUR already does across
  sensor eras, spell counts drift with it, and the drift looks like a
  trend. Spell counts across a known break (OISST's 2016 change, AMSR-E
  to AMSR2 for MUR, two-satellite against all-satellite SLA) show whether
  the estimator or the ocean moved, and are worth publishing with the
  trends.
- **Keep physical units.** Detecting in embedding space loses degrees C
  and mg m-3, and with them the Hobday categories. Embeddings can set
  the context and the weights, but the threshold stays physical.
- **The same estimator for baseline and detection** (as above).


## ARD products

| product | shape | format | notes |
|---|---|---|---|
| baseline + threshold | slot x y x x, per source x def | Zarr v3 (per-pixel reads), or one COG per slot (browser and classic catalog) | the reusable layer; int16 scaled |
| daily category / anomaly | per date | COG (Int8 category, Int16 anomaly) + STAC GeoParquet index | a grist catalog in its own right |
| streaming state | per last-update date | small multi-band raster | run length, gap length, open spell's start and running metrics |
| event table | one row per (series, spell) | GeoParquet, partitioned by year | start, end, peak, duration, intensities, rates, category |
| season summaries | per season year | COG | days in spell, count, maximum intensity, first start and last end (ice advance and retreat) |
| cell sums of spell indicators | cell x date | grist Parquet | mergeable area-in-spell |
| `manifest.json` | per product | JSON | def hash, baseline period, source versions |

**Chunking**: there are two layouts, named here by what a chunk holds,
because the providers' names point opposite ways:

- **Map layout**: one step deep, wide in space. It's for ingest, maps
  and grist. This is CMEMS `timeChunked.zarr` (1, 720, 512), named for
  "one time per chunk".
- **Series layout**: deep in time, small in space. It's for baselines
  and spells. This is CMEMS `geoChunked.zarr` (138, 32, 64), named for
  "one place per chunk".

Getting from one layout to the other is the cost: virtual references
can't rechunk, so it means a physical rewrite. Use sources that already
publish the series layout where you can. CMEMS does for DUACS SLA (see
hypertidy/cmemsarco). The regional MUR Zarr in trend.sst (50 x 50 x
ntime) is our own prototype. Icechunk is the candidate for appending
daily data to a series-layout store.

Rough sizes, uncompressed, before masking land:

- MUR int16 global: 36000 x 17999 x ~8900 days, about 11.5 TB.
- OISST int16: about 35 GB.
- OC-CCI 5-day float32: about 320 GB.
- NSIDC 25 km: a few GB.

OISST and ice can be done on any machine. MUR needs Setonix.


## Where compute runs

| platform | strength | spells work |
|---|---|---|
| **Pawsey Setonix + Acacia** | home of the records; scrontab daily jobs; Acacia `aad-derived/` with anonymous read | the big rechunks and the global MUR baseline; the daily step after grist's accumulate; publication |
| **NCI Gadi + /g/data** | the data is already there (project codes below) | bottom and subsurface MHWs on Australian shelves from BRAN2023 (cf. Amaya et al. 2023 Nat Commun for North America from an ~8 km reanalysis); reanalysis and projection spells without moving data (projections force the fixed/shifting baseline choice); publish to Acacia as `trend.ice/gadi/publish.sh` does |
| **Nectar** | long-lived VM, raadtools collection, interactive | development, regional pilots, OISST and ice global runs; a small service answering "spells for this cell or region" from the sums |
| **GitHub** | Pages, Actions, r-universe | sites; light recompute from published sums (cell-mean and box spells via arrow/duckdb over https); parity CI; distribution via hypertidy.r-universe.dev, CRAN later |
| **AWS Lambda / source.coop** | the ghrsst-cogger pattern (SQS fan-out, Docker, Terraform), next to the MUR COGs | the streaming step: today's COG + the slot's baseline + yesterday's state go in, today's category + state come out, parallel by tile. Catch: the state chain is sequential, so the step must be idempotent and resume from the last good state. An option, not the default |

Default: Setonix for production, Nectar for development, GitHub for
anything that can run from published sums.

### NCI projects to check

On Gadi, `groups` lists your memberships and `ls /g/data/<code>` shows
whether you can read a project. You join through Mancini
(my.nci.org.au). "Local" means the code appears in paths in `~/Git`
repos. "Docs" means a public page names it (checked 2026-11-17).

| code | holds | source | spells use |
|---|---|---|---|
| `gb6` | BRAN2020, BRAN2023 (`/g/data/gb6/BRAN/BRAN2023/daily`) | local (blocklist, rv-banner, trend.ice) | bottom and subsurface MHWs; ocean-reanalysis spells |
| `qm43` | GHRSST (`/g/data/qm43/ghrsst`) | local | MUR in place on Gadi (alternative to source.coop) |
| `sh74` | IMOS / AODN replica (`/g/data/sh74/IMOS_AODN`) | local | moorings and national reference stations: in-situ oracles for spells |
| `jk72` | your own working space (`/g/data/jk72/mds581/...`) | local | scratch and outputs before Acacia |
| `ia39` | Australian Community Reference Climate Data Collection, incl. OISST v2.1 (`/g/data/ia39/aus-ref-clim-data-nci/oisst/`) | docs | OISST in place; other reference obs |
| `rt52` | ERA5 (`/g/data/rt52/era5/`) | docs | atmospheric spells; forcing context for MHWs |
| `zz93` | ERA5-Land | docs | land heatwaves and dry spells (generality beyond ocean) |
| `su28` | ERA5 daily (`/g/data/su28/ERA5/daily`) | docs | daily ERA5 without aggregating hourly data |
| `zv2` | AGCD (BoM gridded climate) | docs | Australian land heatwaves and dry spells |
| `fs38` | CMIP6, ACCESS models (CMORised, `/g/data/fs38/publications`) | docs | projected spells (baseline choice matters) |
| `oi10` | CMIP6 replicas, non-ACCESS models (`/g/data/oi10/replicas`) | docs | multi-model projected spells |
| `ik11`, `cj50`, `ol01` | COSIMA ACCESS-OM2 inputs and outputs (all three needed, with `xp65`) | docs | model MHWs at 1, 0.25 and 0.1 degree |
| `xp65` | ACCESS-NRI analysis conda environments | docs | the Python side (xarray, xclim) for survey cross-checks |


## Phase 0: survey

The comparison grid is one row per package, with these columns: baseline
model, threshold rule, direction, persistence (minimum duration, gap,
order, hysteresis), missing data, time step (daily only?), calendar and
season year, metrics, categories, many series at once?, streaming?, and
outputs.

Packages to cover:

- **heatwave3** first: the API, the C++ core, Zarr input, the 4D and
  blob methods, and regional runs from a global climatology. Also the
  differences between heatwaveR 1.0.0 and 0.5.5. *Done 2026-11-17 from
  the source and checked by running (`inst/survey/heatwave3.md`,
  `heatwaveR-versions.md` and `checks/`).* MHW-MAD (DMI, ESSD 2026: fixed, shifting and
  detrended baselines) and Ocetrac (objects) sit alongside. *Done
  2026-11-17: `mhw-mad.md` (from the paper and data README; the code is
  under embargo; checked against its ERDDAP data and its climatology
  rebuilt from the CCI SST, 2026-11-18) and
  `ocetrac.md` (from the source, not run).*
- R:
  - heatwaveR (+ RmarineHeatWaves, archived)
  - climdex.pcic, ClimInd *(done 2026-11-17 from the source:
    `climdex.pcic.md`, `climind.md`; climdex.pcic's WSDI checks run
    2026-11-18)*
  - lfstat, SPEI, SCI *(done 2026-11-17 from the source, not run:
    `lfstat.md`, `spei-sci.md`)*
  - hydroEvents, EflowStats *(done 2026-11-18 from the source, not run:
    `hydroEvents.md`, `eflowstats.md`)*
  - extRemes, evd, POT (runs declustering) *(done 2026-11-18 from the
    source, with the declustering and HWMI points checked by running:
    `declustering.md`, `hwmi.md`)*
  - anomaly (CAPA) *(done 2026-11-18 from the source, checked by
    running: `anomaly.md`)*
  - iglu *(done 2026-11-18 from the source, not run: `iglu.md`)*
  - land phenology (e.g. phenofit) *(done 2026-11-18 from the source,
    not run: `phenofit.md`)*
- Python: xclim (`run_length`, the spell indicators), marineHeatWaves,
  xmhw. *(done 2026-11-18 from the source; xmhw's and marineHeatWaves'
  points checked by running, marineHeatWaves on a NumPy 2 patched copy,
  with one xarray check; xclim not run: `xclim.md`, `python-mhw.md`)*
- Near-real-time and operational prior art, for presentation:
  - the Marine Heatwave Tracker (heatwave3 on OISST, two baselines);
  - NOAA PSL forecasts;
  - Coral Reef Watch;
  - BoM ACCESS-S2;
  - IMOS AusTemp;
  - C3S;
  - Mercator.

  The summary's table compares them.
- Estimators, a separate short grid with these columns: output variance?
  tested on extremes? stationary over the record? The list: DINEOF,
  DINCAE, 4DVarNet, the providers' L4 methods (OI for OISST, MRVA for
  MUR, DUACS mapping), and any gap-free L4 chl products (CMEMS
  GlobColour; check). Foundation models and embeddings belong only where
  they give a similarity usable as K. *(done 2026-11-18 from papers and
  product documents: `estimators.md`, `estimators.csv`. GlobColour's
  gap-free chlorophyll is kriging OI (Saulquin et al. 2018); the
  Mediterranean and Black Sea ones are modified DINEOF. Embeddings
  weren't searched.)*

The survey is in `inst/survey/`: `grid.csv`, plus a notes file per
package and a findings list in its README.


## Phases

**Don't block trend.sst.** The summary's section 4 is mostly trend.sst
product work, and it runs now on the existing pipeline:

- fix the Oliver claim;
- label baselines;
- add the highest-category map plane and the reached-category charts;
- revise the Tasman and WA boxes;
- run the Nino-1+2 deep dive while the El Nino is on.

spells is extracted in parallel. Parity mode keeps the two continuous,
and anything trend.sst builds in `R/mhw.R` meanwhile moves into spells
at extraction. The spells side of section 4 is phase 1 below: parity
against 1.0.0 and heatwave3, cold spells, the detrended baseline type,
area metrics as sums, and the ice mask.

0. **Survey and decisions** (this brief, the open questions below).
1. **Extract** `spells` from trend.sst `R/mhw.R`:
   - turn the parity script into tests against each named version
     (0.5.5, 1.0.0, heatwave3);
   - make the rule order explicit;
   - add the eligibility mask;
   - add the fixed and detrended baseline types;
   - ship the `hobday2016`, `hobday2018` and `schlegel2021` presets.

   trend.sst then depends on it with `parity = "heatwaveR-0.5.5"`, so
   nothing it publishes changes and the tests stay green.

   *First milestone done 2026-11-18:* `hobday2016(parity =
   "heatwaveR-0.5.5")`, `spell_baseline()`, `spell_mask()` and
   `categories()`, ported from `R/mhw.R`. They reproduce heatwaveR
   0.5.5's climatology, event days and daily categories on seven cases
   (heatwaveR's three OISST series, a 1991-2020 reference, gaps, series
   ending after and inside an event, detection on a stored baseline),
   and trend.sst's `R/mhw.R` bit for bit with `categories()`. The
   stored outputs of heatwaveR 1.0.0 and heatwave3 1.5.0 for the same
   cases are in `tests/testthat/fixtures/`, ready for their modes
   (`data-raw/golden.R` makes them all). *`heatwaveR-1.0.0` done the
   same day*, as two switches on the 0.5.5 mode: the window at the new
   year (`window_ends = "shorten"`) and the trailing gap. Each mode fails
   the other's stored outputs on 37-48 values per case, so the tests
   tell them apart. *`heatwave3-1.5.0` done the same day*, with the
   fill of reference-period gaps: heatwaveR fills each missing (slot,
   year) cell with the slot's mean across the years, heatwave3 leaves it
   out of the window, and both fill slot 60 from whichever of 28
   February and 1 March is there. An eighth case (`wa_refgaps`) has gaps
   in the reference period; there the two rules differ on 172 slots (up
   to 0.031 °C in the threshold) and 8 event days. heatwave3's stored
   outputs now include its daily file, so its event days and daily
   categories are tested too. *`spell_events()` done the same day*: one
   row per spell, reproducing all three engines' event tables exactly
   (dates, duration, the 12 intensities, both rates) and their event
   categories, with spells' own additions (steps beyond the threshold
   and missing, `cut_start` and `cut_end`). Two rules came with it:
   heatwave3 gives no rate when the day outside the spell is missing,
   where heatwaveR counts it as the baseline (`rate_neighbour`), and the
   event category is a rounded share (`categories(event = "share")`). A
   ninth case (`wa_levels`) sets stretches on the category levels, since
   no natural case separated the event-category rules. Not done yet:
   cumulative intensity over the steps beyond the threshold only
   (lfstat's `vbt`; relative to the baseline or the threshold is still
   open), cold spells (`direction = "low"`), and heatwaveR's event names
   and seasons, which are labels. *The clean defaults were decided the
   same day* (see Decisions), *and implemented*: `hobday2016()` without
   `parity` runs them. No engine runs these rules, so they're tested
   against a direct reading of the rules from the dates
   (`tests/testthat/test-clean.R`), on series built by hand, and against
   heatwave3's stored climatology away from 29 February (slots 40-80,
   where filling slot 60 reaches), which the clean baseline matches
   before rounding. On the stored cases, the clean thresholds differ
   from heatwave3's by up to 0.008 °C near 29 February and 0.00005 °C
   elsewhere, and the event days are the same except where short gaps
   are now interpolated (7 days on `wa_gaps`). *The presets done the
   same day* (see Decisions): `hobday2016()`, `hobday2018()` and
   `schlegel2021()`, on an internal `spell_def()`. A cold spell runs on
   the negated series, as both engines do, and every parity mode
   reproduces their cold spells on all nine cases (stored outputs from
   `pctile = 10`, `coldSpells = TRUE`). Schlegel et al. 2021 itself
   couldn't be read (the publisher refuses automated fetches); its ice
   category is known only from heatwaveR's documentation. Still to do in
   this phase: the rule order made explicit, the eligibility mask, the
   fixed and detrended baseline types, and trend.sst moving onto spells. Moving
   trend.sst to clean rules is a separate, visible step, and its labels
   say which rules it uses.
2. **Generality gate 1 (ice)**: re-express trend.ice's ice season through
   spells. It must reproduce the published Int16 COGs exactly.
3. **Generality gate 2 (chl)**: bloom phenology on 5-day composites, the
   non-daily step and heavy missingness.
   Then **3b. Kernel estimation**: chl on fine bins (L3bin or OC-CCI
   native), comparing `interp(n)`, the space-time kernel and one learned
   estimator (DINCAE-style, or a kernel on embedding distance) against
   withheld observations. They're scored on spell metrics (peak
   intensity, duration, count) and on the support of filled steps, not
   on RMSE.
4. **Streaming**: `spell_state()` / `spell_step()`, checked against batch
   over a whole record apart from the provisional tail.
5. **Global products**:
   - OISST per-pixel MHW and cold spells, ice-masked;
   - then daily category COGs;
   - then the indicator sums at a fine S2 level, which gives every
     standard area metric for any registry region;
   - then the trend.sst site.

   After that, MUR on Setonix, tile by tile in the deep-dive order (the
   big rechunk spread over time). Events as objects follow, as a pass
   over the COGs.
6. **SLA spells** (per pixel from CMEMS `geoChunked.zarr`, no rechunk)
   and **compound spells**. All members share the S2 level 5 registry,
   so a compound spell (MHW + low chl, MHW + high SLA, MHW + early
   retreat; cf. Le Grix et al. 2021) is a join on (cell, date). The
   family can do this better than anyone else. Compound work lives in
   whichever member needs it first. Where one spell follows another
   instead of overlapping it, the match needs a rule: the reference
   points, a lag window and its direction, and whether it's one-to-one
   (hydroEvents' `pairEvents()` is prior art).
7. **CRAN**, and a conversation with the heatwave3 maintainers
   (heatwaveR is frozen): a complementary engine with parity tests, not
   a fork. Perhaps heatwave3 as a backend for the Hobday presets.


## Off scope, to explore: an L3 bin database for ocean colour

Not part of spells, but it feeds trend.chl, the kernel estimator and
bloom spells.

**The idea.** A modern queryable store of NASA-style L3 bins: DuckDB
over Parquet, one row per (bin, date) with `nobs`, `nscenes`, the
weights, and sums and sums of squares per product. It covers the whole
archive: SeaWiFS 1997 on, MODIS, VIIRS, and now PACE OCI.
- ISIN bin numbers run row by row, so row-group statistics on `bin`
  prune by latitude band. A region is a set of bin ranges, just as it's
  a set of S2 token ranges.
- hypertidy/L3bin supplies the grid geometry.
- It's grist-shaped: the bins are the cells, and NASA's L3b files are
  already binned, so there's no pixel mapping. grist's README already
  cites L3bin as the prior art.

**The obstacle from 2016/17: local calibration.** Regional algorithms,
such as Johnson et al. 2013 for the Southern Ocean, where standard OCx
underestimates chl, seemed to need a return to L1. It helps to stage
what each change actually needs:

| change | needs | why |
|---|---|---|
| a different chl algorithm (regional band-ratio, OWT blend) | Rrs per pixel (L2), or Rrs in bins with a known bias | chl = f(Rrs) is nonlinear, so f(mean Rrs) != mean f(Rrs) |
| a different atmospheric correction, vicarious calibration, glint or ice-adjacency handling | L1 (l2gen) | these act before Rrs exists |
| a different flagging or masking policy | L2 flags per pixel | binning has already applied NASA's flags |

So a regional *algorithm* may need only Rrs, not L1. Whether binned Rrs
is good enough is a store-design question:
- L3b keeps sum and sum of squares **per band** but no cross-products
  between bands. The ratio algorithm's bias on binned Rrs (by the delta
  method) needs band covariances, which aren't there.
- A store we design could keep the cross-products of the bands an
  algorithm uses. That's the grist principle: store the sufficient
  statistics that make the algorithms you care about computable.

**What to check in what already exists:**
- **ESA OC-CCI** (v6.0, already on Acacia for trend.chl):
  - Does the daily L3S carry merged Rrs per pixel at 4 km? If it does, a
    regional algorithm applies per pixel per day without L1 or L2.
  - CCI's chl already blends algorithms by optical water class, which is
    a form of local algorithm. Does that help or hurt in the Southern
    Ocean?
  - Per-pixel bias and rmsd are the quality weights.
- **IMOS** ocean colour (MODIS-Aqua and VIIRS over the Australian
  region; check `sh74` on Gadi and AODN):
  - Which processing levels (L2 swath, or daily 1 km composites)?
  - Which algorithms ship side by side (e.g. OC3, GSM)?
  - Is Rrs provided?
  - Is any Southern Ocean regional algorithm in it?
- **NASA L3b** directly: the products and bands carried (Rrs per band?),
  the weighting scheme, and PACE OCI's hyperspectral bins, which make
  "store Rrs, apply algorithms later" much more valuable.

**First experiment:** one year of one sensor's L3b into Parquet, queried
with DuckDB. Compare chl from binned Rrs with a regional algorithm
against CCI's per-pixel daily Rrs over the same bins and days. That
measures the nonlinearity bias directly, and says whether L1 or L2 is
really needed for the Southern Ocean.


## Decisions

- 2026-11-17: **hypertidy/spells**, alongside grist.
- 2026-11-17: **clean rules by default**, with heatwaveR matching as
  `parity = "<engine>-<version>"`, which names a version (see "The model").
- 2026-11-17: **compound and cross-member work lives in whichever member
  needs it first**. It moves to the family home only if a second member
  needs it.
- 2026-11-17: **missing data under clean rules**: interpolate runs of n
  or fewer missing steps, then break and censor (see "The model"). n is
  part of each definition.
- 2026-11-18: **Phase 1 starts parity first**. The first milestone is
  trend.sst's `R/mhw.R` running in spells as
  `parity = "heatwaveR-0.5.5"`. Alongside it go fixed input series with
  stored outputs from heatwaveR 0.5.5, heatwaveR 1.0.0 and heatwave3
  1.5.0, so the tests run without any of the three. trend.sst doesn't
  change until spells is ready. The clean defaults are settled before
  the presets are written, not before the parity work.
- 2026-11-18: **The clean defaults** (see "The model"): the window is
  shorter at the reference period's ends; reference-period gaps and
  slot 60 in non-leap years drop out of the window, with nothing
  invented; a slot needs half its window's possible days (each preset
  sets its own share); categories are the floor of the multiple, with
  joined gap days in none and a spell's category its highest day's.
- 2026-11-18: **The presets**: `hobday2016()` detects and has no
  categories, and `hobday2018()` adds them (as heatwaveR splits
  `detect_event()` and `category()`). Cold spells (`schlegel2021()`)
  keep the series' sign: negative intensities and rates, categories
  I-IV. The clean cold-spell preset adds no freezing correction and no
  ice category; SST under ice is the eligibility mask's job. The general
  constructor, `spell_def()`, stays internal until generality gate 1
  (ice) has shown what's general.
- 2026-11-18: **heatwave3 is a test oracle only.** spells doesn't depend
  on it, not even in Suggests. Its outputs are generated once by a
  script and stored with the tests, and the Hobday presets run on spells'
  own engine.


## Open questions

- Is the Lambda streaming step worth building, or is Setonix scrontab
  enough?
- Where does the space-time kernel estimator live: grist (it's a query
  on sums), or an L3bin-aware sibling for the ISIN grid? Does grist
  generalise beyond S2 to carry L3bin grids?
- Add `sumww` (sum of squared weights) to the grist schema now, before
  more records are backfilled?
- How complete must the baseline data be? *Settled 2026-11-18 as a
  def parameter: the share of the reference period's days in a slot's
  window that must be there, half for `hobday2016`.* Still open: the
  share for the chl preset, at generality gate 2, where heavy
  missingness makes it matter.
- Baseline publishing format: Zarr v3, 366 COGs, or both?
- Does "Heatwaves" get its own card on the trend landing page, pointing
  to the member tabs?
- Which parity version is the default for new trend.sst products: 0.5.5
  (continuity), 1.0.0, or heatwave3? (heatwave3's own role is decided:
  an oracle only, see Decisions.)
- The region registry: confirm it goes in the family home (trend). Is
  it only data (polygons plus cell sets), or does it get a small R
  helper?
- What S2 level for the indicator sums: one fine level for everything,
  or a level per member?
- Does the ice mask for polar SST come from MUR's own
  `sea_ice_fraction` (self-contained), or from trend.ice (one ice truth
  for the family)?


## References in play

- Hobday et al. 2016, Prog. Oceanogr. 141 (the MHW definition).
- Hobday et al. 2018, Oceanography 31(2) (categories).
- Schlegel et al. 2021, Prog. Oceanogr. (marine cold spells).
- Massom et al. 2013, PLoS ONE 8(5) e64756 (ice season).
- Siegel et al. 2002, Science 296 (bloom threshold: median + 5%).
- Johnson et al. 2013, JGR Oceans 118 (Southern Ocean chl algorithms;
  the case for local algorithms in the L3 bin thread).
- Oliver et al. 2017, Nat. Commun. 8:16101 (Tasman 2015/16; SEAus box
  147-155 E, 37-45 S: 251 days, 2.9 C).
- Kajtar et al. 2021 (Australian MHW catalogue; Tasman box 147-157 E,
  37-46 S: 318 days, 2.8 C on 1983-2012).
- Smith et al. 2025, Prog. Oceanogr. 231:103404,
  doi:10.1016/j.pocean.2024.103404 (baseline types and protocol).
- Chevillard 2026 (MHW metrics across SST products); Zhang et al. 2025
  (SST under sea ice). Full citations for these and everything in the
  summary are in `trend.ice/research_notes/Marine heatwave presentation
  and regions/`.
- Pearce & Feng 2013, J. Mar. Syst. 111-112 (WA 2010/11).
- Le Grix et al. 2021, Biogeosciences (compound high-temperature and
  low-chlorophyll extremes).
- Amaya et al. 2023, Nature 616:29-32, doi:10.1038/d41586-023-00924-2
  (comment: MHW definitions, fixed vs shifting baselines).
- Amaya et al. 2023, Nat. Commun. 14:1038,
  doi:10.1038/s41467-023-36567-0 (bottom MHWs on North American shelves
  from an ~8 km reanalysis; the model for a BRAN2023 product). CC-BY;
  the abstract was read from Crossref, the full text not yet.
