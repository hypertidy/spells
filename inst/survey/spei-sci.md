# SPEI 1.8.1 and SCI 1.0-3

- **Sources read:**
  - SPEI: the CRAN tarball `SPEI_1.8.1.tar.gz` (published 2023-03-02).
    GitHub sbegueria/SPEI is at `649e529` (2026-11-08), DESCRIPTION
    1.9.0, not on CRAN.
  - SCI: the CRAN tarball `SCI_1.0-3.tar.gz` (2025-05-04), Lukas
    Gudmundsson.
- **How:** read 2026-11-17 from source, and the SPEI GitHub issue list
  for one point below. **Not run.**

## What they are

Both compute **standardized indices**: SPI and SPEI, and in SCI any
"standardized climate index". **Neither detects events.** Drought spells
come from applying a threshold to the index (run theory), which these
packages leave to the user. So for spells they're a **baseline and
threshold family**, not a persistence reference.

## The grid columns

- **Pre-transform: accumulation over `scale` (SPEI) or `time.scale`
  (SCI) steps, trailing only.**
  - SPEI uses a right-aligned rolling weighted sum, with a kernel
    (rectangular, triangular, circular or gaussian, plus a shift).
  - SCI uses a trailing moving mean (`filter(..., sides = 1)`).
  - Either way, a value depends only on the past, so it can stream.
- **Baseline:** a distribution fitted per **slot** (the calendar month;
  in SPEI, any position in the `ts` cycle) over a reference period.
  Values become probabilities through its CDF, then z-scores through
  `qnorm`.
  - SPEI: log-logistic by default (Gamma for SPI, or Pearson III),
    fitted by unbiased or plotting-position PWMs, or by maximum
    likelihood for log-logistic.
    The reference period is `ref.start`/`ref.end`, and the whole series
    by default. A slot needs at least 4 values.
  - SCI: any distribution with `p`/`d` functions, fitted by maximum
    likelihood (`fitdistrplus::mledist`), with checks that set failed
    fits to NA. The reference period is whatever data goes into
    `fitSCI()`.
  - **Zero inflation:** SPI-type indices fit the nonzero values and add
    a probability of zero (`pze` in SPEI, `p0` in SCI, which can also
    use the plotting-position "centre of mass").
- **Fit and apply are separate steps.** SCI has `fitSCI()` and
  `transformSCI()`; SPEI has `params =`. A baseline fitted once can be
  applied to new data: the stored-baseline pattern.
- **Threshold:** none in the packages. In practice it's a z value, which
  is a probability under the fitted distribution.
- **Missing data:**
  - SPEI with `na.rm = FALSE` stops on any NA. With TRUE, NAs are left
    out of the fit, and rolling sums over an NA are NA.
  - SCI drops non-finite values from the fit, and the moving mean over an
    NA is NA.
- **Time step:** monthly by default. SPEI 1.8.0 added other `ts`
  frequencies and 3-d arrays (gridded data). SCI is fixed at 12 months,
  starting at `first.mon`.
- **Outputs:** a z-score series (SPEI: an `spei` object with the fitted
  coefficients); SCI can cap it at `sci.limit`.

**A bug in CRAN SPEI 1.8.1:** the zero-probability adjustment for Gamma
and Pearson III is applied *before* the standardized values are written,
and then overwritten (`R/spei.R`). So **SPI for a zero-precipitation
period is `-Inf`**, and the other values ignore the zero mass. The
upstream issue is sbegueria/SPEI#87, "regression since 1.8.0", closed in
November 2026. It's fixed on GitHub (1.9.0), which isn't on CRAN. Pin
the version if spells ever compares with SPI.

## What this means for spells

1. **Standardized thresholds are another threshold type.** A
   probability, or z value, under a distribution fitted per slot over
   the reference period. Unlike an empirical percentile it can
   extrapolate past the sample, and it handles zero inflation. Add it to
   the brief's threshold types.
2. **Trailing accumulation is part of the analysis space**, like chl's
   log10 transform. A k-step trailing sum or mean taken before the
   baseline streams cleanly, because it uses only the past.
3. **Fitting is separate from applying** (`fitSCI`/`transformSCI`,
   `params =`). That's spells' baseline object: fitted once over the
   reference period, stored and hashed with the def, and applied to new
   steps in batch or streaming.
4. **Drought spells on SPI/SPEI would be a spells preset**: run theory
   on the index, plus lfstat-style pooling and a minimum duration. These
   packages supply the baseline, and spells the persistence.
5. **Not oracles for spells.** They are oracles for a standardized
   baseline if spells implements one.
