# Checks for inst/survey/anomaly.md, the points marked "to confirm" and the
# unresolved %<>% question.
# Run: Rscript anomaly.R > anomaly.out 2>&1
suppressPackageStartupMessages(library(anomaly))
cat("anomaly", format(packageVersion("anomaly")), "\n")
cat("magrittr attached:", "package:magrittr" %in% search(), "\n\n")

## 1. collective_anomalies() and %<>%
data(simulated)
res <- capa(sim.data, type = "mean", min_seg_len = 2, max_lag = 5)
ca <- tryCatch(collective_anomalies(res), error = function(e) e)
cat("1. collective_anomalies() on the capa example:",
    if (inherits(ca, "error")) paste("error:", conditionMessage(ca)) else paste(nrow(ca), "rows"), "\n")
f <- getAnywhere("%<>%")
cat("   %<>% found in:", if (length(f$where)) f$where else "nowhere", "\n")
ns <- asNamespace("anomaly")
cat("   %<>% in the anomaly namespace or its imports:",
    exists("%<>%", envir = ns, inherits = FALSE),
    exists("%<>%", envir = parent.env(ns), inherits = FALSE), "\n")
cat("   magrittr loaded (not attached):", "magrittr" %in% loadedNamespaces(), "\n\n")

## 2. missing values
set.seed(2)
xn <- c(rnorm(100), NA, rnorm(100))
r2 <- tryCatch(capa(xn, type = "mean"), error = function(e) e)
cat("2. capa() with one NA:",
    if (inherits(r2, "error")) paste("error:", conditionMessage(r2)) else "ran", "\n\n")

## 3. a point anomaly at the first observation
set.seed(3)
z <- rnorm(200)
x1 <- z; x1[1] <- 50
x2 <- z; x2[2] <- 50
p1 <- point_anomalies(capa(x1, type = "mean"))
p2 <- point_anomalies(capa(x2, type = "mean"))
cat("3. outlier of 50 at t = 1: point anomalies at", if (nrow(p1)) p1$location else "none", "\n")
cat("   outlier of 50 at t = 2: point anomalies at", if (nrow(p2)) p2$location else "none", "\n")

## 4. Why does %<>% work? Test: only magrittr's %>% is bound, %<>% is not
f <- local({
  `%>%` <- magrittr::`%>%`
  function() { x <- 1:3; x %<>% rev() %>% identity(); x }
})
r4a <- tryCatch(f(), error = function(e) e)
g <- local({
  `%>%` <- magrittr::`%>%`
  function() { x <- 1:3; x %<>% rev(); x }
})
r4b <- tryCatch(g(), error = function(e) e)
cat("\n4. x %<>% rev() %>% identity(), with only %>% bound:",
    if (inherits(r4a, "error")) paste("error:", conditionMessage(r4a)) else paste("x =", paste(r4a, collapse = " ")), "\n")
cat("   x %<>% rev() alone:",
    if (inherits(r4b, "error")) paste("error:", conditionMessage(r4b)) else paste("x =", paste(r4b, collapse = " ")), "\n")
