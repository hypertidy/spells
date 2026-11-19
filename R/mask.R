## Exceedance -> spell -> category, per step.

#' Spell mask and categories per step
#'
#' Applies a fitted baseline to a series by slot, finds the steps beyond
#' the threshold, keeps the runs that pass the def's persistence rules,
#' and gives each step in a spell its category.
#'
#' The rules apply in this order:
#' 1. the eligibility mask: an ineligible step's value is set aside;
#' 2. the def's missing-data rule: a short run of missing steps is
#'    interpolated (clean rules), or a missing step counts as the
#'    baseline (the heatwaveR and heatwave3 modes) or as below the
#'    threshold (trend.ice);
#' 3. the baseline and threshold at each step, by slot, plus the trend
#'    for a detrended baseline;
#' 4. exceedance: the step is above the threshold (below, for a low
#'    spell), or at or beyond it with the def's `compare = ">="`;
#' 5. persistence, in the def's order: the minimum duration first and
#'    then gaps of `max_gap` or fewer joined between spells (Hobday et
#'    al. 2016, and the heatwave presets), gaps joined between runs first
#'    and then the minimum on the joined span, gap steps counted
#'    (MHW-MAD), or the minimum on the run that opens a spell only, with
#'    the runs after it joined across gaps (Massom et al. 2013). No gap
#'    is joined across a step that can't be tested, and with a season
#'    nothing crosses its boundary: runs are cut there;
#' 6. categories, per step.
#'
#' @param x A numeric vector, or a time x series matrix with the same
#'   series (columns) the baseline was fitted on.
#' @param time A `Date` vector of consecutive days, one per row of `x`.
#'   It needn't be the stretch the baseline was fitted on.
#' @param baseline A `spell_baseline` from [spell_baseline()].
#' @param eligible Where the series means something (`TRUE`), such as
#'   SST not under ice: `NULL` for everywhere, a logical matrix the shape
#'   of `x`, or one value per series. An ineligible step isn't missing
#'   data: its value is ignored, it's never interpolated across, no gap
#'   is joined across it, and the spells beside it are cut there. With a
#'   parity mode it is the engine's answer on the series masked to `NA`
#'   there.
#' @return A list of time x series matrices: `event` (logical, `TRUE` on
#'   every step in a spell, joined gaps included), `category` (integer: 0
#'   outside spells and for steps with no category, 1 to 4 for Hobday
#'   2018's I to IV; only if the def has categories) and `anom` (the
#'   series minus the baseline, after the def's missing-data rule: `NA`
#'   where a step can't be tested, and everywhere with a fixed-level
#'   threshold, which has no baseline), and `state` (integer, each step's
#'   state: 0 observed, 1 filled (interpolated, or counted as the
#'   baseline or as below the threshold), 2 missing, 3 ineligible, 4 no
#'   baseline; the names are its `levels` attribute). A low spell (a cold spell) is below the
#'   threshold, and its categories count down from it.
#' @export
#' @examples
#' x <- 20 + 2 * sin(2 * pi * seq_len(3653) / 365.25) + rnorm(3653, sd = 0.5)
#' time <- seq(as.Date("1990-01-01"), by = "day", length.out = 3653)
#' def <- hobday2016(c("1990-01-01", "1999-12-31"))
#' m <- spell_mask(x, time, spell_baseline(x, time, def))
#' sum(m$event)
spell_mask <- function(x, time, baseline, eligible = NULL) {
  p <- prepare_steps(x, time, baseline, eligible)
  def <- baseline$def
  rules <- def$rules
  exceed <- beyond_threshold(p, def)
  ev <- matrix(FALSE, nrow(p$x), ncol(p$x))
  for (j in seq_len(ncol(p$x))) {
    ev[, j] <- spell_runs(exceed[, j], def$min_duration, def$max_gap,
                          leading_gap = rules$leading_gap, trailing_gap = rules$trailing_gap,
                          blocked = p$open[, j], order = def$order, breaks = p$breaks)
  }
  out <- list(event = ev)
  if (!is.null(def$category)) out$category <- step_category(p$x, p$seas, p$thresh, ev, def$category)
  out$anom <- p$sign * (p$x - p$seas)
  out$state <- p$state
  out
}

