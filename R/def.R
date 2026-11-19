## Definitions: what a spell is, as an object.

#' Marine heatwaves and cold spells: the presets
#'
#' * `hobday2016()`: marine heatwaves as Hobday et al. (2016) detect
#'   them: a climatology from an 11-day window pooled over the reference
#'   years and smoothed by a 31-day running mean, the 90th percentile as
#'   the threshold, at least 5 days above it, and gaps of 2 days or fewer
#'   joined. It has no categories.
#' * `hobday2018()`: the same, with Hobday et al. (2018)'s categories,
#'   I to IV, the multiples of the threshold's distance from the
#'   baseline.
#' * `schlegel2021()`: marine cold spells (Schlegel et al. 2021): the
#'   same, below the 10th percentile, with the categories counting down
#'   from it. Intensities and rates are negative, as heatwaveR and
#'   heatwave3 report them. There's no freezing-point correction and no
#'   ice category: SST under ice is a matter for an eligibility mask.
#'
#' By default they run on spells' clean rules:
#' * the climatology window is shorter at the ends of the reference
#'   period, using only the period's own days;
#' * nothing is invented for the baseline: a missing day in the
#'   reference period, and slot 60 (29 February) in a non-leap year,
#'   drop out of the pooled window;
#' * a slot gets a baseline only if at least half of the reference
#'   period's days in its window are there; steps in a slot without one
#'   count as missing;
#' * nothing is rounded;
#' * in detection, a run of 3 or fewer missing steps between two
#'   observed ones is interpolated linearly. A longer run, or one at
#'   either end of the series, can't be tested: no gap is joined across
#'   it, and the spells beside it are cut there (`cut_start`, `cut_end`
#'   in [spell_events()]);
#' * gaps are joined only between two spells;
#' * categories are the floor of the multiple, joined gap days get none,
#'   and a spell's category is its highest step's ([categories()]).
#'
#' `parity` reproduces another package's version instead, for heatwaves
#' and cold spells alike (heatwaveR's and heatwave3's `coldSpells`, with
#' the 10th percentile).
#'
#' @param reference The reference period: two dates, the first and last
#'   day. It must be whole years.
#' @param parity `NULL` for spells' clean rules, or the engine and
#'   version whose behaviour to reproduce: `"heatwaveR-0.5.5"`,
#'   `"heatwaveR-1.0.0"` or `"heatwave3-1.5.0"`. See [parity_modes()].
#' @seealso [massom2013()] for the sea ice season, and [spell_def()] for
#'   the general definition.
#' @param category How each step in a spell gets its category, from
#'   [categories()]. The default is the clean rule, or the parity mode's
#'   own.
#' @param baseline The baseline type: [baseline_fixed()] (the default)
#'   or [baseline_detrended()].
#' @return A `spell_def`.
#' @references Hobday, A. J. et al. (2016). A hierarchical approach to
#'   defining marine heatwaves. Progress in Oceanography 141, 227-238.
#'   \doi{10.1016/j.pocean.2015.12.014}
#'
#'   Hobday, A. J. et al. (2018). Categorizing and naming marine
#'   heatwaves. Oceanography 31(2), 162-173. \doi{10.5670/oceanog.2018.205}
#'
#'   Schlegel, R. W. et al. (2021). Marine cold-spells. Progress in
#'   Oceanography 198, 102684. \doi{10.1016/j.pocean.2021.102684}
#' @name presets
#' @examples
#' ref <- c("1982-01-01", "2011-12-31")
#' hobday2016(ref)
#' hobday2018(ref, parity = "heatwaveR-0.5.5")
#' hobday2018(ref, baseline = baseline_detrended())
#' schlegel2021(ref)
NULL

#' @rdname presets
#' @export
hobday2016 <- function(reference, parity = NULL, baseline = baseline_fixed()) {
  check_parity(parity, "hobday2016")
  spell_def("hobday2016", reference, parity = parity, baseline = baseline)
}

