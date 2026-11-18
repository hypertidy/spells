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
#' @param category How each step in a spell gets its category, from
#'   [categories()]. The default is the clean rule, or the parity mode's
#'   own.
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
#' schlegel2021(ref)
NULL

#' @rdname presets
#' @export
hobday2016 <- function(reference, parity = NULL) {
  mode <- rule_mode(parity)
  spell_def("hobday2016", reference, mode$rules, parity = parity)
}

#' @rdname presets
#' @export
hobday2018 <- function(reference, parity = NULL, category = NULL) {
  mode <- rule_mode(parity)
  spell_def("hobday2018", reference, mode$rules, parity = parity,
            category = if (is.null(category)) mode$category else category)
}

#' @rdname presets
#' @export
schlegel2021 <- function(reference, parity = NULL, category = NULL) {
  mode <- rule_mode(parity)
  spell_def("schlegel2021", reference, mode$rules, parity = parity,
            category = if (is.null(category)) mode$category else category,
            direction = "low", p = 0.1)
}

## The clean rules (each preset's interpolation limit and coverage share;
## all three use 3 steps and half), or a parity mode's.
rule_mode <- function(parity) {
  if (is.null(parity)) clean_mode(max_interp = 3L, coverage = 0.5) else parity_mode(parity)
}

## The general definition the presets fill in. Internal until generality
## gate 1 (the ice season) shows what's general.
spell_def <- function(name, reference, rules, parity = NULL, category = NULL,
                      direction = c("high", "low"), p = 0.9, window = 11L, smooth = 31L,
                      min_duration = 5L, max_gap = 2L) {
  direction <- match.arg(direction)
  if (!is.null(category) && !inherits(category, "spell_categories")) {
    stop("`category` must come from categories()", call. = FALSE)
  }
  structure(list(
    name = name,
    slots = "366",
    reference = as_reference(reference),
    baseline = list(type = "climatology", window = as.integer(window), smooth = as.integer(smooth)),
    threshold = list(type = "percentile", p = p),
    direction = direction,
    min_duration = as.integer(min_duration),
    max_gap = as.integer(max_gap),
    order = "minimum_first",
    category = category,
    parity = parity,
    rules = rules
  ), class = "spell_def")
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
parity_registry <- list(
  "heatwaveR-0.5.5" = list(
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
                             rep(FALSE, length(parity_planned))))
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
  cat("  reference:", format(x$reference[1]), "to", format(x$reference[2]), "\n")
  cat("  baseline: ", x$baseline$type, "window", x$baseline$window, "smooth", x$baseline$smooth,
      "| threshold:", x$threshold$type, x$threshold$p, "|", x$direction, "\n")
  cat("  spells:    min_duration", x$min_duration, "max_gap", x$max_gap,
      paste0("(", x$order, ")"), "\n")
  r <- x$rules
  cat("  missing:  ",
      switch(r$missing, baseline = "counted as the baseline",
             interpolate = paste("runs of", r$max_interp, "or fewer interpolated, longer ones cut")),
      if (!is.null(r$coverage)) paste("| a slot needs", r$coverage, "of its window"), "\n")
  cg <- x$category
  if (is.null(cg)) {
    cat("  category:  none\n")
  } else {
    cat("  category:  compare", cg$compare, "round", if (is.null(cg$round)) "none" else cg$round,
        "gap days", cg$gap_days, "| event", cg$event,
        if (cg$event == "share") paste0("(", cg$event_compare, ")"), "\n")
  }
  invisible(x)
}
