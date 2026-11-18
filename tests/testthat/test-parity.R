## spells' parity modes against the stored outputs of the version each
## names: heatwaveR's ts2clm(), detect_event() and category(climatology =
## TRUE), and heatwave3's detect3() / detect_event3() with daily output,
## for heatwaves (hobday2018()) and cold spells (schlegel2021(); the
## engines' coldSpells with the 10th percentile).
## The event tables are compared column by column, under spells' names.
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

presets <- list(heatwaves = list(def = hobday2018, golden = "cases"),
                cold_spells = list(def = schlegel2021, golden = "cold"))
for (parity in c("heatwaveR-0.5.5", "heatwaveR-1.0.0", "heatwave3-1.5.0")) {
  golden <- fixture(paste0("golden-", parity, ".rds"))
  for (kind in names(presets)) for (nm in names(cases)) {
    test_that(paste0(parity, " parity, ", kind, ", ", nm, ": ", cases[[nm]]$note), {
      k <- cases[[nm]]
      r <- run_case(k, presets[[kind]]$def(k$reference, parity = parity))
      for (j in seq_len(ncol(k$x))) {
        g <- golden[[presets[[kind]]$golden]][[nm]][[j]]
        expect_equal(r$baseline$seas[g$clim$doy, j], g$clim$seas)
        expect_equal(r$baseline$thresh[g$clim$doy, j], g$clim$thresh)
        expect_equal(as.numeric(r$t), as.numeric(g$day$t))
        expect_identical(r$mask$event[, j], g$day$event)
        expect_identical(r$mask$category[, j], daily_category(g$day$category))
        ev <- r$events[r$events$series == j, ]
        expect_events(ev, g$events)
        ## heatwaveR's from category(), heatwave3's in its event table
        expect_event_categories(ev, if (!is.null(g$categories)) g$categories else g$events)
      }
    })
  }
}
