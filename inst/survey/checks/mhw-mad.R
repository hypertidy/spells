# Checks for inst/survey/mhw-mad.md, "To check by running": MHW-MAD's
# per-day categories against its own anomalies and thresholds, on nine
# Tasman Sea pixels (2 degrees apart, 150-154E, 39-43S) for 2015-2016,
# the years of the 2015/16 Tasman Sea marine heatwave.
# Data: DMI ERDDAP (erddap.dmi.dk), fetched once into a cache directory.
# Run: Rscript mhw-mad.R <cache-dir> > mhw-mad.out 2>&1
args <- commandArgs(TRUE)
cache <- if (length(args)) args[1] else file.path(tempdir(), "mhw-mad")
dir.create(cache, showWarnings = FALSE, recursive = TRUE)
options(timeout = 1800)   # the server opens one file per day: ~25 days per second

erddap <- "https://erddap.dmi.dk/erddap/griddap/"
box <- "[(-43.025):40:(-39.025)][(150.025):40:(154.025)]"
fetch <- function(id, vars, t0, t1, doy = FALSE) {
  f <- file.path(cache, paste0(id, ".csv"))
  if (!file.exists(f)) {
    tsel <- if (doy) "[(1):1:(366)]" else sprintf("[(%sT12:00:00Z):1:(%sT12:00:00Z)]", t0, t1)
    q <- paste(paste0(vars, tsel, box), collapse = ",")
    q <- gsub("\\[", "%5B", gsub("\\]", "%5D", q))
    tmp <- paste0(f, ".part")
    t_start <- Sys.time()
    download.file(paste0(erddap, id, ".csv?", q), tmp, quiet = TRUE, method = "libcurl")
    file.rename(tmp, f)
    cat(sprintf("   %s: %.0f s\n", id, as.numeric(difftime(Sys.time(), t_start, units = "secs"))))
  }
  hdr <- names(read.csv(f, nrows = 1))
  d <- read.csv(f, skip = 2, header = FALSE, col.names = hdr)
  d$px <- sprintf("%.3f,%.3f", d$longitude, d$latitude)
  if ("time" %in% hdr) d$date <- as.Date(substr(d$time, 1, 10))
  d
}

cat("Fetched (or read from the cache):\n")
t0 <- "2015-01-01"; t1 <- "2016-12-31"
an90  <- fetch("mhw_raw_wmoClim_90p_10d_anom", "anom", t0, t1)  # no 5d anom dataset is published
c90   <- fetch("mhw_raw_wmoClim_90p_5d_cat",  "cat_HW", t0, t1)
c90_10 <- fetch("mhw_raw_wmoClim_90p_10d_cat", "cat_HW", t0, t1)
c90_30 <- fetch("mhw_raw_wmoClim_90p_30d_cat", "cat_HW", t0, t1)
cl90  <- fetch("mhw_raw_wmoClim_90p_clim", c("mean", "p90", "threshHW"), doy = TRUE)
an95  <- fetch("mhw_raw_wmoClim_95p_5d_anom", "anom", t0, t1)
c95   <- fetch("mhw_raw_wmoClim_95p_5d_cat",  "cat_HW", t0, t1)
cl95  <- fetch("mhw_raw_wmoClim_95p_clim", c("mean", "threshHW"), doy = TRUE)
mv15a <- fetch("mhw_raw_1986_2015_climatology_90p_5d_anom", "anom", "2015-01-01", "2015-12-31")
mv15c <- fetch("mhw_raw_1986_2015_climatology_90p_5d_cat",  "cat_HW", "2015-01-01", "2015-12-31")
mv16a <- fetch("mhw_raw_1987_2016_climatology_90p_5d_anom", "anom", "2016-01-01", "2016-12-31")
mv16c <- fetch("mhw_raw_1987_2016_climatology_90p_5d_cat",  "cat_HW", "2016-01-01", "2016-12-31")
cl16  <- fetch("mhw_raw_1987_2016_climatology_90p_clim", c("mean", "threshHW"), doy = TRUE)
cat("  ", length(list.files(cache)), "files in the cache;", length(unique(c90$px)), "pixels\n\n")

