# Changelog

## glmap 0.1.0

- Initial release of `glmap`: High-Performance GPU Geospatial Mapping
  for `sf` and `terra` in R.
- Added C++17 `GLMP` (vector) and `GLMR` (`Float32` raster) binary
  encoders
  ([`gl_pack_sf_binary()`](https://meztez.github.io/glmap/reference/gl_pack_sf_binary.md),
  [`gl_pack_raster_binary()`](https://meztez.github.io/glmap/reference/gl_pack_raster_binary.md))
  with `mapbox/earcut.h` polygon hole triangulation.
- Added WebGL2 + MapLibre GL JS rendering engine with instanced SDF
  point shaders, polygon/line mesh shaders, additive Gaussian kernel
  heatmaps, 64-bit C++ hexagonal spatial binning
  ([`add_hexbin()`](https://meztez.github.io/glmap/reference/add_hexbin.md)),
  and `RGBA32F` floating-point raster fragment shaders
  ([`add_raster()`](https://meztez.github.io/glmap/reference/add_raster.md))
  with 0 ms LUT palette switching, real-time surface-normal hillshading,
  and multi-band math.
- Added `gl_providers`,
  [`add_provider_tiles()`](https://meztez.github.io/glmap/reference/add_provider_tiles.md),
  [`gl_set_api_key()`](https://meztez.github.io/glmap/reference/gl_set_api_key.md),
  and
  [`gl_get_api_key()`](https://meztez.github.io/glmap/reference/gl_set_api_key.md)
  supporting CARTO, OpenFreeMap, OpenStreetMap, Esri, OpenTopoMap, USGS,
  MapTiler, Stadia, Thunderforest, Jawg, and Mapbox.
- Added full `leaflet` superuser parity functions
  ([`add_circles()`](https://meztez.github.io/glmap/reference/add_circles.md),
  [`add_rectangles()`](https://meztez.github.io/glmap/reference/add_rectangles.md),
  [`add_popups()`](https://meztez.github.io/glmap/reference/add_popups.md),
  [`add_labels()`](https://meztez.github.io/glmap/reference/add_labels.md),
  [`add_wms_tiles()`](https://meztez.github.io/glmap/reference/add_wms_tiles.md),
  [`show_group()`](https://meztez.github.io/glmap/reference/show_group.md),
  [`hide_group()`](https://meztez.github.io/glmap/reference/show_group.md),
  [`clear_group()`](https://meztez.github.io/glmap/reference/show_group.md),
  [`fly_to_bounds()`](https://meztez.github.io/glmap/reference/fly_to_bounds.md),
  [`set_max_bounds()`](https://meztez.github.io/glmap/reference/set_max_bounds.md)).
- Added
  [`glmap_proxy()`](https://meztez.github.io/glmap/reference/glmap_proxy.md),
  [`glmapOutput()`](https://meztez.github.io/glmap/reference/glmapOutput.md),
  and
  [`renderGlmap()`](https://meztez.github.io/glmap/reference/renderGlmap.md)
  with `leaflet`-compatible Shiny events (`_click`, `_bounds`, `_zoom`,
  `_center`, `_marker_click`, `_shape_click`, `_selected`) and
  `crosstalk` linked brushing.
- Added optional out-of-core `DuckDB` / `.parquet` viewport streaming
  ([`add_duckdb()`](https://meztez.github.io/glmap/reference/add_duckdb.md))
  and C++17 spatial grid/R-tree indexing
  ([`gl_spatial_index()`](https://meztez.github.io/glmap/reference/gl_spatial_index.md)).
