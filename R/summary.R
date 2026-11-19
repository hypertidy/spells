## Spell -> summaries: one row per (series, season).

#' Spell summaries by season
#'
#' Summarises a [spell_mask()] per series and season: how many steps are
#' beyond the threshold or in a spell, how many spells there are, when the
#' first starts and the last ends, and why either is cut. The sea ice
#' season's advance and retreat ([massom2013()]) are these summaries. With
#' no season in the def, the whole series is one season.
#'
#' A season whose every step is missing, ineligible or without a baseline
#' (land, for a grid of ice concentration) has no summary: its counts
#' and dates are `NA`.
#'
#' @param x,time The series and dates given to [spell_mask()].
#' @param baseline The `spell_baseline` given to [spell_mask()].
#' @param mask The result of [spell_mask()].
#' @return A data frame, one row per season and series, ordered by season
#'   and then series (so one season's rows fill a grid's cells in order):
#'   * `series`; `season`, the season's label (`NA` with no season), and
#'     `season_start`, `season_end`, its first and last day;
#'   * `n_steps`: the season's steps in `x`, and `complete`: whether
#'     that's all of them (a season the series starts or ends in may not
#'     be);
#'   * `n_observed`, `n_missing`, `n_ineligible`: steps observed, missing
#'     in `x` (interpolated, counted by the def's rule, or untestable),
#'     and ineligible;
#'   * `n_beyond`: steps beyond the threshold, in a spell or not; for the
#'     ice season, the day count. `n_event`: steps in a spell, joined gaps
#'     included; `n_spells`;
#'   * `first_start`, `last_end`: the first step of the season's first
#'     spell and the last step of its last, and `first_start_cut_by`,
#'     `last_end_cut_by`: whether that spell is cut on that side and why
#'     (`"series"`, `"season"`, `"missing"`, `"ineligible"`,
#'     `"no_baseline"`, as in [spell_events()]), or `NA`;
#'   * `beyond_first`, `beyond_last`: whether the season's first and last
#'     steps are beyond the threshold (for the ice season, trend.ice's
#'     `ice_at_start` and `ice_at_end`).
#' @export
#' @examples
#' time <- seq(as.Date("2001-02-15"), as.Date("2003-02-14"), by = "day")
#' x <- 80 * (format(time, "%m") %in% c("05", "06", "07", "08", "09", "10"))
#' b <- spell_baseline(x, time, massom2013())
#' spell_summary(x, time, b, spell_mask(x, time, b))[c("season", "first_start", "last_end")]
spell_summary <- function(x, time, baseline, mask) {
  eligible <- if (is.null(mask$state)) NULL else unname(mask$state != 3L)
  if (!is.null(eligible) && !identical(dim(eligible), dim(as.matrix(x)))) {
    stop("`mask` must be spell_mask()'s result for this `x`")
  }
  p <- prepare_steps(x, time, baseline, eligible)
  ev <- mask$event
  if (!is.logical(ev) || !identical(dim(ev), dim(p$x))) {
    stop("`mask` must be spell_mask()'s result for this `x`")
  }
  def <- baseline$def
  beyond <- beyond_threshold(p, def)
  n <- nrow(p$x)
  ns <- ncol(p$x)
  count <- function(m) as.integer(colSums(m))
  if (is.null(p$season)) {
    group <- rep(1L, n)
    info <- data.frame(season = NA_integer_, season_start = time[1], season_end = time[n])
  } else {
    group <- match(p$season$year, unique(p$season$year))
    first <- !duplicated(group)
    info <- data.frame(season = p$season$label[first], season_start = p$season$first[first],
                       season_end = p$season$last[first])
  }
  out <- lapply(seq_len(nrow(info)), function(g) {
    rows <- which(group == g)
    k <- length(rows)
    E <- ev[rows, , drop = FALSE]
    B <- beyond[rows, , drop = FALSE]
    S <- p$state[rows, , drop = FALSE]
    starts <- E & rbind(TRUE, !E[-k, , drop = FALSE])
    idx <- matrix(seq_len(k), k, ns)
    first_i <- suppressWarnings(matrixStats::colMins(ifelse(E, idx, NA_integer_), na.rm = TRUE))
    last_i <- suppressWarnings(matrixStats::colMaxs(ifelse(E, idx, NA_integer_), na.rm = TRUE))
    has <- is.finite(first_i)
    first_i[!has] <- NA
    last_i[!has] <- NA
    j <- which(has)
    cut_first <- cut_last <- rep(NA_character_, ns)
    cut_first[j] <- cut_reason(rows[first_i[j]], j, "start", p)
    cut_last[j] <- cut_reason(rows[last_i[j]], j, "end", p)
    res <- data.frame(
      series = seq_len(ns), season = info$season[g],
      season_start = info$season_start[g], season_end = info$season_end[g],
      n_steps = k,
      complete = k == as.integer(info$season_end[g] - info$season_start[g]) + 1L,
      n_observed = count(S == 0L),
      n_missing = count(p$missing[rows, , drop = FALSE]),
      n_ineligible = count(S == 3L),
      n_beyond = count(B), n_event = count(E), n_spells = count(starts),
      first_start = time[rows][first_i], first_start_cut_by = cut_first,
      last_end = time[rows][last_i], last_end_cut_by = cut_last,
      beyond_first = B[1L, ], beyond_last = B[k, ])
    ## a season with nothing observed has no summary
    none <- res$n_observed == 0L
    if (any(none)) {
      for (nm in setdiff(names(res), c("series", "season", "season_start", "season_end",
                                       "n_steps", "complete"))) {
        res[[nm]][none] <- NA
      }
    }
    res
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}
