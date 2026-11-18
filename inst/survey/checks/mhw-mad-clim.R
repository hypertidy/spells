# Rebuild MHW-MAD's WMO (1991-2020) 90p climatology at the nine Tasman
# pixels from the ESA SST CCI Analysis v3.0, to settle what the paper
# doesn't say: the window at the ends of the reference period, the
# 29 February slot, and the percentile estimator. Needs the cache filled
# by mhw-mad.R (ERDDAP) and mhw-mad-sst.py (CCI SST from Copernicus Marine).
# MHW-MAD used CDO 2.1.1 (paper, section 3), so CDO's ydrun* pooling and
# its histogram percentile (src/percentiles_hist.cc, src/Ydrunpctl.cc at
# tag cdo-2.1.1) are among the candidates.
# Run: Rscript mhw-mad-clim.R <cache-dir> > mhw-mad-clim.out 2>&1
cache <- commandArgs(TRUE)[1]
rd <- function(f) {
  hdr <- names(read.csv(file.path(cache, f), nrows = 1))
  d <- read.csv(file.path(cache, f), skip = 2, header = FALSE, col.names = hdr)
  d$px <- sprintf("%.3f,%.3f", d$longitude, d$latitude); d
}
cl <- rd("mhw_raw_wmoClim_90p_clim.csv")
an <- rd("mhw_raw_wmoClim_90p_10d_anom.csv"); an$date <- as.Date(substr(an$time, 1, 10))
sst <- read.csv(file.path(cache, "cci_sst_9px.csv"))
sst$date <- as.Date(sst$date); sst$px <- sprintf("%.3f,%.3f", sst$lon, sst$lat)
pxs <- unique(cl$px)
stopifnot(all(pxs %in% sst$px))
cat("CCI SST:", format(min(sst$date)), "to", format(max(sst$date)), ";", length(pxs), "pixels;",
    sum(is.na(sst$sst)), "missing values\n")
cat("ERDDAP's CSV gives mean and p90 to 4 decimals (1e-4 K).\n\n")

## Slots: CDO's day key is (month - 1) * 31 + day, so 29 February has its
## own slot and 1 March is the same slot in every year (the 366-day calendar).
slot_366 <- function(d) {
  j <- as.integer(format(d, "%j")); m <- as.integer(format(d, "%m"))
  j + (!(as.integer(format(d, "%Y")) %% 4 == 0) & m >= 3)
}
smooth31 <- function(v) {        # 31-day running mean, periodic over the 366 slots
  n <- length(v); sapply(seq_len(n), function(k) mean(v[((k - 16 + 0:30) %% n) + 1]))
}

## 1. Is this the SST MHW-MAD used? anomaly = SST - mean[slot], 2015-2016.
m <- merge(an, sst[, c("px", "date", "sst")], by = c("px", "date"))
m$mean <- cl$mean[match(paste(m$px, slot_366(m$date)), paste(cl$px, cl$dayofyear))]
dif <- m$sst - m$mean - m$anom
cat("1. SST - mean[slot] - anom, 9 pixels x 731 days: max |difference|", signif(max(abs(dif)), 3),
    "K; rms", signif(sqrt(mean(dif^2)), 3), "K\n\n")

dates <- sort(unique(sst$date))
yr <- as.integer(format(dates, "%Y"))
inper <- which(yr >= 1991 & yr <= 2020)
sl <- slot_366(dates)
## Pool of SST for slot d: +/-5 days around each date in the period with that slot.
pool_idx <- function(rule, d) {
  occ <- inper[sl[inper] == d]
  if (rule == "cdo_noncircular") {             # CDO ydrun* on a 1991-2020 file: windows that
    occ <- occ[occ >= min(inper) + 5 & occ <= max(inper) - 5]  # would run off its ends are not formed
    return(as.vector(outer(occ, -5:5, `+`)))
  }
  idx <- as.vector(outer(occ, -5:5, `+`))
  if (rule == "adjacent") return(idx)          # days from 1990 and 2021 too (marineHeatWaves)
  if (rule == "shortened") return(idx[idx >= min(inper) & idx <= max(inper)])
  if (rule == "circular") {                    # the period as a loop (CDO's rm=c)
    n <- length(inper); lo <- min(inper); hi <- max(inper)
    idx[idx < lo] <- idx[idx < lo] + n; idx[idx > hi] <- idx[idx > hi] - n; return(idx)
  }
}
vals <- function(p) sst$sst[sst$px == p][match(dates, sst$date[sst$px == p])]
refs <- lapply(setNames(pxs, pxs), function(p) { r <- cl[cl$px == p, ]; r[order(r$dayofyear), ] })
ends <- c(1:20, 347:366)

## 2. The mean: window rule and slot 60.
cat("2. Mean, rebuilt minus published (K), 9 pixels x 366 slots:\n")
cat("   window            slot 60       max    rms  | slots near the new year: max    rms\n")
for (rule in c("adjacent", "shortened", "circular", "cdo_noncircular")) for (f29 in c("own", "interpolated")) {
  r <- unlist(lapply(pxs, function(p) {
    v <- vals(p); mn <- sapply(1:366, function(d) mean(v[pool_idx(rule, d)]))
    if (f29 == "interpolated") mn[60] <- mean(mn[c(59, 61)])
    smooth31(mn) - refs[[p]]$mean
  }))
  re <- r[rep(1:366, length(pxs)) %in% ends]
  cat(sprintf("   %-16s  %-12s  %.4f %.4f  |                        %.4f %.4f\n",
              rule, f29, max(abs(r)), sqrt(mean(r^2)), max(abs(re)), sqrt(mean(re^2))))
}
cat("   (circular and wrapping within each year pool the same days, so they can't be told apart)\n\n")

