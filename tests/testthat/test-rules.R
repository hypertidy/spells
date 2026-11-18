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
  expect_identical(step_category(x, seas, thresh, ev, categories())[, 1], c(1L, 1L, 1L, 2L, 3L, 4L))
  expect_identical(step_category(x, seas, thresh, ev, categories(">", 4, "none"))[, 1],
                   c(0L, 0L, 1L, 1L, 3L, 4L))
  ev[2] <- FALSE
  expect_identical(step_category(x, seas, thresh, ev, categories())[2, 1], 0L)
})

test_that("definitions refuse what isn't implemented", {
  ref <- c("1982-01-01", "2011-12-31")
  expect_error(hobday2016(ref), "clean rules")
  expect_error(hobday2016(ref, parity = "heatwave3-1.5.0"), "isn't implemented yet")
  expect_error(hobday2016(ref, parity = "heatwaveR-9"), "unknown parity mode")
  expect_error(hobday2016(c("1982-02-01", "2011-12-31"), parity = "heatwaveR-0.5.5"), "whole years")
  expect_s3_class(hobday2016(ref, parity = "heatwaveR-0.5.5"), "spell_def")
  pm <- parity_modes()
  expect_identical(pm$parity[pm$implemented], c("heatwaveR-0.5.5", "heatwaveR-1.0.0"))
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
