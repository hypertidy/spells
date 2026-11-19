## Golden outputs for spells' parity tests: the input cases, and what
## heatwaveR 0.5.5, heatwaveR 1.0.0 and heatwave3 1.5.0 make of them, as
## heatwaves and as cold spells.
## The tests read the stored files, so they need none of the three.
##
## Rscript data-raw/golden.R      (from the package root)
##
## Writes tests/testthat/fixtures/cases.rds and
## tests/testthat/fixtures/golden-<engine>-<version>.rds.
##
## Also stores what trend.sst's own R/mhw.R (the code spells is extracted
## from) makes of the cases, so trend.sst can move onto spells knowing
## nothing it publishes changes. TREND_SST names its clone (default
## ~/Git/trend.sst); the file records the commit R/mhw.R was taken from.
##
## Needs heatwaveR 0.5.5 and heatwave3 1.5.0 (@8aff3e5) on the library
## path, and heatwaveR 1.0.0 (@e0ae30d, GitHub only) in a library of its
## own, named by HEATWAVER_100_LIB (default ~/R/heatwaveR-1.0.0). Each
## heatwaveR run is a separate R process (callr), so the two versions
## never share a session; heatwave3 reads NetCDF files written to a
## temporary directory.
##
## The input series are heatwaveR's sst_WA, sst_Med and sst_NW_Atl
## (NOAA OISST v2.1, 1982-2022), the same in 0.5.5 and 1.0.0.
suppressPackageStartupMessages(library(heatwave3))
invisible(setHW3threads(2L))
lib100 <- Sys.getenv("HEATWAVER_100_LIB", path.expand("~/R/heatwaveR-1.0.0"))
lib055 <- .libPaths()[1]
stopifnot(format(packageVersion("heatwave3")) == "1.5.0",
          format(packageVersion("heatwaveR", lib.loc = lib100)) == "1.0.0",
          format(packageVersion("heatwaveR", lib.loc = lib055)) == "0.5.5")
out <- file.path("tests", "testthat", "fixtures")
stopifnot(dir.exists(out))
work <- tempfile("golden"); dir.create(work)

## --- the input cases ------------------------------------------------------
e <- new.env()
data(list = c("sst_WA", "sst_Med", "sst_NW_Atl"), package = "heatwaveR",
     lib.loc = lib055, envir = e)
dates <- e$sst_WA$t
stopifnot(identical(dates, e$sst_Med$t), identical(dates, e$sst_NW_Atl$t),
          all(diff(dates) == 1))
oisst <- cbind(WA = e$sst_WA$temp, Med = e$sst_Med$temp, NW_Atl = e$sst_NW_Atl$temp)
ref_hw <- as.Date(c("1982-01-01", "2011-12-31"))    # heatwaveR's examples
ref_wmo <- as.Date(c("1991-01-01", "2020-12-31"))   # WMO normal: years either side
upto <- function(end) dates <= as.Date(end)
na_at <- function(x, from, to) {
  x[dates >= as.Date(from) & dates <= as.Date(to)] <- NA; x
}
## NA runs after the reference period (wa_gaps) and inside it
## (wa_refgaps, where heatwaveR fills each missing day from that slot's
## mean across the years and heatwave3 leaves it out of the window).
## trend.sst's R/mhw.R stops on a gap inside the reference period.
## Event dates are 0.5.5's on sst_WA with ref_hw.
wa_gaps <- oisst[, "WA"]
wa_gaps <- na_at(wa_gaps, "2012-02-15", "2012-02-15")   # 1 day inside a 101-day event
wa_gaps <- na_at(wa_gaps, "2015-09-28", "2015-09-30")   # first 3 days of a 7-day event
wa_gaps <- na_at(wa_gaps, "2016-06-01", "2016-06-15")   # 15 days, no event near
wa_gaps <- na_at(wa_gaps, "2020-10-01", "2020-10-02")   # 2 days inside a 21-day event
wa_gaps <- na_at(wa_gaps, "2022-03-01", "2022-03-10")   # 10 days inside a 58-day event
wa_gaps <- na_at(wa_gaps, "2022-12-30", "2022-12-31")   # the last 2 days
wa_refgaps <- oisst[, "WA"]
wa_refgaps <- na_at(wa_refgaps, "1982-01-01", "1982-01-04") # the first days: the shortened windows' edge
wa_refgaps <- na_at(wa_refgaps, "1988-02-28", "1988-03-01") # a leap year's 29 February and both neighbours
wa_refgaps <- na_at(wa_refgaps, "1990-02-28", "1990-02-28") # a non-leap year's 28 February: slot 60 from 1 March alone
wa_refgaps <- na_at(wa_refgaps, "1995-06-01", "1995-07-15") # 45 days
wa_refgaps <- na_at(wa_refgaps, "2011-12-25", "2011-12-31") # the reference period's last week

