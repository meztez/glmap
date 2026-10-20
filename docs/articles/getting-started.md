# Getting Started with glmap

## Why `glmap`?

Traditional R mapping packages built on `Leaflet.js` serialize spatial
objects into GeoJSON text inside HTML and draw features using DOM/SVG/2D
Canvas. When your dataset reaches **100,000 to 1,000,000+ features** or
uses high-resolution `terra` rasters, R spends tens of seconds
converting coordinates to text and the browser tab freezes.

`glmap` eliminates the JSON and DOM bottlenecks entirely:

1.  **C++17 Binary Packing (`GEXP` & `GEXR`)**: Coordinates, polygon
    `mapbox/earcut` triangle indices (with full interior hole support),
    and `Float32` raster bands are packed into contiguous binary buffers
    in milliseconds.
2.  **WebGL2 GPU Shaders**: Points, lines, polygons, heatmaps, hexagonal
    bins, and floating-point rasters are rendered directly on the GPU at
    60 FPS.
3.  **Zero-Recompute Raster Exploration**:
    [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
    layers are uploaded as `Float32` textures. Changing palettes
    (`viridis`, `magma`, `turbo`, `terrain`, `rdylbu`) or toggling
    real-time GPU hillshading happens in **0 ms** in the fragment
    shader.

------------------------------------------------------------------------

## 1. Instant One-Line Exploration

[`glmap()`](https://meztez.github.io/glmap/reference/glmap.md) inspects
your input (`sf`, `sfc`,
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html),
[`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html),
[`wk::xy`](https://paleolimbot.github.io/wk/reference/xy.html),
`nanoarrow`, `data.frame`, or
[`crosstalk::SharedData`](https://rdrr.io/pkg/crosstalk/man/SharedData.html))
and automatically chooses the right GPU layer:

``` r

library(glmap)

# Generate synthetic benchmark data
bench <- gl_benchmark_data(n_points = 100000L, n_polygons = 2000L)

# Instant GPU map of 100,000 points
glmap(bench$points_df, color = ~intensity, palette = "turbo", radius = 3)

# Instant GPU map of a Float32 DEM raster with real-time hillshading
glmap(bench$raster_mat, palette = "terrain", hillshade = TRUE)
```

------------------------------------------------------------------------

## 2. Building Multi-Layer GPU Maps with Pipes (`|>`)

Use [`glmap()`](https://meztez.github.io/glmap/reference/glmap.md) with
[`add_raster()`](https://meztez.github.io/glmap/reference/add_raster.md),
[`add_polygons()`](https://meztez.github.io/glmap/reference/add_polygons.md),
[`add_lines()`](https://meztez.github.io/glmap/reference/add_lines.md),
[`add_points()`](https://meztez.github.io/glmap/reference/add_points.md),
[`add_hexbin()`](https://meztez.github.io/glmap/reference/add_hexbin.md),
[`add_heatmap()`](https://meztez.github.io/glmap/reference/add_heatmap.md),
and
[`add_labels()`](https://meztez.github.io/glmap/reference/add_labels.md):

``` r

glmap(basemap = "dark") |>
  add_raster(
    bench$raster_mat,
    palette = "terrain",
    hillshade = TRUE,
    opacity = 0.65,
    group = "Terrain DEM (Float32)"
  ) |>
  add_polygons(
    bench$polygons_sf,
    fill_color = ~elevation,
    palette = "viridis",
    fill_opacity = 0.65,
    group = "Polygons (C++ Earcut)"
  ) |>
  add_hexbin(
    bench$points_df,
    hex_radius = 0.035,
    palette = "plasma",
    opacity = 0.75,
    group = "Hexbins (C++ 64-bit Hash)"
  ) |>
  add_points(
    bench$points_df,
    color = ~intensity,
    palette = "turbo",
    radius = 3.0,
    opacity = 0.85,
    group = "Points (WebGL2 SDF)"
  ) |>
  use_plugin("export_png")
```

------------------------------------------------------------------------

## 3. Handling 1M–10M+ Features with In-Memory C++ Spatial Indexing or DuckDB

For massive datasets in interactive R or Shiny sessions, enable
`dynamic_viewport = TRUE`, `transport = "server"`, or
[`add_duckdb()`](https://meztez.github.io/glmap/reference/add_duckdb.md).
`glmap` builds an in-memory C++ spatial index
([`gl_spatial_index()`](https://meztez.github.io/glmap/reference/gl_spatial_index.md))
or queries DuckDB to stream only the features inside the current
viewport with automatic Level-of-Detail (LOD) stride sampling:

``` r

big_df <- data.frame(
  lon = runif(1e6, -75, -71),
  lat = runif(1e6, 45, 48),
  val = rnorm(1e6)
)

glmap(basemap = "dark", transport = "server") |>
  add_points(
    big_df,
    color = ~val,
    palette = "viridis",
    radius = 2.5,
    dynamic_viewport = TRUE
  )
```
