## The baseline: fitted once over the reference period, then applied to
## any steps by their slot.

#' Fit a spell baseline and threshold
#'
#' Fits the def's baseline and threshold over its reference period, for
#' every series at once. The result is applied to any dates by
#' [spell_mask()], so detection can run on a different stretch of the
#' series than the baseline was fitted on.
#'
#' @param x A numeric vector, or a time x series matrix (one column per
#'   series, all on the same dates).
#' @param time A `Date` vector of consecutive days, one per row of `x`.
#'   It must cover the def's reference period.
#' @param def A `spell_def`, such as from [hobday2016()].
#' @param eligible Where the series means something (`TRUE`), such as
#'   SST not under ice: `NULL` for everywhere, a logical matrix the shape
#'   of `x`, or one value per series. An ineligible day drops out of the
#'   window, as a missing one does, and counts against the slot's
#'   coverage, so a slot mostly ineligible in the reference years gets
#'   no baseline. With a parity mode it is the engine's answer on the
#'   series masked to `NA` there.
#' @return A `spell_baseline`: the def, and `seas` (the baseline) and
#'   `thresh` (the threshold), each a 366 x series matrix by slot. With
#'   a detrended baseline, also `trend`: the slope per series (per day),
#'   the date it's centred on (the reference period's midpoint), and
#'   whether detection adds it to `seas` and `thresh` at each step. With
#'   a fixed-level threshold ([threshold_value()]) nothing is fitted:
#'   `thresh` is the level in every slot, `seas` is `NA`, and `x` and
#'   `time` only give the series.
#' @export
#' @examples
#' x <- 20 + 2 * sin(2 * pi * seq_len(3653) / 365.25) + rnorm(3653, sd = 0.5)
#' time <- seq(as.Date("1990-01-01"), by = "day", length.out = 3653)
#' def <- hobday2016(c("1990-01-01", "1999-12-31"))
#' b <- spell_baseline(x, time, def)
#' str(b$thresh)
spell_baseline <- function(x, time, def, eligible = NULL) {
  if (!inherits(def, "spell_def")) stop("`def` must be a spell_def")
  x <- check_series(x, time)
  el <- check_eligible(eligible, x)
  if (def$threshold$type == "value") {
    n <- ncol(x)
    return(structure(list(def = def, seas = matrix(NA_real_, 366L, n),
                          thresh = matrix(def$threshold$level, 366L, n), series = colnames(x),
                          trend = NULL, ineligible = 0L), class = "spell_baseline"))
  }
  x[!el] <- NA_real_
  ref <- def$reference
  if (min(time) > ref[1] || max(time) < ref[2]) {
    stop("`time` doesn't cover the reference period, ", format(ref[1]), " to ", format(ref[2]))
  }
  inb <- time >= ref[1] & time <= ref[2]
  trend <- NULL
  if (def$baseline$type == "detrended") {
    trend <- fit_trend(x, time, def)
    x <- x - outer(as.numeric(time) - as.numeric(trend$centre), trend$slope)
  }
  fit <- clim_window_pooled(x, time, def)
  structure(list(def = def, seas = fit$seas, thresh = fit$thresh, series = colnames(x),
                 trend = trend, ineligible = sum(!el[inb, ])), class = "spell_baseline")
}

## A linear trend per series over the reference period, centred on its
## midpoint.
##  anomalies (clean): least squares with a mean per slot: fitted to the
##             anomalies from each slot's own mean over the reference
##             years, so the seasonal cycle can't leak into it, uneven
##             coverage of the seasons across the years doesn't bias it,
##             and an added linear trend changes it by exactly that
##             trend (anomalies from the smoothed climatology would lose
##             part of the trend within each year); detection reads it
##  heatwave3: fitted to the daily values, with heatwave3's sums
##             (src/climatology.cpp; no trend with 2 values or fewer);
##             the climatology only, detection on the series as it is
fit_trend <- function(x, time, def) {
  ref <- def$reference
  inb <- time >= ref[1] & time <= ref[2]
  centre <- as.numeric(ref[1]) + (as.numeric(ref[2]) - as.numeric(ref[1])) / 2
  t <- as.numeric(time[inb]) - as.numeric(ref[1])
  how <- def$rules$detrend
  if (!how %in% c("anomalies", "heatwave3")) stop("unknown detrend rule \"", how, "\"")
  y <- x[inb, , drop = FALSE]
  slot <- slot_366(time[inb])
  slope <- vapply(seq_len(ncol(y)), function(j) {
    ok <- !is.na(y[, j])
    tj <- t[ok]
    yj <- y[ok, j]
    n <- length(yj)
    if (how == "heatwave3") {
      if (n <= 2L) return(0)
      mt <- sum(tj) / n
      my <- sum(yj) / n
      return((sum(tj * yj) - n * mt * my) / (sum(tj * tj) - n * mt * mt))
    }
    if (n < 2L) return(NA_real_)
    sj <- slot[ok]
    dt <- tj - stats::ave(tj, sj)
    den <- sum(dt * dt)
    if (den == 0) return(NA_real_)
    sum(dt * (yj - stats::ave(yj, sj))) / den
  }, 0)
  list(model = "linear", slope = slope, centre = as.Date(centre), applied = how != "heatwave3")
}

