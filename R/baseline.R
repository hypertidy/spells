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
  ## whose 29 February is missing), from its neighbours: the mean of 28
  ## February and 1 March, or the one that's there, rounded to 2 decimals
  ## (heatwaveR's .NA2mean on slots 59 to 61; heatwave3 the same). With
  ## neither there, it stays missing.
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
  head_rows <- utils::tail(seq_len(366L), half)
  tail_rows <- utils::head(seq_len(366L), half)
  padded <- switch(rules$window_ends,
    wrap = arr[c(head_rows, seq_len(366L), tail_rows), , , drop = FALSE],
    shorten = {
      before <- after <- array(NA_real_, c(half, ny, np))
      if (ny > 1L) {
        before[, -1L, ] <- arr[head_rows, -ny, , drop = FALSE]
        after[, -ny, ] <- arr[tail_rows, -1L, , drop = FALSE]
      }
      abind_rows(before, arr, after)
    },
    stop("unknown window_ends rule \"", rules$window_ends, "\""))
  ## where a window is short or has gaps, the statistics use the values it has
  short <- anyNA(padded)
  seas <- thresh <- matrix(NA_real_, 366L, np)
  for (i in seq_len(366L)) {
    pool <- matrix(padded[i:(i + 2L * half), , , drop = FALSE], ncol = np)   # one column per series
    seas[i, ] <- colMeans(pool, na.rm = short)
    thresh[i, ] <- matrixStats::colQuantiles(pool, probs = def$threshold$p, type = 7L,
                                             na.rm = short, useNames = FALSE)
  }
  out <- list(seas = running_mean_366(seas, smooth), thresh = running_mean_366(thresh, smooth))
  if (!is.null(rules$round)) out <- lapply(out, round, rules$round)
  out
}

## Stack 3-d arrays along their first dimension.
abind_rows <- function(...) {
  a <- list(...)
  d <- dim(a[[1L]])
  out <- array(NA_real_, c(sum(vapply(a, function(z) dim(z)[1L], 0L)), d[2L], d[3L]))
  at <- 0L
  for (z in a) {
    n <- dim(z)[1L]
    if (n) out[at + seq_len(n), , ] <- z
    at <- at + n
  }
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
