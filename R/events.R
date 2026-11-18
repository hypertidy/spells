## Spell -> metrics: one row per (series, spell).

#' Spell metrics, one row per spell
#'
#' Measures each spell in a [spell_mask()]: its start, peak and end, its
#' duration, its intensities relative to the baseline, to the threshold
#' and in the series' own units, its rates of onset and decline, and its
#' category.
#'
#' Every step in a spell is measured, joined gaps included, after the
#' def's missing-data rule (a missing step counts as the baseline). The
#' peak is the first step of largest anomaly.
#'
#' The rate of onset is the peak anomaly less the anomaly midway between
#' the first step and the step before it, over the steps from that
#' midpoint to the peak; the rate of decline is the same at the end
#' (Hobday et al. 2016). A spell cut by either end of the series
#' (`cut_start`, `cut_end`) has no rate on that side. Whether a rate is
#' given when the step outside the spell is missing is a rule of the
#' def's parity mode: heatwaveR counts that step as the baseline;
#' heatwave3 gives no rate.
#'
#' @param x,time The series and dates given to [spell_mask()].
#' @param baseline The `spell_baseline` given to [spell_mask()].
#' @param mask The result of [spell_mask()].
#' @return A data frame, one row per spell, ordered by series and then
#'   time:
#'   * `series`, `spell`: the column of `x`, and the spell's number in it;
#'   * `start`, `peak`, `end`: dates; `index_start`, `index_peak`,
#'     `index_end`: rows of `x`;
#'   * `duration`: steps in the spell, joined gaps included; `n_beyond`:
#'     those beyond the threshold; `n_missing`: those missing in `x`;
#'   * `cut_start`, `cut_end`: the spell touches the first or last step,
#'     so it may have begun earlier or go on (at the end, a provisional
#'     tail);
#'   * `intensity_max`, `intensity_mean`, `intensity_sd`,
#'     `intensity_cumulative`: of the anomaly (the series minus the
#'     baseline); then the same with suffix `_thresh` (the series minus
#'     the threshold) and `_abs` (the series itself). The `_sd` columns
#'     are heatwaveR's `intensity_var`, which is the standard deviation;
#'   * `rate_onset`, `rate_decline`: per step;
#'   * `category`: 1 to 4 for Hobday 2018's I to IV, by the def's
#'     category rule ([categories()]); `n_moderate`, `n_strong`,
#'     `n_severe`, `n_extreme`: steps in each, by the same rule.
#'
#'   With a parity mode that rounds, the intensities and rates are
#'   rounded as its engine rounds them.
#' @export
#' @examples
#' x <- 20 + 2 * sin(2 * pi * seq_len(3653) / 365.25) + rnorm(3653, sd = 0.5)
#' time <- seq(as.Date("1990-01-01"), by = "day", length.out = 3653)
#' def <- hobday2016(c("1990-01-01", "1999-12-31"), parity = "heatwaveR-0.5.5")
#' b <- spell_baseline(x, time, def)
#' m <- spell_mask(x, time, b)
#' ev <- spell_events(x, time, b, m)
#' head(ev[c("start", "end", "duration", "intensity_max", "category")])
spell_events <- function(x, time, baseline, mask) {
  if (!inherits(baseline, "spell_baseline")) stop("`baseline` must be a spell_baseline")
  x <- check_series(x, time)
  ev <- mask$event
  if (!is.logical(ev) || !identical(dim(ev), dim(x))) {
    stop("`mask` must be spell_mask()'s result for this `x`")
  }
  def <- baseline$def
  rules <- def$rules
  rule <- def$category
  s <- slot_366(time)
  seas <- baseline$seas[s, , drop = FALSE]
  thresh <- baseline$thresh[s, , drop = FALSE]
  if (!identical(rules$missing, "baseline")) stop("only missing = \"baseline\" is implemented")
  miss <- is.na(x)
  x[miss] <- seas[miss]
  beyond <- x > thresh
  ecat <- switch(rule$event,
    max = mask$category,
    share = level_category(x, category_levels(seas, thresh, rule), rule$event_compare),
    stop("unknown event category rule \"", rule$event, "\""))
  neighbour <- rules$rate_neighbour
  if (!neighbour %in% c("filled", "observed")) stop("unknown rate_neighbour rule \"", neighbour, "\"")

  sp <- spell_bounds(ev)
  n <- nrow(x)
  one <- function(j, a, b) {
    t <- a:b
    an <- x[t, j] - seas[t, j]
    at <- x[t, j] - thresh[t, j]
    ab <- x[t, j]
    pk <- which.max(an)
    imax <- an[pk]
    ## heatwaveR's order of operations: 0.5 * (A + B - C)
    onset <- if (a > 1L && (neighbour == "filled" || !miss[a - 1L, j])) {
      (imax - 0.5 * (an[1L] + x[a - 1L, j] - seas[a - 1L, j])) / (pk - 1 + 0.5)
    } else NA_real_
    decline <- if (b < n && (neighbour == "filled" || !miss[b + 1L, j])) {
      (imax - 0.5 * (an[length(t)] + x[b + 1L, j] - seas[b + 1L, j])) / (length(t) - pk + 0.5)
    } else NA_real_
    cnt <- tabulate(ecat[t, j], nbins = 4L)
    c(a + pk - 1L, sum(beyond[t, j]), sum(miss[t, j]),
      imax, mean(an), stats::sd(an), sum(an),
      max(at), mean(at), stats::sd(at), sum(at),
      max(ab), mean(ab), stats::sd(ab), sum(ab),
      onset, decline, cnt)
  }
  vals <- matrix(NA_real_, nrow(sp), 21L)
  for (i in seq_len(nrow(sp))) vals[i, ] <- one(sp$series[i], sp$index_start[i], sp$index_end[i])
  colnames(vals) <- c("index_peak", "n_beyond", "n_missing",
                      paste0("intensity_", c("max", "mean", "sd", "cumulative")),
                      paste0("intensity_", c("max", "mean", "sd", "cumulative"), "_thresh"),
                      paste0("intensity_", c("max", "mean", "sd", "cumulative"), "_abs"),
                      "rate_onset", "rate_decline",
                      "n_moderate", "n_strong", "n_severe", "n_extreme")
  duration <- sp$index_end - sp$index_start + 1L
  cnt <- vals[, c("n_moderate", "n_strong", "n_severe", "n_extreme"), drop = FALSE]
  category <- if (rule$event == "share") {
    ## heatwaveR's category(): the highest category whose share of the
    ## spell's steps, rounded to a whole percent, is above zero; I if none
    p <- round(cnt / duration * 100, 0)
    ifelse(p[, 4L] > 0, 4L, ifelse(p[, 3L] > 0, 3L, ifelse(p[, 2L] > 0, 2L, 1L)))
  } else {
    vapply(seq_len(nrow(sp)), function(i) {
      max(mask$category[sp$index_start[i]:sp$index_end[i], sp$series[i]])
    }, 0L)
  }
  metric <- grep("^(intensity|rate)_", colnames(vals), value = TRUE)
  if (!is.null(rules$round)) vals[, metric] <- round(vals[, metric], rules$round)
  ip <- as.integer(vals[, "index_peak"])
  out <- data.frame(series = sp$series, spell = sp$spell,
                    start = time[sp$index_start], peak = time[ip], end = time[sp$index_end],
                    index_start = sp$index_start, index_peak = ip, index_end = sp$index_end,
                    duration = duration,
                    n_beyond = as.integer(vals[, "n_beyond"]),
                    n_missing = as.integer(vals[, "n_missing"]),
                    cut_start = sp$index_start == 1L, cut_end = sp$index_end == n)
  out <- cbind(out, as.data.frame(vals[, metric, drop = FALSE]))
  out$category <- as.integer(category)
  for (nm in colnames(cnt)) out[[nm]] <- as.integer(cnt[, nm])
  out
}

## The spells in an event mask: series, number in the series, first and
## last row.
spell_bounds <- function(ev) {
  b <- lapply(seq_len(ncol(ev)), function(j) {
    r <- rle(ev[, j])
    e <- cumsum(r$lengths)
    k <- which(r$values)
    if (!length(k)) return(NULL)
    data.frame(series = j, spell = seq_along(k), index_start = e[k] - r$lengths[k] + 1L,
               index_end = e[k])
  })
  b <- do.call(rbind, b)
  if (is.null(b)) b <- data.frame(series = integer(), spell = integer(),
                                  index_start = integer(), index_end = integer())
  b
}
