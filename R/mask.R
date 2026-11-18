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
#'   2018's I to IV) and `anom` (the series minus the baseline, after the
#'   def's missing-data rule).
#' @export
#' @examples
#' x <- 20 + 2 * sin(2 * pi * seq_len(3653) / 365.25) + rnorm(3653, sd = 0.5)
#' time <- seq(as.Date("1990-01-01"), by = "day", length.out = 3653)
#' def <- hobday2016(c("1990-01-01", "1999-12-31"), parity = "heatwaveR-0.5.5")
#' m <- spell_mask(x, time, spell_baseline(x, time, def))
#' sum(m$event)
spell_mask <- function(x, time, baseline) {
  if (!inherits(baseline, "spell_baseline")) stop("`baseline` must be a spell_baseline")
  x <- check_series(x, time)
  def <- baseline$def
  if (ncol(x) != ncol(baseline$seas)) {
    stop("`x` has ", ncol(x), " series but the baseline was fitted on ", ncol(baseline$seas))
  }
  rules <- def$rules
  s <- slot_366(time)
  seas <- baseline$seas[s, , drop = FALSE]
  thresh <- baseline$thresh[s, , drop = FALSE]
  if (!identical(rules$missing, "baseline")) stop("only missing = \"baseline\" is implemented")
  x[is.na(x)] <- seas[is.na(x)]          # heatwaveR: a missing step is the baseline
  exceed <- x > thresh
  ev <- matrix(FALSE, nrow(x), ncol(x))
  for (j in seq_len(ncol(x))) {
    ev[, j] <- spell_runs(exceed[, j], def$min_duration, def$max_gap,
                          leading_gap = rules$leading_gap, trailing_gap = rules$trailing_gap)
  }
  cat <- step_category(x, seas, thresh, ev, def$category)
  list(event = ev, category = cat, anom = x - seas)
}

## Minimum first, then join: runs of at least min_duration exceedances
## are spells; a gap of max_gap or fewer steps between two spells joins
## them. leading_gap / trailing_gap: whether a short gap between the
## series start and the first spell, or the last spell and the series
## end, is joined too (heatwaveR 0.5.5 joins the trailing one).
## This is trend.sst's mhw_event_mask().
spell_runs <- function(exceed, min_duration, max_gap, leading_gap = FALSE, trailing_gap = FALSE) {
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
  for (k in which(gap)) out[s2[k]:e2[k]] <- TRUE
  out
}

## Category per step, on spell steps only (0 elsewhere). d is the
## threshold's distance from the baseline, rounded if the rule says so.
## ">=": the floor of (x - seas) / d, as trend.sst computes it. ">":
## the highest k with x above the k-th level, where level 1 is thresh
## and each level is the one below plus d (rounded each time, as
## heatwaveR's category() builds thresh_2x, _3x and _4x).
step_category <- function(x, seas, thresh, ev, rule) {
  d <- thresh - seas
  if (!is.null(rule$round)) d <- round(d, rule$round)
  if (rule$compare == ">=") {
    cat <- pmax(pmin(floor((x - seas) / d), rule$max), 0)   # matrix first: keeps dim
  } else {
    cat <- matrix(0, nrow(x), ncol(x))
    level <- thresh
    for (k in seq_len(rule$max)) {
      if (k > 1L) {
        level <- level + d
        if (!is.null(rule$round)) level <- round(level, rule$round)
      }
      cat[x > level] <- k
    }
  }
  cat[!ev] <- 0
  if (rule$gap_days == "I") cat[ev & cat == 0] <- 1
  storage.mode(cat) <- "integer"
  cat
}
