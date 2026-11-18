# Fetch the ESA SST CCI Analysis v3.0 (L4, CDR, 1980-2021) at the nine
# Tasman pixels used by mhw-mad.R, from Copernicus Marine's public ARCO
# store (geoChunked Zarr, read with GDAL's multidimensional API over
# /vsicurl/; no login needed). Writes <cache-dir>/cci_sst_9px.csv.
# Run: python3 -I mhw-mad-sst.py <cache-dir> > mhw-mad-sst.out 2>&1
import os, sys, time
import numpy as np
from osgeo import gdal

gdal.UseExceptions()
gdal.SetConfigOption("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
cache = sys.argv[1]
os.makedirs(cache, exist_ok=True)
out = os.path.join(cache, "cci_sst_9px.csv")

url = ("https://s3.waw3-1.cloudferro.com/mdl-arco-geo-046/arco/"
       "SST_GLO_SST_L4_REP_OBSERVATIONS_010_024/ESACCI-GLO-SST-L4-REP-OBS-SST_202603/geoChunked.zarr")
print("GDAL", gdal.__version__)
print("store:", url)
ds = gdal.OpenEx(f'ZARR:"/vsicurl/{url}"', gdal.OF_MULTIDIM_RASTER)
rg = ds.GetRootGroup()
print("title:", rg.GetAttribute("title").Read(), "| version:", rg.GetAttribute("product_version").Read(),
      "| id:", rg.GetAttribute("id").Read())
lat = rg.OpenMDArray("latitude").ReadAsArray()
lon = rg.OpenMDArray("longitude").ReadAsArray()
tarr = rg.OpenMDArray("time")
units = tarr.GetUnit()
t = tarr.ReadAsArray().astype("int64")
print("time units:", units, "| n:", len(t))
assert units.startswith("seconds since 1981-01-01")
dates = (np.datetime64("1981-01-01T00:00:00") + t.astype("timedelta64[s]")).astype("datetime64[D]")
print("first, last date:", dates[0], dates[-1], "| steps of 1 day:", bool(np.all(np.diff(dates).astype(int) == 1)))

sst = rg.OpenMDArray("analysed_sst")
scale, offset = sst.GetScale(), sst.GetOffset()
nodata = sst.GetNoDataValueAsDouble()
print("analysed_sst scale, offset, nodata:", scale, offset, nodata, "| unit:", sst.GetUnit())

px = [(x, y) for y in (-43.025, -41.025, -39.025) for x in (150.025, 152.025, 154.025)]
rows = []
for x, y in px:
    i = int(np.argmin(np.abs(lat - y))); j = int(np.argmin(np.abs(lon - x)))
    t0 = time.time()
    raw = sst.GetView(f"[:,{i},{j}]").ReadAsArray().astype("float64")
    v = np.where(raw == nodata, np.nan, raw * scale + offset)
    print(f"  {x:.3f},{y:.3f}: grid {lon[j]:.4f},{lat[i]:.4f}; {np.isnan(v).sum()} missing; "
          f"{time.time() - t0:.0f} s")
    rows.append((x, y, v))

with open(out + ".part", "w") as f:
    f.write("date,lon,lat,sst\n")
    for x, y, v in rows:
        for d, s in zip(dates, v):
            f.write(f"{d},{x:.3f},{y:.3f},{'' if np.isnan(s) else f'{s:.4f}'}\n")
os.replace(out + ".part", out)
print("wrote", out)