#' @rdname presets
#' @export
hobday2018 <- function(reference, parity = NULL, category = NULL, baseline = baseline_fixed()) {
  mode <- check_parity(parity, "hobday2018")
  spell_def("hobday2018", reference, parity = parity, baseline = baseline,
            category = if (is.null(category)) mode$category else category)
}

#' @rdname presets
#' @export
schlegel2021 <- function(reference, parity = NULL, category = NULL, baseline = baseline_fixed()) {
  mode <- check_parity(parity, "schlegel2021")
  spell_def("schlegel2021", reference, parity = parity, baseline = baseline,
            category = if (is.null(category)) mode$category else category,
            direction = "low", threshold = threshold_percentile(0.1))
}

#' The sea ice season: Massom et al. (2013)
#'
#' The Antarctic sea ice season, per pixel and ice year (15 February to
#' 14 February), as Massom et al. (2013) define it from daily ice
#' concentration:
#' * the day of **advance** is the first day of the first run of at
#'   least 5 days at or above the threshold (15%);
#' * the day of **retreat** is the day after the last day at or above it,
#'   so that ice concentration stays below it to the end of the ice year;
#' * the **duration** is retreat minus advance, and the **day count** is
#'   the number of days at or above the threshold in the ice year.
#'
#' As a spell definition that is one spell per ice year, opened by a run
#' of 5 days (`order = "first_run"`: only the opening run must reach the
#' minimum) and joined across every gap after it (`max_gap = Inf`), with
#' detection cut at 15 February ([season_year()]). Advance and retreat
#' are its season summaries ([spell_summary()]): `first_start` and the
#' day after `last_end`, counted from `season_start` as day 1. There is
#' no retreat when the season's last step is at or above the threshold
#' (`last_end_cut_by` is `"season"` or `"series"`: the ice didn't
#' retreat), and none without an advance, so isolated days of ice in
#' open water don't make one. The threshold is a fixed level
#' ([threshold_value()]), so there is no baseline and no reference
#' period.
#'
#' With the clean rules, a run of 5 or fewer missing days between
#' observed ones is interpolated linearly. A longer run can't be tested:
#' the spell is cut there, an advance or retreat on a side it cuts is
#' unknown (`first_start_cut_by` or `last_end_cut_by` is `"missing"`),
#' and the day count counts only days that can be tested (`n_missing`
#' says how many there are). `parity = "trend.ice-d5be6df"` reproduces
#' trend.ice's `R/ice_season.R` (its rules are unchanged since that
#' commit) and its published COGs: a missing day counts as below the
#' threshold. trend.ice interpolates days missing from the whole field
#' (5 or fewer) before that, as it reads them; that's part of reading
#' the data, not of the definition.
#'
#' @param threshold The ice concentration threshold, in the units of the
#'   series (percent).
#' @param parity `NULL` for spells' clean rules, or `"trend.ice-d5be6df"`.
#'   See [parity_modes()].
#' @return A `spell_def`.
#' @references Massom, R. et al. (2013). Change and variability in East
#'   Antarctic sea ice seasonality, 1979/80-2009/10. PLoS ONE 8(5),
#'   e64756. \doi{10.1371/journal.pone.0064756}
#' @export
#' @examples
#' ## one pixel, one ice year: ice from its day 100 to day 250
#' time <- seq(as.Date("2001-02-15"), as.Date("2002-02-14"), by = "day")
#' x <- ifelse(seq_along(time) %in% 100:250, 80, 0)
#' def <- massom2013()
#' b <- spell_baseline(x, time, def)
#' s <- spell_summary(x, time, b, spell_mask(x, time, b))
#' as.integer(s$first_start - s$season_start) + 1L   # advance: day 100
#' as.integer(s$last_end - s$season_start) + 2L      # retreat: day 251
#' s$n_beyond                                        # day count: 151
massom2013 <- function(threshold = 15, parity = NULL) {
  check_parity(parity, "massom2013")
  spell_def("massom2013", NULL, threshold = threshold_value(threshold), compare = ">=",
            min_duration = 5L, max_gap = Inf, order = "first_run",
            season = season_year("02-15"), max_interp = 5L, parity = parity)
}

