## A small subset of MHW-MAD, stored as the oracle for the join-first
## rule order (tests/testthat/test-order.R).
##
## MHW-MAD: Hayward, A. et al. (2026). Marine Heat Waves and Cold Spells -
## Multiple Analysis/Definitions (MHW-MAD): A Multi-Definition Global
## Marine Heatwave Database from Satellite Sea Surface Temperature Data.
## Earth Syst. Sci. Data 18, 7181-7197, doi:10.5194/essd-18-7181-2026.
## Data: doi:10.5281/zenodo.21835325 (Danish Meteorological Institute),
## licence CC-BY 4.0, served by DMI ERDDAP (erddap.dmi.dk).
##
## The subset: nine Tasman Sea pixels (150-154 E, 39-43 S, every 2
## degrees) for 2015-2016, the WMO climatology (1991-2020) products:
## the SST anomaly, the heatwave threshold relative to the mean
## (threshHW, the 90th and 95th percentiles) per day of year, and the
## per-day categories (cat_HW) of the 90th percentile with 5-, 10- and
## 30-day minimum durations, and of the 95th with 5. These are the
## datasets inst/survey/checks/mhw-mad.R reads.
##
## Rscript data-raw/mhw-mad.R [cache-dir]     (from the package root)
##
## Reads the ERDDAP CSV files from cache-dir if they're there, otherwise
## fetches them into it (default: a temporary directory). Writes
## tests/testthat/fixtures/mhw-mad.rds.
args <- commandArgs(TRUE)
cache <- if (length(args)) args[1] else file.path(tempdir(), "mhw-mad")
dir.create(cache, showWarnings = FALSE, recursive = TRUE)
options(timeout = 1800)
out <- file.path("tests", "testthat", "fixtures", "mhw-mad.rds")
stopifnot(dir.exists(dirname(out)))

erddap <- "https://erddap.dmi.dk/erddap/griddap/"
box <- "[(-43.025):40:(-39.025)][(150.025):40:(154.025)]"
fetch <- function(id, vars, doy = FALSE) {
  f <- file.path(cache, paste0(id, ".csv"))
  if (!file.exists(f)) {
    tsel <- if (doy) "[(1):1:(366)]" else "[(2015-01-01T12:00:00Z):1:(2016-12-31T12:00:00Z)]"
    q <- paste(paste0(vars, tsel, box), collapse = ",")
    q <- gsub("\\[", "%5B", gsub("\\]", "%5D", q))
    download.file(paste0(erddap, id, ".csv?", q), paste0(f, ".part"), quiet = TRUE, method = "libcurl")
    file.rename(paste0(f, ".part"), f)
  }
  hdr <- names(utils::read.csv(f, nrows = 1))
  d <- utils::read.csv(f, skip = 2, header = FALSE, col.names = hdr)
  d$px <- sprintf("%.3f,%.3f", d$longitude, d$latitude)
  d
}
## one column per pixel, rows by time (or day of year)
spread <- function(d, var, key) {
  px <- unique(d$px)
  keys <- sort(unique(d[[key]]))
  m <- vapply(px, function(p) {
    s <- d[d$px == p, ]
    s[[var]][match(keys, s[[key]])]
  }, numeric(length(keys)))
  dimnames(m) <- list(NULL, px)
  m
}

anom <- fetch("mhw_raw_wmoClim_90p_10d_anom", "anom")   # no 5d anomaly dataset is published
an95 <- fetch("mhw_raw_wmoClim_95p_5d_anom", "anom")
stopifnot(isTRUE(all.equal(anom$anom, an95$anom, tolerance = 0)))   # the same anomalies
cl90 <- fetch("mhw_raw_wmoClim_90p_clim", c("mean", "p90", "threshHW"), doy = TRUE)
cl95 <- fetch("mhw_raw_wmoClim_95p_clim", c("mean", "threshHW"), doy = TRUE)
cats <- list(p90_5d = fetch("mhw_raw_wmoClim_90p_5d_cat", "cat_HW"),
             p90_10d = fetch("mhw_raw_wmoClim_90p_10d_cat", "cat_HW"),
             p90_30d = fetch("mhw_raw_wmoClim_90p_30d_cat", "cat_HW"),
             p95_5d = fetch("mhw_raw_wmoClim_95p_5d_cat", "cat_HW"))

dates <- as.Date(substr(sort(unique(anom$time)), 1, 10))
stopifnot(identical(as.numeric(dates), as.numeric(seq(as.Date("2015-01-01"), as.Date("2016-12-31"), by = "day"))))
x <- spread(anom, "anom", "time")
## the categories are stored as floats a little off whole numbers (up to
## 3.1e-05; inst/survey/mhw-mad.md)
category <- lapply(cats, function(d) {
  m <- spread(d, "cat_HW", "time")
  stopifnot(identical(colnames(m), colnames(x)), max(abs(m - round(m))) < 1e-4)
  m <- round(m)
  storage.mode(m) <- "integer"
  m
})
thresh <- list(p90 = spread(cl90, "threshHW", "dayofyear"), p95 = spread(cl95, "threshHW", "dayofyear"))
stopifnot(all(vapply(thresh, nrow, 0L) == 366L), identical(colnames(thresh$p90), colnames(x)))

saveRDS(list(
  meta = list(
    source = paste("MHW-MAD (Hayward et al. 2026, Earth Syst. Sci. Data 18, 7181-7197,",
                   "doi:10.5194/essd-18-7181-2026), data doi:10.5281/zenodo.21835325,",
                   "Danish Meteorological Institute, via DMI ERDDAP"),
    licence = "CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)",
    subset = "nine Tasman Sea pixels (150-154 E, 39-43 S, 2 degrees apart), 2015-2016, WMO climatology 1991-2020",
    datasets = c("mhw_raw_wmoClim_90p_10d_anom", "mhw_raw_wmoClim_90p_clim",
                 "mhw_raw_wmoClim_95p_clim", paste0("mhw_raw_wmoClim_", c("90p_5d", "90p_10d",
                                                                         "90p_30d", "95p_5d"), "_cat")),
    note = "cat_HW rounded to whole numbers; threshHW is the threshold minus the mean, by day of year",
    generated = Sys.Date(), script = "data-raw/mhw-mad.R"),
  dates = dates, anom = unname(x), pixels = colnames(x),
  thresh = lapply(thresh, unname), category = lapply(category, unname)),
  out, compress = "xz")
cat("wrote", out, file.size(out), "bytes:", ncol(x), "pixels,", length(dates), "days\n")
