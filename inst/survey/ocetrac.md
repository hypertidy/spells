# Ocetrac 0.1.7

- **Source read:** ocetrac/ocetrac at `b76a43f` (2026-06-18, v0.1.7 plus
  two documentation commits), MIT, Python (xarray, dask, scipy,
  scikit-image).
- **How:** read 2026-11-17 from the source and docs. **Not run.** The
  findings below don't depend on running it.
- **References:** Scannell et al. 2024, *J. Atmos. Oceanic Technol.*,
  doi:10.1175/JTECH-D-23-0126.1 (SurfTrack), and Cai et al. 2025, SciPy
  Proceedings, doi:10.25080/vxkf4244. DeepTrack is unpublished.
- Paths below are relative to `ocetrac/` at that commit.

## What it is

Ocetrac labels and tracks objects in a field it is given. It doesn't
define heatwaves: `preprocessing/` offers one way to make the field.
There are two trackers:
- **SurfTrack**, on (time, lat, lon): the original algorithm, in
  `SurfTrack/`;
- **DeepTrack**, on (time, depth, lat, lon): new in 0.1.7, for the POP
  grid (CESM) only, in `DeepTrack/`.

## Preprocessing (`preprocessing/preprocessing.py`)

- **Baseline:** a least-squares fit per pixel over the whole record:
  mean, linear trend, and annual and semiannual harmonics. The
  anomalies are the residuals, so this is a detrended baseline.
  - The time variable is `year + month/12`, so the model is monthly.
    With daily data, every day of a month gets the same time value.
- **Threshold:** one quantile per pixel over all time steps (default
  0.9), not one per day of year. The comparison is `>=`.
- **Persistence:** none. No minimum duration and no gap joining.

## SurfTrack (`SurfTrack/tracker.py`, `SurfTrack/__init__.py`)

The steps, in order:
1. **Binarise:** `> 0` for warm, `< 0` for cold, on the given field
   (usually the anomalies at or above the threshold, NaN elsewhere).
2. **Morphological cleaning** of each frame: a closing, then an opening,
   with a disk of `radius` (default 2).
   - The disk is `x² + y² < r²`, so radius 2 is a 3×3 square, and radius
     1 does nothing. `preprocessing.clean_binary`, which DeepTrack uses,
     takes `<=` instead.
   - The padding wraps **both** axes (`np.pad(..., mode="wrap")`).
     Within the radius, the north edge connects to the south edge, and
     on a regional grid the east edge connects to the west.
   - A pixel can join an object without exceeding the threshold, or
     leave one while exceeding it.
3. **Ocean mask:** cells outside it are set to 0.
4. **Area filter, per frame and per blob, in grid cells:** it keeps blobs
   of at least `max(min_area_cells = 100, the 25th percentile of all blob
   areas)`. The percentile is over the whole dataset, so adding data
   changes which past blobs survive. Blobs are counted in cells, not
   km², so the same threshold means a smaller area at high latitudes.
5. **Linking** across time, by one of two methods:
   - `"3d"` (the default): connected components of the (time, lat, lon)
     volume with connectivity 3, which is all 26 neighbours, diagonals
     in time included. Objects merge and split freely.
   - `"temporal_neighbor"`: each frame is labelled on its own, and blobs
     in adjacent frames are joined (union-find) when they overlap by at
     least `contain_thresh`, measured as max(|A∩B|/|A|, |A∩B|/|B|).
     A gap of one frame starts a new event.
6. **Dateline:** labels in the first and last longitude columns are
   merged when the grid spans 360°.

**Output:** a label array (time, lat, lon) with NaN background, and the
parameters as attributes.

**Measures** (`SurfTrack/measures/`):
- duration, in time steps;
- intensity: the spatial sum, mean, max, standard deviation and a
  quantile of the anomalies, per step and overall. These aren't weighted
  by cell area;
- shape: area in km² (cos(lat) × 111.32 km by 110.574 km per degree),
  convex-hull ratio, circularity, deformation;
- motion: displacement of the centroid and the centre of mass, in km.

## DeepTrack (`DeepTrack/`), skimmed

1. Clean and label each (time, depth) slice, then apply the area filter
   per depth level.
2. Connect through depth with an anisotropic structuring element.
3. Drop the smallest fraction of 3-D objects by voxel count.
4. Track across time by containment, with splitting and a lineage map:
   - the score is `alpha` × voxel containment + (1 − `alpha`) × volume
     containment, with `contain_thresh` 0.3 by default;
   - when two lineages merge, the smaller ID wins.

Cell volumes come from POP's `TAREA` and layer thicknesses. Handling the
dateline is still a TODO in `DeepTrack/tracker.py`.

## What this means for spells

1. **Not an oracle for spells' per-pixel spells.** Its baseline is a
   monthly harmonic and trend fit, its threshold isn't seasonal, and it
   has no duration rule. For events as objects it's the main prior art,
   but it labels a cleaned exceedance mask, as heatwave3's blobs do.
   Neither labels a spell mask, so the brief's design stays its own.
2. **Linking rules worth offering:** spells' "components of the
   space-time spell mask" is Ocetrac's `"3d"` method applied to a
   different mask. `"temporal_neighbor"` with a containment threshold
   (DeepTrack's lineage version too) is a second rule, which limits how
   far chains of merges can run. The def should name the rule and its
   connectivity, as it names the gap rule.
3. **Area by weight, not by cell count.** Area filters and intensity sums
   should use cell area (grist weights), so a threshold means the same
   area at every latitude.
4. **No dataset-relative filters.** A threshold taken from a percentile
   of all blob areas changes past events whenever data is added. That
   breaks the "batch and streaming agree" rule. Fixed area thresholds
   don't.
5. **Morphological cleaning changes which pixels are in an event.** If
   spells offers it, it has to be a separate step that the def records,
   applied after the spell mask, and periodic in longitude only.
6. **DeepTrack** is prior art for the subsurface work (BRAN2023 on Gadi):
   connecting through depth, volume-weighted containment, and
   vertically uneven grids.