## A parity mode a preset can use: NULL (the clean rules) or a mode made
## for it. Returns the mode (the clean rules' categories for NULL).
check_parity <- function(parity, preset) {
  if (is.null(parity)) return(list(category = categories()))
  mode <- parity_mode(parity)
  if (!preset %in% mode$presets) {
    stop("parity mode \"", parity, "\" isn't for ", preset, "(); it reproduces ",
         paste0(mode$presets, "()", collapse = ", "), call. = FALSE)
  }
  mode
}

#' Spell definitions
#'
#' The general definition the presets fill in ([hobday2016()],
#' [hobday2018()], [schlegel2021()], [massom2013()]). It is
#' **experimental**: its arguments may still change as definitions for
#' other variables are added (non-daily steps, analysis in log space).
#'
#' A spell is a run of steps beyond a threshold that passes the
#' persistence rules. `threshold` sets the level: a percentile of the
#' reference period per slot, with a climatology as the baseline, or a
#' fixed level with no baseline. `direction` and `compare` say what
#' beyond is. `min_duration`, `max_gap` and `order` are the persistence
#' rules, and `season` cuts detection at a boundary each year.
#'
#' @param name A name for the definition, printed and kept with it.
#' @param reference The reference period the baseline and a percentile
#'   threshold are fitted over: two dates, whole years. `NULL` with a
#'   fixed-level threshold, which needs none.
#' @param threshold [threshold_percentile()] or [threshold_value()].
#' @param baseline The baseline type: [baseline_fixed()] (the default)
#'   or [baseline_detrended()]. A fixed-level threshold has no baseline.
#' @param direction `"high"` (spells above the threshold) or `"low"`
#'   (below it).
#' @param compare How a step is compared with the threshold: `">"`,
#'   strictly beyond (Hobday et al. 2016), or `">="`, at or beyond
#'   (Massom et al. 2013's 15%). For a low spell, below or at or below.
#' @param window,smooth A percentile threshold's climatology: the window
#'   pooled around each slot, and the running mean that smooths the
#'   result, in slots.
#' @param min_duration The minimum duration, in steps.
#' @param max_gap The longest gap joined, in steps. `Inf` joins every
#'   gap (in each season, with `season`).
#' @param order Which runs the minimum applies to:
#'   * `"minimum_first"`: every run, before gaps are joined between the
#'     runs that reach it (Hobday et al. 2016);
#'   * `"join_first"`: the span left after gaps are joined between runs
#'     of any length, gap steps counted (MHW-MAD);
#'   * `"first_run"`: only the run that opens a spell; after it, runs of
#'     any length join across gaps of `max_gap` or fewer, and the spell
#'     ends after the last of them (iglu's start and end rules; Massom et
#'     al. 2013's ice season).
#'
#'   Either way no gap is joined across a step that can't be tested.
#' @param season `NULL`, or a [season_year()]: detection never crosses
#'   its boundary, and [spell_summary()] summarises by it.
#' @param category How each step in a spell gets its category, from
#'   [categories()], or `NULL` for none. Categories need a baseline.
#' @param max_interp,coverage The clean rules' interpolation limit (a
#'   run of `max_interp` or fewer missing steps between observed ones is
#'   interpolated), and the share of its window's possible days a slot
#'   needs for a baseline. A parity mode has its own.
#' @param parity `NULL` for spells' clean rules, or a parity mode: that
#'   engine's rules ([parity_modes()]).
#' @return A `spell_def`.
#' @export
#' @examples
#' ## the 95th percentile, at least 3 days, gaps of 1 joined
#' spell_def("p95", c("1991-01-01", "2020-12-31"), threshold = threshold_percentile(0.95),
#'           min_duration = 3, max_gap = 1)
#' ## a fixed level, at or above, in seasons starting 1 July
#' spell_def("level", threshold = threshold_value(30), compare = ">=",
#'           season = season_year("07-01"))
spell_def <- function(name, reference = NULL, threshold = threshold_percentile(0.9),
                      baseline = baseline_fixed(), direction = c("high", "low"),
                      compare = c(">", ">="), window = 11L, smooth = 31L,
                      min_duration = 5L, max_gap = 2L,
                      order = c("minimum_first", "join_first", "first_run"),
                      season = NULL, category = NULL, max_interp = 3L, coverage = 0.5,
                      parity = NULL) {
  direction <- match.arg(direction)
  compare <- match.arg(compare)
  order <- match.arg(order)
  if (!is.character(name) || length(name) != 1L) stop("`name` must be one string", call. = FALSE)
  if (!inherits(threshold, "spell_threshold_type")) {
    stop("`threshold` must come from threshold_percentile() or threshold_value()", call. = FALSE)
  }
  if (!is.null(category) && !inherits(category, "spell_categories")) {
    stop("`category` must come from categories()", call. = FALSE)
  }
  if (!inherits(baseline, "spell_baseline_type")) {
    stop("`baseline` must come from baseline_fixed() or baseline_detrended()", call. = FALSE)
  }
  if (!is.null(season) && !inherits(season, "spell_season")) {
    stop("`season` must come from season_year()", call. = FALSE)
  }
  if (!is.numeric(min_duration) || length(min_duration) != 1L || !is.finite(min_duration) ||
      min_duration < 1) {
    stop("`min_duration` must be a whole number of steps, 1 or more", call. = FALSE)
  }
  if (!is.numeric(max_gap) || length(max_gap) != 1L || is.na(max_gap) || max_gap < 0) {
    stop("`max_gap` must be a whole number of steps, 0 or more, or Inf", call. = FALSE)
  }
  max_gap <- if (is.finite(max_gap)) as.integer(max_gap) else Inf
  rules <- if (is.null(parity)) clean_mode(max_interp, coverage)$rules else parity_mode(parity)$rules
  fixed_level <- threshold$type == "value"
  if (fixed_level) {
    if (!is.null(category)) stop("categories need a baseline; a fixed-level threshold has none",
                                 call. = FALSE)
    if (baseline$type != "fixed") stop("a fixed-level threshold has no baseline to detrend",
                                       call. = FALSE)
    if (!is.null(reference)) reference <- as_reference(reference)
  } else {
    if (is.null(reference)) stop("a percentile threshold needs a `reference` period", call. = FALSE)
    reference <- as_reference(reference)
    if (is.null(rules$window_ends)) {
      stop("parity mode \"", parity, "\" has no climatology rules; it is for a fixed-level threshold",
           call. = FALSE)
    }
  }
  if (baseline$type == "detrended") {
    if (is.null(rules$detrend)) {
      stop(parity, " has no detrended baseline", call. = FALSE)
    }
    ## how this def fits the trend, and whether detection reads it
    baseline$fit <- switch(rules$detrend, anomalies = "anomalies", heatwave3 = "daily values")
    baseline$detection <- switch(rules$detrend, anomalies = "detrended", heatwave3 = "raw")
  }
  structure(list(
    name = name,
    slots = "366",
    reference = reference,
    baseline = if (fixed_level) list(type = "none") else
      c(unclass(baseline), window = as.integer(window), smooth = as.integer(smooth)),
    threshold = unclass(threshold),
    direction = direction,
    compare = compare,
    min_duration = as.integer(min_duration),
    max_gap = max_gap,
    order = order,
    season = if (is.null(season)) NULL else unclass(season),
    category = category,
    parity = parity,
    rules = rules
  ), class = "spell_def")
}

