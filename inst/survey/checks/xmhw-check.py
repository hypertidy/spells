# Checks for inst/survey/python-mhw.md, the xmhw points marked "to confirm",
# plus the decline rate of an event that peaks on the series' last day, and
# whether block_average() runs.
# Run: python3 -I xmhw-check.py > xmhw-check.out 2>&1
# (Named -check so that it cannot shadow the xmhw package.)
#
# The threshold and climatology are set by hand (seas = 20, thresh = 21 on
# every day of year), so thresh - seas = 1 and a day's category is
# floor(1 + (T - 21)), and every expected value can be worked out exactly.
import contextlib, io, warnings
import numpy as np, pandas as pd, xarray as xr
import xmhw
from xmhw.xmhw import detect
from xmhw.stats import block_average
from importlib.metadata import version

warnings.filterwarnings("ignore")
print("xmhw", version("xmhw"), " xarray", xr.__version__, " pandas", pd.__version__,
      " numpy", np.__version__, "\n")

time = pd.date_range("2001-01-01", "2002-12-31", freq="D")
doy = np.arange(1, 367)
seas = xr.DataArray(np.full(366, 20.0), dims="doy", coords={"doy": doy})
thresh = xr.DataArray(np.full(366, 21.0), dims="doy", coords={"doy": doy})

def series(events):
    """A base of 20 (= seas, below thresh) with events as {start: values}."""
    v = np.full(len(time), 20.0)
    for st, vals in events.items():
        v[st:st + len(vals)] = vals
    return xr.DataArray(v, dims="time", coords={"time": time})

def run(ts, **kw):
    with contextlib.redirect_stdout(io.StringIO()):   # detect() prints progress
        return detect(ts, thresh, seas, **kw)

def show(mhw, cols):
    df = mhw.to_dataframe()[cols]
    print(df.to_string(index=False))

## 1. An event that starts on the series' first day.
print("1. A 7-day event on days 0-6 (the series' first 7 days), T = 22:")
m = run(series({0: [22.0] * 7}))
show(m, ["index_start", "index_end", "duration", "time_start"])
print("   marineHeatWaves (by its code): index_start 0, duration 7")
print("   A 5-day event on days 0-4:")
m = run(series({0: [22.0] * 5, 300: [22.0] * 6}))
show(m, ["index_start", "duration"])
print("   (the 6-day event on days 300-305 is there for comparison)\n")

## 2. Onset rate of an event that peaks on its first day, not at the series start.
print("2. Event on days 50-56, T = 24 then 22 x 6; day 49 is 20 (anomaly 0).")
m = run(series({50: [24.0] + [22.0] * 6}))
show(m, ["index_start", "index_peak", "intensity_max", "rate_onset"])
edge = 0.5 * (4.0 + 0.0)
print(f"   by hand: (4 - {edge}) / 1.5 = {(4 - edge) / 1.5:.4f} (xmhw's period);"
      f" / 0.5 = {(4 - edge) / 0.5:.4f} (marineHeatWaves)\n")

## 3. Decline rate of an event that ends on the series' last day and peaks there.
n = len(time)
print(f"3. Event on the last 6 days (indexes {n - 6}-{n - 1}), T = 22 x 5 then 24:")
m = run(series({n - 6: [22.0] * 5 + [24.0]}))
show(m, ["index_end", "index_peak", "intensity_max", "rate_decline"])
print("   intended (both codes' comments): period 1 day, so (4 - 4) / 1 = 0")
print("   the test compares the peak's position within the event with the"
      " series' last index, so the period is 0\n")

## 4. block_average(), the public entry point, as in xmhw's docs:
##    block_average(mhw, dstime=intermediate). xmhw's own test_block_average()
##    is an empty `pass`.
v = series({100: [24.5] * 3 + [25.5] * 4, 200: [22.0] * 7})
lat = lon = [0.0, 1.0]
grid = lambda a, d: xr.DataArray(np.broadcast_to(a.values[:, None, None], (a.shape[0], 2, 2)).copy(),
                                 dims=(d, "lat", "lon"), coords={d: a[d].values, "lat": lat, "lon": lon})
print("4. block_average(mhw, dstime=intermediate):")
for label, args in [("2 x 2 lat-lon grid", (grid(v, "time"), grid(thresh, "doy"), grid(seas, "doy"))),
                    ("single series", (v, thresh, seas))]:
    with contextlib.redirect_stdout(io.StringIO()):
        m, inter = detect(*args, intermediate=True)
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            block_average(m, dstime=inter)
        print(f"   {label}: ran")
    except Exception as e:
        print(f"   {label}:", type(e).__name__ + ":", e)
print()

## 5. The block rules, by calling the aggregation functions block_average()
##    would call (agg_mhw on events, agg_cats on the time axis) for one series.
from xmhw.stats import agg_mhw, agg_cats, check_variables
print("5. Event on days 100-106 of 2001: T = 24.5 x 3 (category 4), then 25.5 x 4 (category 5);")
print("   event on days 200-206 of 2001: T = 22 x 7 (category 2).")
with contextlib.redirect_stdout(io.StringIO()):
    m, inter = detect(v, thresh, seas, intermediate=True)
ev = m.to_dataframe()
print("   per event:")
print(ev[["index_start", "duration", "duration_extreme", "category",
          "intensity_mean", "intensity_mean_abs"]].to_string(index=False))
bins = range(2001, 2004)
bm = agg_mhw(ev, m.time_start.dt.year, bins)
dt, _, _ = check_variables(inter)
bc = agg_cats(dt.to_dataframe(), dt["index"].dt.year, bins)   # one series: the time axis is "index"
bc["total_days"] = bc[["moderate_days", "strong_days", "severe_days", "extreme_days"]].sum(axis=1)
r = pd.concat([bm, bc], axis=1).iloc[0]
print("   block 2001:")
for k in ["ecount", "moderate_days", "strong_days", "severe_days", "extreme_days",
          "total_days", "intensity_mean", "intensity_mean_abs",
          "intensity_cumulative", "intensity_cumulative_abs"]:
    print(f"     {k:26s} {float(r[k]):.4f}")
print("   expected if extreme_days counted category >= 4: 7, and total_days 14")
print("   expected absolute block means: intensity_mean_abs",
      f"{ev.intensity_mean_abs.mean():.4f},",
      f"intensity_cumulative_abs {ev.intensity_cumulative_abs.mean():.4f}")