## wa_levels: sst_WA with three stretches after the reference period set
## from heatwaveR 0.5.5's own climatology (mid-year, where 0.5.5's and
## 1.0.0's agree), to tell the category rules apart. Each is in category
## I (1.5 x the threshold's distance from the baseline, to 2 decimals)
## between 3 days at the baseline, except for:
##  - 250 days with one day in IV: heatwaveR's event category is the
##    highest whose share of days, rounded to a whole percent, is above
##    zero, so I;
##  - 10 days with one day exactly on the II level: at or above it
##    (heatwaveR's event share) but not above it (its daily category);
##  - 10 days with days 0.00003 above the threshold and the II level and
##    0.00003 below the III level: heatwaveR's category() rounds the
##    value to 4 decimals before comparing, heatwave3 doesn't.
clim055 <- callr::r(function(t, temp, ref) {
  heatwaveR::ts2clm(data.frame(t = t, temp = temp), climatologyPeriod = ref)
}, args = list(dates, oisst[, "WA"], ref_hw), libpath = unique(c(lib055, .libPaths())))
stopifnot(identical(as.numeric(clim055$t), as.numeric(dates)))
lv <- with(clim055, {
  d <- round(thresh - seas, 4)
  l2 <- round(thresh + d, 4); l3 <- round(l2 + d, 4)
  list(seas = seas, d = thresh - seas, l1 = thresh, l2 = l2, l3 = l3)
})
stretch <- function(x, from, n, at = list()) {
  i <- which(dates == as.Date(from)) + seq_len(n) - 1L
  edge <- c(i[1] - 3:1, i[n] + 1:3)
  x[edge] <- lv$seas[edge]
  x[i] <- round(lv$seas[i] + 1.5 * lv$d[i], 2)
  for (k in names(at)) {
    j <- i[as.integer(k)]
    x[j] <- at[[k]](j)
  }
  x
}
wa_levels <- oisst[, "WA"]
wa_levels <- stretch(wa_levels, "2013-03-01", 250,
                     list("125" = function(j) round(lv$seas[j] + 4.5 * lv$d[j], 2)))
wa_levels <- stretch(wa_levels, "2014-05-01", 10, list("5" = function(j) lv$l2[j]))
wa_levels <- stretch(wa_levels, "2015-05-01", 10,
                     list("2" = function(j) lv$l1[j] + 3e-5, "4" = function(j) lv$l2[j] + 3e-5,
                          "7" = function(j) lv$l3[j] - 3e-5))

case <- function(x, keep = rep(TRUE, length(dates)), reference = ref_hw,
                 detect_from = NULL, note) {
  x <- as.matrix(x); if (is.null(colnames(x))) colnames(x) <- "WA"
  list(dates = dates[keep], x = x[keep, , drop = FALSE], reference = reference,
       detect_from = if (!is.null(detect_from)) as.Date(detect_from), note = note)
}
cases <- list(
  oisst3 = case(oisst, note = "three complete series as one time x series matrix"),
  wa_wmo = case(oisst[, "WA", drop = FALSE], reference = ref_wmo,
                note = "reference period with years on both sides (0.5.5 and 1.0.0 differ at the new year)"),
  wa_gaps = case(wa_gaps, note = "NA runs of 1-15 days after the reference period, inside, at the start of, and away from events, and at the series end"),
  wa_tail1 = case(oisst[, "WA", drop = FALSE], upto("2021-08-31"),
                  note = "ends 1 day after an event (2021-08-23 to 08-30)"),
  wa_tail2 = case(oisst[, "WA", drop = FALSE], upto("2022-06-26"),
                  note = "ends 2 days after an event (2022-06-12 to 06-24)"),
  wa_midevent = case(oisst[, "WA", drop = FALSE], upto("2022-04-01"),
                     note = "ends inside an event (2022-02-14 to 04-12)"),
  wa_lead = case(oisst[, "WA", drop = FALSE], detect_from = "2012-01-08",
                 note = "baseline from the whole series; detection on the series from 2012-01-08, 2 days before an event (2012-01-10 to 04-19)"),
  wa_refgaps = case(wa_refgaps, note = "NA runs inside the reference period: its first days, a leap year's 28 Feb to 1 Mar, a non-leap 28 Feb, 45 days, its last week"),
  wa_levels = case(wa_levels, note = "stretches set on the category levels: a 250-day spell with one day in IV, a day exactly on the II level, days 0.00003 either side of a level")
)

