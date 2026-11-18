## Definitions: what a spell is, as an object.

#' Marine heatwaves, Hobday et al. (2016)
#'
#' The marine heatwave definition of Hobday et al. (2016): a climatology
#' from an 11-day window pooled over the reference years and smoothed by
#' a 31-day running mean, the 90th percentile as the threshold, at least
#' 5 days above it, and gaps of 2 days or fewer joined.
#'
#' Only the heatwaveR parity modes are implemented so far. The clean
#' rules (spells' own defaults) come once their open choices are settled;
#' until then `parity` must be given.
#'
#' @param reference The reference period: two dates, the first and last
#'   day. It must be whole years.
#' @param parity The engine and version whose behaviour to reproduce:
#'   `"heatwaveR-0.5.5"` or `"heatwaveR-1.0.0"`. See [parity_modes()].
#' @param category How each step in a spell gets its category, from
#'   [categories()]. The default is the parity mode's own rule.
#' @return A `spell_def`.
#' @references Hobday, A. J. et al. (2016). A hierarchical approach to
#'   defining marine heatwaves. Progress in Oceanography 141, 227-238.
#'   \doi{10.1016/j.pocean.2015.12.014}
#'
#'   Hobday, A. J. et al. (2018). Categorizing and naming marine
#'   heatwaves. Oceanography 31(2), 162-173. \doi{10.5670/oceanog.2018.205}
#' @export
#' @examples
#' hobday2016(c("1982-01-01", "2011-12-31"), parity = "heatwaveR-0.5.5")
hobday2016 <- function(reference, parity = NULL, category = NULL) {
  reference <- as_reference(reference)
  if (is.null(parity)) {
    stop("spells' clean rules aren't implemented yet; give a parity mode, ",
         "such as parity = \"heatwaveR-0.5.5\"", call. = FALSE)
  }
  mode <- parity_mode(parity)
  if (is.null(category)) category <- mode$category
  if (!inherits(category, "spell_categories")) stop("`category` must come from categories()")
  structure(list(
    name = "hobday2016",
    slots = "366",
    reference = reference,
    baseline = list(type = "climatology", window = 11L, smooth = 31L),
    threshold = list(type = "percentile", p = 0.9),
    direction = "high",
    min_duration = 5L,
    max_gap = 2L,
    order = "minimum_first",
    category = category,
    parity = parity,
    rules = mode$rules
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
#'   baseline): `"I"`, as trend.sst does, or `"none"` (category 0), as
#'   heatwaveR, marineHeatWaves and xmhw do.
#' @return A `spell_categories` rule.
#' @export
#' @examples
#' categories()                                         # trend.sst
#' categories(compare = ">", round = 4, gap_days = "none") # heatwaveR's daily categories
categories <- function(compare = c(">=", ">"), round = NULL, gap_days = c("I", "none")) {
  compare <- match.arg(compare)
  gap_days <- match.arg(gap_days)
  if (!is.null(round)) round <- as.integer(round)
  structure(list(unit = "threshold", max = 4L, compare = compare, round = round,
                 gap_days = gap_days), class = "spell_categories")
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
      reference_missing = "stop", # R/mhw.R stops; heatwaveR fills from the slot's mean
      missing = "baseline",     # a missing step is set to the baseline: never beyond it
      leading_gap = FALSE,      # a gap before the first spell is not joined
      trailing_gap = TRUE       # a gap of max_gap or fewer at the series end is joined
    ),
    category = categories(compare = ">", round = 4L, gap_days = "none")
  ),
  ## 1.0.0 (robwschlegel/heatwaveR @e0ae30d): the window runs on through
  ## the adjacent years at the new year, shorter at the reference ends
  ## (R/clim_spread.R), and the trailing gap isn't joined (R/proto_event.R)
  "heatwaveR-1.0.0" = list(
    rules = list(
      window_ends = "shorten",
      feb29 = "neighbours",
      round = 4L,
      reference_missing = "stop",
      missing = "baseline",
      leading_gap = FALSE,
      trailing_gap = FALSE
    ),
    category = categories(compare = ">", round = 4L, gap_days = "none")
  )
)
parity_planned <- c("heatwave3-1.5.0")

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
  cat("<spell_def>", x$name, if (!is.null(x$parity)) paste0("(parity ", x$parity, ")"), "\n")
  cat("  reference:", format(x$reference[1]), "to", format(x$reference[2]), "\n")
  cat("  baseline: ", x$baseline$type, "window", x$baseline$window, "smooth", x$baseline$smooth,
      "| threshold:", x$threshold$type, x$threshold$p, "|", x$direction, "\n")
  cat("  spells:    min_duration", x$min_duration, "max_gap", x$max_gap,
      paste0("(", x$order, ")"), "\n")
  cg <- x$category
  cat("  category:  compare", cg$compare, "round", if (is.null(cg$round)) "none" else cg$round,
      "gap days", cg$gap_days, "\n")
  invisible(x)
}
