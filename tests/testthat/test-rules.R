test_that("slot_366 gives 29 February its own slot", {
  d <- as.Date(c("2015-01-01", "2015-02-28", "2015-03-01", "2015-12-31",
                 "2016-02-28", "2016-02-29", "2016-03-01", "2016-12-31",
                 "1900-03-01", "2000-03-01"))
  expect_identical(slot_366(d), c(1L, 59L, 61L, 366L, 59L, 60L, 61L, 366L, 61L, 61L))
})

test_that("spell_runs: minimum first, then gaps between spells joined", {
  x <- c(F, T, T, T, T, T, F, F, T, T, T, T, T, F, F, F, T, T, T, T, T)
  ev <- spell_runs(x, 5L, 2L)
  expect_identical(ev, c(F, rep(T, 12), F, F, F, rep(T, 5)))
  ## minimum first: a run too short to be a spell doesn't bridge, so the
  ## gap between the two spells is 4 steps and isn't joined
  y <- c(rep(T, 5), F, T, T, F, rep(T, 5))
  expect_identical(spell_runs(y, 5L, 2L), c(rep(T, 5), F, F, F, F, rep(T, 5)))
})

test_that("spell_runs: leading and trailing gaps", {
  x <- c(F, F, rep(T, 5), F, F)
  expect_identical(spell_runs(x, 5L, 2L), c(F, F, rep(T, 5), F, F))
  expect_identical(spell_runs(x, 5L, 2L, trailing_gap = TRUE), c(F, F, rep(T, 7)))
  expect_identical(spell_runs(x, 5L, 2L, leading_gap = TRUE), c(rep(T, 7), F, F))
  expect_identical(spell_runs(c(F, F, F), 5L, 2L), c(F, F, F))
})

test_that("category rules", {
  seas <- matrix(0, 6, 1); thresh <- matrix(1, 6, 1)
  x <- matrix(c(0.5, 1, 1.5, 2, 3.2, 9), 6, 1)
  ev <- matrix(TRUE, 6, 1)
  ## trend.sst: the floor of the multiple, gap days in I
  tsst <- categories(gap_days = "I")
  expect_identical(step_category(x, seas, thresh, ev, tsst)[, 1], c(1L, 1L, 1L, 2L, 3L, 4L))
  ## clean: the same floor, and no category for a step that isn't beyond
  ## the threshold, even at it
  expect_identical(step_category(x, seas, thresh, ev, categories())[, 1], c(0L, 0L, 1L, 2L, 3L, 4L))
  expect_identical(step_category(x, seas, thresh, ev, categories(">", 4, "none"))[, 1],
                   c(0L, 0L, 1L, 1L, 3L, 4L))
  ev[2] <- FALSE
  expect_identical(step_category(x, seas, thresh, ev, tsst)[2, 1], 0L)
})

test_that("definitions: clean by default, parity by name", {
  ref <- c("1982-01-01", "2011-12-31")
  expect_s3_class(hobday2016(ref), "spell_def")
  expect_null(hobday2016(ref)$parity)
  expect_error(hobday2016(ref, parity = "heatwaveR-9"), "unknown parity mode")
  expect_error(hobday2016(c("1982-02-01", "2011-12-31"), parity = "heatwaveR-0.5.5"), "whole years")
  expect_s3_class(hobday2016(ref, parity = "heatwaveR-0.5.5"), "spell_def")
  sc <- schlegel2021(ref)
  expect_identical(sc$direction, "low")
  expect_identical(sc$threshold$p, 0.1)
  expect_s3_class(sc$category, "spell_categories")
  expect_null(hobday2016(ref)$category)
  expect_identical(hobday2018(ref, parity = "heatwave3-1.5.0")$category$event, "share")
  pm <- parity_modes()
  expect_identical(pm$parity[pm$implemented],
                   c("heatwaveR-0.5.5", "heatwaveR-1.0.0", "heatwave3-1.5.0", "trend.ice-d5be6df"))
})

test_that("inputs are checked", {
  k <- cases$wa_tail1
  def <- hobday2016(k$reference, parity = "heatwaveR-0.5.5")
  expect_error(spell_baseline(k$x, k$dates[-1], def), "steps")
  expect_error(spell_baseline(k$x[-5, ], k$dates[-5], def), "consecutive")
  late <- k$dates >= as.Date("1990-01-01")
  expect_error(spell_baseline(k$x[late, ], k$dates[late], def), "reference period")
  b <- spell_baseline(k$x, k$dates, def)
  expect_error(spell_mask(cbind(k$x, k$x), k$dates, b), "series")
})