## --- heatwaveR, one process per version -----------------------------------
## cold: cold spells, the 10th percentile and coldSpells = TRUE (with
## category()'s defaults: no MCScorrect, no MCSice)
run_heatwaveR <- function(lib, cs, cold = FALSE) {
  callr::r(function(cs, cold) {
    one <- function(dates, temp, reference, detect_from) {
      ts <- data.frame(t = dates, temp = temp)
      cl <- heatwaveR::ts2clm(ts, climatologyPeriod = reference, pctile = if (cold) 10 else 90)
      if (!is.null(detect_from)) cl <- cl[cl$t >= detect_from, ]
      de <- heatwaveR::detect_event(cl, coldSpells = cold)
      ca <- heatwaveR::category(de, climatology = TRUE)
      dc <- de$climatology
      daycat <- ca$climatology$category[match(dc$t, ca$climatology$t)]
      list(clim = as.data.frame(cl[!duplicated(cl$doy), c("doy", "seas", "thresh")]),
           day = data.frame(t = dc$t, event = dc$event, event_no = dc$event_no,
                            category = daycat),
           events = as.data.frame(de$event),
           categories = as.data.frame(ca$event))
    }
    res <- lapply(cs, function(k) lapply(seq_len(ncol(k$x)), function(j)
      one(k$dates, k$x[, j], k$reference, k$detect_from)))
    list(version = format(utils::packageVersion("heatwaveR")),
         path = find.package("heatwaveR"), cases = res)
  }, args = list(cs, cold), libpath = unique(c(lib, .libPaths())))
}

## --- heatwave3, from NetCDF ------------------------------------------------
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
## detect3() fits and detects in one call, with its event categories. For a detection window cut
## from a longer series (wa_lead), detect_event3() reads the stored
## climatology and only the window's dates (time_range).
## detrend: detect3(detrend = TRUE), a linear trend removed for the
## climatology only (detection reads the raw SST)
run_heatwave3 <- function(cs, cold = FALSE, detrend = FALSE) {
  one <- function(dates, temp, reference, detect_from) {
    stem <- tempfile(tmpdir = work)
    path <- write_nc(paste0(stem, "_in.nc"), dates, temp)
    detect3(path, name = stem, climatologyPeriod = format(reference), category = TRUE,
            pctile = if (cold) 10 else 90, coldSpells = cold, detrend = detrend,
            daily = "also", quiet = TRUE)
    if (!is.null(detect_from)) {
      stem2 <- paste0(stem, "_window")
      detect_event3(path, name = stem2, clim_file = paste0(stem, "_clim.nc"),
                    time_range = format(c(detect_from, max(dates))), category = TRUE,
                    coldSpells = cold, daily = "also", quiet = TRUE)
    } else stem2 <- stem
    cd <- heatwave3:::hw3_read_clim_nc(paste0(stem, "_clim.nc"))
    dd <- as.data.frame(hw3_export(paste0(stem2, "_events_daily.nc")))
    list(clim = data.frame(doy = 1:366, seas = cd$seas[1:366], thresh = cd$thresh[1:366]),
         day = data.frame(t = as.Date(dd$t), event = dd$event, event_no = dd$event_no,
                          category = dd$category),
         events = as.data.frame(hw3_export(paste0(stem2, "_events.nc"))))
  }
  lapply(cs, function(k) lapply(seq_len(ncol(k$x)), function(j)
    one(k$dates, k$x[, j], k$reference, k$detect_from)))
}