## 1. How categories are stored
cat("1. distinct cat_HW values (WMO 90p 5d):", paste(signif(sort(unique(c90$cat_HW)), 7), collapse = ", "), "\n")
cat("   largest distance from a whole number:", signif(max(abs(c90$cat_HW - round(c90$cat_HW))), 3), "\n")
cat("   anomalies identical in the 90p 10d and 95p 5d WMO datasets:",
    isTRUE(all.equal(an90$anom, an95$anom, tolerance = 0)), "\n\n")
rnd <- function(d) { d$cat <- round(d$cat_HW); d }
c90 <- rnd(c90); c90_10 <- rnd(c90_10); c90_30 <- rnd(c90_30); c95 <- rnd(c95)
mv15c <- rnd(mv15c); mv16c <- rnd(mv16c)

## Day-of-year slot, two candidate rules
slot_doy <- function(d) as.integer(format(d, "%j"))                    # calendar day number
slot_366 <- function(d) {                                              # 366-day calendar
  j <- as.integer(format(d, "%j")); m <- as.integer(format(d, "%m"))
  leap <- as.integer(format(d, "%Y")) %% 4 == 0
  j + (!leap & m >= 3)
}
thr_at <- function(cl, px, slots, var = "threshHW") {
  s <- cl[cl$px == px, ]; s[[var]][match(slots, s$dayofyear)]
}

## Event rules on a logical exceedance vector
runs <- function(x) { r <- rle(x); e <- cumsum(r$lengths); data.frame(v = r$values, s = e - r$lengths + 1, e = e, n = r$lengths) }
## A: Hobday / marineHeatWaves: runs >= dmin, then gaps <= maxgap joined between them
rule_A <- function(x, dmin = 5, maxgap = 2) {
  r <- runs(x); keep <- r[r$v & r$n >= dmin, ]
  ev <- rep(FALSE, length(x)); if (!nrow(keep)) return(list(day = ev, gap = ev))
  for (i in seq_len(nrow(keep))) ev[keep$s[i]:keep$e[i]] <- TRUE
  gap <- rep(FALSE, length(x))
  if (nrow(keep) > 1) for (i in 2:nrow(keep)) {
    g <- keep$s[i] - keep$e[i - 1] - 1
    if (g <= maxgap) gap[(keep$e[i - 1] + 1):(keep$s[i] - 1)] <- TRUE
  }
  list(day = ev, gap = gap)
}
## B: gaps <= maxgap bridged first, then the bridged span must be >= dmin
rule_B <- function(x, dmin = 5, maxgap = 2) {
  r <- runs(x); b <- x
  for (i in which(!r$v)) if (i > 1 && i < nrow(r) && r$n[i] <= maxgap) b[r$s[i]:r$e[i]] <- TRUE
  rb <- runs(b); span <- rep(FALSE, length(x))
  for (i in which(rb$v & rb$n >= dmin)) span[rb$s[i]:rb$e[i]] <- TRUE
  list(day = span & x, gap = span & !x)
}
## C: as B, but the minimum counts only the days above the threshold
rule_C <- function(x, dmin = 5, maxgap = 2) {
  r <- runs(x); b <- x
  for (i in which(!r$v)) if (i > 1 && i < nrow(r) && r$n[i] <= maxgap) b[r$s[i]:r$e[i]] <- TRUE
  rb <- runs(b); span <- rep(FALSE, length(x))
  for (i in which(rb$v)) if (sum(x[rb$s[i]:rb$e[i]]) >= dmin) span[rb$s[i]:rb$e[i]] <- TRUE
  list(day = span & x, gap = span & !x)
}

