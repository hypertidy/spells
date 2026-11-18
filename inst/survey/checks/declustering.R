# Checks for inst/survey/declustering.md, the points marked "to confirm".
# Run: Rscript declustering.R > declustering.out 2>&1
suppressPackageStartupMessages({
  library(extRemes)
  library(evd)
  library(POT)
})
cat("extRemes", format(packageVersion("extRemes")),
    " evd", format(packageVersion("evd")),
    " POT", format(packageVersion("POT")), "\n\n")

## 1. extRemes: does intervals declustering use its estimated run length?
x <- rep(0, 300)
x[c(10, 12, 14,  60, 63,  100, 102, 104, 106,  150, 154,  200, 201, 203,
    250, 252)] <- 1
u <- 0.5
ei <- extremalindex(x, u, method = "intervals")
cat("1. extremalindex(intervals): theta =", round(ei[1], 3),
    " clusters =", ei[2], " run.length =", ei[3], "\n")
di <- decluster(x, u, method = "intervals")
n_int <- length(unique(attr(di, "clusters")))
n_r1  <- length(unique(attr(decluster(x, u, method = "runs", r = 1), "clusters")))
n_rk  <- length(unique(attr(decluster(x, u, method = "runs", r = ei[3]), "clusters")))
cat("   decluster(intervals): reported run.length =", attr(di, "run.length"),
    " clusters =", n_int, "\n")
cat("   runs with r = 1 gives", n_r1, "clusters; runs with r =", ei[3], "gives", n_rk, "\n\n")

## 2. extRemes: varying threshold with na.omit
xv <- c(5, NA, 5, 1, 5)
th <- c(4, 0, 4, 4, 10)
cat("2. x =", xv, "; threshold =", th, "\n")
cat("   after dropping the NA step, x has", sum(!is.na(xv)), "values and the matching thresholds are",
    th[!is.na(xv)], "\n")
warns <- character()
r2 <- withCallingHandlers(
  decluster(xv, th, method = "runs", na.action = na.omit),
  warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") })
cat("   decluster() warnings:", if (length(warns)) unique(warns) else "none", "\n")
cat("   output length", length(c(r2)), "for", sum(!is.na(xv)), "input values; output =", c(r2), "\n\n")

## 3. extRemes: groups with a varying threshold
g <- rep(1:2, each = 150)
r3 <- tryCatch(decluster(x, rep(u, 300), method = "runs", r = 1, groups = g),
               error = function(e) e)
cat("3. groups + varying threshold (the code passes clusterfun = cluster, the id vector):",
    if (inherits(r3, "error")) paste("error:", conditionMessage(r3)) else "ran", "\n\n")

## 4. POT clust(): is the time condition measured from the running maximum?
obs <- c(0, 15, 9, 9.5, 9.7, 9.8, 9.9, 10.5, 5, 5, 5, 0)
d <- data.frame(obs = obs, time = seq_along(obs))
cl <- clust(d, u = 10, tim.cond = 1)
cat("4. POT clust, u = 10, tim.cond = 1; exceedances at times", which(obs > 10), "\n")
cat("   documented rule (inter-arrival > 1 means independent): 2 clusters\n")
cat("   clust() found", length(cl), "cluster(s):\n")
for (k in seq_along(cl)) cat("   ", names(cl)[k], ": times", range(cl[[k]]["time", ]), "\n")
cat("   exi =", attr(cl, "exi"), "\n")
cr <- clusters(obs, u = 10, r = 2)
cat("   evd clusters(r = 2, i.e. join gaps < 2):", length(cr), "cluster(s)\n\n")

## 5. POT clust(): a cluster running to the end of the series
obs5 <- c(0, 0, 12, 13, 14)
cl5 <- clust(data.frame(obs = obs5, time = 1:5), u = 10, tim.cond = 1, clust.max = TRUE)
cat("5. POT clust at the series end: obs", obs5, "\n")
print(cl5)
cat("   (the maximum is 14 at time 5)\n\n")

## 6. Intervals estimator of the extremal index: POT vs evd vs extRemes
set.seed(1)
y <- as.numeric(arima.sim(list(ar = 0.7), n = 5000))
uq <- quantile(y, 0.95)
iy <- diff(which(y > uq))
cat("6. AR(1) series, threshold at the 95th percentile; max interval between exceedances =", max(iy), "\n")
cat("   evd::exi(r = 0)              =", round(exi(y, uq, r = 0), 4), "\n")
cat("   extRemes::extremalindex      =", round(extremalindex(y, uq, method = "intervals")[1], 4), "\n")
cat("   POT::fitexi                  =", round(fitexi(y, uq)$exi, 4), "\n")
# both forms by hand
N <- length(iy) + 1
th_hat   <- min(1, 2 * sum(iy)^2 / ((N - 1) * sum(iy^2)))
th_tilde <- min(1, 2 * sum(iy - 1)^2 / ((N - 1) * sum((iy - 1) * (iy - 2))))
cat("   by hand: form with T, T^2 =", round(th_hat, 4),
    "; form with T-1, (T-1)(T-2) =", round(th_tilde, 4), "\n")
