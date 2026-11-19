## Comparing spells' results with the engines' stored outputs, under
## spells' column names (test-parity.R, test-eligible.R).
codes <- c("I Moderate" = 1L, "II Strong" = 2L, "III Severe" = 3L, "IV Extreme" = 4L)
daily_category <- function(x) {
  out <- if (is.character(x)) unname(codes[x]) else as.integer(x)
  out[is.na(out)] <- 0L
  out
}
## engine column -> spells column
event_cols <- c(date_start = "start", date_peak = "peak", date_end = "end",
                index_start = "index_start", index_peak = "index_peak", index_end = "index_end",
                duration = "duration",
                setNames(paste0("intensity_", rep(c("mean", "max", "sd", "cumulative"), 3),
                                rep(c("", "_thresh", "_abs"), each = 4)),
                         paste0("intensity_", rep(c("mean", "max", "var", "cumulative"), 3),
                                rep(c("", "_relThresh", "_abs"), each = 4))),
                rate_onset = "rate_onset", rate_decline = "rate_decline")
expect_events <- function(ev, g) {
  g <- g[!is.na(g$event_no), , drop = FALSE]
  expect_identical(ev$spell, g$event_no)
  for (nm in intersect(names(event_cols), names(g))) {
    expect_equal(as.numeric(ev[[event_cols[[nm]]]]), as.numeric(g[[nm]]), label = event_cols[[nm]])
  }
}
## the event's category, and its share of steps in each (heatwaveR's category())
expect_event_categories <- function(ev, g) {
  g <- g[match(ev$spell, g$event_no), ]
  expect_identical(ev$category, unname(codes[g$category]))
  n <- c(p_moderate = "n_moderate", p_strong = "n_strong", p_severe = "n_severe", p_extreme = "n_extreme")
  for (nm in names(n)) expect_equal(round(ev[[n[[nm]]]] / ev$duration * 100, 0), g[[nm]], label = nm)
}

