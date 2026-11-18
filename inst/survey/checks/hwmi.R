# Checks for inst/survey/hwmi.md: the points marked "to confirm", and two
# more found while writing this script (the duplicated hwyear(), and ties
# in consecDayMax()).
# Run: Rscript hwmi.R > hwmi.out 2>&1
suppressPackageStartupMessages(library(extRemes))
cat("extRemes", format(packageVersion("extRemes")), "\n\n")
ns <- asNamespace("extRemes")

## 0. hwmi.R and hwmid.R each define cut366thDay, mvThreshold and hwyear.
##    The two hwyear() differ: a "whole year" branch at >= 122 days above the
##    threshold (hwmi.R) or >= 365 (hwmid.R). Which one is live?
hb <- paste(deparse(body(get("hwyear", ns))), collapse = "\n")
cat("0. live hwyear() has 'sum(index) >= 122':", grepl(">= 122", hb),
    "; '>= 365':", grepl(">= 365", hb), "\n\n")

## Synthetic data: 32 noleap years (cut366thDay leaves a whole number of
## 365-day years alone), a seasonal cycle plus noise, not rounded (no ties).
set.seed(10)
ny <- 32
doy <- rep(1:365, ny)
yr <- rep(1:ny, each = 365)
Tref <- 25 + 8 * sin(2 * pi * (doy - 110) / 365) + rnorm(365 * ny, sd = 2)
## padding year 32 gets a 3-day spike far above anything else
spike <- which(yr == 32 & doy %in% 200:202)
Tref[spike] <- Tref[spike] + 15

## 1. HWMI: which reference years feed the 3-day-maximum density?
t3 <- sapply(1:ny, function(y) {
  x <- Tref[yr == y]
  max(sapply(2:364, function(i) sum(x[(i - 1):(i + 1)])))
})
Temp <- Tref[yr == 16]   # any one year; only the density is compared here
h <- hwmi(1981, Tref, 1996, Temp)
d_2_31 <- density(t3[2:31], bw.SJ(t3[2:31]))
d_2_32 <- density(t3[2:32], bw.SJ(t3[2:32]))
cat("1. HWMI 3-day maxima: year 32 (padding) =", round(t3[32], 2),
    "; years 2-31 range", paste(round(range(t3[2:31]), 2), collapse = " - "), "\n")
cat("   hwmi()$pdfx range:", paste(round(range(h$pdfx), 2), collapse = " - "), "\n")
cat("   identical to density over years 2-31:",
    isTRUE(all.equal(h$pdfx, d_2_31$x)) && isTRUE(all.equal(h$pdfy, d_2_31$y)),
    "; over years 2-32:",
    isTRUE(all.equal(h$pdfx, d_2_32$x)) && isTRUE(all.equal(h$pdfy, d_2_32$y)), "\n")

## HWMId: which years feed the annual maxima?
am <- sapply(1:ny, function(y) max(Tref[yr == y]))
hd <- hwmid(1981, Tref, 1996, Temp)
cat("   HWMId T30y25p, T30y75p:", round(hd$T30y25p, 4), round(hd$T30y75p, 4), "\n")
cat("   quantiles of annual maxima, years 2-31:", round(quantile(am[2:31], c(.25, .75)), 4),
    "; years 2-32:", round(quantile(am[2:32], c(.25, .75)), 4), "\n\n")

## 2. consecDayMax() with a tie: it returns c(times, max), and hwmi() keeps
##    element 2, so with two tied maxima element 2 is the second time.
x <- rep(10, 365)
x[100:102] <- 20   # 3-day sums centred on 100 and 102 are 50, on 101 is 60
x[250:252] <- 20   # a second identical block: the 60 occurs twice
cdm <- get("consecDayMax", ns)(2, 364, x, 3)
cat("2. consecDayMax with the maximum 3-day sum (60) at days 101 and 251:", cdm, "\n")
cat("   hwmi() keeps element 2 as the year's 3-day maximum:", cdm[2], "\n")
## and in the package's own example data (tenths of a degree)
data("CarcasonneHeat")
tiid <- CarcasonneHeat[2, ]
Tc <- CarcasonneHeat[3, which(tiid == 19800101):which(tiid == 20111231)] / 10
Tc365 <- get("cut366thDay", ns)(1980, 2011, Tc)
ties <- sapply(2:32, function(y) {
  r <- get("consecDayMax", ns)(2, 364, Tc365[((y - 1) * 365 + 1):(y * 365)], 3)
  length(r) - 1
})
cat("   CarcasonneHeat 1981-2011: years whose 3-day maximum is tied:",
    sum(ties > 1), "of 31\n\n")

## 3. HWMI padding of a 3n + 2 day heatwave. A 5-day heatwave on days
##    180-184 of an otherwise cool year; the code's main branch pads with
##    max(Ts[hwt - 1], Ts[hwt:(hwt + hwd)]).
thr <- h$thr
f <- approxfun(h$pdfx, h$pdfy, yleft = 0, yright = 0)
P <- function(s) integrate(f, lower = -Inf, upper = s, stop.on.error = FALSE)$value
Ty <- 25 + 8 * sin(2 * pi * (1:365 - 110) / 365) - 5     # well below thr
mid <- median(t3[2:32]) / 3                               # sums mid-density
hwv <- pmax(thr[180:184] + 0.2, mid + c(-0.6, -0.4, 1.2, -0.4, -0.6))
Ty[180:184] <- hwv
cat("3. 5-day heatwave, days 180-184:", round(hwv, 2), "; day 179:", round(Ty[179], 2),
    "; day 185:", round(Ty[185], 2), "\n")
r3 <- hwmi(1981, Tref, 1996, Ty)$hwmi
cat("   hwmi(): magnitude", round(r3[1, 1], 6), " duration", r3[1, 2], " start", r3[1, 3], "\n")
b1 <- sum(Ty[180:182])
pad_code <- max(Ty[179], Ty[180:185])
pad_edge <- max(Ty[179], Ty[185])
cat("   by hand, pad = max(day before, heatwave, day after) =", round(pad_code, 2), ":",
    round(P(b1) + P(sum(Ty[183:184], pad_code)), 6), "\n")
cat("   by hand, pad = max(day before, day after) =", round(pad_edge, 2), ":",
    round(P(b1) + P(sum(Ty[183:184], pad_edge)), 6), "\n\n")

## 4. The package examples, for the record
h03 <- hwmi(1980, Tc, 2003, CarcasonneHeat[3, which(tiid == 20030101):which(tiid == 20031231)] / 10)
cat("4. hwmi() example, Carcassonne 2003:", round(h03$hwmi[1, ], 2),
    " (man page text: hwmi = 3.68, 12 days, start day 214)\n")
hd03 <- hwmid(1980, Tc, 2003, CarcasonneHeat[3, which(tiid == 20030101):which(tiid == 20031231)] / 10)
cat("   hwmid() on the same data:", round(hd03$hwmid[1, ], 2), "\n")