## 3. p90 with the best-fitting pool (circular, slot 60 interpolated).
pct_hist <- function(x, lo, hi, p = 0.9, nbins = 101) {   # CDO histGetPercentile, > 50 samples
  x <- x[x >= lo & x <= hi]                                # values outside the bounds are dropped
  step <- (hi - lo) / nbins
  b <- pmin(floor((x - lo) / step), nbins - 1)
  h <- tabulate(b + 1, nbins); s <- length(x) * p
  cs <- cumsum(h); i <- which(cs >= s)[1]
  lo + (i - (cs[i] - s) / h[i]) * step
}
cands <- list()
for (p in pxs) {
  v <- vals(p)
  P <- lapply(1:366, function(d) v[pool_idx("circular", d)])
  day <- lapply(1:366, function(d) v[inper][sl[inper] == d])      # the 30 values of each slot
  q <- cbind(sapply(1:9, function(t) sapply(P, quantile, 0.9, type = t, names = FALSE)),
             hist_runbounds = sapply(P, function(x) pct_hist(x, min(x), max(x))),
             hist_daybounds = mapply(function(x, y) pct_hist(x, min(y), max(y)), P, day),
             day30_type1 = sapply(day, quantile, 0.9, type = 1, names = FALSE),
             day30_type7 = sapply(day, quantile, 0.9, type = 7, names = FALSE))
  colnames(q)[1:9] <- paste0("pool_type", 1:9)
  q[60, ] <- colMeans(q[c(59, 61), , drop = FALSE])
  cands[[p]] <- apply(q, 2, smooth31) - refs[[p]]$p90
}
D <- do.call(rbind, cands)
cat("3. p90, rebuilt minus published (K), circular pool, slot 60 interpolated:\n")
print(data.frame(candidate = colnames(D), max_abs = signif(apply(abs(D), 2, max), 3),
                 mean = signif(colMeans(D), 3), sd = signif(apply(D, 2, sd), 3)), row.names = FALSE)
cat("   pool_type1-9: R quantile types on the 330 pooled values;\n",
    "  hist_runbounds: CDO's 101-bin histogram with ydrunmin/ydrunmax bounds (the pool's own);\n",
    "  hist_daybounds: the same with ydaymin/ydaymax bounds (pool values outside them dropped);\n",
    "  day30_*: the 30 values of each slot only, no window\n")

## 4. The rule that reproduces both: per-slot statistics of the 30 values
##    (mean; CDO's default nearest rank, ceil(n * p), which is R type 1),
##    slot 60 interpolated between 59 and 61, then an 11-day and a 31-day
##    running mean, both periodic over the 366 slots. So the "11-day window"
##    smooths per-day statistics rather than pooling values.
runk <- function(v, k) { n <- length(v); h <- (k - 1) / 2; sapply(seq_len(n), function(i) mean(v[((i - 1 + (-h:h)) %% n) + 1])) }
rec <- lapply(setNames(pxs, pxs), function(p) {
  v <- vals(p); day <- lapply(1:366, function(d) v[inper][sl[inper] == d])
  mn <- sapply(day, mean); q <- sapply(day, quantile, 0.9, type = 1, names = FALSE)
  mn[60] <- mean(mn[c(59, 61)]); q[60] <- mean(q[c(59, 61)])
  list(mean = runk(runk(mn, 11), 31), p90 = runk(runk(q, 11), 31))
})
for (v in c("mean", "p90")) {
  D <- unlist(lapply(pxs, function(p) rec[[p]][[v]] - refs[[p]][[v]]))
  cat(sprintf("4. %-8s per-slot statistic -> 11-day -> 31-day running means: max |difference| %.5f K, rms %.5f K\n",
              v, max(abs(D)), sqrt(mean(D^2))))
}
D <- unlist(lapply(pxs, function(p) (rec[[p]]$p90 - rec[[p]]$mean) - refs[[p]]$threshHW))
cat(sprintf("   threshHW (p90 - mean):                                    max |difference| %.5f K\n", max(abs(D))))
cat("   with slot 60 from its own 8 leap years instead, or type 7, the p90 is off by up to 0.03 and 0.06 K\n\n")

## 5. How far that is from a Hobday-style threshold (pooled +/-5 days,
##    linear percentile, then the 31-day running mean; days from the
##    adjacent years at the ends, as marineHeatWaves).
H <- unlist(lapply(pxs, function(p) {
  v <- vals(p); q <- sapply(1:366, function(d) quantile(v[pool_idx("adjacent", d)], 0.9, type = 7, names = FALSE))
  q[60] <- mean(q[c(59, 61)]); smooth31(q) - refs[[p]]$p90
}))
cat(sprintf("5. Hobday-style p90 minus MHW-MAD's p90: mean %+.3f K, range %+.3f to %+.3f K\n", mean(H), min(H), max(H)))
