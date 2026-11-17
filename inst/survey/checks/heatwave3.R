## Phase 0 checks: heatwave3 1.5.0 against heatwaveR 1.0.0 and 0.5.5, on
## sst_WA. The results are in heatwave3.out; the findings they settle are
## in ../heatwave3.md, "Checked by running".
##
## Rscript heatwave3.R <work dir> > heatwave3.out
##
## Needs heatwave3 1.5.0 (@8aff3e5) and heatwaveR 0.5.5 on the library
## path, and heatwaveR 1.0.0 (@e0ae30d) in a library of its own (named by
## HEATWAVER_100_LIB), so the two heatwaveR versions can be used side by
## side. Each heatwaveR run is a separate R process (callr); heatwave3
## runs in this one and reads NetCDF files written to <work dir>.
suppressPackageStartupMessages(library(heatwave3))
invisible(setHW3threads(2L))
work <- commandArgs(TRUE)[1]
dir.create(work, showWarnings = FALSE)
lib100 <- Sys.getenv("HEATWAVER_100_LIB", path.expand("~/R/heatwaveR-1.0.0"))
lib055 <- .libPaths()[1]
stopifnot(format(packageVersion("heatwave3")) == "1.5.0",
          format(packageVersion("heatwaveR", lib.loc = lib100)) == "1.0.0",
          format(packageVersion("heatwaveR")) == "0.5.5")
cp <- c("1982-01-01", "2011-12-31")
wa <- heatwaveR::sst_WA
dates <- wa$t

write_nc <- function(path, dates, x) {
  dl <- ncdf4::ncdim_def("longitude", "degrees_east", 112)
  da <- ncdf4::ncdim_def("latitude", "degrees_north", -29)
  dt <- ncdf4::ncdim_def("time", "days since 1970-01-01", as.integer(dates),
                         calendar = "standard")
  v <- ncdf4::ncvar_def("sst", "degree_Celsius", list(dl, da, dt),
                        missval = -999, prec = "double")
  nc <- ncdf4::nc_create(path, v)
  ncdf4::ncvar_put(nc, v, array(x, c(1, 1, length(x))))
  ncdf4::nc_close(nc)
  path
}

## heatwaveR in a fresh process; `clim` given means detect on it directly
run_R <- function(lib, dates, temp, maxPadLength = FALSE, clim = NULL) {
  callr::r(function(dates, temp, cp, maxPadLength, clim) {
    ts <- data.frame(t = dates, temp = temp)
    cl <- if (is.null(clim)) {
      heatwaveR::ts2clm(ts, climatologyPeriod = cp, maxPadLength = maxPadLength)
    } else {
      doy <- as.integer(format(dates, "%j"))
      leap <- (as.integer(format(dates, "%Y")) %% 4 == 0)
      doy <- ifelse(!leap & doy >= 60, doy + 1L, doy)
      cbind(ts, doy = doy, seas = clim$seas[doy], thresh = clim$thresh[doy])
    }
    de <- heatwaveR::detect_event(cl)
    list(version = format(utils::packageVersion("heatwaveR")),
         clim = cl[!duplicated(cl$doy), c("doy", "seas", "thresh")],
         event = as.data.frame(de$event))
  }, args = list(dates, temp, cp, maxPadLength, clim),
  libpath = unique(c(lib, .libPaths())))
}

run_3 <- function(path, ...) {
  stem <- tempfile(tmpdir = work)
  detect3(path, name = stem, climatologyPeriod = cp, quiet = TRUE, ...)
  ev <- hw3_export(paste0(stem, "_events.nc"))
  cd <- heatwave3:::hw3_read_clim_nc(paste0(stem, "_clim.nc"))
  list(event = ev, clim = data.frame(doy = 1:366, seas = cd$seas[1:366],
                                     thresh = cd$thresh[1:366]))
}

