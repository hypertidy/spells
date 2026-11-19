## The sea ice season (Massom et al. 2013): generality gate 1. The oracle
## is trend.ice's published ice season COGs: a stored subset of 230
## pixels in three ice years (data-raw/massom2013.R, which checks every
## pixel of every published year), and trend.ice's own hand-built cases
## (its tests/test_ice_season.R).

## trend.ice's seven layers from the season summaries
massom_layers <- function(s) {
  day <- function(d) as.integer(d - s$season_start) + 1L
  data_cut <- function(by) !is.na(by) & !by %in% c("series", "season")
  advance <- day(s$first_start)
  advance[data_cut(s$first_start_cut_by)] <- NA
  retreat <- day(s$last_end) + 1L
  retreat[!is.na(s$last_end_cut_by)] <- NA
  data.frame(advance = advance, retreat = retreat, duration = retreat - advance,
             daycount = s$n_beyond, ice_at_start = as.integer(s$beyond_first),
             ice_at_end = as.integer(s$beyond_last), n_missing = s$n_missing)
}
run_massom <- function(x, time, def) {
  b <- spell_baseline(x, time, def)
  spell_summary(x, time, b, spell_mask(x, time, b))
}
ice_year <- seq(as.Date("2001-02-15"), as.Date("2002-02-14"), by = "day")
mk <- function(on, n = 365) { v <- rep(0, n); v[on] <- 80; v }

test_that("massom2013: trend.ice's own cases", {
  m <- cbind(a = mk(100:250),                 # a simple season
             b = mk(c(50:52, 100:250)),       # a short blip before: advance still 100
             c = mk(c(100:250, 300:302)),     # a late short blip: retreat 303
             d = mk(1:365),                   # perennial: advance 1, no retreat
             e = mk(integer(0)),              # open water
             f = rep(NA_real_, 365),          # land
             g = mk(c(1:30, 200:365)),        # ice at the start and the end
             h = mk(c(40, 41, 200)))          # isolated ice days: no season
  for (parity in list(NULL, "trend.ice-d5be6df")) {
    l <- massom_layers(run_massom(m, ice_year, massom2013(parity = parity)))
    expect_identical(l$advance, c(100L, 100L, 100L, 1L, NA, NA, 1L, NA))
    expect_identical(l$retreat, c(251L, 251L, 303L, NA, NA, NA, NA, NA))
    expect_identical(l$daycount, c(151L, 154L, 154L, 365L, 0L, NA, 196L, 3L))
    expect_identical(l$ice_at_start, c(0L, 0L, 0L, 1L, 0L, NA, 1L, 0L))
    expect_identical(l$ice_at_end, c(0L, 0L, 0L, 1L, 0L, NA, 1L, 0L))
  }
})

test_that("massom2013 parity reproduces trend.ice's published COGs", {
  fx <- fixture("massom2013.rds")
  for (y in names(fx$years)) {
    k <- fx$years[[y]]
    l <- massom_layers(run_massom(k$x, k$dates, massom2013(parity = "trend.ice-d5be6df")))
    expect_identical(l, k$layers[names(l)], label = y)
  }
  ## the subset has what it was picked for
  k82 <- fx$years[["1982"]]
  expect_true(any(k82$layers$n_missing > 0, na.rm = TRUE))
  expect_true(all(is.na(k82$layers$advance[fx$meta$strata$land])))
  ## 1984 has 13 empty days (12 to 24 August), which the published file
  ## reads as open water; the clean rules can't test them, so pixels that
  ## advance just after them have no advance
  k84 <- fx$years[["1984"]]
  empty <- which(rowSums(!is.na(k84$x)) == 0)
  expect_identical(format(range(k84$dates[empty])), c("1984-08-12", "1984-08-24"))
  cl <- massom_layers(run_massom(k84$x, k84$dates, massom2013()))
  expect_gt(sum(is.na(cl$advance) & !is.na(k84$layers$advance)), 0L)
  ## every published year, every pixel (recorded by data-raw/massom2013.R)
  expect_identical(sum(fx$gate$parity_identical, na.rm = TRUE), sum(fx$gate$published))
})