## Climatology: the window pooled over the reference years, its mean and
## percentile, then a running mean over the slots. This began as
## trend.sst's mhw_clim() (heatwaveR 0.5.5 ts2clm() defaults); the def
## gives the window half width, percentile and smoothing, and its parity
## rules the window ends and the treatment of reference-period gaps.
clim_window_pooled <- function(x, time, def) {
  rules <- def$rules
  half <- (def$baseline$window - 1L) %/% 2L
  smooth <- def$baseline$smooth
  ref <- def$reference
  inb <- time >= ref[1] & time <= ref[2]
  yr <- as.integer(format(time[inb], "%Y"))
  years <- as.integer(format(ref[1], "%Y")):as.integer(format(ref[2], "%Y"))
  slot <- slot_366(time[inb])
  xb <- x[inb, , drop = FALSE]
  ny <- length(years); np <- ncol(x)
  ## spread to arr[slot, year, series]
  arr <- array(NA_real_, c(366L, ny, np))
  for (j in seq_len(ny)) {
    k <- which(yr == years[j])
    arr[slot[k], j, ] <- xb[k, , drop = FALSE]
  }
  ## Slot 60 where it's missing (every non-leap year, and a leap year
  ## whose 29 February is missing):
  ##  neighbours: the mean of 28 February and 1 March, or the one that's
  ##              there, rounded to 2 decimals (heatwaveR's .NA2mean on
  ##              slots 59 to 61; heatwave3 the same); with neither there,
  ##              it stays missing
  ##  omit:       left empty, so non-leap years add nothing to slot 60
  ##              (spells' clean rule)
  leap <- is_leap(years)
  if (!rules$feb29 %in% c("neighbours", "omit")) stop("unknown feb29 rule \"", rules$feb29, "\"")
  if (identical(rules$feb29, "neighbours")) {
    v59 <- arr[59L, , , drop = FALSE]; v61 <- arr[61L, , , drop = FALSE]
    both <- (v59 + v61) / 2
    fill <- ifelse(is.na(v59), v61, ifelse(is.na(v61), v59, both))
    f29 <- is.na(arr[60L, , , drop = FALSE])
    arr[60L, , ][f29] <- round(fill[f29], 2)
  }
  ## Missing (slot, year) cells in the reference period:
  ##  plug: each is filled with that slot's mean across the years, not
  ##        rounded (heatwaveR's clim_spread() "plugs")
  ##  omit: left out of the window (heatwave3)
  if (anyNA(arr)) {
    rm_rule <- rules$reference_missing
    if (identical(rm_rule, "plug")) {
      for (s in seq_len(np)) {
        m <- matrix(arr[, , s], 366L)
        if (!anyNA(m)) next
        at <- which(is.na(m), arr.ind = TRUE)
        m[at] <- rowMeans(m, na.rm = TRUE)[at[, 1L]]
        arr[, , s] <- m
      }
    } else if (!identical(rm_rule, "omit")) {
      stop("unknown reference_missing rule \"", rm_rule, "\"")
    }
  }
  ## Pad the slots by the window's half width at each end, so slot i's
  ## window is padded rows i to i + 2 * half.
  ##  wrap:    within each year, 1 January's window takes 27-31 December
  ##           of the same year (heatwaveR 0.5.5)
  ##  shorten: on through the adjacent years, 1 January's window takes
  ##           27-31 December of the year before; the reference period's
  ##           first and last years have nothing there, so their windows
  ##           are shorter (heatwaveR 1.0.0)
  padded <- pad_slots(arr, half, rules$window_ends)
  ## where a window is short or has gaps, the statistics use the values it has
  short <- anyNA(padded)
  ## Coverage: a slot gets a baseline only if at least this share of the
  ## reference period's days in its window are there. Its possible days
  ## are the (slot, year) cells that are dates in the reference period,
  ## padded as the values are.
  coverage <- rules$coverage
  if (!is.null(coverage)) {
    real <- array(TRUE, c(366L, ny, 1L))
    real[60L, !leap, 1L] <- identical(rules$feb29, "neighbours")
    possible <- pad_slots(real, half, rules$window_ends)
    possible[is.na(possible)] <- FALSE
  }
  seas <- thresh <- matrix(NA_real_, 366L, np)
  for (i in seq_len(366L)) {
    rows <- i:(i + 2L * half)
    pool <- matrix(padded[rows, , , drop = FALSE], ncol = np)   # one column per series
    seas[i, ] <- colMeans(pool, na.rm = short)
    thresh[i, ] <- matrixStats::colQuantiles(pool, probs = def$threshold$p, type = 7L,
                                             na.rm = short, useNames = FALSE)
    if (!is.null(coverage)) {
      few <- colSums(!is.na(pool)) < coverage * sum(possible[rows, , 1L])
      seas[i, few] <- NA_real_
      thresh[i, few] <- NA_real_
    }
  }
  ## a slot without a baseline stays without one; with the clean rules
  ## the smoothing uses the slots around it that have one
  skip <- !is.null(coverage)
  out <- list(seas = running_mean_366(seas, smooth, skip_na = skip),
              thresh = running_mean_366(thresh, smooth, skip_na = skip))
  if (!is.null(rules$round)) out <- lapply(out, round, rules$round)
  out
}