#' Threshold types
#'
#' * `threshold_percentile()`: the `p` quantile (type 7) of the reference
#'   period's values pooled in each slot's window, smoothed as the
#'   climatology is (Hobday et al. 2016's 90th percentile is `p = 0.9`;
#'   Schlegel et al. 2021's cold spells use 0.1).
#' * `threshold_value()`: a fixed level in the series' units, the same at
#'   every step (Massom et al. 2013's 15% ice concentration). Nothing is
#'   fitted: there's no baseline, so no reference period, and the
#'   anomalies and the intensities relative to a baseline are `NA`.
#'
#' @param p The quantile, between 0 and 1.
#' @param level The level.
#' @return A `spell_threshold_type`, for [spell_def()].
#' @export
#' @examples
#' threshold_percentile(0.9)
#' threshold_value(15)
threshold_percentile <- function(p = 0.9) {
  if (!is.numeric(p) || length(p) != 1L || is.na(p) || p <= 0 || p >= 1) {
    stop("`p` must be one number between 0 and 1", call. = FALSE)
  }
  structure(list(type = "percentile", p = p), class = "spell_threshold_type")
}

#' @rdname threshold_percentile
#' @export
threshold_value <- function(level) {
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level)) {
    stop("`level` must be one finite number", call. = FALSE)
  }
  structure(list(type = "value", level = level), class = "spell_threshold_type")
}

