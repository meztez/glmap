# Changelog

## glmap 1.0.0

- **Production 1.0.0 Release**: Complete C++17 + WebGL2 + MapLibre GL
  geospatial mapping engine for R (`sf`, `terra`, `wk`, `nanoarrow`,
  `DuckDB`, `Shiny`, `Quarto`) with 100% drop-in `leaflet` and
  `leaflet.extras` compatibility.
- **Zero-Rewrite `leaflet` Compatibility Layer (`leaflet_compat`)**:
  - Added full camelCase function and option exports
    ([`leaflet()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addTiles()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addProviderTiles()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addMarkers()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addAwesomeMarkers()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addCircleMarkers()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addLabelOnlyMarkers()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addPolygons()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addPolylines()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addCircles()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addRectangles()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addPopups()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`clearPopups()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addRasterImage()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addWMSTiles()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addLegend()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addLayersControl()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addMeasure()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addMiniMap()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addGraticule()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addSimpleGraticule()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addTerminator()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addDrawToolbar()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`removeDrawToolbar()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`addSearchOSM()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`setView()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`fitBounds()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`flyTo()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`flyToBounds()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`setMaxBounds()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`showGroup()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`hideGroup()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`clearGroup()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`clearShapes()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`clearMarkers()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`clearControls()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`removeShape()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`removeMarker()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`leafletOutput()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`renderLeaflet()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`leafletProxy()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    `providers`, and `%>%`).
  - Added palette & formatting functions
    ([`color_numeric()`](https://meztez.github.io/glmap/reference/color_numeric.md)
    /
    [`colorNumeric()`](https://meztez.github.io/glmap/reference/color_numeric.md),
    [`color_bin()`](https://meztez.github.io/glmap/reference/color_numeric.md)
    /
    [`colorBin()`](https://meztez.github.io/glmap/reference/color_numeric.md),
    [`color_quantile()`](https://meztez.github.io/glmap/reference/color_numeric.md)
    /
    [`colorQuantile()`](https://meztez.github.io/glmap/reference/color_numeric.md),
    [`color_factor()`](https://meztez.github.io/glmap/reference/color_numeric.md)
    /
    [`colorFactor()`](https://meztez.github.io/glmap/reference/color_numeric.md),
    [`label_format()`](https://meztez.github.io/glmap/reference/color_numeric.md)
    /
    [`labelFormat()`](https://meztez.github.io/glmap/reference/color_numeric.md))
    and option builders
    ([`highlight_options()`](https://meztez.github.io/glmap/reference/highlight_options.md)
    /
    [`highlightOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`label_options()`](https://meztez.github.io/glmap/reference/highlight_options.md)
    /
    [`labelOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`popup_options()`](https://meztez.github.io/glmap/reference/highlight_options.md)
    /
    [`popupOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`icons()`](https://meztez.github.io/glmap/reference/add_markers.md),
    [`icon_list()`](https://meztez.github.io/glmap/reference/add_markers.md)
    /
    [`iconList()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`awesome_icons()`](https://meztez.github.io/glmap/reference/add_markers.md)
    /
    [`awesomeIcons()`](https://meztez.github.io/glmap/reference/leaflet_compat.md),
    [`awesome_icon_list()`](https://meztez.github.io/glmap/reference/add_markers.md)
    /
    [`awesomeIconList()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)).
  - Added hover polygon/line border highlighting (`highlightOptions`),
    permanent label layers (`labelOptions(noHide = TRUE)`), unfilled
    polygon rings (`fill = FALSE`), 2-column matrix and `maps::map`
    geometry support, and vectorized per-feature `layerId = ~col`
    propagation to Shiny `_shape_click` / `_marker_click` events.
- **Three-Mode GPU Custom Icon & Marker Engine (`atlas`, `cluster`,
  `lod`)**:
  - WebGL2 Sprite Texture Atlas shader (`progIcons`) with automatic
    `crossOrigin = "anonymous"` CORS handling and multi-color
    [`awesomeIcons()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
    sprite sheets.
  - Screen-space marker clustering
    ([`marker_cluster_options()`](https://meztez.github.io/glmap/reference/add_markers.md))
    with automatic **Spiderfy Web Expansion** (radial/spiral WebGL legs
    drawn underneath icons and terminating at exact icon centers) when
    overlapping points share identical coordinates.
  - Zoom-level Level-of-Detail (`"lod"`) cross-fade between GPU SDF
    points and custom icons, plus an interactive **Marker / Icon
    Engine** switcher in `☰ Layers`.
- **4-Channel `RGBA` Raster LUT, Web Mercator Latitude Unprojection &
  Shader Controls**:
  - Preserves per-stop alpha (`#RRGGBBAA`) in 1D GPU LUT textures so
    transparent `0 mm` precipitation / nodata ranges are discarded
    cleanly on the GPU.
  - Unprojects Web Mercator fragments back to geographic latitude in
    `fsRaster` so `EPSG:4326` rasters align tightly with vector borders
    across wide latitude spans.
  - Added interactive **Layer Opacity** slider and
    `shader_controls = TRUE/FALSE` toggle on
    [`add_raster()`](https://meztez.github.io/glmap/reference/add_raster.md)
    and
    [`set_raster_style()`](https://meztez.github.io/glmap/reference/set_raster_style.md).
- **9-Zone Directional Control Dock & Built-in Widgets**:
  - Added
    [`add_minimap()`](https://meztez.github.io/glmap/reference/add_minimap.md),
    [`add_graticule()`](https://meztez.github.io/glmap/reference/add_graticule.md),
    [`add_simple_graticule()`](https://meztez.github.io/glmap/reference/add_graticule.md),
    [`add_terminator()`](https://meztez.github.io/glmap/reference/add_terminator.md),
    [`add_measure()`](https://meztez.github.io/glmap/reference/add_measure.md),
    [`add_search_osm()`](https://meztez.github.io/glmap/reference/add_search_osm.md),
    and
    [`add_draw_toolbar()`](https://meztez.github.io/glmap/reference/add_draw_toolbar.md)
    inside an isolated CSS stacking context
    (`isolation: isolate; z-index: 0;`).
- **Quarto HTML / PDF & Static Export (`gl_save_png`)**:
  - Enabled `preserveDrawingBuffer: true` on both the MapLibre GL base
    canvas and the WebGL2 overlay canvas, added `@media print` rules,
    and exported
    [`gl_save_png()`](https://meztez.github.io/glmap/reference/gl_save_png.md)
    for headless Chromium PNG/PDF snapshot capture.
- **Licensing & Attributions**:
  - Documented permissive MIT package license alongside bundled
    `MapLibre GL JS v4.7.1` (`BSD-3-Clause`) and
    `mapbox/earcut.hpp v2.2.4` (`ISC`) notices in `LICENSE.md` and
    `inst/COPYRIGHTS`.

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
