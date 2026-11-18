# Estimators: the short grid

The brief's separate grid for whatever supplies the value at a (series,
step): `interp(n)`, the learned gap-fillers, and the providers' own L4
analyses. Its three questions are: **does it output a variance? Has it
been tested on extremes? Is it stationary over the record?** The rows
are in `estimators.csv`.

- **How:** read 2026-11-18 from:
  - abstracts via Crossref;
  - product pages (NCEI OISST, PO.DAAC MUR, Copernicus Marine ocean
    colour);
  - the Copernicus ocean colour Product User Manual (CMEMS-OC-PUM 7.0,
    March 2026) and Quality Information Document, with their text
    extracted locally;
  - two papers read in full on the publisher's page (Schlegel et al.
    2019; Rovšček et al. 2026), partly through a summary.

  **Nothing was run.** Where a point came only from a search-engine
  abstract or a summary, it's marked as such in the CSV.
- Foundation models and embeddings weren't searched in this round. The
  brief's rule stands: they come in only where they give a similarity
  usable as K.

## The answers

**Output variance: most have one.**
- OISST and MUR each carry an estimated error standard deviation
  (OISST's "error field"; MUR's `analysis_error`).
- DUACS has a formal mapping error.
- DINCAE gives an error variance per pixel and step.
- DINEOF has had error maps since Beckers et al. 2006; before that it
  had only a global cross-validation error.
- DIRECT 1.0 (2026) gives an ensemble spread with a post-hoc variance
  term.
- 4DVarNet has none in its base form, but there are ensemble and SPDE
  extensions.
- GlobColour's gap-free chlorophyll carries a flag for interpolated
  pixels. GlobColour products in general carry a per-pixel uncertainty,
  but whether it covers the interpolation in the gap-free files is to
  confirm.
- `interp(n)` has none.

So the brief's "estimate, support and, ideally, a variance" contract is
realistic for every provider L4 the family uses.

**Tested on extremes: none of the gap-fillers.**
- Every method and product here is validated on overall error: RMSE on
  withheld pixels, bias and SD against buoys and Argo, r² against in
  situ chlorophyll (0.71 for GlobColour's gap-free product against 0.75
  for the daily L3), tide-gauge differences, spectra and CRPS.
- DIRECT's authors note that their single variance offset "cannot
  correct calibration that varies across space or across the tails"
  (from the summary).
- The one study that measured extremes is about the simplest estimator:
  Schlegel et al. (2019) removed 0–50% of OISST days at random, filled
  them by linear interpolation, and compared MHW metrics with the
  complete series. Less than 25% missing barely mattered, and up to 50%
  was acceptable with interpolation. Duration was the metric most
  affected. The gaps were random single days, not blocks, so this
  doesn't cover long gaps or gaps during an event, where the authors say
  interpolation won't work.

That confirms the brief's first guardrail: spells will have to run the
extremes test itself (step 3b: withheld observations, scored on peak
intensity, duration and count).

**Stationary over the record: not shown for any, and broken for some.**
- **OISST v2.1** changed its inputs from 1 January 2016: Argo added,
  MetOp-B replacing NOAA-19, and revised ship–buoy and ice–SST handling.
  NCEI says the improvements apply "for data from January 1, 2016
  onward". That's a processing change inside one product version, in
  the middle of the period most MHW trend work uses.
- **MUR**'s sensor mix changes through its record (from 2002-06-01; for
  example AMSR-E to AMSR2 in 2011–2012). The product page doesn't say
  how resolution or error respond.
- **DUACS**: the all-satellite product's constellation changes. The C3S
  two-satellite product exists for stability, and Sánchez-Román et al.
  (2023) find it the more stable of the two, the all-satellite one being
  better at short time scales.
- **GlobColour gap-free chlorophyll** has been operational since 2016,
  with its scheme "significantly improved during 2018", and the sensors
  and coverage behind it change from 1997 on.
- **The learned and EOF methods** are fitted on the record itself
  (DINEOF's modes, DINCAE's and DIRECT's training sets), or on model
  simulations (4DVarNet). So adding data, or a change in coverage, can
  change past estimates.

## What this means for spells

1. **Record the estimator in the def, with its version and processing
   breaks.** For OISST that means v2.1 and its 2016 change, and for SLA
   the constellation (two-satellite or all-satellite). The def hash
   names the estimator, as the brief says; this makes the known breaks
   part of it.
2. **Use the providers' error fields as the support column.** OISST's
   error, MUR's `analysis_error` and DUACS's mapping error are the
   "variance per (bin, step)" the brief asks of an estimator. GlobColour's
   interpolated-pixel flag is the minimum (filled or not).
3. **The extremes test is spells' to run.** No producer reports skill on
   peaks, durations or counts. Step 3b's design (withheld real
   observations, scored on spell metrics) is the missing evidence, and
   the same test applies to the providers' L4s, not only to learned
   estimators.
4. **Stationarity is checkable, and it's a spells output too.** Spell
   counts per season across a known break (OISST in 2016, the AMSR-E to
   AMSR2 change for MUR, the two-satellite against the all-satellite
   SLA) show whether the estimator, not the ocean, moved. That's a
   validation product worth publishing with the trends.
5. **Schlegel et al. (2019) supports a small `interp(n)` default** for
   scattered single-day gaps, but not long interpolation. The brief's
   per-preset n (3 for `hobday2016`, 5 for `massom2013`), with breaks and
   censoring beyond it, is consistent with it.
6. **For chlorophyll, three estimators are already in use regionally:**
   kriging OI (global and Atlantic GlobColour), modified DINEOF
   (Mediterranean and Black Sea) and none (L3, OC-CCI). Gate 2 and step
   3b should say which one each chl spell ran on.