#' Season years
#'
#' A season year starts on the same day every year: 15 February for the
#' Antarctic ice year (Massom et al. 2013), 1 July for an austral year.
#' In a [spell_def()], detection never crosses a season boundary: a run
#' is cut there and each piece must reach the minimum on its own (as
#' ETCCDI's WSDI does by default), no gap is joined across it, and a
#' spell that touches it is cut by `"season"` ([spell_events()]).
#' [spell_summary()] gives one row per series and season.
#'
#' @param start The season's first day, `"MM-DD"` (not `"02-29"`).
#' @param label The season's label: `"start"`, the year it starts in
#'   (trend.ice's ice year), or `"end"`, the year it ends in.
#' @return A `spell_season`, for [spell_def()].
#' @export
#' @examples
#' season_year("02-15")                  # the ice year
#' season_year("07-01", label = "end")   # an austral year, by the year it ends
season_year <- function(start = "01-01", label = c("start", "end")) {
  label <- match.arg(label)
  ok <- is.character(start) && length(start) == 1L && grepl("^[0-9]{2}-[0-9]{2}$", start) &&
    !is.na(as.Date(paste0("2001-", start), format = "%Y-%m-%d"))
  if (!ok) stop("`start` must be a day of the year, \"MM-DD\", not 29 February", call. = FALSE)
  structure(list(start = start, label = label, cross = "cut"), class = "spell_season")
}

## Each step's season: the year it starts in, its label, and its first
## and last day.
season_steps <- function(time, season) {
  y <- as.integer(format(time, "%Y"))
  sy <- y - (format(time, "%m-%d") < season$start)
  first <- as.Date(paste0(sy, "-", season$start))
  last <- as.Date(paste0(sy + 1L, "-", season$start)) - 1L
  label <- if (season$label == "start" || season$start == "01-01") sy else sy + 1L
  list(year = sy, label = label, first = first, last = last)
}

