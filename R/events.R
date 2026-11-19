## Spell -> metrics: one row per (series, spell).

#' Spell metrics, one row per spell
#'
#' Measures each spell in a [spell_mask()]: its start, peak and end, its
#' duration, its intensities relative to the baseline, to the threshold
#' and in the series' own units, its rates of onset and decline, and its
#' category if the def has categories.
#'
#' A spell below the threshold (a cold spell, [schlegel2021()]) keeps the
#' series' sign: its anomalies and rates are negative, `intensity_max` is
#' its most negative anomaly and `intensity_max_abs` its lowest value, as
#' heatwaveR and heatwave3 report them. Its categories are I to IV, as a
#' high spell's.
#'
#' Every step in a spell is measured, joined gaps included, after the
#' def's missing-data rule (with the clean rules a short run of missing
#' steps is interpolated; with the parity modes a missing step counts as
#' the baseline). The peak is the first step of largest anomaly.
#'
#' The rate of onset is the peak anomaly less the anomaly midway between
#' the first step and the step before it, over the steps from that
#' midpoint to the peak; the rate of decline is the same at the end
#' (Hobday et al. 2016). A spell cut by either end of the series, or by
#' steps that can't be tested (`cut_start`, `cut_end`), has no rate on
#' that side. With the parity modes, a missing step just outside the
#' spell is a rule of the mode: heatwaveR counts it as the baseline;
#' heatwave3 gives no rate.
#'
#' @param x,time The series and dates given to [spell_mask()].
#' @param baseline The `spell_baseline` given to [spell_mask()].
#' @param mask The result of [spell_mask()]. Its step states carry the
#'   eligibility mask, if one was given.
#' @return A data frame, one row per spell, ordered by series and then
#'   time:
#'   * `series`, `spell`: the column of `x`, and the spell's number in it;
#'   * `start`, `peak`, `end`: dates; `index_start`, `index_peak`,
#'     `index_end`: rows of `x`;
#'   * `duration`: steps in the spell, joined gaps included; `n_beyond`:
#'     those beyond the threshold; `n_missing`: those missing in `x`
#'     (interpolated, or counted as the baseline); `n_ineligible`: those
#'     ineligible (always 0 with the clean rules, which cut a spell
#'     there; with a parity mode they count as missing);
#'   * `cut_start`, `cut_end`: the spell touches the first or last step,
#'     or a step that can't be tested, so it may have begun earlier or go
#'     on (at the series' end, a provisional tail); `cut_start_by`,
#'     `cut_end_by`: why, `"series"` (its end), `"missing"`,
#'     `"ineligible"` or `"no_baseline"`, or `NA` if not cut;
#'   * `intensity_max`, `intensity_mean`, `intensity_sd`,
#'     `intensity_cumulative`: of the anomaly (the series minus the
#'     baseline); then the same with suffix `_thresh` (the series minus
#'     the threshold) and `_abs` (the series itself). The `_sd` columns
#'     are heatwaveR's `intensity_var`, which is the standard deviation;
#'   * `rate_onset`, `rate_decline`: per step;
#'   * `category`: 1 to 4 for Hobday 2018's I to IV, by the def's
#'     category rule ([categories()]); `n_moderate`, `n_strong`,
#'     `n_severe`, `n_extreme`: steps in each, by the same rule. These
#'     columns are there only if the def has categories ([hobday2018()],
#'     not [hobday2016()]).
#'
#'   With a parity mode that rounds, the intensities and rates are
#'   rounded as its engine rounds them.
#' @export
#' @examples
#' x <- 20 + 2 * sin(2 * pi * seq_len(3653) / 365.25) + rnorm(3653, sd = 0.5)
#' time <- seq(as.Date("1990-01-01"), by = "day", length.out = 3653)
#' def <- hobday2018(c("1990-01-01", "1999-12-31"))
#' b <- spell_baseline(x, time, def)
#' m <- spell_mask(x, time, b)
#' ev <- spell_events(x, time, b, m)
#' head(ev[c("start", "end", "duration", "intensity_max", "category")])
spell_events <- function(x, time, baseline, mask) {
  ## the eligibility mask comes with the mask, in its step states
  eligible <- if (is.null(mask$state)) NULL else unname(mask$state != 3L)
  if (!is.null(eligible) && !identical(dim(eligible), dim(as.matrix(x)))) {
    stop("`mask` must be spell_mask()'s result for this `x`")
  }
  p <- prepare_steps(x, time, baseline, eligible)
  x <- p$x
  seas <- p$seas
  thresh <- p$thresh
  ev <- mask$event
  if (!is.logical(ev) || !identical(dim(ev), dim(x))) {
    stop("`mask` must be spell_mask()'s result for this `x`")
  }
  def <- baseline$def
  rules <- def$rules
  rule <- def$category
  miss <- p$missing
  ## a rate's step outside the spell: "observed" gives no rate across a
  ## missing or ineligible step that wasn't interpolated, or one that
  ## can't be tested
  no_rate <- p$open | ((miss | p$ineligible) & !p$interpolated)
  beyond <- x > thresh
  beyond[p$open] <- FALSE
  ecat <- if (is.null(rule)) {
    matrix(0L, nrow(x), ncol(x))
  } else switch(rule$event,
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
    onset <- if (a > 1L && (neighbour == "filled" || !no_rate[a - 1L, j])) {
      (imax - 0.5 * (an[1L] + x[a - 1L, j] - seas[a - 1L, j])) / (pk - 1 + 0.5)
    } else NA_real_
    decline <- if (b < n && (neighbour == "filled" || !no_rate[b + 1L, j])) {
      (imax - 0.5 * (an[length(t)] + x[b + 1L, j] - seas[b + 1L, j])) / (length(t) - pk + 0.5)
    } else NA_real_
    cnt <- tabulate(ecat[t, j], nbins = 4L)
    c(a + pk - 1L, sum(beyond[t, j]), sum(miss[t, j]), sum(p$ineligible[t, j]),
      imax, mean(an), stats::sd(an), sum(an),
      max(at), mean(at), stats::sd(at), sum(at),
      max(ab), mean(ab), stats::sd(ab), sum(ab),
      onset, decline, cnt)
  }
  vals <- matrix(NA_real_, nrow(sp), 22L)
  for (i in seq_len(nrow(sp))) vals[i, ] <- one(sp$series[i], sp$index_start[i], sp$index_end[i])
  colnames(vals) <- c("index_peak", "n_beyond", "n_missing", "n_ineligible",
                      paste0("intensity_", c("max", "mean", "sd", "cumulative")),
                      paste0("intensity_", c("max", "mean", "sd", "cumulative"), "_thresh"),
                      paste0("intensity_", c("max", "mean", "sd", "cumulative"), "_abs"),
                      "rate_onset", "rate_decline",
                      "n_moderate", "n_strong", "n_severe", "n_extreme")
  duration <- sp$index_end - sp$index_start + 1L
  cnt <- vals[, c("n_moderate", "n_strong", "n_severe", "n_extreme"), drop = FALSE]
  category <- if (is.null(rule)) {
    NULL
  } else if (rule$event == "share") {
    ## heatwaveR's category(): the highest category whose share of the
    ## spell's steps, rounded to a whole percent, is above zero; I if none
    pct <- round(cnt / duration * 100, 0)
    ifelse(pct[, 4L] > 0, 4L, ifelse(pct[, 3L] > 0, 3L, ifelse(pct[, 2L] > 0, 2L, 1L)))
  } else {
    vapply(seq_len(nrow(sp)), function(i) {
      max(mask$category[sp$index_start[i]:sp$index_end[i], sp$series[i]])
    }, 0L)
  }
  metric <- grep("^(intensity|rate)_", colnames(vals), value = TRUE)
  ## a low spell was measured on the negated series: its intensities and
  ## rates go back to the series' own sign (heatwaveR, heatwave3), so the
  ## anomalies are negative and intensity_max is the most negative; the
  ## spreads (sd) have no sign
  if (p$sign < 0) {
    signed <- grep("^(intensity_(max|mean|cumulative)|rate_)", colnames(vals), value = TRUE)
    vals[, signed] <- -vals[, signed]
  }
  if (!is.null(rules$round)) vals[, metric] <- round(vals[, metric], rules$round)
  ip <- as.integer(vals[, "index_peak"])
  out <- data.frame(series = sp$series, spell = sp$spell,
                    start = time[sp$index_start], peak = time[ip], end = time[sp$index_end],
                    index_start = sp$index_start, index_peak = ip, index_end = sp$index_end,
                    duration = duration,
                    n_beyond = as.integer(vals[, "n_beyond"]),
                    n_missing = as.integer(vals[, "n_missing"]),
                    n_ineligible = as.integer(vals[, "n_ineligible"]))
  ## cut by the series' end, or by a step outside the spell that can't
  ## be tested, and why
  cut_by <- function(at_edge, nb) {
    by <- rep(NA_character_, length(nb))
    inside <- !at_edge
    o <- p$open[cbind(nb[inside], sp$series[inside])]
    by[inside][o] <- step_states[p$state[cbind(nb[inside], sp$series[inside])][o] + 1L]
    by[at_edge] <- "series"
    by
  }
  out$cut_start_by <- cut_by(sp$index_start == 1L, sp$index_start - 1L)
  out$cut_end_by <- cut_by(sp$index_end == n, sp$index_end + 1L)
  out$cut_start <- !is.na(out$cut_start_by)
  out$cut_end <- !is.na(out$cut_end_by)
  out <- out[c(names(out)[1:12], "cut_start", "cut_end", "cut_start_by", "cut_end_by")]
  out <- cbind(out, as.data.frame(vals[, metric, drop = FALSE]))
  if (!is.null(rule)) {
    out$category <- as.integer(category)
    for (nm in colnames(cnt)) out[[nm]] <- as.integer(cnt[, nm])
  }
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
