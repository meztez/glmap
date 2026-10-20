# glmap 0.1.0

* Initial release of `glmap`: High-Performance GPU Geospatial Mapping for `sf` and `terra` in R.
* Added C++17 `GLMP` (vector) and `GLMR` (`Float32` raster) binary encoders (`gl_pack_sf_binary()`, `gl_pack_raster_binary()`) with `mapbox/earcut.h` polygon hole triangulation.
* Added WebGL2 + MapLibre GL JS rendering engine with instanced SDF point shaders, polygon/line mesh shaders, additive Gaussian kernel heatmaps, 64-bit C++ hexagonal spatial binning (`add_hexbin()`), and `RGBA32F` floating-point raster fragment shaders (`add_raster()`) with 0 ms LUT palette switching, real-time surface-normal hillshading, and multi-band math.
* Added `gl_providers`, `add_provider_tiles()`, `gl_set_api_key()`, and `gl_get_api_key()` supporting CARTO, OpenFreeMap, OpenStreetMap, Esri, OpenTopoMap, USGS, MapTiler, Stadia, Thunderforest, Jawg, and Mapbox.
* Added full `leaflet` superuser parity functions (`add_circles()`, `add_rectangles()`, `add_popups()`, `add_labels()`, `add_wms_tiles()`, `show_group()`, `hide_group()`, `clear_group()`, `fly_to_bounds()`, `set_max_bounds()`).
* Added `glmap_proxy()`, `glmapOutput()`, and `renderGlmap()` with `leaflet`-compatible Shiny events (`_click`, `_bounds`, `_zoom`, `_center`, `_marker_click`, `_shape_click`, `_selected`) and `crosstalk` linked brushing.
* Added optional out-of-core `DuckDB` / `.parquet` viewport streaming (`add_duckdb()`) and C++17 spatial grid/R-tree indexing (`gl_spatial_index()`).
