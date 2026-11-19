## The eligibility mask: where the series means something (SST not under
## ice). No engine has one. With a parity mode an ineligible step is the
## engine's answer on the series masked to NA there, so a complete series
## masked where wa_gaps and wa_refgaps are missing must give their stored
## outputs. With the clean rules it's tested on series built by hand.

test_that("parity: ineligible is the engine on the series masked to NA", {
  complete <- cases$oisst3$x[, "WA", drop = FALSE]
  kinds <- list(cases = hobday2018, cold = schlegel2021)
  for (parity in c("heatwaveR-0.5.5", "heatwaveR-1.0.0", "heatwave3-1.5.0")) {
    golden <- fixture(paste0("golden-", parity, ".rds"))
    for (kind in names(kinds)) for (nm in c("wa_gaps", "wa_refgaps")) {
      k <- cases[[nm]]
      eligible <- !is.na(k$x)
      km <- k
      km$x <- complete
      r <- run_case(km, kinds[[kind]](k$reference, parity = parity), eligible = eligible)
      g <- golden[[kind]][[nm]][[1]]
      expect_equal(r$baseline$seas[g$clim$doy, 1], g$clim$seas)
      expect_equal(r$baseline$thresh[g$clim$doy, 1], g$clim$thresh)
      expect_identical(r$mask$event[, 1], g$day$event)
      expect_identical(r$mask$category[, 1], daily_category(g$day$category))
      expect_events(r$events, g$events)
      expect_event_categories(r$events, if (!is.null(g$categories)) g$categories else g$events)
      expect_identical(r$mask$state[, 1] == 3L, !eligible[, 1])
      ## a parity mode joins across an ineligible day, as across a missing one
      if (kind == "cases" && nm == "wa_gaps") expect_gt(sum(r$events$n_ineligible), 0L)
    }
  }
})

## a flat baseline 0 and threshold 1, under the clean rules
flat_clean <- function() {
  def <- hobday2018(c("2001-01-01", "2001-12-31"))
  list(time = seq(as.Date("2001-01-01"), by = "day", length.out = 365),
       b = structure(list(def = def, seas = matrix(0, 366, 1), thresh = matrix(1, 366, 1)),
                     class = "spell_baseline"))
}

test_that("clean: an ineligible step isn't missing data", {
  f <- flat_clean()
  x <- rep(0, 365)
  x[20:30] <- 2                                 # one ineligible day inside
  x[50] <- 0; x[51] <- NA; x[53] <- 0           # a gap beside an ineligible day
  x[100:110] <- 3                               # beyond, but all ineligible
  el <- rep(TRUE, 365)
  el[c(25, 52, 100:110)] <- FALSE
  m <- spell_mask(x, f$time, f$b, eligible = el)
  ev <- spell_events(x, f$time, f$b, m)
  ## its value is ignored: no spell under the mask
  expect_identical(ev$index_start, c(20L, 26L))
  expect_identical(ev$index_end, c(24L, 30L))
  ## not interpolated, nor interpolated across: the spells either side are cut
  expect_identical(ev$cut_end_by, c("ineligible", NA))
  expect_identical(ev$cut_start_by, c(NA, "ineligible"))
  expect_identical(is.na(ev$rate_decline), c(TRUE, FALSE))
  expect_identical(is.na(ev$rate_onset), c(FALSE, TRUE))
  expect_identical(ev$n_ineligible, c(0L, 0L))
  ## a missing day beside an ineligible one has no observed day on that
  ## side, so it stays missing
  expect_identical(attr(m$state, "levels")[m$state[c(25, 50:53, 100), 1] + 1L],
                   c("ineligible", "observed", "missing", "ineligible", "observed", "ineligible"))
  expect_true(all(is.na(m$anom[c(25, 51, 52, 100:110), 1])))
  ## the same day missing instead of ineligible is interpolated: one spell
  x2 <- x; x2[25] <- NA
  el2 <- el; el2[25] <- TRUE
  ev2 <- spell_events(x2, f$time, f$b, spell_mask(x2, f$time, f$b, eligible = el2))
  expect_identical(ev2$index_start[1], 20L)
  expect_identical(ev2$index_end[1], 30L)
  expect_identical(ev2$n_missing[1], 1L)
})

test_that("clean: why a spell is cut", {
  f <- flat_clean()
  hole <- slot_366(f$time[200])
  f$b$seas[hole, 1] <- NA
  f$b$thresh[hole, 1] <- NA
  x <- rep(0, 365)
  x[1:6] <- 2                                   # from the series' start
  x[40:46] <- 2; x[47:50] <- NA                 # into a gap too long to interpolate
  x[193:199] <- 2                               # into a slot without a baseline
  x[300:306] <- 2; x[307] <- 0.5                # not cut
  x[360:365] <- 2                               # to the series' end
  ev <- spell_events(x, f$time, f$b, spell_mask(x, f$time, f$b))
  expect_identical(ev$cut_start_by, c("series", NA, NA, NA, NA))
  expect_identical(ev$cut_end_by, c(NA, "missing", "no_baseline", NA, "series"))
  expect_identical(ev$cut_start, !is.na(ev$cut_start_by))
  expect_identical(ev$cut_end, !is.na(ev$cut_end_by))
})

test_that("clean: ineligible days in the reference count against coverage", {
  set.seed(2)
  time <- seq(as.Date("2003-01-01"), as.Date("2006-12-31"), by = "day")
  x <- 20 + 3 * sin(2 * pi * seq_along(time) / 365.25) + stats::rnorm(length(time), sd = 0.6)
  winter <- as.integer(format(time, "%m")) %in% 6:8 & format(time, "%Y") != "2003"
  def <- hobday2016(range(time))
  b_el <- spell_baseline(x, time, def, eligible = !winter)
  b_na <- spell_baseline(replace(x, winter, NA), time, def)
  expect_identical(b_el$seas, b_na$seas)
  expect_identical(b_el$thresh, b_na$thresh)
  ## winter has one eligible year in four: no baseline
  expect_true(all(is.na(b_el$thresh[slot_366(as.Date("2005-07-15")), ])))
  expect_identical(b_el$ineligible, sum(winter))
})

test_that("clean: a whole series ineligible", {
  set.seed(4)
  time <- seq(as.Date("2003-01-01"), as.Date("2006-12-31"), by = "day")
  x <- cbind(a = stats::rnorm(length(time)), b = stats::rnorm(length(time)))
  def <- hobday2018(range(time))
  b <- spell_baseline(x, time, def, eligible = c(TRUE, FALSE))
  expect_false(anyNA(b$thresh[, 1]))
  expect_true(all(is.na(b$thresh[, 2])))
  m <- spell_mask(x, time, b, eligible = c(TRUE, FALSE))
  expect_true(all(m$state[, 2] == 3L))
  expect_false(any(m$event[, 2]))
  expect_false(any(spell_events(x, time, b, m)$series == 2L))
})

test_that("eligibility masks are checked", {
  x <- matrix(0, 10, 2)
  expect_identical(dim(check_eligible(NULL, x)), c(10L, 2L))
  expect_identical(check_eligible(c(TRUE, FALSE), x)[, 2], rep(FALSE, 10))
  expect_error(check_eligible(c(TRUE, NA), x), "no NA")
  expect_error(check_eligible(rep(TRUE, 3), x), "one value per series")
  expect_error(check_eligible(matrix(TRUE, 9, 2), x), "same shape")
  expect_identical(check_eligible(rep(c(TRUE, FALSE), 5), x[, 1, drop = FALSE])[2, 1], FALSE)
})