#' Baseline types
#'
#' The baseline type is part of the def, and of every label made from it
#' (Smith et al. 2025 name five: fixed, detrended, shifting,
#' adaptation-adjusted and periodically updated).
#'
#' * `baseline_fixed()`: the climatology of the reference period, the
#'   same for every year.
#' * `baseline_detrended()`: a linear trend per series is fitted over the
#'   reference period and removed, keeping the level at the period's
#'   midpoint, and the climatology is fitted to the detrended series. The
#'   baseline at each step is that climatology plus the trend, extrapolated
#'   outside the reference period, so detection reads the detrended
#'   series (Jacox et al. 2020) and adding data never changes past
#'   spells. With the clean rules the trend is a least-squares fit with a
#'   mean per slot: it is fitted to the anomalies from each slot's own
#'   mean over the reference years, so the seasonal cycle can't leak into
#'   it and seasons covered unevenly across the years (gaps, ice) don't
#'   bias it. (A trend fitted to the daily values picks up the seasonal
#'   cycle: on heatwaveR's three OISST series, -0.04 to +0.10 degrees C
#'   per decade.) With `parity = "heatwave3-1.5.0"`
#'   it is heatwave3's `detrend = TRUE`: the trend fitted to the daily
#'   values, the climatology fitted to the detrended series, and
#'   detection on the series as it is. The heatwaveR modes have no
#'   detrended baseline.
#'
#' @return A `spell_baseline_type`.
#' @references Jacox, M. G. et al. (2020). Thermal displacement by marine
#'   heatwaves. Nature 584, 82-86. \doi{10.1038/s41586-020-2534-z}
#'
#'   Smith, K. E. et al. (2025). Baseline matters: challenges and
#'   implications of different marine heatwave baselines. Progress in
#'   Oceanography 231, 103404. \doi{10.1016/j.pocean.2024.103404}
#' @export
#' @examples
#' hobday2018(c("1982-01-01", "2011-12-31"), baseline = baseline_detrended())
baseline_fixed <- function() {
  structure(list(type = "fixed"), class = "spell_baseline_type")
}

#' @rdname baseline_fixed
#' @export
baseline_detrended <- function() {
  structure(list(type = "detrended", model = "linear", per = "series", period = "reference"),
            class = "spell_baseline_type")
}

#' Category rules
#'
#' Hobday et al. (2018) categories are multiples of the threshold's
#' distance from the baseline: I (1x) moderate, II (2x) strong, III (3x)
#' severe, IV (4x and above) extreme. Packages differ in how a step is
#' compared with the multiples and in what joined gap days get.
#'
#' @param compare `">="`: category k when the anomaly is at least k
#'   times the threshold's distance from the baseline, computed as the
#'   floor of their ratio (as trend.sst does). `">"`: when the value is
#'   above the k-th level, where level 1 is the threshold and each level
#'   adds the distance to the one below (heatwaveR's daily categories).
#' @param round Decimal places to round the distance, and each level as
#'   it is built, or `NULL` for none. heatwaveR rounds to 4.
#' @param gap_days The category of a step in a spell that is not beyond
#'   the threshold (a joined gap day, or a missing step counted as
#'   baseline): `"none"` (category 0), as heatwaveR, marineHeatWaves and
#'   xmhw do, or `"I"`, as trend.sst does. With `"none"`, a step exactly
#'   at the threshold gets none too, though the floor of its multiple is
#'   1, so only the steps beyond the threshold have a category
#'   (marineHeatWaves' formula gives such a step I).
#' @param event A spell's category, in [spell_events()]: `"max"`, the
#'   highest category of its steps; or `"share"`, the highest category
#'   whose share of the spell's steps, rounded to a whole percent, is
#'   above zero (heatwaveR's and heatwave3's event category). With
#'   `"share"`, a long spell with one step in a category can be given the
#'   category below.
#' @param event_compare For `event = "share"`: how each step is compared
#'   with the levels, `">="` (heatwaveR's `category()`, though its daily
#'   categories use `">"`) or `">"`.
#' @return A `spell_categories` rule.
#' @export
#' @examples
#' categories()                                         # spells' clean rule
#' categories(gap_days = "I")                           # trend.sst
#' categories(compare = ">", round = 4, gap_days = "none") # heatwaveR's daily categories
categories <- function(compare = c(">=", ">"), round = NULL, gap_days = c("none", "I"),
                       event = c("max", "share"), event_compare = c(">=", ">")) {
  compare <- match.arg(compare)
  gap_days <- match.arg(gap_days)
  event <- match.arg(event)
  event_compare <- match.arg(event_compare)
  if (!is.null(round)) round <- as.integer(round)
  structure(list(unit = "threshold", max = 4L, compare = compare, round = round,
                 gap_days = gap_days, event = event, event_compare = event_compare),
            class = "spell_categories")
}

