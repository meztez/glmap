# Package index

## Map Initialization, Camera & Providers

Initialize a GPU map and control camera position, bounds, basemap
providers, API keys, terrain, and projection.

- [`glmap()`](https://meztez.github.io/glmap/reference/glmap.md) :

  Create a High-Performance GPU Map Widget (`glmap`)

- [`set_view()`](https://meztez.github.io/glmap/reference/set_view.md) :
  Set Map Camera View (Center, Zoom, Pitch, Bearing)

- [`fit_bounds()`](https://meztez.github.io/glmap/reference/fit_bounds.md)
  :

  Fit Map Camera to a Bounding Box `[xmin, ymin, xmax, ymax]`
  (`fit_bounds`)

- [`fly_to()`](https://meztez.github.io/glmap/reference/fly_to.md) :

  Smoothly Animate Camera to Target Location (`flyTo`)

- [`fly_to_bounds()`](https://meztez.github.io/glmap/reference/fly_to_bounds.md)
  :

  Smoothly Animate Camera to Bounding Box (`fly_to_bounds`)

- [`set_max_bounds()`](https://meztez.github.io/glmap/reference/set_max_bounds.md)
  :

  Restrict Map Panning to Maximum Bounding Box (`set_max_bounds`)

- [`set_basemap()`](https://meztez.github.io/glmap/reference/set_basemap.md)
  :

  Change the Map Basemap Style (`set_basemap`)

- [`add_provider_tiles()`](https://meztez.github.io/glmap/reference/add_provider_tiles.md)
  :

  Add or Switch Basemap Provider Tiles (`add_provider_tiles`)

- [`gl_providers`](https://meztez.github.io/glmap/reference/gl_providers.md)
  :

  Basemap Tile Providers Catalog (`gl_providers`)

- [`gl_list_providers()`](https://meztez.github.io/glmap/reference/gl_list_providers.md)
  :

  List All Built-in Basemap Tile Providers in `glmap`

- [`gl_set_api_key()`](https://meztez.github.io/glmap/reference/gl_set_api_key.md)
  [`gl_get_api_key()`](https://meztez.github.io/glmap/reference/gl_set_api_key.md)
  :

  Set or Retrieve a Provider API Key (`gl_set_api_key` /
  `gl_get_api_key`)

- [`set_terrain()`](https://meztez.github.io/glmap/reference/set_terrain.md)
  : Enable 3D Terrain Elevation on the Map

- [`set_projection()`](https://meztez.github.io/glmap/reference/set_projection.md)
  :

  Set Map Projection (`"mercator"` or `"globe"`)

- [`add_control()`](https://meztez.github.io/glmap/reference/add_control.md)
  :

  Configure Map UI Controls & 9-Zone Layout Anchoring (`add_control`)

- [`add_layers_control()`](https://meztez.github.io/glmap/reference/add_layers_control.md)
  :

  Add a Collapsible Layers & Basemap Control (`add_layers_control`)

- [`layers_control_options()`](https://meztez.github.io/glmap/reference/layers_control_options.md)
  :

  Options for
  [`add_layers_control()`](https://meztez.github.io/glmap/reference/add_layers_control.md)
  (`layers_control_options`)

- [`add_draw_toolbar()`](https://meztez.github.io/glmap/reference/add_draw_toolbar.md)
  :

  Add an Interactive Vector Drawing Toolbar (`add_draw_toolbar`)

- [`remove_draw_toolbar()`](https://meztez.github.io/glmap/reference/remove_draw_toolbar.md)
  :

  Remove the Interactive Drawing Toolbar (`remove_draw_toolbar`)

- [`draw_toolbar_options()`](https://meztez.github.io/glmap/reference/draw_toolbar_options.md)
  :

  Configure Custom Tooltip Titles for
  [`add_draw_toolbar()`](https://meztez.github.io/glmap/reference/add_draw_toolbar.md)
  (`draw_toolbar_options`)

- [`add_measure()`](https://meztez.github.io/glmap/reference/add_measure.md)
  :

  Add an Interactive Distance & Area Measurement Control (`add_measure`)

- [`add_search_osm()`](https://meztez.github.io/glmap/reference/add_search_osm.md)
  [`search_options()`](https://meztez.github.io/glmap/reference/add_search_osm.md)
  :

  Add an OpenStreetMap Address & Place Search Bar (`add_search_osm`,
  `search_options`)

- [`add_minimap()`](https://meztez.github.io/glmap/reference/add_minimap.md)
  :

  Add an Interactive Overview MiniMap (`add_minimap`)

- [`add_graticule()`](https://meztez.github.io/glmap/reference/add_graticule.md)
  [`add_simple_graticule()`](https://meztez.github.io/glmap/reference/add_graticule.md)
  :

  Add a Coordinate Graticule Grid (`add_graticule`,
  `add_simple_graticule`)

- [`add_terminator()`](https://meztez.github.io/glmap/reference/add_terminator.md)
  :

  Add a Solar Day/Night Terminator Polygon Layer (`add_terminator`)

- [`add_legend()`](https://meztez.github.io/glmap/reference/add_legend.md)
  :

  Add a Custom Map Legend (`add_legend`)

- [`gl_save_html()`](https://meztez.github.io/glmap/reference/gl_save_html.md)
  :

  Save a `glmap` Map to a Standalone HTML File (`gl_save_html`)

- [`gl_save_png()`](https://meztez.github.io/glmap/reference/gl_save_png.md)
  :

  Capture a High-Resolution Static PNG Screenshot of a `glmap` Widget
  (`gl_save_png`)

## GPU Vector, Raster & Out-of-Core Layers

Add high-density point clouds, geodesic circles, rectangles, lines,
earcut-triangulated polygons, Float32 rasters, hexbins, heatmaps, WMS,
PMTiles, and DuckDB layers.

- [`add_sf()`](https://meztez.github.io/glmap/reference/add_sf.md) :

  Automatically Add an `sf`, `sfc`, or `data.frame` Layer to a `glmap`
  Map

- [`add_points()`](https://meztez.github.io/glmap/reference/add_points.md)
  : Add a GPU Instanced Point Layer (Handles 1M+ Points at 60 FPS)

- [`add_markers()`](https://meztez.github.io/glmap/reference/add_markers.md)
  [`make_icon()`](https://meztez.github.io/glmap/reference/add_markers.md)
  [`icons()`](https://meztez.github.io/glmap/reference/add_markers.md)
  [`icon_list()`](https://meztez.github.io/glmap/reference/add_markers.md)
  [`make_awesome_icon()`](https://meztez.github.io/glmap/reference/add_markers.md)
  [`awesome_icons()`](https://meztez.github.io/glmap/reference/add_markers.md)
  [`awesome_icon_list()`](https://meztez.github.io/glmap/reference/add_markers.md)
  [`marker_cluster_options()`](https://meztez.github.io/glmap/reference/add_markers.md)
  [`icon_render_options()`](https://meztez.github.io/glmap/reference/add_markers.md)
  :

  Add Custom Icon or Awesome Markers (`add_markers`, `make_icon`,
  `make_awesome_icon`)

- [`add_circles()`](https://meztez.github.io/glmap/reference/add_circles.md)
  :

  Add a Geodesic Circle Layer (`add_circles`)

- [`add_rectangles()`](https://meztez.github.io/glmap/reference/add_rectangles.md)
  :

  Add a Bounding-Box Rectangle Layer (`add_rectangles`)

- [`add_lines()`](https://meztez.github.io/glmap/reference/add_lines.md)
  : Add a GPU LineString / MultiLineString Layer

- [`add_polygons()`](https://meztez.github.io/glmap/reference/add_polygons.md)
  : Add a Pre-Triangulated GPU Polygon / MultiPolygon Layer

- [`add_raster()`](https://meztez.github.io/glmap/reference/add_raster.md)
  :

  Add a GPU Fragment-Shader Raster Layer for
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)

- [`add_hexbin()`](https://meztez.github.io/glmap/reference/add_hexbin.md)
  : Add a C++ Accelerated Hexagonal Binning Layer for 1M+ Points

- [`add_heatmap()`](https://meztez.github.io/glmap/reference/add_heatmap.md)
  : Add a GPU Additive Kernel Density Heatmap Layer

- [`add_labels()`](https://meztez.github.io/glmap/reference/add_labels.md)
  :

  Add a GPU Text / Symbol Label Layer (`add_labels`)

- [`add_popups()`](https://meztez.github.io/glmap/reference/add_popups.md)
  [`clear_popups()`](https://meztez.github.io/glmap/reference/add_popups.md)
  :

  Add Standalone HTML Popups (`add_popups`, `clear_popups`)

- [`add_wms_tiles()`](https://meztez.github.io/glmap/reference/add_wms_tiles.md)
  :

  Add an OGC Web Map Service (WMS) Raster Tile Layer (`add_wms_tiles`)

- [`add_pmtiles()`](https://meztez.github.io/glmap/reference/add_pmtiles.md)
  [`add_mvt()`](https://meztez.github.io/glmap/reference/add_pmtiles.md)
  : Add a Cloud-Native PMTiles or Mapbox Vector Tile (MVT) Layer

- [`add_geojson()`](https://meztez.github.io/glmap/reference/add_geojson.md)
  : Add a Raw GeoJSON URL or Object Layer

- [`add_duckdb()`](https://meztez.github.io/glmap/reference/add_duckdb.md)
  :

  Add a Live Out-of-Core DuckDB / Parquet Layer (`add_duckdb`)

- [`color_numeric()`](https://meztez.github.io/glmap/reference/color_numeric.md)
  [`color_bin()`](https://meztez.github.io/glmap/reference/color_numeric.md)
  [`color_quantile()`](https://meztez.github.io/glmap/reference/color_numeric.md)
  [`color_factor()`](https://meztez.github.io/glmap/reference/color_numeric.md)
  [`label_format()`](https://meztez.github.io/glmap/reference/color_numeric.md)
  [`colorNumeric()`](https://meztez.github.io/glmap/reference/color_numeric.md)
  [`colorBin()`](https://meztez.github.io/glmap/reference/color_numeric.md)
  [`colorQuantile()`](https://meztez.github.io/glmap/reference/color_numeric.md)
  [`colorFactor()`](https://meztez.github.io/glmap/reference/color_numeric.md)
  [`labelFormat()`](https://meztez.github.io/glmap/reference/color_numeric.md)
  :

  Leaflet-Compatible Color Palette Functions (`color_numeric`,
  `color_bin`, `color_quantile`, `color_factor`, `label_format`)

- [`highlight_options()`](https://meztez.github.io/glmap/reference/highlight_options.md)
  [`label_options()`](https://meztez.github.io/glmap/reference/highlight_options.md)
  [`popup_options()`](https://meztez.github.io/glmap/reference/highlight_options.md)
  [`provider_tile_options()`](https://meztez.github.io/glmap/reference/highlight_options.md)
  [`wms_tile_options()`](https://meztez.github.io/glmap/reference/highlight_options.md)
  :

  Leaflet Option Helpers (`highlight_options`, `label_options`,
  `popup_options`, `provider_tile_options`, `wms_tile_options`)

## Shiny Proxy, Group Controls & Live GPU Updates

Update layers, groups, visibility, opacity, filters, and GPU raster
shaders in 0ms without re-rendering.

- [`glmapOutput()`](https://meztez.github.io/glmap/reference/glmapOutput.md)
  :

  Shiny UI Output for `glmap`

- [`renderGlmap()`](https://meztez.github.io/glmap/reference/renderGlmap.md)
  :

  Shiny Server Render Function for `glmap`

- [`glmap_proxy()`](https://meztez.github.io/glmap/reference/glmap_proxy.md)
  :

  Create a Shiny Proxy for a `glmap` Map Widget

- [`show_group()`](https://meztez.github.io/glmap/reference/show_group.md)
  [`hide_group()`](https://meztez.github.io/glmap/reference/show_group.md)
  [`clear_group()`](https://meztez.github.io/glmap/reference/show_group.md)
  :

  Show, Hide, or Clear Layers by Group Name (`show_group`, `hide_group`,
  `clear_group`)

- [`clear_layer()`](https://meztez.github.io/glmap/reference/clear_layer.md)
  : Clear a Single Layer by ID

- [`clear_layers()`](https://meztez.github.io/glmap/reference/clear_layers.md)
  [`clear_shapes()`](https://meztez.github.io/glmap/reference/clear_layers.md)
  [`clear_markers()`](https://meztez.github.io/glmap/reference/clear_layers.md)
  [`clear_controls()`](https://meztez.github.io/glmap/reference/clear_layers.md)
  [`remove_shape()`](https://meztez.github.io/glmap/reference/clear_layers.md)
  [`remove_marker()`](https://meztez.github.io/glmap/reference/clear_layers.md)
  :

  Clear All Data Layers from a Map (`clear_layers`, `clear_shapes`,
  `clear_markers`, `clear_controls`, `remove_shape`, `remove_marker`)

- [`set_layer_visibility()`](https://meztez.github.io/glmap/reference/set_layer_visibility.md)
  : Toggle Layer Visibility

- [`set_layer_opacity()`](https://meztez.github.io/glmap/reference/set_layer_opacity.md)
  : Update Layer Opacity Dynamically

- [`set_raster_style()`](https://meztez.github.io/glmap/reference/set_raster_style.md)
  : Live-Update a GPU Raster Layer's Colormap, Contrast Range, or
  Hillshading (0ms GPU Update)

- [`set_marker_mode()`](https://meztez.github.io/glmap/reference/set_marker_mode.md)
  :

  Dynamically Switch Marker / Icon Rendering Strategy in Shiny
  (`set_marker_mode`)

- [`set_filter()`](https://meztez.github.io/glmap/reference/set_filter.md)
  : Filter Visible Features by Index on the GPU

## Drop-In Leaflet & Leaflet.Extras Compatibility API

100% camelCase function and option aliases so existing R leaflet
scripts, Quarto reports, and Shiny apps run on glmap’s GPU engine
without modification.

- [`leaflet()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`leafletOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`providers`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addTiles()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addProviderTiles()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`providerTileOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`setView()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`fitBounds()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`flyTo()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`flyToBounds()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`setMaxBounds()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addMarkers()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`makeIcon()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`iconList()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addAwesomeMarkers()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`makeAwesomeIcon()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`awesomeIcons()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`awesomeIconList()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`markerClusterOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addCircleMarkers()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addLabelOnlyMarkers()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addPolygons()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addPolylines()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addCircles()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addRectangles()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addPopups()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`clearPopups()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`popupOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`labelOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`highlightOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addRasterImage()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addWMSTiles()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`WMSTileOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addLegend()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addLayersControl()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`layersControlOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addMeasure()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addMiniMap()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addGraticule()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addSimpleGraticule()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addTerminator()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addDrawToolbar()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`removeDrawToolbar()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`addSearchOSM()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`searchOptions()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`showGroup()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`hideGroup()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`clearGroup()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`clearShapes()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`clearMarkers()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`clearControls()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`removeShape()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`removeMarker()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`leafletOutput()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`` `%>%` ``](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`renderLeaflet()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  [`leafletProxy()`](https://meztez.github.io/glmap/reference/leaflet_compat.md)
  :

  Drop-In `leaflet` & `leaflet.extras` Compatibility Layer

## Plugins, Custom Shaders & Binary Engine

Extend glmap with custom JS plugins, GLSL shaders, C++17 binary packers,
and spatial indices.

- [`register_plugin()`](https://meztez.github.io/glmap/reference/register_plugin.md)
  :

  Register a Reusable `glmap` Extension Plugin

- [`use_plugin()`](https://meztez.github.io/glmap/reference/use_plugin.md)
  :

  Attach a Registered or Inline Plugin to a `glmap` Map

- [`list_plugins()`](https://meztez.github.io/glmap/reference/list_plugins.md)
  :

  List Available `glmap` Plugins

- [`add_webgl_shader_layer()`](https://meztez.github.io/glmap/reference/add_webgl_shader_layer.md)
  :

  Add a Custom WebGL2 Shader Layer to a `glmap` Map

- [`add_deck_layer()`](https://meztez.github.io/glmap/reference/add_deck_layer.md)
  : Add a Custom Deck.gl / External Layer Specification

- [`gl_pack_sf_binary()`](https://meztez.github.io/glmap/reference/gl_pack_sf_binary.md)
  :

  Pack an sf, sfc, or data.frame object into a GLMP binary buffer
  (`gl_pack_sf_binary`)

- [`gl_pack_raster_binary()`](https://meztez.github.io/glmap/reference/gl_pack_raster_binary.md)
  :

  Pack a terra SpatRaster or matrix into a GLMR Float32 binary buffer
  (`gl_pack_raster_binary`)

- [`gl_spatial_index()`](https://meztez.github.io/glmap/reference/gl_spatial_index.md)
  :

  Build an in-memory C++ spatial index for fast viewport queries
  (`gl_spatial_index`)

- [`gl_query_index()`](https://meztez.github.io/glmap/reference/gl_query_index.md)
  :

  Query a spatial index for features intersecting a bounding box
  (`gl_query_index`)

- [`gl_duckdb_index()`](https://meztez.github.io/glmap/reference/gl_duckdb_index.md)
  :

  Create a DuckDB Out-of-Core Spatial Query Index (`gl_duckdb_index`)

- [`gl_serve_start()`](https://meztez.github.io/glmap/reference/gl_serve_start.md)
  :

  Start the local zero-copy binary & tile server (`gl_serve_start`)

- [`gl_serve_stop()`](https://meztez.github.io/glmap/reference/gl_serve_stop.md)
  :

  Stop the local zero-copy binary server (`gl_serve_stop`)

- [`gl_server_status()`](https://meztez.github.io/glmap/reference/gl_server_status.md)
  :

  Query status of the local binary server and registered buffers
  (`gl_server_status`)

- [`gl_benchmark_data()`](https://meztez.github.io/glmap/reference/gl_benchmark_data.md)
  :

  Generate Synthetic Geospatial Benchmark Datasets (`gl_benchmark_data`)

- [`gl_popup_table()`](https://meztez.github.io/glmap/reference/gl_popup_table.md)
  :

  Generate Compact HTML Table Popups (`gl_popup_table`)

- [`gl_bbox_to_wkt()`](https://meztez.github.io/glmap/reference/gl_bbox_to_wkt.md)
  :

  Convert a `glmap` Selection or Bounds Event into a WKT Polygon
  (`gl_bbox_to_wkt`)