## Pad the slots by the window's half width at each end, so slot i's
## window is padded rows i to i + 2 * half (see clim_window_pooled()).
pad_slots <- function(arr, half, window_ends) {
  ny <- dim(arr)[2L]
  head_rows <- utils::tail(seq_len(366L), half)
  tail_rows <- utils::head(seq_len(366L), half)
  switch(window_ends,
    wrap = arr[c(head_rows, seq_len(366L), tail_rows), , , drop = FALSE],
    shorten = {
      before <- after <- array(NA, c(half, ny, dim(arr)[3L]))
      storage.mode(before) <- storage.mode(after) <- storage.mode(arr)
      if (ny > 1L) {
        before[, -1L, ] <- arr[head_rows, -ny, , drop = FALSE]
        after[, -ny, ] <- arr[tail_rows, -1L, , drop = FALSE]
      }
      abind_rows(before, arr, after)
    },
    stop("unknown window_ends rule \"", window_ends, "\""))
}

is_leap <- function(y) (y %% 4L == 0L & y %% 100L != 0L) | y %% 400L == 0L

## Stack 3-d arrays along their first dimension.
abind_rows <- function(...) {
  a <- list(...)
  d <- dim(a[[1L]])
  out <- array(NA, c(sum(vapply(a, function(z) dim(z)[1L], 0L)), d[2L], d[3L]))
  storage.mode(out) <- storage.mode(a[[1L]])
  at <- 0L
  for (z in a) {
    n <- dim(z)[1L]
    if (n) out[at + seq_len(n), , ] <- z
    at <- at + n
  }
  out
}

## Centred running mean of width w over the 366 slots, periodic. A
## missing slot makes every mean whose window holds it missing (a plain
## sum, as heatwave3's), or with skip_na the mean is of the slots that
## are there, and the missing slot stays missing.
running_mean_366 <- function(m, w, skip_na = FALSE) {
  h <- w %/% 2L
  idx <- c(utils::tail(seq_len(366L), h), seq_len(366L), utils::head(seq_len(366L), h))
  mm <- m[idx, , drop = FALSE]
  lo <- seq_len(366L); hi <- lo + w
  if (!anyNA(mm)) {
    cs <- rbind(0, matrixStats::colCumsums(mm))
    return((cs[hi, , drop = FALSE] - cs[lo, , drop = FALSE]) / w)
  }
  ok <- !is.na(mm)
  mm[!ok] <- 0
  cs <- rbind(0, matrixStats::colCumsums(mm))
  cn <- rbind(0, matrixStats::colCumsums(ok * 1))
  n <- cn[hi, , drop = FALSE] - cn[lo, , drop = FALSE]
  out <- (cs[hi, , drop = FALSE] - cs[lo, , drop = FALSE]) / n
  if (skip_na) out[is.na(m) | n == 0] <- NA_real_ else out[n < w] <- NA_real_
  out
}

#' @export
print.spell_baseline <- function(x, ...) {
  cat("<spell_baseline>", ncol(x$seas), "series, 366 slots;", x$def$name,
      if (!is.null(x$def$parity)) paste0("(parity ", x$def$parity, ")"),
      if (x$def$threshold$type == "value") paste("fixed level", x$def$threshold$level, "(no baseline)")
      else paste("reference", format(x$def$reference[1]), "to", format(x$def$reference[2])), "\n")
  if (!is.null(x$trend)) {
    cat("  detrended: slope", paste(signif(x$trend$slope * 3652.5, 3), collapse = ", "),
        "per decade, centred on", format(x$trend$centre),
        if (!x$trend$applied) "(climatology only: detection on the series as it is)", "\n")
  }
  if (isTRUE(x$ineligible > 0)) cat("  ", x$ineligible, "ineligible steps in the reference period\n")
  invisible(x)
}
