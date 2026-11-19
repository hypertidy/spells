## Detrended baselines. With parity = "heatwave3-1.5.0" it is heatwave3's
## detect3(detrend = TRUE): stored outputs for every case. The clean
## rule (a trend fitted to the anomalies, detection on the detrended
## series) has no engine, so it's tested by what it must do.

test_that("heatwave3 parity: detect3(detrend = TRUE)", {
  golden <- fixture("golden-heatwave3-1.5.0.rds")$detrend
  for (nm in names(cases)) {
    k <- cases[[nm]]
    r <- run_case(k, hobday2018(k$reference, parity = "heatwave3-1.5.0",
                                baseline = baseline_detrended()))
    expect_false(r$baseline$trend$applied)
    for (j in seq_len(ncol(k$x))) {
      g <- golden[[nm]][[j]]
      expect_equal(r$baseline$seas[g$clim$doy, j], g$clim$seas)
      expect_equal(r$baseline$thresh[g$clim$doy, j], g$clim$thresh)
      expect_identical(r$mask$event[, j], g$day$event)
      expect_identical(r$mask$category[, j], daily_category(g$day$category))
      ev <- r$events[r$events$series == j, ]
      expect_events(ev, g$events)
      expect_event_categories(ev, g$events)
    }
  }
})

test_that("heatwaveR has no detrended baseline", {
  expect_error(hobday2018(c("1982-01-01", "2011-12-31"), parity = "heatwaveR-0.5.5",
                          baseline = baseline_detrended()), "no detrended baseline")
  expect_error(hobday2018(c("1982-01-01", "2011-12-31"), baseline = "detrended"),
               "baseline_fixed")
})

seasonal <- function(seed, years = 2001:2010, slope = 0, amp = 4, sd = 0.4) {
  set.seed(seed)
  time <- seq(as.Date(paste0(min(years), "-01-01")), as.Date(paste0(max(years), "-12-31")), by = "day")
  t <- as.numeric(time)
  x <- 15 + amp * cos(2 * pi * (t - 40) / 365.25) + slope * (t - mean(t)) +
    as.numeric(stats::filter(stats::rnorm(length(t), sd = sd), 0.7, method = "recursive"))
  list(time = time, x = x, ref = as.Date(paste0(range(years), c("-01-01", "-12-31"))))
}

test_that("clean detrended: the trend is fitted to the anomalies", {
  ## a known trend comes back, and the seasonal cycle doesn't leak into it
  s <- seasonal(1, slope = 0.3 / 3652.5, sd = 0.1)
  b <- spell_baseline(s$x, s$time, hobday2018(s$ref, baseline = baseline_detrended()))
  expect_true(b$trend$applied)
  expect_identical(b$trend$centre, as.Date("2006-01-01") - 0.5)
  expect_equal(b$trend$slope * 3652.5, 0.3, tolerance = 0.1)
  ## no trend, but the cold seasons missing (ineligible) in the early
  ## years: fitted to the daily values (heatwave3) the slope is badly
  ## biased; fitted to the anomalies it isn't
  s0 <- seasonal(2, slope = 0)
  mon <- as.integer(format(s0$time, "%m"))
  early <- as.integer(format(s0$time, "%Y")) <= 2005
  el <- !(early & mon %in% c(1, 2, 3, 12))
  bc <- spell_baseline(s0$x, s0$time, hobday2018(s0$ref, baseline = baseline_detrended()),
                       eligible = el)
  bh <- spell_baseline(s0$x, s0$time, hobday2018(s0$ref, parity = "heatwave3-1.5.0",
                                                 baseline = baseline_detrended()), eligible = el)
  expect_lt(abs(bc$trend$slope * 3652.5), 0.1)
  expect_gt(abs(bh$trend$slope * 3652.5), 1)
})

test_that("clean detrended: detection reads the detrended series", {
  s <- seasonal(3, slope = 0.5 / 3652.5)
  def <- hobday2018(s$ref, baseline = baseline_detrended())
  b <- spell_baseline(s$x, s$time, def)
  ## the baseline at each step is the climatology plus the trend,
  ## extrapolated past the reference period
  late <- seq(as.Date("2011-01-01"), as.Date("2012-12-31"), by = "day")
  xl <- 15 + stats::rnorm(length(late))
  m <- spell_mask(xl, late, b)
  trend <- b$trend$slope * (as.numeric(late) - as.numeric(b$trend$centre))
  expect_equal(m$anom[, 1], xl - (b$seas[slot_366(late), 1] + trend))
  ## adding a trend to the series changes the fitted slope by it, and
  ## nothing else: the same climatology and the same spells
  add <- 0.8 / 3652.5 * (as.numeric(s$time) - as.numeric(b$trend$centre))
  b2 <- spell_baseline(s$x + add, s$time, def)
  expect_equal(b2$trend$slope - b$trend$slope, 0.8 / 3652.5)
  expect_equal(b2$seas, b$seas)
  expect_equal(b2$thresh, b$thresh)
  m1 <- spell_mask(s$x, s$time, b)
  m2 <- spell_mask(s$x + add, s$time, b2)
  expect_identical(m2$event, m1$event)
  expect_identical(m2$category, m1$category)
  ## a fixed baseline on the same warming series finds more heatwave
  ## days late in the record than early; the detrended one doesn't
  sw <- seasonal(4, years = 1991:2020, slope = 1 / 3652.5)
  mf <- spell_mask(sw$x, sw$time, spell_baseline(sw$x, sw$time, hobday2018(sw$ref)))
  md <- spell_mask(sw$x, sw$time, spell_baseline(sw$x, sw$time,
                                                 hobday2018(sw$ref, baseline = baseline_detrended())))
  first <- sw$time < as.Date("2001-01-01")
  last <- sw$time >= as.Date("2011-01-01")
  expect_gt(sum(mf$event[last, ]), 3 * sum(mf$event[first, ]))
  expect_lt(abs(sum(md$event[last, ]) - sum(md$event[first, ])),
            0.5 * max(sum(md$event[last, ]), sum(md$event[first, ])))
})

test_that("detrended defs print their trend", {
  def <- hobday2018(c("1982-01-01", "2011-12-31"), baseline = baseline_detrended())
  expect_match(capture.output(print(def))[3], "detrended \\(linear per series, fitted to anomalies")
  k <- cases$wa_tail1
  b <- spell_baseline(k$x, k$dates, hobday2018(k$reference, baseline = baseline_detrended()))
  expect_true(any(grepl("per decade, centred on 1996-12-31", capture.output(print(b)))))
})
