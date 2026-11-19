## Generality gate 1: the sea ice season (Massom et al. 2013) through
## spells, against trend.ice's published COGs.
##
## trend.ice (mdsumner/trend.ice) computes the season per 25 km pixel and
## ice year (15 Feb to 14 Feb) from the NOAA-NSIDC Climate Data Record of
## Passive Microwave Sea Ice Concentration, Version 6 (G02202,
## doi:10.7265/b18j-z797; "No constraints on data access or use"), and
## publishes one Int16 COG per ice year with seven layers (advance,
## retreat, duration, daycount, ice_at_start, ice_at_end, n_missing) to
## Pawsey Acacia, aad-derived/trend-ice/iceseason_t15/ (anonymous read).
## The published files were made by its R/ice_season.R at d5be6df,
## reading every date as it is; its rules (ice_season()) are unchanged
## since, and its reading now drops dates with an empty field and
## interpolates them (72ccc0f).
##
## For each ice year 1979-2025 this script:
##  1. reads the CDR as d5be6df's read_ice_obs() does (raadtools), or
##     from the cache;
##  2. runs massom2013(parity = "trend.ice-d5be6df"), maps its season
##     summaries to the seven layers, and compares every pixel with the
##     published COG;
##  3. reads as trend.ice's current read_ice_obs() and fill_daily() do
##     (empty dates dropped, runs of 5 or fewer interpolated, a longer
##     one refuses the year), and compares spells with trend.ice's own
##     ice_season() on that input;
##  4. runs the clean massom2013() on the d5be6df read, and counts the
##     pixels whose layers differ from the published ones.
## Then it writes tests/testthat/fixtures/massom2013.rds: 230 pixels in
## three ice years (1982, with missing pixel-days; 1984, with 13 empty
## days, published as open water; 2001), their inputs and published
## layers, and the per-year results.
##
## Needs a machine that sees the raadtools ice collection (or a cache of
## the reads), the trend.ice clone (TREND_ICE, default ~/Git/trend.ice),
## terra, mirai, devtools. ICESEASON names a directory of the COGs
## instead of Acacia.
##
## Rscript data-raw/massom2013.R [cache-dir] [workers]     (from the package root)
args <- commandArgs(TRUE)
cache <- if (length(args)) args[1] else file.path(tempdir(), "massom2013")
workers <- if (length(args) > 1) as.integer(args[2]) else 4L
dir.create(cache, showWarnings = FALSE, recursive = TRUE)
out <- file.path("tests", "testthat", "fixtures", "massom2013.rds")
stopifnot(dir.exists(dirname(out)))
tice <- Sys.getenv("TREND_ICE", path.expand("~/Git/trend.ice"))
cog_dir <- Sys.getenv("ICESEASON",
                      "/vsicurl/https://projects.pawsey.org.au/aad-derived/trend-ice/iceseason_t15")
commits <- c(published = "d5be6df", current = "72ccc0f")
src <- vapply(commits, function(cm) {
  f <- file.path(cache, paste0("ice_season_", cm, ".R"))
  writeLines(system2("git", c("-C", tice, "show", paste0(cm, ":R/ice_season.R")), stdout = TRUE), f)
  stopifnot(!any(grepl("spells::", readLines(f), fixed = TRUE)))
  f
}, "")

one_year <- function(year, src, cache, cog_dir) {
  ## The seven layers from spells' season summaries (one season)
  massom_layers <- function(s) {
    day <- function(d) as.integer(d - s$season_start) + 1L
    data_cut <- function(by) !is.na(by) & !by %in% c("series", "season")
    advance <- day(s$first_start)
    advance[data_cut(s$first_start_cut_by)] <- NA
    retreat <- day(s$last_end) + 1L
    retreat[!is.na(s$last_end_cut_by)] <- NA
    data.frame(advance = advance, retreat = retreat, duration = retreat - advance,
               daycount = s$n_beyond, ice_at_start = as.integer(s$beyond_first),
               ice_at_end = as.integer(s$beyond_last), n_missing = s$n_missing)
  }
  run_spells <- function(m, dates, def) {
    x <- t(m)
    b <- spells::spell_baseline(x, dates, def)
    massom_layers(spells::spell_summary(x, dates, b, spells::spell_mask(x, dates, b)))
  }
  ## pixels differing, per layer (NA patterns included)
  n_differ <- function(a, b) {
    vapply(names(a), function(v) sum(xor(is.na(a[[v]]), is.na(b[[v]])) |
                                       (!is.na(a[[v]]) & !is.na(b[[v]]) & a[[v]] != b[[v]])), 0L)
  }
  pub <- new.env(); sys.source(src[["published"]], envir = pub)
  cur <- new.env(); sys.source(src[["current"]], envir = cur)
  dates <- pub$ice_year_dates(year)
  cf <- file.path(cache, sprintf("ice_%d.rds", year))
  if (file.exists(cf)) {
    raw <- readRDS(cf)
  } else {
    for (try in 1:4) {     # the network store fails a read now and then under load
      raw <- tryCatch(pub$read_ice_obs(dates), error = function(e) e)
      if (!inherits(raw, "error")) break
      Sys.sleep(10 * try)
    }
    if (inherits(raw, "error")) stop(year, ": ", conditionMessage(raw))
    raw <- list(year = year, dates = dates, obs_dates = raw$obs_dates, m = raw$m)
    saveRDS(raw, cf, compress = "gzip")
  }
  res <- list(year = year, n_dates = length(dates))
  ## 2. parity, on the published files' read
  m <- pub$fill_daily(raw$m, raw$obs_dates, dates)
  par <- run_spells(m, dates, spells::massom2013(parity = "trend.ice-d5be6df"))
  cog <- file.path(cog_dir, sprintf("south_iceseason_t15_%d-02-15.tif", year))
  g <- tryCatch(terra::values(terra::rast(cog), mat = TRUE), error = function(e) NULL)
  res$published <- !is.null(g)
  if (!is.null(g)) {
    g <- as.data.frame(matrix(as.integer(g), nrow(g), dimnames = list(NULL, colnames(g))))
    res$parity_identical <- identical(par, g[names(par)])
    res$parity_differ <- sum(n_differ(par, g[names(par)]))
  }
  ## 3. trend.ice's current reading, and its own rules on it
  nvalid <- colSums(!is.na(raw$m))
  keep <- nvalid >= 0.5 * stats::median(nvalid)
  res$n_empty_dates <- sum(!keep)
  mc <- cur$fill_daily(raw$m[, keep, drop = FALSE], raw$obs_dates[keep], dates)
  res$current_computed <- !is.null(mc)
  if (!is.null(mc)) {
    tc <- cur$ice_season(mc)
    sc <- run_spells(mc, dates, spells::massom2013(parity = "trend.ice-d5be6df"))
    res$current_identical <- identical(sc, tc)
    if (!is.null(g)) res$current_vs_published <- sum(n_differ(tc, g[names(tc)]))
  }
  ## 4. the clean rules on the same read
  if (!is.null(g)) {
    cl <- run_spells(m, dates, spells::massom2013())
    d <- n_differ(cl, g[names(cl)])
    res[paste0("clean_", names(d))] <- as.list(d)
  }
  as.data.frame(res)
}