## spells' clean rules, as the same switches the parity modes set. Each
## preset gives its own interpolation limit and coverage share.
clean_mode <- function(max_interp, coverage) {
  list(
    rules = list(
      window_ends = "shorten",     # only the reference period's own days
      feb29 = "omit",              # non-leap years have no slot 60
      round = NULL,                # nothing rounded
      reference_missing = "omit",  # a missing day drops out of the window
      detrend = "anomalies",       # a detrended baseline's trend: fitted to the anomalies
      coverage = coverage,         # share of the window's possible days a slot needs
      missing = "interpolate",     # runs of max_interp or fewer, between observed steps
      max_interp = as.integer(max_interp),
      leading_gap = FALSE,         # gaps joined only between two spells
      trailing_gap = FALSE,
      rate_neighbour = "observed"  # no rate across a step that can't be tested
    ),
    category = categories()
  )
}

## The parity modes. Each names an engine and version and lists the
## behaviours that differ from spells' clean rules, as switches the
## engine reads. Only implemented modes are listed here.
mhw_presets <- c("hobday2016", "hobday2018", "schlegel2021")
parity_registry <- list(
  "heatwaveR-0.5.5" = list(
    presets = mhw_presets,
    rules = list(
      window_ends = "wrap",     # the climatology window wraps within each year
      feb29 = "neighbours",     # non-leap years: slot 60 = round(mean(slot 59, 61), 2)
      round = 4L,               # seas and thresh rounded after smoothing
      reference_missing = "plug", # a missing cell gets its slot's mean across the years
      missing = "baseline",     # a missing step is set to the baseline: never beyond it
      leading_gap = FALSE,      # a gap before the first spell is not joined
      trailing_gap = TRUE,      # a gap of max_gap or fewer at the series end is joined
      rate_neighbour = "filled" # a rate's step outside the spell, if missing, is the baseline
    ),
    ## daily categories strict (">"); the event's by rounded share, at or above (">=")
    category = categories(compare = ">", round = 4L, gap_days = "none",
                          event = "share", event_compare = ">=")
  ),
  ## 1.0.0 (robwschlegel/heatwaveR @e0ae30d): the window runs on through
  ## the adjacent years at the new year, shorter at the reference ends
  ## (R/clim_spread.R), and the trailing gap isn't joined (R/proto_event.R)
  "heatwaveR-1.0.0" = list(
    presets = mhw_presets,
    rules = list(
      window_ends = "shorten",
      feb29 = "neighbours",
      round = 4L,
      reference_missing = "plug",
      missing = "baseline",
      leading_gap = FALSE,
      trailing_gap = FALSE,
      rate_neighbour = "filled"
    ),
    category = categories(compare = ">", round = 4L, gap_days = "none",
                          event = "share", event_compare = ">=")
  )
)
## heatwave3 1.5.0 (robwschlegel/heatwave3 @8aff3e5): heatwaveR 1.0.0's
## rules, except that a missing reference cell is left out of the window
## (src/climatology.cpp), and a rate of onset or decline whose step
## outside the spell is missing isn't given (src/event_detect.cpp). Its
## default maxPadLength interpolates nothing.
parity_registry[["heatwave3-1.5.0"]] <- parity_registry[["heatwaveR-1.0.0"]]
parity_registry[["heatwave3-1.5.0"]]$rules$reference_missing <- "omit"
parity_registry[["heatwave3-1.5.0"]]$rules$rate_neighbour <- "observed"
## detrend = TRUE: a trend fitted to the daily values over the
## climatology period, removed for the climatology only (src/climatology.cpp)
parity_registry[["heatwave3-1.5.0"]]$rules$detrend <- "heatwave3"
## trend.ice's R/ice_season.R (mdsumner/trend.ice; its rules unchanged
## since d5be6df, which made the published COGs): a missing day is not
## ice, so it counts as below the threshold and the season goes on
## across it. It reads each ice year on its own, and interpolates days
## missing from the whole field before that (read_ice_obs(),
## fill_daily()): that's reading the data, not the definition.
parity_registry[["trend.ice-d5be6df"]] <- list(
  presets = "massom2013",
  rules = list(
    missing = "below",          # a missing step counts as below the threshold, and isn't a cut
    leading_gap = FALSE,
    trailing_gap = FALSE,
    rate_neighbour = "observed"
  ),
  category = NULL
)
parity_planned <- character()

