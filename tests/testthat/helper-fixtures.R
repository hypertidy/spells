## The stored inputs and outputs, from data-raw/golden.R.
fixture <- function(name) readRDS(test_path("fixtures", name))
cases <- fixture("cases.rds")

## Fit on the whole case, detect on its detection window.
run_case <- function(k, def) {
  b <- spell_baseline(k$x, k$dates, def)
  keep <- if (is.null(k$detect_from)) rep(TRUE, length(k$dates)) else k$dates >= k$detect_from
  x <- k$x[keep, , drop = FALSE]
  m <- spell_mask(x, k$dates[keep], b)
  list(baseline = b, mask = m, t = k$dates[keep], events = spell_events(x, k$dates[keep], b, m))
}