## Each step's state, by precedence: ineligible, then still missing, then
## in a slot without a baseline, then filled, else observed.
step_states <- c("observed", "filled", "missing", "ineligible", "no_baseline")

## The steps beyond the threshold, by the def's comparison (a low spell's
## series and threshold are already negated); never a step that can't
## be tested or has no value.
beyond_threshold <- function(p, def) {
  b <- switch(def$compare, ">" = p$x > p$thresh, ">=" = p$x >= p$thresh,
              stop("unknown comparison \"", def$compare, "\""))
  b[is.na(b) | p$open] <- FALSE
  b
}

## The series, baseline and threshold per step, after the def's
## missing-data rule:
##  baseline:    a missing step is set to the baseline, so it's never
##               beyond it (heatwaveR, heatwave3)
##  interpolate: a run of max_interp or fewer missing steps with an
##               observed step on both sides is interpolated linearly
##               (spells' clean rule); the rest stay missing
##  below:       a missing step counts as below the threshold, so it's
##               never beyond it, and is no cut: it has no value, and
##               the spell goes on across it (trend.ice)
## Also: which steps were missing, which were interpolated, and which
## are open (can't be tested: still missing, ineligible, or in a slot
## without a baseline). No gap is joined across an open step.
## An ineligible step is set to NA first: with the clean rules it's
## never interpolated, nor interpolated across; with a parity mode it is
## then just missing, as the engine would see the masked series.
## A low spell's series, baseline and threshold are negated (sign -1),
## so everything after looks for steps above the threshold, as
## heatwaveR and heatwave3 detect cold spells. With a season, `breaks`
## is TRUE on each season's first step (and the series' first).
prepare_steps <- function(x, time, baseline, eligible = NULL) {
  if (!inherits(baseline, "spell_baseline")) stop("`baseline` must be a spell_baseline")
  x <- check_series(x, time)
  if (ncol(x) != ncol(baseline$seas)) {
    stop("`x` has ", ncol(x), " series but the baseline was fitted on ", ncol(baseline$seas))
  }
  ineligible <- !check_eligible(eligible, x)
  x[ineligible] <- NA_real_
  rules <- baseline$def$rules
  s <- slot_366(time)
  seas <- baseline$seas[s, , drop = FALSE]
  thresh <- baseline$thresh[s, , drop = FALSE]
  ## a detrended baseline: the climatology plus the trend at each step
  tr <- baseline$trend
  if (!is.null(tr) && tr$applied) {
    shift <- outer(as.numeric(time) - as.numeric(tr$centre), tr$slope)
    seas <- seas + shift
    thresh <- thresh + shift
  }
  missing <- is.na(x) & !ineligible           # data gaps only
  filled <- matrix(FALSE, nrow(x), ncol(x))
  switch(rules$missing,
    baseline = {
      na <- is.na(x)
      x[na] <- seas[na]
      filled <- na & !is.na(x)
    },
    interpolate = {
      x <- interpolate_runs(x, rules$max_interp, blocked = ineligible)
      filled <- missing & !is.na(x)
    },
    below = {
      filled <- is.na(x)
    },
    stop("unknown missing rule \"", rules$missing, "\""))
  ## a fixed level has no baseline: only the threshold has to be there
  fixed_level <- baseline$def$threshold$type == "value"
  nobase <- is.na(thresh) | (!fixed_level & is.na(seas))
  open <- (is.na(x) & !filled) | nobase
  state <- matrix(0L, nrow(x), ncol(x))
  state[filled] <- 1L
  state[nobase] <- 4L
  state[is.na(x) & missing & !filled] <- 2L
  state[ineligible] <- 3L
  attr(state, "levels") <- step_states
  sign <- switch(baseline$def$direction, high = 1, low = -1,
                 stop("unknown direction \"", baseline$def$direction, "\""))
  season <- if (is.null(baseline$def$season)) NULL else season_steps(time, baseline$def$season)
  breaks <- if (is.null(season)) NULL else c(TRUE, diff(season$year) != 0L)
  list(x = sign * x, seas = sign * seas, thresh = sign * thresh, missing = missing,
       ineligible = ineligible, interpolated = filled & rules$missing == "interpolate",
       open = open, state = state, sign = sign, season = season, breaks = breaks)
}