key <- function(e) paste(as.Date(e$date_start), as.Date(e$date_end))
cmp_events <- function(a, b, la, lb) {
  ka <- key(a); kb <- key(b)
  m <- match(ka, kb)
  ok <- !is.na(m)
  ic <- if (any(ok)) max(abs(a$intensity_cumulative[ok] -
                               b$intensity_cumulative[m[ok]])) else NA
  cat(sprintf("  %s %d events, %s %d events, %d identical in dates; max |intensity_cumulative| diff on those %.4g\n",
              la, nrow(a), lb, nrow(b), sum(ok), ic))
  show <- function(e, k, other, lab) {
    d <- e[!k %in% other, c("date_start", "date_end", "duration")]
    if (nrow(d)) {
      cat(sprintf("  only in %s:\n", lab))
      d$date_start <- as.Date(d$date_start); d$date_end <- as.Date(d$date_end)
      print(utils::head(d, 12), row.names = FALSE)
      if (nrow(d) > 12) cat(sprintf("  ... %d more\n", nrow(d) - 12))
    }
  }
  show(a, ka, kb, la); show(b, kb, ka, lb)
  invisible(ok)
}
cmp_clim <- function(a, b, la, lb) {
  a <- a[order(a$doy), ]; b <- b[order(b$doy), ]
  ds <- a$seas - b$seas; dt <- a$thresh - b$thresh
  bad <- which(ds != 0 | dt != 0)
  cat(sprintf("  climatology %s vs %s: %d of 366 doys differ; max |seas| %.4g, max |thresh| %.4g\n",
              la, lb, length(bad), max(abs(ds)), max(abs(dt))))
  if (length(bad)) {
    md <- format(as.Date(bad - 1, origin = "2000-01-01"), "%d %b")
    cat("  differing doys:", if (length(bad) <= 60) paste(md, collapse = ", ")
        else paste(length(bad), "doys, from", md[1], "to", md[length(md)]), "\n")
  }
  invisible(bad)
}

## 4. Gap-free -----------------------------------------------------------------
cat("\n## 4. gap-free sst_WA\n")
f4 <- write_nc(file.path(work, "clean.nc"), dates, wa$temp)
h3 <- run_3(f4)
r1 <- run_R(lib100, dates, wa$temp)
r0 <- run_R(lib055, dates, wa$temp)
cat("  heatwaveR versions run:", r1$version, r0$version, "\n")
cmp_clim(h3$clim, r1$clim, "heatwave3", "1.0.0")
cmp_clim(r1$clim, r0$clim, "1.0.0", "0.5.5")
cmp_events(h3$event, r1$event, "heatwave3", "1.0.0")
cmp_events(r1$event, r0$event, "1.0.0", "0.5.5")

cat("\n## 4b. series ending 1 day after an event (trailing gap)\n")
e_end <- as.Date(r1$event$date_end)
cutday <- max(e_end[e_end < as.Date("2021-01-01")]) + 1
keep <- dates <= cutday
cat("  series truncated to", format(cutday), "\n")
f4b <- write_nc(file.path(work, "trunc.nc"), dates[keep], wa$temp[keep])
h3b <- run_3(f4b)
r1b <- run_R(lib100, dates[keep], wa$temp[keep])
r0b <- run_R(lib055, dates[keep], wa$temp[keep])
cmp_events(h3b$event, r1b$event, "heatwave3", "1.0.0")
cmp_events(r1b$event, r0b$event, "1.0.0", "0.5.5")

