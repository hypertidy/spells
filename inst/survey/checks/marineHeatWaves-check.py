# Checks for inst/survey/python-mhw.md, the marineHeatWaves points: those
# read from the code, and two side effects found while writing this script
# (the climatologyPeriod default is written back, and NaNs in the caller's
# array are overwritten).
# Run: python3 -I marineHeatWaves-check.py > marineHeatWaves-check.out 2>&1
# (Named -check so that it cannot shadow the marineHeatWaves module.)
import warnings
from datetime import date
from importlib.metadata import version
import importlib.util, types
import numpy as np
import marineHeatWaves as mhw_installed

warnings.simplefilter("always")
warnings.showwarning = lambda m, c, *a, **k: print(f"   [{c.__name__}: {m}]")
print("marineHeatWaves", version("marineHeatWaves"), " numpy", np.__version__, "\n")

## The installed module as it is, under NumPy 2:
tt = np.arange(date(2001, 1, 1).toordinal(), date(2001, 12, 31).toordinal() + 1)
try:
    mhw_installed.detect(tt, np.full(len(tt), 20.0))
    print("unmodified detect(): ran")
except Exception as e:
    print("unmodified detect():", type(e).__name__ + ":", e)

## So the checks run on a copy of the installed source with only the NumPy 2
## fixes below, applied in memory (the installed file is not changed): a
## one-element array assigned to an array element (lines 207, 235), and
## np.NaN, removed in NumPy 2.0 (lines 260-264).
origin = importlib.util.find_spec("marineHeatWaves").origin
with open(origin) as fh:
    src = fh.read()
subs = [
    ("doy[tt] = doy_leapYear[(month_leapYear == month[tt]) * (day_leapYear == day[tt])]",
     "doy[tt] = doy_leapYear[(month_leapYear == month[tt]) * (day_leapYear == day[tt])][0]", 1),
    ("doyClim[i] = doy_leapYear[(month_leapYear == monthClim[i]) * (day_leapYear == dayClim[i])]",
     "doyClim[i] = doy_leapYear[(month_leapYear == monthClim[i]) * (day_leapYear == dayClim[i])][0]", 1),
    ("np.NaN", "np.nan", 4),
]
for old, new, count in subs:
    assert src.count(old) == count, (old, src.count(old))
    src = src.replace(old, new)
    print(f"patched x{count}: {old}  ->  ...{new[-12:]}")
mhw = types.ModuleType("marineHeatWaves")
exec(compile(src, origin, "exec"), mhw.__dict__)
print()

def days(y0, y1):
    return np.arange(date(y0, 1, 1).toordinal(), date(y1, 12, 31).toordinal() + 1)

def idx(t, y, m, d):
    return int(np.where(t == date(y, m, d).toordinal())[0][0])

## 0. The default climatologyPeriod=[None, None] is a list that detect()
##    fills in, so it stays filled for the next call.
print("0. detect.__defaults__[0] before any call:", mhw.detect.__defaults__[0])
tA = days(2001, 2002)
rng = np.random.default_rng(1)
mhw.detect(tA, 20 + rng.normal(size=len(tA)))
print("   after detect() on a 2001-2002 series:", mhw.detect.__defaults__[0])
tB = days(1999, 2004)
xB = 20 + rng.normal(size=len(tB))
_, cB_default = mhw.detect(tB, xB.copy())
_, cB_full = mhw.detect(tB, xB.copy(), climatologyPeriod=[1999, 2004])
print("   next call, a 1999-2004 series with the default: thresholds equal to",
      "climatologyPeriod=[1999, 2004]?", bool(np.allclose(cB_default["thresh"], cB_full["thresh"])))
print("   max difference:", round(float(np.max(np.abs(cB_default["thresh"] - cB_full["thresh"]))), 4), "\n")

## A climatology series that gives seas = 20 and thresh = 21 away from the
## new year: per day-of-year, 10 years x 11 window days, 8 years at 19.75
## and 2 at 21 (mean 20; linear 90th percentile 21). So thresh - seas = 1.
tC = days(1993, 2002)
yC = np.array([date.fromordinal(int(o)).year for o in tC])
xC = np.where(np.isin(yC, [1996, 1997]), 21.0, 19.75)
alt = dict(climatologyPeriod=[1993, 2002], alternateClimatology=[tC, xC])

