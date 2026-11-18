# hydroEvents 0.13.0

- **Source read:** the CRAN tarball `hydroEvents_0.13.0.tar.gz`
  (published 2025-12-11). GitHub: conradwasko/hydroEvents. Wasko, Guo
  and Mohammadpour Khoie. GPL-3.
- **How:** read 2026-11-18 from source. **Not run.**
- **References:** Wasko and Guo 2022, *Hydrol. Process.*,
  doi:10.1002/hyp.14563; Mohammadpour Khoie, Guo and Wasko 2025,
  *Environ. Model. Softw.*, doi:10.1016/j.envsoft.2025.106521 (RVEIM and
  REIC).
- Paths below are relative to the package source.

## What it is

Event extraction from single hydrological series (rainfall, streamflow,
quickflow), plus matching events across two series. Every function
takes a bare numeric vector and returns **indices**, with no dates, so
the time step is whatever the vector is (daily and hourly examples
ship with it).

There are four ways to find events. Only one is a threshold run:
- `eventPOT()` (`R/eventPOT.R`): peaks over threshold, the run kind;
- `eventMaxima()` and `eventMinima()`: segments from trough to trough,
  chosen by the size of the rise and fall;
- `eventBaseflow()`: runs where the baseflow index is low;
- `eventRVEIM()` (new in 0.13.0): streamflow events matched to rainfall
  events, from a rolling variance of the flow.

## The grid columns

- **Baseline:** none for `eventPOT()`. For streamflow, the usual
  baseline is **baseflow from a recursive digital filter**, and events
  are found on the quickflow, `q − baseflow`:
  - `baseflowA()`: Lyne and Hollick as in EcoHydRology, 3 passes
    forward, backward and forward again. Its starting values come from
    the whole series (`quantile(q, 0.25)`, `mean(q)`).
  - `baseflowB()`: Ladson et al. 2013, 3 passes, with 30 values
    reflected at each end to settle the filter.

  Both are **two-sided**: the backward pass makes each step's baseflow
  depend on later steps, so new data changes the past baseflow.
- **Threshold:**
  - `eventPOT()`: an absolute value, default 0 (on quickflow, "zero"
    flow).
  - `eventMaxima()` and `eventMinima()`: the threshold is a **filter
    applied after separation**: events whose peak is below it are
    dropped (`max >= threshold`), and leading and trailing steps at or
    below it are trimmed. The docs say so: it removes "trace amounts",
    it doesn't separate events.
  - `eventBaseflow()`: BFI below `BFI_Th` (0.5).
- **Direction:** above, strictly (`data > threshold`).
- **Persistence (`eventPOT()`):** exceedances whose indices differ by
  more than `min.diff` start a new event, so gaps of up to
  `min.diff − 1` steps are joined. The default of 1 joins nothing. There
  is no minimum duration: one step is an event.
  - `eventBaseflow()` takes a minimum length, and its events run from
    the last baseflow step before to the first one after, so each event
    includes one step either side. Events that touch the start or end of
    the record aren't returned.
  - `eventMaxima()` and `eventMinima()` share boundary troughs between
    neighbouring events.
- **Missing data:** not handled.
  - `eventPOT()` uses `which(data > threshold)`, which drops NA, so a
    missing step counts as below the threshold and can be joined across.
    The event's `max` and `sum` are then NA.
  - In `eventBaseflow()`, a step with a missing BFI counts as an event
    step, for the same reason.
  - The baseflow filters fail on NA (`quantile()` without `na.rm`, and
    `if()` or a subscripted assignment on NA).
- **Time step:** any, by index. **Calendar and season year:** none.
- **Metrics per event** (`calcStats()`): start and end indices, the
  index and value of the maximum, and the sum, over **start to end
  inclusive**, so joined gap steps are in the sum. `limbs()` splits each
  event at its peak into a rising and a falling limb.
- **Matching across series** (`pairEvents()`): events in one series are
  paired with events in another within a lag, by one of five rules:
  1. the peak of series 2 falls between the start of an event in series
     1 and its end + lag;
  2. an event in series 2 starts and ends between the start of the
     series-1 event and its end + lag;
  3. backwards: the peak of series 1 falls between the start of an event
     in series 2 − lag and that event's peak;
  4. backwards, by start: a series-1 event starts between a series-2
     event's start − lag and its start;
  5. centred: the peaks are within ± lag.

  Pairing isn't one-to-one: each event takes the start of its first
  match and the end of its last, and one event can be matched more than
  once. `postCorrection()` then removes duplicates or shifts
  overlapping events apart.
- **Data-set-relative settings in RVEIM:** the lag between rainfall and
  flow is the one (0 to 10 steps) with the highest correlation over the
  whole series, and the variance limit comes from the median + 3 MAD of
  the whole series' baseflow.
- **Categories:** none. **Many series:** one per call (two for pairing).
  **Streaming:** no.
- **Outputs:** data frames of start and end indices, plus the summary
  statistics.

## What this means for spells

1. **Not an oracle for spells.** Only `eventPOT()` is a threshold run,
   and it is a plain one: a strict comparison, gap joining, no minimum,
   no missing-data policy.
2. **A filter along time is another baseline type.** Baseflow
   separation gives an expected value per step from the neighbouring
   steps, not per slot. Lyne and Hollick as implemented here is
   two-sided, so it can't stream: batch and streaming would disagree
   near the end of the record. A one-pass forward filter would stream.
   If spells offers a filter baseline, the def records the filter, its
   parameters, the passes and the end treatment.
3. **A minimum on the peak is another opening.** `eventMaxima()` keeps an
   event only if its peak reaches the threshold. For spells that's a
   rule next to the minimum duration: detect at one level and keep the
   spells whose peak passes another. It's close to hysteresis, but the
   start and end stay at the detection level.
4. **Matching spells across variables needs a rule.** `pairEvents()` is
   prior art for the brief's compound spells (MHW with low chl, for
   instance) when the second spell follows the first rather than
   overlapping it. The def would name the reference points (start,
   peak, end), the lag window and its direction, and whether matching
   is one-to-one.
5. **More data-set-relative settings** (RVEIM's lag and variance limit).
   Like lfstat's minor-event rule, they change past events as data is
   added.