## 1. Gaps inside heatwaves, maxPadLength = 2 ----------------------------------
cat("\n## 1. 1-2 day gaps inside events of 10+ days, maxPadLength = 2\n")
ev <- r1$event[r1$event$duration >= 10, ]
g1 <- wa$temp
for (i in seq_len(nrow(ev))) {
  s <- which(dates == as.Date(ev$date_start[i]))
  off <- if (i %% 2) 2L else c(ev$duration[i] %/% 2L, ev$duration[i] %/% 2L + 1L)
  g1[s + off] <- NA
}
cat(sprintf("  %d events of 10+ days; %d days set missing\n", nrow(ev), sum(is.na(g1))))
f1 <- write_nc(file.path(work, "gaps_in_events.nc"), dates, g1)
h31 <- run_3(f1, maxPadLength = 2L)
r11 <- run_R(lib100, dates, g1, maxPadLength = 2)
cmp_events(h31$event, r11$event, "heatwave3", "1.0.0")
cmp_clim(h31$clim, r11$clim, "heatwave3", "1.0.0")
k <- key(ev)
cat(sprintf("  gapped events unchanged: heatwave3 %d of %d, 1.0.0 %d of %d\n",
            sum(k %in% key(h31$event)), length(k),
            sum(k %in% key(r11$event)), length(k)))
cat("  heatwave3 vs heatwaveR 1.0.0 detecting on the gapped series without\n",
    " interpolation, with heatwave3's climatology:\n")
rN <- run_R(lib100, dates, g1, clim = h31$clim)
cmp_events(h31$event, rN$event, "heatwave3", "1.0.0 no interp")

## 2. Gaps in the climatology period, no interpolation -------------------------
cat("\n## 2. missing runs of 1-5 days in the climatology period, maxPadLength = FALSE\n")
set.seed(20261117)
g2 <- wa$temp
in_cp <- which(dates <= as.Date(cp[2]))
starts <- sample(in_cp, 120)
for (s in starts) g2[s + seq_len(sample(1:5, 1)) - 1L] <- NA
cat(sprintf("  %d days set missing (%.1f%% of the climatology period)\n",
            sum(is.na(g2)), 100 * sum(is.na(g2)) / length(in_cp)))
f2 <- write_nc(file.path(work, "gaps_in_clim.nc"), dates, g2)
h32 <- run_3(f2)
r12 <- run_R(lib100, dates, g2)
cmp_clim(h32$clim, r12$clim, "heatwave3", "1.0.0")
cmp_events(h32$event, r12$event, "heatwave3", "1.0.0")

## 3. Detrend ------------------------------------------------------------------
cat("\n## 3. sst_WA + 0.04 degC/yr, detrend = TRUE\n")
yrs <- as.numeric(dates - as.Date("1982-01-01")) / 365.25
g3 <- wa$temp + 0.04 * yrs
f3 <- write_nc(file.path(work, "trend.nc"), dates, g3)
h3t <- run_3(f3, detrend = TRUE)
h3f <- run_3(f3, detrend = FALSE)
## detrended series: least squares over the climatology period, centred there
inc <- dates >= as.Date(cp[1]) & dates <= as.Date(cp[2])
tt <- as.numeric(dates)
b <- coef(lm(g3[inc] ~ tt[inc]))[2]
mid <- mean(range(tt[inc]))
g3d <- g3 - b * (tt - mid)
cat(sprintf("  fitted slope %.4f degC/yr\n", b * 365.25))
rd <- run_R(lib100, dates, g3d)
cmp_clim(h3t$clim, rd$clim, "heatwave3 detrend", "1.0.0 on detrended series")
cat("  (a) heatwave3 detrend events vs heatwaveR on the RAW series with heatwave3's detrended climatology:\n")
rr <- run_R(lib100, dates, g3, clim = h3t$clim)
cmp_events(h3t$event, rr$event, "heatwave3 detrend", "raw+hw3clim")
cat("  (b) heatwave3 detrend events vs heatwaveR on the DETRENDED series (Jacox-style):\n")
cmp_events(h3t$event, rd$event, "heatwave3 detrend", "detrended")
dec <- function(e) {
  d <- as.Date(e$date_start)
  tapply(e$duration, cut(d, as.Date(c("1982-01-01", "1992-01-01", "2002-01-01",
                                      "2012-01-01", "2023-01-01"))), sum)
}
cat("  event days by decade (start):\n")
print(rbind(`heatwave3 detrend = TRUE` = dec(h3t$event),
            `heatwave3 detrend = FALSE` = dec(h3f$event),
            `detrended series` = dec(rd$event)))
