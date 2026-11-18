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
#' @return A `spell_baseline`: the def, and `seas` (the baseline) and
#'   `thresh` (the threshold), each a 366 x series matrix by slot.
#' @export
#' @examples
#' x <- 20 + 2 * sin(2 * pi * seq_len(3653) / 365.25) + rnorm(3653, sd = 0.5)
#' time <- seq(as.Date("1990-01-01"), by = "day", length.out = 3653)
#' def <- hobday2016(c("1990-01-01", "1999-12-31"), parity = "heatwaveR-0.5.5")
#' b <- spell_baseline(x, time, def)
#' str(b$thresh)
spell_baseline <- function(x, time, def) {
  if (!inherits(def, "spell_def")) stop("`def` must be a spell_def")
  x <- check_series(x, time)
  ref <- def$reference
  if (min(time) > ref[1] || max(time) < ref[2]) {
    stop("`time` doesn't cover the reference period, ", format(ref[1]), " to ", format(ref[2]))
  }
  fit <- clim_window_pooled(x, time, def)
  structure(list(def = def, seas = fit$seas, thresh = fit$thresh,
                 series = colnames(x)), class = "spell_baseline")
}

## Climatology: the window pooled over the reference years, its mean and
## percentile, then a running mean over the slots. This is trend.sst's
## mhw_clim() (heatwaveR 0.5.5 ts2clm() defaults), with the window half
## width, percentile and smoothing taken from the def.
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
  if (anyNA(xb) && identical(rules$reference_missing, "stop")) {
    stop("missing values in the reference period aren't supported in this parity mode yet")
  }
  ny <- length(years); np <- ncol(x)
  ## spread to arr[slot, year, series]
  arr <- array(NA_real_, c(366L, ny, np))
  for (j in seq_len(ny)) {
    k <- which(yr == years[j])
    arr[slot[k], j, ] <- xb[k, , drop = FALSE]
  }
  ## 29 February in non-leap years, from its neighbours (heatwaveR's
  ## .NA2mean on slots 59 to 61, rounded to 2 decimals)
  f29 <- is.na(arr[60L, , 1L])
  if (any(f29) && identical(rules$feb29, "neighbours")) {
    arr[60L, f29, ] <- round((arr[59L, f29, , drop = FALSE] +
                              arr[61L, f29, , drop = FALSE]) / 2, 2)
  }
  if (anyNA(arr)) stop("reference years must be whole years")
  if (!identical(rules$window_ends, "wrap")) stop("only the wrapped window is implemented")
  ## the window wraps within each year at the new year
  pad <- c(utils::tail(seq_len(366L), half), seq_len(366L), utils::head(seq_len(366L), half))
  seas <- thresh <- matrix(NA_real_, 366L, np)
  for (i in seq_len(366L)) {
    rows <- pad[i:(i + 2L * half)]
    pool <- matrix(arr[rows, , , drop = FALSE], ncol = np)   # one column per series
    seas[i, ] <- colMeans(pool)
    thresh[i, ] <- matrixStats::colQuantiles(pool, probs = def$threshold$p,
                                             type = 7L, useNames = FALSE)
  }
  out <- list(seas = running_mean_366(seas, smooth), thresh = running_mean_366(thresh, smooth))
  if (!is.null(rules$round)) out <- lapply(out, round, rules$round)
  out
}

## Centred running mean of width w over the 366 slots, periodic.
running_mean_366 <- function(m, w) {
  h <- w %/% 2L
  idx <- c(utils::tail(seq_len(366L), h), seq_len(366L), utils::head(seq_len(366L), h))
  cs <- rbind(0, matrixStats::colCumsums(m[idx, , drop = FALSE]))
  (cs[seq_len(366L) + w, , drop = FALSE] - cs[seq_len(366L), , drop = FALSE]) / w
}

#' @export
print.spell_baseline <- function(x, ...) {
  cat("<spell_baseline>", ncol(x$seas), "series, 366 slots;", x$def$name,
      if (!is.null(x$def$parity)) paste0("(parity ", x$def$parity, ")"),
      "reference", format(x$def$reference[1]), "to", format(x$def$reference[2]), "\n")
  invisible(x)
}
