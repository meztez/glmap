# Generate Synthetic Geospatial Benchmark Datasets (`gl_benchmark_data`)

Useful for stress-testing 100k–1M+ points, polygons, and rasters.

## Usage

``` r
gl_benchmark_data(
  n_points = 100000L,
  n_polygons = 2000L,
  raster_dim = c(250L, 250L),
  bbox = c(-74.2, 45.3, -71, 47)
)
```

## Arguments

- n_points:

  Number of points to generate.

- n_polygons:

  Number of polygons to generate.

- raster_dim:

  Integer vector `c(nrow, ncol)` for synthetic DEM raster.

- bbox:

  Bounding box `c(xmin, ymin, xmax, ymax)`.

## Value

A list with `points_df`, `polygons_sf`, and `raster_mat`.
