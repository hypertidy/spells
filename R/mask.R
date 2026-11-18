## Exceedance -> spell -> category, per step.

#' Spell mask and categories per step
#'
#' Applies a fitted baseline to a series by slot, finds the steps beyond
#' the threshold, keeps the runs that pass the def's persistence rules,
#' and gives each step in a spell its category.
#'
#' @param x A numeric vector, or a time x series matrix with the same
#'   series (columns) the baseline was fitted on.
#' @param time A `Date` vector of consecutive days, one per row of `x`.
#'   It needn't be the stretch the baseline was fitted on.
#' @param baseline A `spell_baseline` from [spell_baseline()].
#' @return A list of time x series matrices: `event` (logical, `TRUE` on
#'   every step in a spell, joined gaps included), `category` (integer: 0
#'   outside spells and for steps with no category, 1 to 4 for Hobday
#'   2018's I to IV; only if the def has categories) and `anom` (the
#'   series minus the baseline, after the def's missing-data rule: `NA`
#'   where a step can't be tested). A low spell (a cold spell) is below
#'   the threshold, and its categories count down from it.
#' @export
#' @examples
#' x <- 20 + 2 * sin(2 * pi * seq_len(3653) / 365.25) + rnorm(3653, sd = 0.5)
#' time <- seq(as.Date("1990-01-01"), by = "day", length.out = 3653)
#' def <- hobday2016(c("1990-01-01", "1999-12-31"))
#' m <- spell_mask(x, time, spell_baseline(x, time, def))
#' sum(m$event)
spell_mask <- function(x, time, baseline) {
  p <- prepare_steps(x, time, baseline)
  def <- baseline$def
  rules <- def$rules
  exceed <- p$x > p$thresh
  exceed[p$open] <- FALSE
  ev <- matrix(FALSE, nrow(p$x), ncol(p$x))
  for (j in seq_len(ncol(p$x))) {
    ev[, j] <- spell_runs(exceed[, j], def$min_duration, def$max_gap,
                          leading_gap = rules$leading_gap, trailing_gap = rules$trailing_gap,
                          blocked = p$open[, j])
  }
  out <- list(event = ev)
  if (!is.null(def$category)) out$category <- step_category(p$x, p$seas, p$thresh, ev, def$category)
  out$anom <- p$sign * (p$x - p$seas)
  out
}

## The series, baseline and threshold per step, after the def's
## missing-data rule:
##  baseline:    a missing step is set to the baseline, so it's never
##               beyond it (heatwaveR, heatwave3)
##  interpolate: a run of max_interp or fewer missing steps with an
##               observed step on both sides is interpolated linearly
##               (spells' clean rule); the rest stay missing
## Also: which steps were missing, which were interpolated, and which
## are open (can't be tested: still missing, or in a slot without a
## baseline). No gap is joined across an open step.
## A low spell's series, baseline and threshold are negated (sign -1),
## so everything after looks for steps above the threshold, as
## heatwaveR and heatwave3 detect cold spells.
prepare_steps <- function(x, time, baseline) {
  if (!inherits(baseline, "spell_baseline")) stop("`baseline` must be a spell_baseline")
  x <- check_series(x, time)
  if (ncol(x) != ncol(baseline$seas)) {
    stop("`x` has ", ncol(x), " series but the baseline was fitted on ", ncol(baseline$seas))
  }
  rules <- baseline$def$rules
  s <- slot_366(time)
  seas <- baseline$seas[s, , drop = FALSE]
  thresh <- baseline$thresh[s, , drop = FALSE]
  missing <- is.na(x)
  interpolated <- matrix(FALSE, nrow(x), ncol(x))
  switch(rules$missing,
    baseline = {
      x[missing] <- seas[missing]
    },
    interpolate = {
      x <- interpolate_runs(x, rules$max_interp)
      interpolated <- missing & !is.na(x)
    },
    stop("unknown missing rule \"", rules$missing, "\""))
  open <- is.na(x) | is.na(seas) | is.na(thresh)
  sign <- switch(baseline$def$direction, high = 1, low = -1,
                 stop("unknown direction \"", baseline$def$direction, "\""))
  list(x = sign * x, seas = sign * seas, thresh = sign * thresh, missing = missing,
       interpolated = interpolated, open = open, sign = sign)
}

## Linear interpolation of each run of n or fewer missing steps that has
## an observed step on both sides, per column.
interpolate_runs <- function(x, n) {
  for (j in seq_len(ncol(x))) {
    v <- x[, j]
    na <- is.na(v)
    if (!any(na) || all(na)) next
    r <- rle(na)
    e <- cumsum(r$lengths)
    s <- e - r$lengths + 1L
    k <- which(r$values & r$lengths <= n & s > 1L & e < length(v))
    if (!length(k)) next
    at <- unlist(lapply(k, function(i) s[i]:e[i]))
    v[at] <- stats::approx(which(!na), v[!na], xout = at)$y
    x[, j] <- v
  }
  x
}

## Minimum first, then join: runs of at least min_duration exceedances
## are spells; a gap of max_gap or fewer steps between two spells joins
## them, unless it holds a blocked step (one that can't be tested).
## leading_gap / trailing_gap: whether a short gap between the series
## start and the first spell, or the last spell and the series end, is
## joined too (heatwaveR 0.5.5 joins the trailing one).
## This is trend.sst's mhw_event_mask().
spell_runs <- function(exceed, min_duration, max_gap, leading_gap = FALSE, trailing_gap = FALSE,
                       blocked = NULL) {
  n <- length(exceed)
  out <- logical(n)
  r <- rle(exceed)
  ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1L
  keep <- r$values & r$lengths >= min_duration
  if (!any(keep)) return(out)
  for (k in which(keep)) out[starts[k]:ends[k]] <- TRUE
  r2 <- rle(out)
  e2 <- cumsum(r2$lengths); s2 <- e2 - r2$lengths + 1L
  on <- which(r2$values)
  gap <- !r2$values & r2$lengths <= max_gap
  if (!leading_gap) gap <- gap & e2 > s2[on[1]]
  if (!trailing_gap) gap <- gap & s2 < e2[on[length(on)]]
  if (!is.null(blocked) && any(blocked)) {
    cb <- c(0L, cumsum(blocked))
    gap <- gap & cb[e2 + 1L] == cb[s2]
  }
  for (k in which(gap)) out[s2[k]:e2[k]] <- TRUE
  out
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