mirai::daemons(workers)
mirai::everywhere({ setwd(wd); suppressMessages(devtools::load_all(quiet = TRUE)) }, wd = getwd())
t0 <- Sys.time()
years_run <- if (nzchar(Sys.getenv("YEARS"))) as.integer(strsplit(Sys.getenv("YEARS"), ",")[[1]]) else 1979:2025
gate <- mirai::mirai_map(years_run, one_year,
                         .args = list(src = src, cache = cache, cog_dir = cog_dir))[.stop]
mirai::daemons(0)
cols <- unique(unlist(lapply(gate, names)))
gate <- do.call(rbind, lapply(gate, function(r) { r[setdiff(cols, names(r))] <- NA; r[cols] }))
message(sprintf("done in %.1f min", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
print(gate, row.names = FALSE)
cat("\npublished ice years:", sum(gate$published), "; spells parity identical on all seven layers:",
    sum(gate$parity_identical, na.rm = TRUE), "\n")
cat("trend.ice's current reading: computed", sum(gate$current_computed), "years; spells identical to",
    "its ice_season():", sum(gate$current_identical, na.rm = TRUE), "\n")

## The stored subset: 230 pixels, stratified on the 2001 layers, plus
## pixels with missing days in 1982
set.seed(20261119)
g01 <- terra::values(terra::rast(file.path(cog_dir, "south_iceseason_t15_2001-02-15.tif")), mat = TRUE)
r82 <- readRDS(file.path(cache, "ice_1982.rds"))
sea <- !is.na(g01[, "n_missing"])
partial82 <- which(rowSums(is.na(r82$m)) > 0 & rowSums(!is.na(r82$m)) > 0)
pick <- function(ok, n) { k <- which(ok); k[sample.int(length(k), min(n, length(k)))] }
strata <- list(
  season = pick(sea & !is.na(g01[, "retreat"]), 60),
  ice_at_end = pick(sea & g01[, "ice_at_end"] == 1 & !is.na(g01[, "advance"]), 30),
  ice_at_start = pick(sea & g01[, "ice_at_start"] == 1, 30),
  isolated = pick(sea & is.na(g01[, "advance"]) & g01[, "daycount"] > 0, 30),
  open_water = pick(sea & g01[, "daycount"] == 0, 30),
  land = pick(!sea, 20),
  missing_1982 = partial82[sample.int(length(partial82), 30)])
cells <- unique(unlist(strata))
years <- c(1982L, 1984L, 2001L)
sub <- lapply(years, function(y) {
  r <- readRDS(file.path(cache, sprintf("ice_%d.rds", y)))
  stopifnot(length(r$obs_dates) == length(r$dates), all(r$obs_dates == r$dates))  # fill_daily() changes nothing
  g <- terra::values(terra::rast(file.path(cog_dir, sprintf("south_iceseason_t15_%d-02-15.tif", y))),
                     mat = TRUE)[cells, , drop = FALSE]
  list(dates = r$dates, x = t(r$m[cells, , drop = FALSE]),
       layers = as.data.frame(matrix(as.integer(g), nrow(g), dimnames = list(NULL, colnames(g)))))
})
names(sub) <- years
saveRDS(list(
  meta = list(
    source = paste("NOAA-NSIDC Climate Data Record of Passive Microwave Sea Ice Concentration,",
                   "Version 6 (G02202, south, 25 km), doi:10.7265/b18j-z797, read by raadtools"),
    licence = "No constraints on data access or use (the files' licence attribute)",
    layers = paste("trend.ice's published ice season COGs (aad-derived/trend-ice/iceseason_t15/",
                   "on Pawsey Acacia), made by R/ice_season.R at", commits[["published"]]),
    cells = "cell numbers in the 316 x 332 EPSG:3412 grid, in terra's order",
    strata = lapply(strata, function(k) match(k, cells)),
    generated = Sys.Date(), script = "data-raw/massom2013.R"),
  cells = cells, years = sub, gate = gate),
  out, compress = "xz")
cat("wrote", out, file.size(out), "bytes:", length(cells), "pixels,", length(years), "ice years\n")
