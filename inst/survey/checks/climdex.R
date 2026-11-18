# Checks for inst/survey/climdex.pcic.md, "To check by running".
# Run: Rscript climdex.R > climdex.out 2>&1
suppressPackageStartupMessages({
  library(PCICt)
  library(climdex.pcic)
})
cat("climdex.pcic", format(packageVersion("climdex.pcic")),
    " RemoteSha", packageDescription("climdex.pcic")$RemoteSha,
    " PCICt", format(packageVersion("PCICt")), "\n\n")

## A smooth seasonal tmax with small noise, 1961-1992; base 1961-1990.
dates <- seq(as.Date("1961-01-01"), as.Date("1992-12-31"), by = "day")
set.seed(4)
doy <- as.integer(format(dates, "%j"))
tmax <- 20 + 8 * sin(2 * pi * (doy - 100) / 365.25) + rnorm(length(dates), sd = 0.5)
## a 9-day hot spell across the new year: 28 Dec 1991 to 5 Jan 1992
hot <- dates >= as.Date("1991-12-28") & dates <= as.Date("1992-01-05")
tmax[hot] <- tmax[hot] + 10
## and a 7-day hot spell inside the base period, 10-16 Jul 1975
hot75 <- dates >= as.Date("1975-07-10") & dates <= as.Date("1975-07-16")
tmax[hot75] <- tmax[hot75] + 10
tmin <- tmax - 10
prec <- rep(0, length(dates))
pd <- as.PCICt(format(dates), cal = "gregorian")
ci <- climdexInput.raw(tmax, tmin, prec, pd, pd, pd, base.range = c(1961, 1990))

## 1. a spell across 1 January, with and without spells.can.span.years
w_cut  <- climdex.wsdi(ci, spells.can.span.years = FALSE)
w_span <- climdex.wsdi(ci, spells.can.span.years = TRUE)
yrs <- c("1975", "1990", "1991", "1992")
cat("1. WSDI with the 9-day spell 28 Dec 1991 - 5 Jan 1992 (4 + 5 days):\n")
print(rbind(cut = w_cut[yrs], span = w_span[yrs]))
cat("   expected: cut gives 0 extra days in 1991 and 1992 (pieces of 4 and 5 < 6);",
    "span gives 4 in 1991 and 5 in 1992\n\n")

## 2. which thresholds WSDI uses in base years
cat("2. thresholds available for tmax:", paste(names(ci@quantiles$tmax), collapse = ", "), "\n")
b <- paste(deparse(body(climdex.wsdi)), collapse = "\n")
cat("   climdex.wsdi body mentions 'outbase':", grepl("outbase", b),
    " 'inbase':", grepl("inbase", b), "\n")
cat(b, "\n\n")
cat("   1975 (a base year) counts the 7-day July spell:", w_cut["1975"], "days\n")
