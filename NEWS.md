# glmap 1.0.1

* **Triangulated Polygon Interior Hit-Testing & Picking (`glmap.js`)**:
  * Added exact Mercator triangle point-in-polygon hit-testing (`_pickFeatureAt` using `parsed.indices` and `parsed.mercCoords`) in both `_handleHover()` and `_handleClick()` in reverse layer draw order (`points`/`labels` prioritized before `polygons`/`lines`). Hovering or clicking anywhere inside a filled polygon or hexagon now reliably triggers tooltips, hover highlights (`highlightOptions`), popups, and Shiny `_shape_mouseover` / `_shape_click` events instead of requiring cursor proximity to a boundary vertex.
* **Popup vs. Hover Tooltip Separation (`add_points`, `add_polygons`, `add_lines`)**:
  * Separated hover `tooltips` (`label`) from click `popups` (`popup`) in layer specifications so hovering displays `label` while clicking opens `popup` when both are provided, and raised the default `max_items` cap in `build_popup_labels()` and `feature_ids` to `250,000` features for high-density GPU layers.
* **Layer Switcher & Legend Group Synchronization**:
  * Excluded internal helper layer groups (`cat_claims_overlay`, `sg_shape`, `js_single_call`) from the user-facing `☰ Layers` switcher list.
  * Updated `addLayer()` and `clearGroup()` in `glmap.js` to synchronize `_selectedOverlayGroups`, remove group-bound legends when a group is cleared, and emit `<mapId>_groups` to Shiny when visible overlay groups change.

# glmap 1.0.0

* **Production 1.0.0 Release**: Complete C++17 + WebGL2 + MapLibre GL geospatial mapping engine for R (`sf`, `terra`, `wk`, `nanoarrow`, `DuckDB`, `Shiny`, `Quarto`) with 100% drop-in `leaflet` and `leaflet.extras` compatibility.
* **Zero-Rewrite `leaflet` Compatibility Layer (`leaflet_compat`)**:
  * Added full camelCase function and option exports (`leaflet()`, `addTiles()`, `addProviderTiles()`, `addMarkers()`, `addAwesomeMarkers()`, `addCircleMarkers()`, `addLabelOnlyMarkers()`, `addPolygons()`, `addPolylines()`, `addCircles()`, `addRectangles()`, `addPopups()`, `clearPopups()`, `addRasterImage()`, `addWMSTiles()`, `addLegend()`, `addLayersControl()`, `addMeasure()`, `addMiniMap()`, `addGraticule()`, `addSimpleGraticule()`, `addTerminator()`, `addDrawToolbar()`, `removeDrawToolbar()`, `addSearchOSM()`, `setView()`, `fitBounds()`, `flyTo()`, `flyToBounds()`, `setMaxBounds()`, `showGroup()`, `hideGroup()`, `clearGroup()`, `clearShapes()`, `clearMarkers()`, `clearControls()`, `removeShape()`, `removeMarker()`, `leafletOutput()`, `renderLeaflet()`, `leafletProxy()`, `providers`, and `%>%`).
  * Added palette & formatting functions (`color_numeric()` / `colorNumeric()`, `color_bin()` / `colorBin()`, `color_quantile()` / `colorQuantile()`, `color_factor()` / `colorFactor()`, `label_format()` / `labelFormat()`) and option builders (`highlight_options()` / `highlightOptions()`, `label_options()` / `labelOptions()`, `popup_options()` / `popupOptions()`, `icons()`, `icon_list()` / `iconList()`, `awesome_icons()` / `awesomeIcons()`, `awesome_icon_list()` / `awesomeIconList()`).
  * Added hover polygon/line border highlighting (`highlightOptions`), permanent label layers (`labelOptions(noHide = TRUE)`), unfilled polygon rings (`fill = FALSE`), 2-column matrix and `maps::map` geometry support, and vectorized per-feature `layerId = ~col` propagation to Shiny `_shape_click` / `_marker_click` events.