test_that("spell_events: edges, step counts and the empty case", {
  ## a flat baseline 0, threshold 1: spells at both ends of the series,
  ## one with a joined gap and a missing step
  def <- hobday2016(c("2001-01-01", "2001-12-31"), parity = "heatwaveR-1.0.0")
  time <- seq(as.Date("2001-01-01"), by = "day", length.out = 365)
  b <- structure(list(def = def, seas = matrix(0, 366, 1), thresh = matrix(1, 366, 1)),
                 class = "spell_baseline")
  x <- rep(0, 365)
  x[1:6] <- c(3, 2, 2, 2, 2, 2)                 # from the first step
  x[100:112] <- c(2, 2, 4, 2, 2, 0.5, NA, 2, 2, 2, 2, 2, 2)   # a 2-step gap, one missing
  x[361:365] <- 2                               # to the last step
  m <- spell_mask(x, time, b)
  ev <- spell_events(x, time, b, m)
  expect_identical(nrow(ev), 3L)
  expect_identical(ev$duration, c(6L, 13L, 5L))
  expect_identical(ev$n_beyond, c(6L, 11L, 5L))
  expect_identical(ev$n_missing, c(0L, 1L, 0L))
  expect_identical(ev$cut_start, c(TRUE, FALSE, FALSE))
  expect_identical(ev$cut_end, c(FALSE, FALSE, TRUE))
  expect_identical(ev$index_peak, c(1L, 102L, 361L))
  ## no rate on a side cut by the series' end
  expect_true(is.na(ev$rate_onset[1]) && !is.na(ev$rate_decline[1]))
  expect_true(!is.na(ev$rate_onset[3]) && is.na(ev$rate_decline[3]))
  ## onset from the midpoint of the step before and the first step
  expect_equal(ev$rate_onset[2], round((4 - 0.5 * (2 + 0)) / (2 + 0.5), 4))
  expect_equal(ev$intensity_cumulative[2], sum(c(2, 2, 4, 2, 2, 0.5, 0, 2, 2, 2, 2, 2, 2)))
  ## a missing step outside the spell: heatwaveR counts it as the
  ## baseline, heatwave3 gives no rate
  x2 <- x; x2[99] <- NA
  expect_false(is.na(spell_events(x2, time, b, spell_mask(x2, time, b))$rate_onset[2]))
  b3 <- b; b3$def <- hobday2016(def$reference, parity = "heatwave3-1.5.0")
  expect_true(is.na(spell_events(x2, time, b3, spell_mask(x2, time, b3))$rate_onset[2]))
  ## no spells: no rows, the same columns
  z <- spell_events(rep(0, 365), time, b, spell_mask(rep(0, 365), time, b))
  expect_identical(nrow(z), 0L)
  expect_identical(names(z), names(ev))
  expect_error(spell_events(x[-1], time[-1], b, m), "spell_mask")
})

test_that("event category rules", {
  def <- hobday2018(c("2001-01-01", "2001-12-31"), parity = "heatwaveR-1.0.0")
  time <- seq(as.Date("2001-01-01"), by = "day", length.out = 365)
  b <- structure(list(def = def, seas = matrix(0, 366, 1), thresh = matrix(1, 366, 1)),
                 class = "spell_baseline")
  x <- rep(0, 365)
  x[10:259] <- 1.5; x[100] <- 4.5               # 250 steps in I, one in IV
  x[300:309] <- 1.5; x[305] <- 2                # one step exactly on the II level
  m <- spell_mask(x, time, b)
  ev <- spell_events(x, time, b, m)
  ## heatwaveR: the highest category whose rounded share is above zero,
  ## counting steps at or above each level
  expect_identical(ev$category, c(1L, 2L))
  expect_identical(ev$n_extreme, c(1L, 0L))
  expect_identical(ev$n_strong, c(0L, 1L))
  ## the highest daily category
  b$def$category <- categories(">", 4, "none", event = "max")
  ev <- spell_events(x, time, b, m)
  expect_identical(ev$category, c(4L, 1L))
  expect_identical(ev$n_strong, c(0L, 0L))
})