t = days(2001, 2002)
n = len(t)
x = np.full(n, 20.0)
x[0:7] = 22.0                                   # event on the series' first 7 days
i50 = 50; x[i50:i50 + 7] = [24.0] + [22.0] * 6  # peak on its first day; day 49 = seas
i200 = 200; x[i200:i200 + 6] = 22.5             # 6 days, category 2,
x[i200 + 8:i200 + 14] = 22.5                    # a 2-day gap, 6 more days
iny = idx(t, 2001, 12, 28); x[iny:iny + 8] = 23.0   # 28 Dec 2001 - 4 Jan 2002
x[n - 6:] = [22.0] * 5 + [24.0]                 # ends on the last day, peaks there
m, c = mhw.detect(t, x.copy(), **alt)
day = lambda i: date.fromordinal(int(t[i])).isoformat()
print(f"   (climatology check: seas {c['seas'][i50]:.4f}, thresh {c['thresh'][i50]:.4f} on day {i50})\n")
E = {m["index_start"][k]: k for k in range(m["n_events"])}
print("   events found (index_start, duration):",
      [(int(m["index_start"][k]), int(m["duration"][k])) for k in range(m["n_events"])], "\n")

## 1. An event on the series' first day.
k = E.get(0)
print("1. 7-day event on days 0-6:",
      "index_start", m["index_start"][k], "duration", m["duration"][k] if k is not None else None)
print("   (xmhw: index_start 1, duration 6)\n")

## 2. Onset rate, peak on the event's first day, not at the series start.
k = E[i50]
print("2. event from day 50, peak 24 on its first day, day 49 at seas:",
      "rate_onset", round(m["rate_onset"][k], 4), " (xmhw: 1.3333)\n")

## 3. Decline rate, event ends on the series' last day and peaks there.
print(f"3. event on the last 6 days (to index {n - 1}), peak on the last day:")
k = E[n - 6]
print("   index_end", m["index_end"][k], " index_peak", m["index_peak"][k],
      " rate_decline", m["rate_decline"][k], " (comment's rule: 1-day period, so 0)\n")

## 4. Joined gap days fall in no category.
k = E[i200]
cats = sum(m[f"duration_{c_}"][k] for c_ in ["moderate", "strong", "severe", "extreme"])
print("4. two 6-day runs at category 2 joined across a 2-day gap:",
      "duration", m["duration"][k], " category days", cats,
      " (strong", m["duration_strong"][k], ")\n")

## 5. blockAverage(): total_icum for an event across 1 January.
k = E[iny]
print("5. event", day(m["index_start"][k]), "to", day(m["index_end"][k]),
      " intensity_cumulative", round(m["intensity_cumulative"][k], 4))
b = mhw.blockAverage(t, m, clim=c, temp=x)
for j, yr in enumerate(b["years_start"]):
    ev = [kk for kk in range(m["n_events"]) if m["date_start"][kk].year == yr]
    print(f"   {int(yr)}: count {int(b['count'][j])}, total_icum {b['total_icum'][j]:.4f},",
          f"sum of icum of events starting in {int(yr)}:",
          f"{sum(m['intensity_cumulative'][kk] for kk in ev):.4f}")
print("   (the comment: 'icum for a MHW is assigned to its start year')\n")

## 6. maxPadLength: the docstring says the default (False) interpolates over
##    all missing values. A 10-day event with one missing day in it:
x6 = np.full(n, 20.0); x6[100:110] = 23.0; x6[104] = np.nan
for mpl in [False, 1]:
    xin = x6.copy()
    m6, c6 = mhw.detect(t, xin, maxPadLength=mpl, **alt)
    print(f"6. maxPadLength={mpl}: events (index_start, duration)",
          [(int(m6['index_start'][k]), int(m6['duration'][k])) for k in range(m6['n_events'])],
          f"; caller's array still has its NaN: {bool(np.isnan(xin).any())}")
print()

## 7. The window at the ends of the climatology period, and 29 February.
t7 = days(1990, 1999)
x7 = 20 + np.random.default_rng(7).normal(size=len(t7))
_, c7 = mhw.detect(t7, x7.copy(), climatologyPeriod=[1991, 1998], smoothPercentile=False)
y7 = np.array([date.fromordinal(int(o)).year for o in t7])
jan1 = [idx(t7, y, 1, 1) for y in range(1991, 1999)]
pool = np.concatenate([np.arange(i - 5, i + 6) for i in jan1])
inside = pool[(y7[pool] >= 1991) & (y7[pool] <= 1998)]
print("7. thresh for 1 January, climatology period 1991-1998, no smoothing:",
      round(c7["thresh"][jan1[0]], 6))
print("   90th percentile of the pool with the days outside the period (Dec 1990):",
      round(np.percentile(x7[pool], 90), 6), "; without them:", round(np.percentile(x7[inside], 90), 6))
f28, f29, m1 = idx(t7, 1992, 2, 28), idx(t7, 1992, 2, 29), idx(t7, 1992, 3, 1)
print("   29 Feb thresh", round(c7["thresh"][f29], 6), "; mean of 28 Feb and 1 Mar",
      round(0.5 * (c7["thresh"][f28] + c7["thresh"][m1]), 6))
