# Does xarray's interpolate_na accept an integer max_gap on a date axis?
# xmhw passes its maxPadLength (documented as an int, in days) straight to
# DataArray.interpolate_na(dim="time", max_gap=maxPadLength).
# Run: python3 -I xarray-maxgap.py > xarray-maxgap.out
import numpy as np, pandas as pd, xarray as xr
print("xarray", xr.__version__, "pandas", pd.__version__, "numpy", np.__version__)
t = pd.date_range("2000-01-01", periods=6, freq="D")
da = xr.DataArray([1.0, np.nan, 3.0, np.nan, np.nan, 6.0], dims="time", coords={"time": t})
try:
    da.interpolate_na(dim="time", max_gap=2)
    print("max_gap=2: accepted")
except Exception as e:
    print("max_gap=2:", type(e).__name__ + ":", e)
