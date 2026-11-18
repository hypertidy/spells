## spells' clean rules. No engine runs them, so the baseline is checked
## against a direct, slow reading of the rules from the dates, and
## detection on series built by hand.

## The clean baseline straight from the dates: slot i's window in each
## reference year is the reference days within 5 slots of it on a
## continuous slot axis (366 per year, so a non-leap year has no slot 60
## and the window runs on into the adjacent reference years); a slot
## needs half its window's possible days; then a 31-slot mean, periodic,
## over the slots that have a baseline.
naive_baseline <- function(x, time, ref, coverage = 0.5) {
  inref <- time >= ref[1] & time <= ref[2]
  t <- time[inref]
  v <- x[inref]
  y <- as.integer(format(t, "%Y"))
  pos <- (y - min(y)) * 366 + slot_366(t)
  centres <- (unique(y) - min(y)) * 366
  raw_m <- raw_p <- rep(NA_real_, 366)
  for (i in 1:366) {
    inwin <- vapply(pos, function(q) any(abs(q - (centres + i)) <= 5), TRUE)
    vals <- v[inwin & !is.na(v)]
    if (length(vals) > 0 && length(vals) >= coverage * sum(inwin)) {
      raw_m[i] <- mean(vals)
      raw_p[i] <- stats::quantile(vals, 0.9, type = 7, names = FALSE)
    }
  }
  smooth <- function(r) vapply(1:366, function(i) {
    if (is.na(r[i])) return(NA_real_)
    mean(r[(((i - 15):(i + 15)) - 1) %% 366 + 1], na.rm = TRUE)
  }, 0)
  list(seas = smooth(raw_m), thresh = smooth(raw_p))
}

test_that("clean baseline: the rules read directly from the dates", {
  set.seed(1)
  time <- seq(as.Date("2002-01-01"), as.Date("2007-12-31"), by = "day")
  x <- 20 + 3 * sin(2 * pi * seq_along(time) / 365.25) + stats::rnorm(length(time), sd = 0.6)
  na_at <- function(x, from, to) { x[time >= as.Date(from) & time <= as.Date(to)] <- NA; x }
  x <- na_at(x, "2003-01-01", "2003-01-03")       # the reference period's first days
  for (yr in 2004:2006) x <- na_at(x, paste0(yr, "-06-01"), paste0(yr, "-07-10"))  # June in 3 of 4 years
  x <- na_at(x, "2005-02-27", "2005-03-02")       # around a non-leap slot 60
  x <- na_at(x, "2006-12-28", "2006-12-31")       # the reference period's last days
  ref <- as.Date(c("2003-01-01", "2006-12-31"))
  b <- spell_baseline(x, time, hobday2016(ref))
  nb <- naive_baseline(x, time, ref)
  expect_equal(b$seas[, 1], nb$seas)
  expect_equal(b$thresh[, 1], nb$thresh)
  ## June has too few days in its window, and stays without a baseline
  june <- slot_366(as.Date("2005-06-10")):slot_366(as.Date("2005-06-30"))
  expect_true(all(is.na(b$thresh[june, 1])))
  expect_false(anyNA(b$thresh[-(140:200), 1]))
  ## nothing outside the reference period is used
  x2 <- x
  x2[time < ref[1] | time > ref[2]] <- 99
  b2 <- spell_baseline(x2, time, hobday2016(ref))
  expect_identical(b2$seas, b$seas)
  expect_identical(b2$thresh, b$thresh)
})

test_that("clean baseline: heatwave3's, unrounded, away from 29 February", {
  ## heatwave3 shortens the window and leaves gaps out too; it fills
  ## slot 60 in non-leap years, which reaches slots 40 to 80 after the
  ## smoothing, and rounds to 4 decimals
  g <- fixture("golden-heatwave3-1.5.0.rds")$cases
  for (nm in c("wa_wmo", "wa_refgaps")) {
    k <- cases[[nm]]
    b <- spell_baseline(k$x, k$dates, hobday2016(k$reference))
    far <- setdiff(1:366, 40:80)
    clim <- g[[nm]][[1]]$clim
    expect_equal(round(b$seas[clim$doy, 1], 4)[clim$doy %in% far], clim$seas[clim$doy %in% far])
    expect_equal(round(b$thresh[clim$doy, 1], 4)[clim$doy %in% far], clim$thresh[clim$doy %in% far])
  }
})