#' Parity modes
#'
#' The engines and versions spells can reproduce, and those planned.
#' @return A data frame with the mode's name and whether it is
#'   implemented.
#' @export
#' @examples
#' parity_modes()
parity_modes <- function() {
  data.frame(parity = c(names(parity_registry), parity_planned),
             implemented = c(rep(TRUE, length(parity_registry)),
                             rep(FALSE, length(parity_planned))),
             presets = c(vapply(parity_registry, function(m) paste(m$presets, collapse = ", "), ""),
                         rep(NA_character_, length(parity_planned))),
             row.names = NULL)
}

parity_mode <- function(parity) {
  if (!is.character(parity) || length(parity) != 1L) stop("`parity` must be one string")
  mode <- parity_registry[[parity]]
  if (is.null(mode)) {
    if (parity %in% parity_planned) stop("parity mode \"", parity, "\" isn't implemented yet", call. = FALSE)
    stop("unknown parity mode \"", parity, "\"; see parity_modes()", call. = FALSE)
  }
  mode
}

as_reference <- function(reference) {
  reference <- as.Date(reference)
  if (length(reference) != 2L || anyNA(reference) || reference[2] < reference[1]) {
    stop("`reference` must be two dates, first and last day", call. = FALSE)
  }
  if (format(reference[1], "%m-%d") != "01-01" || format(reference[2], "%m-%d") != "12-31") {
    stop("`reference` must be whole years, 1 January to 31 December", call. = FALSE)
  }
  reference
}

#' @export
print.spell_def <- function(x, ...) {
  cat("<spell_def>", x$name,
      if (is.null(x$parity)) "(clean rules)" else paste0("(parity ", x$parity, ")"), "\n")
  cat("  reference:", if (is.null(x$reference)) "none" else
        paste(format(x$reference[1]), "to", format(x$reference[2])), "\n")
  bl <- x$baseline
  th <- x$threshold
  cat("  baseline: ", if (bl$type == "none") "none" else c(bl$type,
      if (bl$type == "detrended") paste0("(linear per series, fitted to ", bl$fit,
                                         ", detection on the ", bl$detection, " series)"),
      "climatology, window", bl$window, "smooth", bl$smooth),
      "| threshold:", th$type, if (th$type == "value") th$level else th$p,
      paste0("(", x$compare, ")"), "|", x$direction, "\n")
  cat("  spells:    min_duration", x$min_duration, "max_gap", x$max_gap,
      paste0("(", x$order, ")"), "\n")
  r <- x$rules
  cat("  missing:  ",
      switch(r$missing, baseline = "counted as the baseline",
             below = "counted as below the threshold",
             interpolate = paste("runs of", r$max_interp, "or fewer interpolated, longer ones cut")),
      if (!is.null(r$coverage) && bl$type != "none") paste("| a slot needs", r$coverage, "of its window"),
      "\n")
  cg <- x$category
  if (is.null(cg)) {
    cat("  category:  none\n")
  } else {
    cat("  category:  compare", cg$compare, "round", if (is.null(cg$round)) "none" else cg$round,
        "gap days", cg$gap_days, "| event", cg$event,
        if (cg$event == "share") paste0("(", cg$event_compare, ")"), "\n")
  }
  if (!is.null(x$season)) {
    cat("  season:    from", x$season$start, "labelled by its", x$season$label,
        "year, detection cut at the boundary\n")
  }
  invisible(x)
}
