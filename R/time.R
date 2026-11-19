## The time axis: steps, slots and checks.

#' Slots on a 366-day calendar
#'
#' The climatological position of each date: its day of year, counted so
#' that 29 February is always slot 60. Non-leap years skip slot 60, so
#' 1 March is slot 61 in every year (heatwaveR's convention).
#'
#' @param time A `Date` vector.
#' @return An integer vector of slots, 1 to 366.
#' @export
#' @examples
#' slot_366(as.Date(c("2015-02-28", "2015-03-01", "2016-02-29", "2016-03-01")))
slot_366 <- function(time) {
  y <- as.integer(format(time, "%Y"))
  d <- as.integer(format(time, "%j"))
  leap <- (y %% 4L == 0L & y %% 100L != 0L) | y %% 400L == 0L
  d + (!leap & d > 59L)
}

check_series <- function(x, time) {
  if (!inherits(time, "Date")) stop("`time` must be a Date vector")
  if (is.null(dim(x))) x <- matrix(x, ncol = 1L)
  x <- as.matrix(x)
  if (!is.numeric(x)) stop("`x` must be numeric: a vector, or a time x series matrix")
  if (nrow(x) != length(time)) {
    stop("`x` has ", nrow(x), " steps but `time` has ", length(time))
  }
  if (length(time) > 1L && any(diff(time) != 1)) {
    stop("`time` must be consecutive days (other steps aren't supported yet)")
  }
  x
}

## The eligibility mask, as a logical time x series matrix the shape of
## x: NULL (every step eligible), a matrix the shape of x, a vector of
## one value per series (a whole series in or out), or for a single
## series a vector of one value per step.
check_eligible <- function(eligible, x) {
  if (is.null(eligible)) return(matrix(TRUE, nrow(x), ncol(x)))
  if (!is.logical(eligible) || anyNA(eligible)) {
    stop("`eligible` must be TRUE or FALSE throughout, with no NA", call. = FALSE)
  }
  if (is.null(dim(eligible))) {
    if (length(eligible) == ncol(x) && (ncol(x) > 1L || nrow(x) == 1L)) {
      return(matrix(eligible, nrow(x), ncol(x), byrow = TRUE))
    }
    if (ncol(x) == 1L && length(eligible) == nrow(x)) return(matrix(eligible, ncol = 1L))
    stop("`eligible` must be a time x series matrix like `x`, or one value per series",
         call. = FALSE)
  }
  if (!identical(dim(eligible), dim(x))) {
    stop("`eligible` must be the same shape as `x`", call. = FALSE)
  }
  unname(eligible)
}