## a flat baseline 0 and threshold 1, under the clean rules
flat <- function(n_days = 365) {
  def <- hobday2016(c("2001-01-01", "2001-12-31"))
  list(time = seq(as.Date("2001-01-01"), by = "day", length.out = n_days),
       b = structure(list(def = def, seas = matrix(0, 366, 1), thresh = matrix(1, 366, 1)),
                     class = "spell_baseline"))
}

test_that("clean detection: short gaps interpolated, longer ones cut", {
  f <- flat()
  x <- rep(0, 365)
  x[1:2] <- NA; x[3:9] <- 2                     # missing at the start: can't be interpolated
  x[20:30] <- 2; x[24:25] <- NA                 # 2 missing inside a run: interpolated
  x[40:46] <- 2; x[47:50] <- NA; x[51:57] <- 2  # 4 missing: cut on both sides
  x[70:76] <- 2; x[77:79] <- NA; x[80:86] <- 2  # 3 missing between two runs: interpolated, one spell
  m <- spell_mask(x, f$time, f$b)
  ev <- spell_events(x, f$time, f$b, m)
  expect_identical(ev$index_start, c(3L, 20L, 40L, 51L, 70L))
  expect_identical(ev$index_end, c(9L, 30L, 46L, 57L, 86L))
  expect_identical(ev$n_missing, c(0L, 2L, 0L, 0L, 3L))
  expect_identical(ev$cut_start, c(TRUE, FALSE, FALSE, TRUE, FALSE))
  expect_identical(ev$cut_end, c(FALSE, FALSE, TRUE, FALSE, FALSE))
  expect_identical(is.na(ev$rate_onset), c(TRUE, FALSE, FALSE, TRUE, FALSE))
  expect_identical(is.na(ev$rate_decline), c(FALSE, FALSE, TRUE, FALSE, FALSE))
  ## steps that can't be tested have no anomaly
  expect_true(all(is.na(m$anom[c(1:2, 47:50), 1])))
  expect_false(anyNA(m$anom[-c(1:2, 47:50), 1]))
  ## an interpolated step outside a spell gives its rate: from 0 at 59 to 2 at 61
  x2 <- rep(0, 365); x2[60] <- NA; x2[61:67] <- 2
  e2 <- spell_events(x2, f$time, f$b, spell_mask(x2, f$time, f$b))
  expect_identical(e2$index_start, 61L)
  expect_equal(e2$rate_onset, (2 - 0.5 * (2 + 1)) / 0.5)
})

test_that("clean detection: no gap is joined across a slot without a baseline", {
  f <- flat()
  hole <- slot_366(f$time[150])
  f$b$seas[hole, 1] <- NA
  f$b$thresh[hole, 1] <- NA
  x <- rep(0, 365)
  x[140:149] <- 2; x[151:160] <- 2              # a 1-step gap, but it can't be tested
  ev <- spell_events(x, f$time, f$b, spell_mask(x, f$time, f$b))
  expect_identical(ev$index_start, c(140L, 151L))
  expect_identical(ev$cut_end, c(TRUE, FALSE))
  expect_identical(ev$cut_start, c(FALSE, TRUE))
  ## the same gap with a baseline is joined
  f2 <- flat()
  ev2 <- spell_events(x, f2$time, f2$b, spell_mask(x, f2$time, f2$b))
  expect_identical(ev2$index_start, 140L)
  expect_identical(ev2$duration, 21L)
})

test_that("clean categories: the floor of the multiple, gap days none, spell by its highest", {
  f <- flat()
  x <- rep(0, 365)
  x[10:27] <- c(1.5, 2, 3.99, 4, 9, 0.5, 0.5, rep(1.5, 5), 1, rep(1.5, 5))
  m <- spell_mask(x, f$time, f$b)
  ## x = 1 (step 22) is at the threshold, not beyond it: a joined gap
  ## day, so no category, though the floor of its multiple is 1
  expect_identical(m$category[10:27, 1],
                   c(1L, 2L, 3L, 4L, 4L, 0L, 0L, rep(1L, 5), 0L, rep(1L, 5)))
  ev <- spell_events(x, f$time, f$b, m)
  expect_identical(ev$category, 4L)
  expect_identical(ev$n_extreme, 2L)
  expect_identical(ev$duration, 18L)
  expect_identical(ev$n_beyond, 15L)
  ## every step beyond the threshold has a category, and only those
  expect_identical(ev$n_moderate + ev$n_strong + ev$n_severe + ev$n_extreme, ev$n_beyond)
})

test_that("clean definition prints its rules", {
  out <- capture.output(print(hobday2016(c("1982-01-01", "2011-12-31"))))
  expect_match(out[1], "clean rules")
  expect_true(any(grepl("3 or fewer interpolated", out)))
})
