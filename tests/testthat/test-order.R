## The rule order: the minimum duration first, then gaps joined (Hobday
## et al. 2016), or gaps joined first, then the minimum on the joined
## span, gap steps counted (MHW-MAD, Hayward et al. 2026).
##
## The join-first oracle is MHW-MAD's own per-day categories (CC-BY 4.0,
## doi:10.5281/zenodo.21835325; data-raw/mhw-mad.R), at nine Tasman Sea
## pixels for 2015-2016, from its own anomalies and thresholds: the
## baseline is 0 and the threshold is its threshHW (the percentile minus
## the mean) by day of year.

test_that("spell_runs: minimum first and join first", {
  x <- c(TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE)
  ## minimum first: neither run is 5 long, so nothing
  expect_false(any(spell_runs(x, 5L, 2L)))
  ## join first: 3 + 1 gap + 4 = an 8-step spell, the gap counted
  expect_identical(which(spell_runs(x, 5L, 2L, order = "join_first")), 1:8)
  ## a blocked step in the gap isn't joined across, either way
  blocked <- logical(12); blocked[4] <- TRUE
  expect_false(any(spell_runs(x, 5L, 2L, blocked = blocked, order = "join_first")))
  ## the same 8 steps with a minimum of 9 isn't a spell
  expect_false(any(spell_runs(x, 9L, 2L, order = "join_first")))
  ## a long run with a short one 2 steps after: joined only by join first
  y <- c(rep(TRUE, 6), FALSE, FALSE, TRUE, FALSE)
  expect_identical(which(spell_runs(y, 5L, 2L)), 1:6)
  expect_identical(which(spell_runs(y, 5L, 2L, order = "join_first")), 1:9)
})

mad <- fixture("mhw-mad.rds")
mad_slot <- slot_366(mad$dates)
run_mad <- function(product, min_duration, order) {
  thr <- mad$thresh[[product]]
  def <- spell_def("mhw-mad", c("1991-01-01", "2020-12-31"), rule_mode(NULL)$rules,
                   category = categories(), min_duration = min_duration, order = order)
  b <- structure(list(def = def, seas = matrix(0, 366, ncol(thr)), thresh = thr),
                 class = "spell_baseline")
  spell_mask(mad$anom, mad$dates, b)
}
## Days that aren't scored: those in a joined run of exceedances that
## touches either end of the 2015-2016 window (the event goes on outside
## the stored data), or that holds a tie: a day whose stored anomaly is
## within 1e-4 of the stored threshold. The data is stored in single
## precision (its categories are up to 3.1e-5 off whole numbers, and one
## float32 step at 290 K is 3.05e-5), so such a day can fall either side
## of the threshold in MHW-MAD's own arithmetic. There is one, in the
## 95th percentile product: 2016-09-02 at 150 E 43 S, 3.3e-5 above.
unscored <- function(product) {
  d <- mad$anom - mad$thresh[[product]][mad_slot, ]
  tie <- abs(d) < 1e-4
  vapply(seq_len(ncol(d)), function(j) {
    b <- spell_runs(d[, j] > 0 | tie[, j], 1L, 2L, order = "join_first")
    r <- rle(b)
    end <- cumsum(r$lengths); start <- end - r$lengths + 1L
    out <- logical(nrow(d))
    for (k in which(r$values)) {
      t <- start[k]:end[k]
      if (start[k] == 1L || end[k] == nrow(d) || any(tie[t, j])) out[t] <- TRUE
    }
    out
  }, logical(nrow(d)))
}

test_that("join first reproduces MHW-MAD's categories", {
  expect_false(anyNA(mad$anom))
  products <- list(p90_5d = c("p90", 5L), p90_10d = c("p90", 10L), p90_30d = c("p90", 30L),
                   p95_5d = c("p95", 5L))
  for (nm in names(products)) {
    th <- products[[nm]][1]
    m <- run_mad(th, as.integer(products[[nm]][2]), "join_first")
    inner <- !unscored(th)
    expect_identical(m$category[inner], mad$category[[nm]][inner], label = nm)
  }
  ## the 90th percentile with a 5-day minimum has no tie, and every day
  ## matches, the window's ends included
  expect_gt(min(abs(mad$anom - mad$thresh$p90[mad_slot, ])), 1e-4)
  expect_identical(sum(abs(mad$anom - mad$thresh$p95[mad_slot, ]) < 1e-4), 1L)
  m5 <- run_mad("p90", 5L, "join_first")
  expect_identical(m5$category, mad$category$p90_5d)
  ## bridged gap days are in a spell with no category, as MHW-MAD's
  gap <- m5$event & m5$category == 0L
  expect_gt(sum(gap), 0L)
})

test_that("minimum first doesn't reproduce MHW-MAD", {
  ## the orders differ on 88 of MHW-MAD's 1942 event days away from the
  ## window's ends (inst/survey/mhw-mad.md)
  m <- run_mad("p90", 5L, "minimum_first")
  inner <- !unscored("p90")
  bad <- (m$category > 0L) != (mad$category$p90_5d > 0L)
  expect_identical(sum(bad & inner), 88L)
  expect_identical(sum(mad$category$p90_5d > 0L), 1942L)
})

test_that("the order is part of the def", {
  ref <- c("1982-01-01", "2011-12-31")
  expect_identical(hobday2018(ref)$order, "minimum_first")
  expect_identical(schlegel2021(ref, parity = "heatwave3-1.5.0")$order, "minimum_first")
  d <- spell_def("x", ref, rule_mode(NULL)$rules, order = "join_first")
  expect_identical(d$order, "join_first")
  expect_match(capture.output(print(d))[4], "join_first")
  expect_error(spell_def("x", ref, rule_mode(NULL)$rules, order = "neither"))
})