## Linear interpolation of each run of n or fewer missing steps that has
## an observed, unblocked step on both sides, per column. A blocked
## (ineligible) step is never filled, and no run is interpolated across
## or up to one.
interpolate_runs <- function(x, n, blocked = NULL) {
  if (is.null(blocked)) blocked <- matrix(FALSE, nrow(x), ncol(x))
  for (j in seq_len(ncol(x))) {
    v <- x[, j]
    na <- is.na(v)
    gap <- na & !blocked[, j]
    obs <- !na & !blocked[, j]
    if (!any(gap) || !any(obs)) next
    r <- rle(gap)
    e <- cumsum(r$lengths)
    s <- e - r$lengths + 1L
    k <- which(r$values & r$lengths <= n & s > 1L & e < length(v))
    k <- k[obs[s[k] - 1L] & obs[e[k] + 1L]]
    if (!length(k)) next
    at <- unlist(lapply(k, function(i) s[i]:e[i]))
    v[at] <- stats::approx(which(obs), v[obs], xout = at)$y
    x[, j] <- v
  }
  x
}

## The runs of a logical vector, split also where `breaks` is TRUE (the
## first step of a season): each run's first and last index, value and
## length, and whether it begins or ends a segment (the series, or a
## season in it).
step_runs <- function(v, breaks = NULL) {
  n <- length(v)
  chg <- c(TRUE, v[-1L] != v[-n])
  if (!is.null(breaks)) chg <- chg | breaks
  s <- which(chg)
  e <- c(s[-1L] - 1L, n)
  first <- s == 1L
  last <- e == n
  if (!is.null(breaks)) {
    first <- first | breaks[s]
    last[!last] <- breaks[e[!last] + 1L]
  }
  list(s = s, e = e, v = v[s], len = e - s + 1L, first = first, last = last)
}

