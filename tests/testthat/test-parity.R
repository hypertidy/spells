## spells' parity modes against the stored outputs of the version each
## names: heatwaveR's ts2clm(), detect_event() and category(climatology =
## TRUE), and heatwave3's detect3() / detect_event3() with daily output,
## for heatwaves (hobday2018()) and cold spells (schlegel2021(); the
## engines' coldSpells with the 10th percentile).
## The event tables are compared column by column, under spells' names.
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
