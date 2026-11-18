## spells with parity = "heatwaveR-<version>" against that version's own
## ts2clm(), detect_event() and category(climatology = TRUE), stored.
codes <- c("I Moderate" = 1L, "II Strong" = 2L, "III Severe" = 3L, "IV Extreme" = 4L)

for (version in c("0.5.5", "1.0.0")) {
  golden <- fixture(paste0("golden-heatwaveR-", version, ".rds"))
  parity <- paste0("heatwaveR-", version)
  for (nm in names(cases)) {
    test_that(paste0(parity, " parity, ", nm, ": ", cases[[nm]]$note), {
      k <- cases[[nm]]
      r <- run_case(k, hobday2016(k$reference, parity = parity))
      for (j in seq_len(ncol(k$x))) {
        g <- golden$cases[[nm]][[j]]
        expect_equal(r$baseline$seas[g$clim$doy, j], g$clim$seas)
        expect_equal(r$baseline$thresh[g$clim$doy, j], g$clim$thresh)
        expect_equal(as.numeric(r$t), as.numeric(g$day$t))
        expect_identical(r$mask$event[, j], g$day$event)
        want <- unname(codes[g$day$category]); want[is.na(want)] <- 0L
        expect_identical(r$mask$category[, j], want)
      }
    })
  }
}