## The persistence rules, in the def's order:
##  minimum_first: runs of at least min_duration exceedances are spells,
##        then a gap of max_gap or fewer steps between two spells joins
##        them (Hobday et al. 2016, marineHeatWaves, heatwaveR; trend.sst's
##        mhw_event_mask())
##  join_first: a gap of max_gap or fewer steps between two runs of
##        exceedances (of any length) is joined first, then a joined span
##        is a spell if it's at least min_duration steps, gap steps
##        counted (MHW-MAD, checked against its data; lfstat pools first)
##  first_run: a spell opens with a run of at least min_duration
##        exceedances, and the runs after it, of any length, join it
##        across gaps of max_gap or fewer; it ends with the last of them.
##        Runs before the opening one aren't in it (iglu's start and end
##        rules; Massom et al. 2013 with max_gap = Inf in each ice year)
## Either way no gap is joined across a blocked step (one that can't be
## tested), and with breaks (season boundaries) runs are cut there, each
## piece on its own, and no gap is joined across one. leading_gap /
## trailing_gap: whether a short gap between a segment's start and its
## first run, or its last run and its end, is joined too (heatwaveR
## 0.5.5 joins the trailing one at the series' end).
spell_runs <- function(exceed, min_duration, max_gap, leading_gap = FALSE, trailing_gap = FALSE,
                       blocked = NULL, order = c("minimum_first", "join_first", "first_run"),
                       breaks = NULL) {
  order <- match.arg(order)
  n <- length(exceed)
  out <- logical(n)
  if (!any(exceed)) return(out)
  cb <- if (!is.null(blocked) && any(blocked)) c(0L, cumsum(blocked)) else NULL
  fill <- function(mask, s, e) {
    if (length(s)) mask[unlist(lapply(seq_along(s), function(i) s[i]:e[i]))] <- TRUE
    mask
  }
  ## the short gaps of on_mask, a run mask, joined
  joinable <- function(on_mask) {
    r <- step_runs(on_mask, breaks)
    gap <- !r$v & r$len <= max_gap & !(r$first & r$last)
    if (!leading_gap) gap <- gap & !r$first
    if (!trailing_gap) gap <- gap & !r$last
    if (!is.null(cb)) gap <- gap & cb[r$e + 1L] == cb[r$s]
    k <- which(gap)
    fill(on_mask, r$s[k], r$e[k])
  }
  ## the runs of on_mask at least min_duration long
  long_runs <- function(on_mask) {
    r <- step_runs(on_mask, breaks)
    k <- which(r$v & r$len >= min_duration)
    fill(logical(n), r$s[k], r$e[k])
  }
  switch(order,
    minimum_first = {
      out <- long_runs(exceed)
      if (any(out)) joinable(out) else out
    },
    join_first = long_runs(joinable(exceed)),
    first_run = {
      ## spans of runs joined across short gaps; in each, the spell
      ## starts at the first run of at least min_duration, and goes to
      ## the span's end
      span <- step_runs(joinable(exceed), breaks)
      r <- step_runs(exceed, breaks)
      opening <- r$s[r$v & r$len >= min_duration]
      if (!length(opening)) return(out)
      k <- findInterval(opening, span$s)
      keep <- !duplicated(k)
      fill(out, opening[keep], span$e[k[keep]])
    })
}

## Category per step, on spell steps only (0 elsewhere). ">=": the
## floor of (x - seas) / d, where d is the threshold's distance from the
## baseline, as trend.sst computes it. ">": the highest k with x above
## the k-th level (category_levels()).
step_category <- function(x, seas, thresh, ev, rule) {
  if (rule$compare == ">=") {
    d <- thresh - seas
    if (!is.null(rule$round)) d <- round(d, rule$round)
    cat <- pmax(pmin(floor((x - seas) / d), rule$max), 0)   # matrix first: keeps dim
  } else {
    cat <- level_category(x, category_levels(seas, thresh, rule), ">")
  }
  cat[!ev] <- 0
  ## steps in a spell that aren't beyond the threshold (joined gaps): none,
  ## even at the threshold itself, where the floor of the multiple is 1;
  ## or I (trend.sst)
  gap <- ev & !(x > thresh)
  cat[which(gap)] <- if (rule$gap_days == "I") 1 else 0
  storage.mode(cat) <- "integer"
  cat
}

## The category levels: level 1 is the threshold, and each level is the
## one below plus the threshold's distance from the baseline, d. With a
## rounding rule, d and each level are rounded as they are built (as
## heatwaveR's category() builds thresh_2x, _3x and _4x).
category_levels <- function(seas, thresh, rule) {
  d <- thresh - seas
  if (!is.null(rule$round)) d <- round(d, rule$round)
  lv <- vector("list", rule$max)
  level <- thresh
  for (k in seq_len(rule$max)) {
    if (k > 1L) {
      level <- level + d
      if (!is.null(rule$round)) level <- round(level, rule$round)
    }
    lv[[k]] <- level
  }
  lv
}

## The highest level each step is above (">") or at or above (">="), 0
## for none.
level_category <- function(x, levels, compare) {
  cat <- matrix(0L, nrow(x), ncol(x))
  for (k in seq_along(levels)) {
    cat[which(if (compare == ">") x > levels[[k]] else x >= levels[[k]])] <- k
  }
  cat
}