## --- trend.sst's R/mhw.R ----------------------------------------------------
run_trend_sst <- function(cs, root) {
  env <- new.env()
  sys.source(file.path(root, "R", "mhw.R"), envir = env)
  lapply(cs, function(k) {
    inb <- k$dates >= k$reference[1] & k$dates <= k$reference[2]
    if (anyNA(k$x[inb, ])) return(NULL)     # mhw_clim() stops: nothing to store
    clim <- env$mhw_clim(k$x, k$dates, k$reference)
    keep <- if (is.null(k$detect_from)) rep(TRUE, length(k$dates)) else k$dates >= k$detect_from
    det <- env$mhw_detect(k$x[keep, , drop = FALSE], k$dates[keep], clim)
    list(seas = clim$seas, thresh = clim$thresh, t = k$dates[keep],
         event = det$event, category = det$category)
  })
}
tsst <- Sys.getenv("TREND_SST", path.expand("~/Git/trend.sst"))
tsst_commit <- system2("git", c("-C", tsst, "log", "-1", "--format=%h", "--", "R/mhw.R"), stdout = TRUE)
stopifnot(length(system2("git", c("-C", tsst, "status", "--porcelain", "--", "R/mhw.R"), stdout = TRUE)) == 0)

meta <- function(engine, version, source) {
  list(engine = engine, version = version, source = source,
       generated = Sys.Date(), R = R.version.string, script = "data-raw/golden.R")
}
h055 <- run_heatwaveR(lib055, cases)
h100 <- run_heatwaveR(lib100, cases)
stopifnot(h055$version == "0.5.5", h100$version == "1.0.0")
c055 <- run_heatwaveR(lib055, cases, cold = TRUE)
c100 <- run_heatwaveR(lib100, cases, cold = TRUE)
## wa_levels' stretches are where 0.5.5's and 1.0.0's climatologies agree
at <- unique(clim055$doy[cases$wa_levels$x[, 1] != oisst[, "WA"]])
clim_at <- function(h) with(h$cases$wa_levels[[1]]$clim, cbind(seas, thresh)[match(at, doy), ])
stopifnot(identical(clim_at(h055), clim_at(h100)))
h3 <- run_heatwave3(cases)
c3 <- run_heatwave3(cases, cold = TRUE)
d3 <- run_heatwave3(cases, detrend = TRUE)
ts <- run_trend_sst(cases, tsst)

saveRDS(cases, file.path(out, "cases.rds"), compress = "xz")
## cases: heatwaves (90th percentile); cold: cold spells (10th, coldSpells);
## detrend (heatwave3 only): heatwaves with detect3(detrend = TRUE)
saveRDS(list(meta = meta("heatwaveR", "0.5.5", "CRAN"), cases = h055$cases, cold = c055$cases),
        file.path(out, "golden-heatwaveR-0.5.5.rds"), compress = "xz")
saveRDS(list(meta = meta("heatwaveR", "1.0.0", "GitHub robwschlegel/heatwaveR @e0ae30d"),
             cases = h100$cases, cold = c100$cases),
        file.path(out, "golden-heatwaveR-1.0.0.rds"), compress = "xz")
saveRDS(list(meta = meta("heatwave3", "1.5.0", "GitHub @8aff3e5"), cases = h3, cold = c3,
             detrend = d3),
        file.path(out, "golden-heatwave3-1.5.0.rds"), compress = "xz")
saveRDS(list(meta = meta("trend.sst R/mhw.R", tsst_commit,
                         paste("mdsumner/trend.sst, R/mhw.R as of", tsst_commit)), cases = ts),
        file.path(out, "golden-trend.sst.rds"), compress = "xz")

## a short record of what was written
for (nm in names(cases)) {
  k <- cases[[nm]]
  ev <- function(g) if (is.null(g)) "-" else paste(sapply(g, function(s) nrow(s$events)), collapse = "/")
  cat(sprintf("%-12s %s to %s, %d series, reference %s to %s; events 0.5.5 %s, 1.0.0 %s, heatwave3 %s; cold spells %s, %s, %s\n",
              nm, format(min(k$dates)), format(max(k$dates)), ncol(k$x),
              format(k$reference[1]), format(k$reference[2]),
              ev(h055$cases[[nm]]), ev(h100$cases[[nm]]), ev(h3[[nm]]),
              ev(c055$cases[[nm]]), ev(c100$cases[[nm]]), ev(c3[[nm]])))
}
print(file.info(list.files(out, full.names = TRUE))[, "size", drop = FALSE])