## Days in a bridged run that touches either end of the 2015-2016 window:
## such events continue outside the data fetched, so they're not scored.
edge_days <- function(x, maxgap = 2) {
  r <- runs(x); b <- x
  for (i in which(!r$v)) if (i > 1 && i < nrow(r) && r$n[i] <= maxgap) b[r$s[i]:r$e[i]] <- TRUE
  rb <- runs(b); e <- rep(FALSE, length(x))
  for (i in which(rb$v & (rb$s == 1 | rb$e == length(x)))) e[rb$s[i]:rb$e[i]] <- TRUE
  e
}
score <- function(an, ca, cl, slotf, cmp = `>=`, dmin = 5, label = "") {
  out <- NULL
  for (p in unique(an$px)) {
    a <- an[an$px == p, ]; k <- ca[ca$px == p, ]
    k <- k[match(a$date, k$date), ]
    th <- thr_at(cl, p, slotf(a$date))
    x <- cmp(a$anom, th)
    inner <- !edge_days(x)
    for (nm in c("A", "B", "C")) {
      ev <- get(paste0("rule_", nm))(x, dmin)
      bad <- (k$cat > 0) != ev$day
      out <- rbind(out, data.frame(px = p, rule = nm, days = length(x),
        mismatch = sum(bad), inner_mismatch = sum(bad & inner), gap_days = sum(ev$gap),
        gap_cat0 = sum(ev$gap & k$cat == 0)))
    }
  }
  out
}
fmt <- function(s) {
  a <- aggregate(cbind(mismatch, inner_mismatch) ~ rule, s, sum)
  paste(sprintf("rule %s %d (%d)", a$rule, a$mismatch, a$inner_mismatch), collapse = "; ")
}

## 2. Slot rule and comparison: exceedances vs cat > 0, summed over pixels
cat("2. Days where (cat_HW > 0) differs from each rule, WMO 90p 5d, 9 pixels x 731 days\n",
    "  (in brackets: leaving out runs that touch the ends of the 2015-2016 window):\n")
for (sl in c("slot_doy", "slot_366")) for (cm in c(">=", ">")) {
  s <- score(an90, c90, cl90, get(sl), match.fun(cm))
  cat(sprintf("   %s, anom %s threshHW: ", sl, cm), fmt(s), "\n")
}
x_all <- unlist(lapply(unique(an90$px), function(p) {
  a <- an90[an90$px == p, ]; a$anom - thr_at(cl90, p, slot_366(a$date)) }))
cat("   days with anom exactly equal to threshHW (where >= and > would differ):", sum(x_all == 0), "\n")
cat("   rule A: runs >= 5 first, then gaps <= 2 joined between them (marineHeatWaves);\n",
    "  rule B: gaps <= 2 bridged first, then the span >= 5; rule C: as B, counting only days above\n\n")

best <- score(an90, c90, cl90, slot_366, `>=`)
cat("   per pixel, slot_366 and >=:\n")
print(reshape(best[, c("px", "rule", "inner_mismatch")], idvar = "px", timevar = "rule", direction = "wide"), row.names = FALSE)
gB <- aggregate(cbind(gap_days, gap_cat0) ~ rule, best, sum)
cat("\n   bridged gap days and how many of them have cat_HW == 0:\n"); print(gB, row.names = FALSE)

## 3. The 10- and 30-day products
cat("\n3. Longer minimum durations (slot_366, >=), mismatched days (leaving out the window ends):\n")
for (dd in list(list(c90_10, 10), list(c90_30, 30))) {
  s <- score(an90, dd[[1]], cl90, slot_366, `>=`, dmin = dd[[2]])
  cat(sprintf("   %2d days: ", dd[[2]]), fmt(s), "\n")
}

## 4. Category bands on event days
bands <- function(an, ca, cl, label) {
  m <- merge(an, ca[, c("px", "date", "cat")], by = c("px", "date"))
  m$thr <- mapply(function(p, s) thr_at(cl, p, s), m$px, slot_366(m$date))
  e <- m[m$cat > 0, ]
  r <- e$anom / e$thr
  pred_floor <- pmin(4, floor(r))
  cat(sprintf("4. %s: event days %d; cat == min(4, floor(anom / threshHW)): %d; max ratio %.2f\n",
              label, nrow(e), sum(e$cat == pred_floor), max(r)))
  tab <- table(cat = e$cat, floor_ratio = pmin(4, floor(r)))
  print(tab)
}
bands(an90, c90, cl90, "WMO 90p")
bands(an95, c95, cl95, "WMO 95p (unit: p95 minus the mean)")
m95 <- merge(an95, c95[, c("px", "date", "cat")], by = c("px", "date"))
m95$t90 <- mapply(function(p, s) thr_at(cl90, p, s), m95$px, slot_366(m95$date))
e95 <- m95[m95$cat > 0, ]
cat("   95p event days whose category in units of p90 minus the mean would differ:",
    sum(e95$cat != pmin(4, floor(e95$anom / e95$t90))), "of", nrow(e95), "\n\n")

