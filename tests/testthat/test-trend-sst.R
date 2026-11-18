## trend.sst's R/mhw.R, stored: what trend.sst publishes today. It uses
## the heatwaveR 0.5.5 parity mode with its own category rule (the floor
## of the ratio, joined gap days in category I), so moving onto spells
## changes none of it.
golden <- fixture("golden-trend.sst.rds")

for (nm in names(cases)) {
  test_that(paste0("trend.sst R/mhw.R, ", nm), {
    k <- cases[[nm]]
    g <- golden$cases[[nm]]
    skip_if(is.null(g), "R/mhw.R stops on a gap in the reference period")
    def <- hobday2016(k$reference, parity = "heatwaveR-0.5.5", category = categories(gap_days = "I"))
    r <- run_case(k, def)
    expect_identical(r$baseline$seas, g$seas)
    expect_identical(r$baseline$thresh, g$thresh)
    expect_equal(as.numeric(r$t), as.numeric(g$t))
    expect_identical(r$mask$event, g$event)
    expect_identical(unname(r$mask$category), unname(g$category))
  })
}