test_that("spell_runs: the opening run", {
  x <- c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, TRUE)
  ## the first run of 3 opens the spell, which joins every gap after it
  expect_identical(which(spell_runs(x, 3L, Inf, order = "first_run")), 4:12)
  ## a gap of 3 closes it if only 2 are joined, and nothing after opens another
  expect_identical(which(spell_runs(x, 3L, 2L, order = "first_run")), 4:6)
  expect_identical(which(spell_runs(x, 3L, 3L, order = "first_run")), 4:12)
  ## minimum first needs every joined run to reach the minimum
  expect_identical(which(spell_runs(x, 3L, 3L)), 4:6)
  ## a season boundary at step 8: the first season's spell can't run on
  ## into the second, whose runs are too short to open one
  brk <- seq_along(x) %in% c(1L, 8L)
  expect_identical(which(spell_runs(x, 3L, Inf, order = "first_run", breaks = brk)), 4:6)
  ## a run across the boundary is cut, and each piece must reach the minimum
  y <- rep(c(FALSE, TRUE, FALSE), c(4, 6, 4))
  expect_identical(which(spell_runs(y, 5L, 2L, breaks = seq_along(y) %in% c(1L, 8L))), integer())
  expect_identical(which(spell_runs(y, 3L, 2L, breaks = seq_along(y) %in% c(1L, 8L))), 5:10)
})

test_that("seasons: detection is cut at the boundary", {
  time <- seq(as.Date("2001-02-15"), as.Date("2003-02-14"), by = "day")
  n <- length(time)
  ## ice right across 15 February 2002, and perennial ice
  b15 <- which(time == as.Date("2002-02-15"))
  x <- cbind(across = mk((b15 - 10):(b15 + 9), n), short = mk((b15 - 3):(b15 + 2), n),
             perennial = mk(seq_len(n), n))
  def <- massom2013()
  b <- spell_baseline(x, time, def)
  m <- spell_mask(x, time, b)
  ev <- spell_events(x, time, b, m)
  ## each piece of 10 is a spell, cut by the season; 3 + 3 is neither
  a <- ev[ev$series == 1L, ]
  expect_identical(a$season, c(2001L, 2002L))
  expect_identical(a$duration, c(10L, 10L))
  expect_identical(a$cut_end_by, c("season", NA))
  expect_identical(a$cut_start_by, c(NA, "season"))
  expect_false(any(ev$series == 2L))
  s <- spell_summary(x, time, b, m)
  expect_identical(s$season, rep(c(2001L, 2002L), each = 3))
  expect_identical(s$season_start, rep(as.Date(c("2001-02-15", "2002-02-15")), each = 3))
  p <- massom_layers(s[s$series == 3L, ])
  expect_identical(p$advance, c(1L, 1L))
  expect_identical(p$retreat, c(NA_integer_, NA_integer_))
  expect_identical(s$first_start_cut_by[s$series == 3L], c("series", "season"))
  expect_identical(s$last_end_cut_by[s$series == 3L], c("season", "series"))
  ## labels, and an incomplete season at the series' ends
  expect_identical(season_steps(as.Date(c("2001-02-14", "2001-02-15")), season_year("02-15"))$label,
                   c(2000L, 2001L))
  expect_identical(season_steps(as.Date("2001-02-15"), season_year("02-15", "end"))$label, 2002L)
  part <- spell_summary(x[1:100, ], time[1:100], b, spell_mask(x[1:100, ], time[1:100], b))
  expect_false(any(part$complete))
  expect_error(season_year("02-29"), "not 29 February")
})

test_that("seasons: no rate across the boundary", {
  ## a flat baseline 0 and threshold 1, seasons from 1 July
  def <- spell_def("flat", c("2001-01-01", "2001-12-31"), min_duration = 3L,
                   season = season_year("07-01"))
  b <- structure(list(def = def, seas = matrix(0, 366, 1), thresh = matrix(1, 366, 1)),
                 class = "spell_baseline")
  time <- seq(as.Date("2001-06-01"), as.Date("2001-07-31"), by = "day")
  x <- rep(0, length(time))
  x[time >= as.Date("2001-06-26") & time <= as.Date("2001-07-05")] <- 2   # across 1 July
  x[time >= as.Date("2001-07-15") & time <= as.Date("2001-07-20")] <- 2
  ev <- spell_events(x, time, b, spell_mask(x, time, b))
  expect_identical(format(ev$start), c("2001-06-26", "2001-07-01", "2001-07-15"))
  expect_identical(ev$season, c(2000L, 2001L, 2001L))
  expect_identical(is.na(ev$rate_decline), c(TRUE, FALSE, FALSE))
  expect_identical(is.na(ev$rate_onset), c(FALSE, TRUE, FALSE))
})