* **Three-Mode GPU Custom Icon & Marker Engine (`atlas`, `cluster`, `lod`)**:
  * WebGL2 Sprite Texture Atlas shader (`progIcons`) with automatic `crossOrigin = "anonymous"` CORS handling and multi-color `awesomeIcons()` sprite sheets.
  * Screen-space marker clustering (`marker_cluster_options()`) with automatic **Spiderfy Web Expansion** (radial/spiral WebGL legs drawn underneath icons and terminating at exact icon centers) when overlapping points share identical coordinates.
  * Zoom-level Level-of-Detail (`"lod"`) cross-fade between GPU SDF points and custom icons, plus an interactive **Marker / Icon Engine** switcher in `☰ Layers`.
* **4-Channel `RGBA` Raster LUT, Web Mercator Latitude Unprojection & Shader Controls**:
  * Preserves per-stop alpha (`#RRGGBBAA`) in 1D GPU LUT textures so transparent `0 mm` precipitation / nodata ranges are discarded cleanly on the GPU.
  * Unprojects Web Mercator fragments back to geographic latitude in `fsRaster` so `EPSG:4326` rasters align tightly with vector borders across wide latitude spans.
  * Added interactive **Layer Opacity** slider and `shader_controls = TRUE/FALSE` toggle on `add_raster()` and `set_raster_style()`.
* **9-Zone Directional Control Dock & Built-in Widgets**:
  * Added `add_minimap()`, `add_graticule()`, `add_simple_graticule()`, `add_terminator()`, `add_measure()`, `add_search_osm()`, and `add_draw_toolbar()` inside an isolated CSS stacking context (`isolation: isolate; z-index: 0;`).
* **Quarto HTML / PDF & Static Export (`gl_save_png`)**:
  * Enabled `preserveDrawingBuffer: true` on both the MapLibre GL base canvas and the WebGL2 overlay canvas, added `@media print` rules, and exported `gl_save_png()` for headless Chromium PNG/PDF snapshot capture.
* **Licensing & Attributions**:
  * Documented permissive MIT package license alongside bundled `MapLibre GL JS v4.7.1` (`BSD-3-Clause`) and `mapbox/earcut.hpp v2.2.4` (`ISC`) notices in `LICENSE.md` and `inst/COPYRIGHTS`.

# glmap 0.1.0

* Initial release of `glmap`: High-Performance GPU Geospatial Mapping for `sf` and `terra` in R.
* Added C++17 `GLMP` (vector) and `GLMR` (`Float32` raster) binary encoders (`gl_pack_sf_binary()`, `gl_pack_raster_binary()`) with `mapbox/earcut.h` polygon hole triangulation.
* Added WebGL2 + MapLibre GL JS rendering engine with instanced SDF point shaders, polygon/line mesh shaders, additive Gaussian kernel heatmaps, 64-bit C++ hexagonal spatial binning (`add_hexbin()`), and `RGBA32F` floating-point raster fragment shaders (`add_raster()`) with 0 ms LUT palette switching, real-time surface-normal hillshading, and multi-band math.
* Added `gl_providers`, `add_provider_tiles()`, `gl_set_api_key()`, and `gl_get_api_key()` supporting CARTO, OpenFreeMap, OpenStreetMap, Esri, OpenTopoMap, USGS, MapTiler, Stadia, Thunderforest, Jawg, and Mapbox.
* Added full `leaflet` superuser parity functions (`add_circles()`, `add_rectangles()`, `add_popups()`, `add_labels()`, `add_wms_tiles()`, `show_group()`, `hide_group()`, `clear_group()`, `fly_to_bounds()`, `set_max_bounds()`).
* Added `glmap_proxy()`, `glmapOutput()`, and `renderGlmap()` with `leaflet`-compatible Shiny events (`_click`, `_bounds`, `_zoom`, `_center`, `_marker_click`, `_shape_click`, `_selected`) and `crosstalk` linked brushing.
* Added optional out-of-core `DuckDB` / `.parquet` viewport streaming (`add_duckdb()`) and C++17 spatial grid/R-tree indexing (`gl_spatial_index()`).
