# ClimInd 0.1-3

- **Source read:** the CRAN tarball `ClimInd_0.1-3.tar.gz` (published
  2021-04-10), GPL (>= 3). INDECIS project
  (https://gitlab.com/indecis-eu/indecis). Reig-Gracia, Vicente-Serrano,
  Dominguez-Castro and Bedia-Jiménez.
- **How:** read 2026-11-17 from source. **Not run.** There have been no
  releases since 2021.
- Paths below are relative to the package source.

## What it is

ClimInd computes "138 standard climate indices" (the DESCRIPTION;
`R/indecis_indices.R` defines 128 `index_names`). They are monthly,
seasonal or annual aggregates from data frames named by date (`chron`).
Most follow the ECA&D indices dictionary. The spell-type indices are:
- WSDI and CSDI;
- GSL, and the onset of the growing season (`ogs6`, `ogs10`);
- the longest runs: CFD (frost), CSD (summer days), CDD and CWD;
- snow cover: the first and last day of the longest snow-cover run, per
  hydrological year (`fpsc`, `lpsc`).

## The grid columns

- **Baseline / threshold:** for WSDI and CSDI it says itself that it
  isn't ETCCDI. The docs say the 90th or 10th percentile "is computed
  based on the time scale selected (month, season or year) not daily as
  ETCCDI does".
  - The quantile is taken over the **whole record** (no base period),
    pooled by the time-scale label: one value for `YEAR`, one per
    calendar month for `MONTH`, one per season for `SEASON`.
  - It's R's default type-7 quantile with `na.rm = TRUE`
    (`quantile_null()`, `select_all_time_function()`), with no window
    and no smoothing.
  - So the annual WSDI threshold is a single number for the whole year,
    the threshold changes as data is added, and the base and the
    assessed years are the same data.
- **Direction:** WSDI uses `>`. **CSDI uses `<=`, though the docs say
  `<`.**
- **Persistence:** runs of at least 6, found with `rle()` within each
  month, season or year (no spanning). No gap joining.
  - **GSL needs runs longer than 6** (`rle()$lengths > 6`, so 7 or more
    days), though it's documented as "at least 6 days". The July 1 split
    is fixed, with no hemisphere option.
- **Missing data:** a block with any missing day is NA, unless
  `na.rm = TRUE`. Then `rle()` breaks runs at the missing days.
  `calcf_data()` turns NaN results into 0.
- **Time step:** daily. **Calendar:** `chron` dates, gregorian.
- **Season year:**
  - **DJF is labelled by its January year**: December moves forward
    (`seasonals_years()`). The first winter is set to NA and the last
    season dropped. climdex.pcic labels winter by December's year
    instead.
  - The hydrological year runs from October to September and is labelled
    by the year it ends in (`hydrological_years()`).
- **Metrics:** aggregates per block (counts, longest run, the first day
  of the longest run). **Categories:** none. **Many series:** one series
  per call. **Streaming:** no.
- **Outputs:** named vectors, or arrays by year and month or season.

## What this means for spells

1. **Not an oracle.** Its WSDI and CSDI aren't the ETCCDI indices: their
   thresholds come from the whole record and aren't seasonal, and runs
   can't cross a block boundary. Its GSL minimum is one day off its own
   docs.
2. **Season labels differ between packages:** winter is labelled by its
   January year here and by its December year in climdex.pcic. The
   season-year rule in the def has to name its label, not only its
   boundaries.
3. **Summaries worth covering:** the first and last day of the longest
   run per hydrological year (snow cover) are spell summaries of the
   kind the brief lists ("first start, last end"). "Longest run" is
   another one: add it next to the first and last.
4. **Two documented-versus-coded mismatches** (CSDI's comparison, GSL's
   minimum) are reasons spells' presets should be tested against written
   definitions as well as against code.