test_that("a fixed level, at or beyond it", {
  x <- c(rep(10, 5), rep(15, 6), rep(10, 5))
  time <- seq(as.Date("2001-03-01"), by = "day", length.out = 16)
  at <- spell_def("at", threshold = threshold_value(15), compare = ">=", max_gap = 0)
  above <- spell_def("above", threshold = threshold_value(15), max_gap = 0)
  run <- function(def) spell_mask(x, time, spell_baseline(x, time, def))$event[, 1]
  expect_identical(which(run(at)), 6:11)
  expect_false(any(run(above)))
  ## no baseline: no reference period, no anomaly, no categories
  b <- spell_baseline(x, time, at)
  expect_true(all(is.na(b$seas)) && all(b$thresh == 15))
  m <- spell_mask(x, time, b)
  expect_true(all(is.na(m$anom)))
  ev <- spell_events(x, time, b, m)
  expect_identical(ev$intensity_max_abs, 15)
  expect_identical(ev$intensity_max_thresh, 0)
  expect_true(is.na(ev$intensity_max) && is.na(ev$rate_onset))
  expect_error(spell_def("x", threshold = threshold_value(15), category = categories()), "need a baseline")
  expect_error(spell_def("x", threshold = threshold_value(15), baseline = baseline_detrended()),
               "no baseline")
  expect_error(spell_def("x"), "needs a `reference`")
  expect_error(threshold_percentile(1.2))
})

test_that("massom2013: missing days, clean and trend.ice", {
  x <- mk(100:250)
  gap <- function(at) { v <- x; v[at] <- NA; v }
  m <- cbind(inside = gap(150:152), before = gap(94:99), after = gap(251:256), long = gap(150:160))
  clean <- run_massom(m, ice_year, massom2013())
  lc <- massom_layers(clean)
  ## 3 days inside are interpolated; 6 just before the advance, or just
  ## after the last ice day, can't be tested: no advance, or no retreat
  expect_identical(lc$advance, c(100L, NA, 100L, 100L))
  expect_identical(lc$retreat, c(251L, 251L, NA, 251L))
  expect_identical(clean$first_start_cut_by, c(NA, "missing", NA, NA))
  ## 11 inside cut the spell in two; the season goes on
  expect_identical(clean$n_spells, c(1L, 1L, 1L, 2L))
  expect_identical(lc$daycount, c(151L, 151L, 151L, 140L))
  expect_identical(lc$n_missing, c(3L, 6L, 6L, 11L))
  ## trend.ice: a missing day is not ice, and the season goes on across it
  lt <- massom_layers(run_massom(m, ice_year, massom2013(parity = "trend.ice-d5be6df")))
  expect_identical(lt$advance, rep(100L, 4))
  expect_identical(lt$retreat, rep(251L, 4))
  expect_identical(lt$daycount, c(148L, 151L, 151L, 140L))
})

test_that("definitions: the ice preset, spell_def() and parity modes", {
  def <- massom2013()
  expect_null(def$reference)
  expect_identical(def$threshold, list(type = "value", level = 15))
  expect_identical(def$compare, ">=")
  expect_identical(def$max_gap, Inf)
  expect_identical(def$order, "first_run")
  expect_identical(def$rules$max_interp, 5L)
  out <- capture.output(print(def))
  expect_match(out[3], "threshold: value 15 \\(>=\\)")
  expect_match(out[7], "season:    from 02-15")
  expect_identical(massom2013(parity = "trend.ice-d5be6df")$rules$missing, "below")
  expect_error(hobday2016(c("1982-01-01", "2011-12-31"), parity = "trend.ice-d5be6df"),
               "isn't for hobday2016")
  expect_error(massom2013(parity = "heatwaveR-0.5.5"), "isn't for massom2013")
  expect_error(spell_def("x", c("1982-01-01", "2011-12-31"), parity = "trend.ice-d5be6df"),
               "no climatology rules")
  pm <- parity_modes()
  expect_identical(pm$presets[pm$parity == "trend.ice-d5be6df"], "massom2013")
  expect_error(spell_def("x", threshold = threshold_value(1), max_gap = -1), "max_gap")
  expect_error(spell_def("x", threshold = threshold_value(1), season = "02-15"), "season_year")
  ## a def with no season summarises the whole series
  k <- cases$oisst3
  r <- run_case(k, hobday2016(k$reference))
  keep <- k$dates %in% r$t
  s <- spell_summary(k$x[keep, , drop = FALSE], r$t, r$baseline, r$mask)
  expect_identical(nrow(s), ncol(k$x))
  expect_true(all(is.na(s$season)))
  expect_identical(s$n_spells, as.integer(table(factor(r$events$series, seq_len(ncol(k$x))))))
  expect_identical(s$first_start, r$events$start[!duplicated(r$events$series)])
  expect_identical(s$last_end, r$events$end[!duplicated(r$events$series, fromLast = TRUE)])
  expect_identical(s$n_event, as.integer(colSums(r$mask$event)))
})