## 5. The moving-window products at 1 January 2016
cat("5. Moving windows: 1986-2015 (file year 2015) and 1987-2016 (file year 2016)\n")
cat("   anomaly change from 31 Dec 2015 to 1 Jan 2016 in the moving products vs the WMO product:\n")
for (p in unique(an90$px)) {
  d31 <- as.Date("2015-12-31"); d01 <- as.Date("2016-01-01")
  mv <- mv16a$anom[mv16a$px == p & mv16a$date == d01] - mv15a$anom[mv15a$px == p & mv15a$date == d31]
  wm <- an90$anom[an90$px == p & an90$date == d01] - an90$anom[an90$px == p & an90$date == d31]
  cat(sprintf("   %s: moving %+.3f, WMO %+.3f\n", p, mv, wm))
}
cat("   Runs from 1 Jan 2016 in the 1987-2016 product (its own anomalies and threshold):\n")
for (p in unique(mv16a$px)) {
  a <- mv16a[mv16a$px == p, ]; k <- mv16c[mv16c$px == p, ]; k <- k[match(a$date, k$date), ]
  x <- a$anom >= thr_at(cl16, p, slot_366(a$date))
  r <- runs(x)
  if (r$v[1]) {
    b <- rule_B(x)
    cat(sprintf("   %s: first run %d days from 1 Jan; flagged in the product: %s; by rule B within 2016 alone: %s\n",
                p, r$n[1], any(k$cat[1:r$n[1]] > 0), any(b$day[1:r$n[1]])))
  }
}
## December 2015 against the 1987-2016 climatology: SST = WMO anomaly + WMO
## mean, then minus the 1987-2016 mean. Checked on 1 Jan 2016 against the
## product's own anomaly.
p <- "154.025,-39.025"
dd <- seq(as.Date("2015-12-20"), as.Date("2016-01-04"), by = "day")
w <- an90[an90$px == p & an90$date %in% dd, ]; sl <- slot_366(w$date)
a16 <- w$anom + thr_at(cl90, p, sl, "mean") - thr_at(cl16, p, sl, "mean")
cat(sprintf("   %s, 1 Jan 2016 anomaly rebuilt from the WMO product: %.4f; the 1987-2016 product's: %.4f\n",
            p, a16[w$date == as.Date("2016-01-01")], mv16a$anom[mv16a$px == p & mv16a$date == as.Date("2016-01-01")]))
kk <- rbind(mv15c[mv15c$px == p, c("date", "cat")], mv16c[mv16c$px == p, c("date", "cat")])
cat("   20 Dec 2015 - 4 Jan 2016: above the 1987-2016 threshold ",
    paste0(ifelse(a16 >= thr_at(cl16, p, sl), "x", "."), collapse = ""),
    "\n                             cat_HW > 0 in the moving files ",
    paste0(ifelse(kk$cat[match(w$date, kk$date)] > 0, "c", "."), collapse = ""), "\n")
k15 <- mv15c[mv15c$date == as.Date("2015-12-31"), c("px", "cat")]
k16 <- mv16c[mv16c$date == as.Date("2016-01-01"), c("px", "cat")]
cat("   cat_HW on 31 Dec 2015 (1986-2015) and 1 Jan 2016 (1987-2016) per pixel:\n")
print(merge(k15, k16, by = "px", suffixes = c("_31dec2015", "_1jan2016")), row.names = FALSE)

## 6. The 29 February slot (60): interpolated between 59 and 61?
cat("\n6. Slot 60 against the mean of slots 59 and 61, WMO 90p climatology, max difference over pixels:\n")
for (v in c("mean", "p90", "threshHW")) {
  dif <- sapply(unique(cl90$px), function(p) {
    s <- cl90[cl90$px == p, ]; s[[v]][s$dayofyear == 60] - 0.5 * (s[[v]][s$dayofyear == 59] + s[[v]][s$dayofyear == 61])
  })
  ref <- sapply(unique(cl90$px), function(p) {
    s <- cl90[cl90$px == p, ]; max(abs(diff(s[[v]][s$dayofyear %in% 50:70])))
  })
  cat(sprintf("   %-8s %.2e  (largest day-to-day change over slots 50-70: %.2e)\n", v, max(abs(dif)), max(ref)))
}
