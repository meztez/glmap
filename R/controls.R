#' Customize or Localize User-Facing UI Labels in `glmap` (`gl_labels`, `set_labels`)
#'
#' Creates a flat named list of user-facing UI strings used across `glmap`'s
#' built-in controls (navigation tooltips, layer switcher, marker engine selector,
#' legends & GPU raster shader controls, draw toolbar, measurement widget,
#' address search bar, overview minimap, and HUD).
#'
#' By default, `glmap` uses English for all user-facing text and carries no
#' built-in multi-language dictionaries. Supply `gl_labels(...)` to `glmap(labels = ...)`
#' at initialization or call `set_labels(proxy, ...)` in Shiny to switch any or
#' all UI strings on the fly without re-rendering the map or losing active layers.
#'
#' Use `basemap_groups` and `layer_groups` (named character vectors or lists, e.g.
#' `c("Risks" = "Risques", "Claims" = "Réclamations")`) to translate the display
#' names shown in the Layer Switcher while keeping the underlying group IDs
#' unchanged for `show_group()`, `hide_group()`, `clear_group()`, and `input$<mapId>_groups`.
#'
#' @param map A `glmap` widget or `glmap_proxy` (for `set_labels()`).
#' @param labels A named list of label overrides (e.g., from `gl_labels(...)`), or `NULL` to use arguments in `...`.
#' @param zoom_in,zoom_out,reset_north Tooltips for the navigation zoom/compass buttons.
#' @param layers_title,basemap_header,overlays_header,marker_engine_header Section headers in the Layer Switcher.
#' @param marker_mode_auto,marker_mode_cluster,marker_mode_lod,marker_mode_atlas,marker_mode_points Option labels in the Marker / Icon Engine dropdown.
#' @param basemap_groups Optional named character vector/list mapping basemap group IDs to display labels (e.g. `c("Light" = "Clair", "Dark" = "Sombre", "Satellite" = "Satellite")`).
#' @param layer_groups Optional named character vector/list mapping overlay group IDs to display labels (e.g. `c("Risks" = "Risques")`).
#' @param legend_default_title,layer_opacity,shader_palette,gpu_hillshade,custom_palette Labels inside legend and raster shader cards.
#' @param draw_poly_label,draw_rect_label,draw_circle_label,draw_line_label,draw_pin_label,draw_clear_label Short button labels on the draw toolbar.
#' @param draw_poly_title,draw_rect_title,draw_circle_title,draw_line_title,draw_pin_title,draw_clear_title Hover tooltips on the draw toolbar.
#' @param drawn_area_prefix,remove_drawn_button Labels inside the popup shown when clicking a drawn shape.
#' @param measure_start,measure_finish,measure_clear,measure_length,measure_area,measure_hint Labels inside the distance/area measurement control.
#' @param search_placeholder,search_button_title,search_clear_title,search_searching,search_no_results,search_unavailable Labels inside the OpenStreetMap search control.
#' @param minimap_title,export_png Header for the overview minimap and label for the PNG export button.
#' @param hud_features,hud_lon_lat,hud_raster,hud_dist Labels inside the bottom status HUD.
#' @param ... Additional named label overrides.
#' @return For `gl_labels()`, a named list of UI label strings. For `set_labels()`, the updated `glmap` widget or `glmap_proxy`.
#' @export
gl_labels <- function(
    zoom_in = "Zoom in",
    zoom_out = "Zoom out",
    reset_north = "Reset bearing to north",
    layers_title = "Layers",
    basemap_header = "Basemap",
    overlays_header = "Overlays",
    marker_engine_header = "Marker / Icon Engine",
    marker_mode_auto = "Auto (Dynamic)",
    marker_mode_cluster = "Cluster + GPU Atlas",
    marker_mode_lod = "LOD Hybrid (Dots -> Icons)",
    marker_mode_atlas = "GPU Sprite Atlas (All Icons)",
    marker_mode_points = "GPU Fast Dots (SDF)",
    basemap_groups = NULL,
    layer_groups = NULL,
    legend_default_title = "Legend",
    layer_opacity = "Layer Opacity",
    shader_palette = "GPU Shader Palette",
    gpu_hillshade = "Real-Time GPU Hillshade",
    custom_palette = "custom (R)",
    draw_poly_label = "Poly",
    draw_rect_label = "Rect",
    draw_circle_label = "Circle",
    draw_line_label = "Line",
    draw_pin_label = "Pin",
    draw_clear_label = "Clear",
    draw_poly_title = "Draw a polygon",
    draw_rect_title = "Draw a rectangle",
    draw_circle_title = "Draw a circle",
    draw_line_title = "Draw a polyline",
    draw_pin_title = "Draw a marker",
    draw_clear_title = "Clear all drawn shapes",
    drawn_area_prefix = "Drawn Area #",
    remove_drawn_button = "Remove",
    measure_start = "Measure Distance / Area",
    measure_finish = "Finish Measure",
    measure_clear = "Clear",
    measure_length = "Length",
    measure_area = "Area",
    measure_hint = "Click points on map (3+ for area, double-click to finish)",
    search_placeholder = "Search address or place...",
    search_button_title = "Search OpenStreetMap",
    search_clear_title = "Clear search",
    search_searching = "Searching OpenStreetMap...",
    search_no_results = "No results found.",
    search_unavailable = "Search unavailable.",
    minimap_title = "Overview",
    export_png = "Export PNG",
    hud_features = "Features",
    hud_lon_lat = "Lon/Lat",
    hud_raster = "Raster",
    hud_dist = "Dist",
    ...
) {
  base_list <- list(
    zoom_in = as.character(zoom_in[1]),
    zoom_out = as.character(zoom_out[1]),
    reset_north = as.character(reset_north[1]),
    layers_title = as.character(layers_title[1]),
    basemap_header = as.character(basemap_header[1]),
    overlays_header = as.character(overlays_header[1]),
    marker_engine_header = as.character(marker_engine_header[1]),
    marker_mode_auto = as.character(marker_mode_auto[1]),
    marker_mode_cluster = as.character(marker_mode_cluster[1]),
    marker_mode_lod = as.character(marker_mode_lod[1]),
    marker_mode_atlas = as.character(marker_mode_atlas[1]),
    marker_mode_points = as.character(marker_mode_points[1]),
    basemap_groups = if (!is.null(basemap_groups)) as.list(basemap_groups) else stats::setNames(list(), character(0)),
    layer_groups = if (!is.null(layer_groups)) as.list(layer_groups) else stats::setNames(list(), character(0)),
    legend_default_title = as.character(legend_default_title[1]),
    layer_opacity = as.character(layer_opacity[1]),
    shader_palette = as.character(shader_palette[1]),
    gpu_hillshade = as.character(gpu_hillshade[1]),
    custom_palette = as.character(custom_palette[1]),
    draw_poly_label = as.character(draw_poly_label[1]),
    draw_rect_label = as.character(draw_rect_label[1]),
    draw_circle_label = as.character(draw_circle_label[1]),
    draw_line_label = as.character(draw_line_label[1]),
    draw_pin_label = as.character(draw_pin_label[1]),
    draw_clear_label = as.character(draw_clear_label[1]),
    draw_poly_title = as.character(draw_poly_title[1]),
    draw_rect_title = as.character(draw_rect_title[1]),
    draw_circle_title = as.character(draw_circle_title[1]),
    draw_line_title = as.character(draw_line_title[1]),
    draw_pin_title = as.character(draw_pin_title[1]),
    draw_clear_title = as.character(draw_clear_title[1]),
    drawn_area_prefix = as.character(drawn_area_prefix[1]),
    remove_drawn_button = as.character(remove_drawn_button[1]),
    measure_start = as.character(measure_start[1]),
    measure_finish = as.character(measure_finish[1]),
    measure_clear = as.character(measure_clear[1]),
    measure_length = as.character(measure_length[1]),
    measure_area = as.character(measure_area[1]),
    measure_hint = as.character(measure_hint[1]),
    search_placeholder = as.character(search_placeholder[1]),
    search_button_title = as.character(search_button_title[1]),
    search_clear_title = as.character(search_clear_title[1]),
    search_searching = as.character(search_searching[1]),
    search_no_results = as.character(search_no_results[1]),
    search_unavailable = as.character(search_unavailable[1]),
    minimap_title = as.character(minimap_title[1]),
    export_png = as.character(export_png[1]),
    hud_features = as.character(hud_features[1]),
    hud_lon_lat = as.character(hud_lon_lat[1]),
    hud_raster = as.character(hud_raster[1]),
    hud_dist = as.character(hud_dist[1])
  )
  extra <- list(...)
  if (length(extra) > 0L) {
    for (nm in names(extra)) {
      if (nzchar(nm)) base_list[[nm]] <- extra[[nm]]
    }
  }
  base_list
}

#' @rdname gl_labels
#' @export
set_labels <- function(map, labels = NULL, ...) {
  overrides <- if (is.null(labels)) list(...) else utils::modifyList(as.list(labels), list(...))
  if (!is.null(overrides$basemap_groups)) overrides$basemap_groups <- as.list(overrides$basemap_groups)
  if (!is.null(overrides$layer_groups)) overrides$layer_groups <- as.list(overrides$layer_groups)
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setLabels", overrides))
  }
  cur <- map$x$labels %||% gl_labels()
  map$x$labels <- utils::modifyList(cur, overrides)
  map
}

#' Set Map Camera View (Center, Zoom, Pitch, Bearing)
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param lng Longitude of center.
#' @param lat Latitude of center.
#' @param zoom Zoom level (`0` to `22`).
#' @param pitch Pitch tilt in degrees (`0` to `85`).
#' @param bearing Rotation bearing in degrees.
#' @export
set_view <- function(map, lng, lat, zoom = 10, pitch = 0, bearing = 0) {
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setView", list(
      center = c(as.numeric(lng), as.numeric(lat)),
      zoom = as.numeric(zoom),
      pitch = as.numeric(pitch),
      bearing = as.numeric(bearing)
    )))
  }
  map$x$view$center <- c(as.numeric(lng), as.numeric(lat))
  map$x$view$zoom <- as.numeric(zoom)
  map$x$view$pitch <- as.numeric(pitch)
  map$x$view$bearing <- as.numeric(bearing)
  map
}

#' Smoothly Animate Camera to Bounding Box (`fly_to_bounds`)
#'
#' Drop-in equivalent of `leaflet::flyToBounds()`.
#'
#' @inheritParams fit_bounds
#' @param duration Animation duration in milliseconds (default `1600`).
#' @export
fly_to_bounds <- function(map, bbox, padding = 40, duration = 1600) {
  if (inherits(bbox, c("sf", "sfc"))) {
    bbox <- as.numeric(sf::st_bbox(bbox))
  } else if (inherits(bbox, "SpatRaster")) {
    ext <- as.vector(terra::ext(bbox))
    bbox <- c(unname(ext[1]), unname(ext[3]), unname(ext[2]), unname(ext[4]))
  }
  bbox <- as.numeric(bbox)[1:4]
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "flyToBounds", list(bounds = bbox, padding = padding, duration = as.integer(duration))))
  }
  map$x$view$bounds <- bbox
  map$x$view$padding <- padding
  map
}

#' Restrict Map Panning to Maximum Bounding Box (`set_max_bounds`)
#'
#' Drop-in equivalent of `leaflet::setMaxBounds()`.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param bbox Numeric vector `c(xmin, ymin, xmax, ymax)` or `sf`/`SpatRaster`.
#' @export
set_max_bounds <- function(map, bbox) {
  if (inherits(bbox, c("sf", "sfc"))) {
    bbox <- as.numeric(sf::st_bbox(bbox))
  } else if (inherits(bbox, "SpatRaster")) {
    ext <- as.vector(terra::ext(bbox))
    bbox <- c(unname(ext[1]), unname(ext[3]), unname(ext[2]), unname(ext[4]))
  }
  bbox <- as.numeric(bbox)[1:4]
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setMaxBounds", list(max_bounds = bbox)))
  }
  map$x$view$max_bounds <- bbox
  map
}

#' Fit Map Camera to a Bounding Box `[xmin, ymin, xmax, ymax]` (`fit_bounds`)
#'
#' Supports both `fit_bounds(map, c(xmin, ymin, xmax, ymax))` (or an `sf`/`SpatRaster` object)
#' and `leaflet::fitBounds(map, lng1, lat1, lng2, lat2)` 4-argument calls (including formulas `~min(long)`).
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param bbox Numeric vector `c(xmin, ymin, xmax, ymax)`, `sf`/`SpatRaster` object, or `lng1`.
#' @param lat1 Optional `lat1` when called with 4 coordinate arguments (`lng1, lat1, lng2, lat2`).
#' @param lng2 Optional `lng2` when called with 4 coordinate arguments.
#' @param lat2 Optional `lat2` when called with 4 coordinate arguments.
#' @param padding Viewport padding in pixels (default `40`).
#' @export
fit_bounds <- function(map, bbox, lat1 = NULL, lng2 = NULL, lat2 = NULL, padding = 40) {
  data <- attr(map$x, "glmap_data")
  if (!is.null(lat1) && !is.null(lng2) && !is.null(lat2)) {
    x1 <- as.numeric(eval_aesthetic(bbox, data))[1]
    y1 <- as.numeric(eval_aesthetic(lat1, data))[1]
    x2 <- as.numeric(eval_aesthetic(lng2, data))[1]
    y2 <- as.numeric(eval_aesthetic(lat2, data))[1]
    bbox <- c(min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2))
  } else if (inherits(bbox, c("sf", "sfc"))) {
    bbox <- as.numeric(sf::st_bbox(bbox))
  } else if (inherits(bbox, "SpatRaster")) {
    ext <- as.vector(terra::ext(bbox))
    bbox <- c(unname(ext[1]), unname(ext[3]), unname(ext[2]), unname(ext[4]))
  } else {
    bbox <- as.numeric(bbox)[1:4]
  }
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "fitBounds", list(bounds = bbox, padding = padding)))
  }
  map$x$view$bounds <- bbox
  map$x$view$padding <- padding
  map
}

#' Smoothly Animate Camera to Target Location (`flyTo`)
#'
#' @inheritParams set_view
#' @param duration Animation duration in milliseconds (default `1600`).
#' @export
fly_to <- function(map, lng, lat, zoom = 12, pitch = 45, bearing = 0, duration = 1600) {
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "flyTo", list(
      center = c(as.numeric(lng), as.numeric(lat)),
      zoom = as.numeric(zoom),
      pitch = as.numeric(pitch),
      bearing = as.numeric(bearing),
      duration = as.integer(duration)
    )))
  }
  set_view(map, lng, lat, zoom, pitch, bearing)
}

#' Change the Map Basemap Style (`set_basemap`)
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param basemap Basemap name (`"dark"`, `"positron"`, `"voyager"`, `"osm"`, `"satellite"`, `"none"`),
#'   a provider from [gl_providers], or a custom style / tile URL.
#' @param api_key Optional API key string for the provider (or set via [gl_set_api_key()] / env vars).
#' @export
set_basemap <- function(map, basemap = "dark", api_key = NULL) {
  spec <- resolve_basemap_spec(basemap, api_key = api_key)
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setBasemap", list(basemap = spec, name = basemap)))
  }
  map$x$basemap <- spec
  map$x$basemap_name <- as.character(basemap[1])
  map
}

#' Enable 3D Terrain Elevation on the Map
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param exaggeration Vertical exaggeration factor (default `1.5`).
#' @param source_url Optional Terrarium/Mapbox DEM tile URL.
#' @export
set_terrain <- function(map, exaggeration = 1.5, source_url = NULL) {
  terrain_spec <- list(
    enabled = exaggeration > 0,
    exaggeration = as.numeric(exaggeration),
    source_url = source_url %||% "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
  )
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setTerrain", terrain_spec))
  }
  map$x$terrain <- terrain_spec
  map
}

#' Set Map Projection (`"mercator"` or `"globe"`)
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param projection Either `"mercator"` or `"globe"`.
#' @export
set_projection <- function(map, projection = c("mercator", "globe")) {
  projection <- match.arg(projection)
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setProjection", list(projection = projection)))
  }
  map$x$view$projection <- projection
  map
}

normalize_anchor_position <- function(position = "top-right") {
  p <- tolower(trimws(as.character(position[1])))
  switch(
    p,
    "topleft" = , "top-left" = "top-left",
    "topcenter" = , "top-center" = , "top" = "top-center",
    "topright" = , "top-right" = "top-right",
    "centerleft" = , "center-left" = , "left" = "center-left",
    "center" = , "center-center" = "center-center",
    "centerright" = , "center-right" = , "right" = "center-right",
    "bottomleft" = , "bottom-left" = "bottom-left",
    "bottomcenter" = , "bottom-center" = , "bottom" = "bottom-center",
    "bottomright" = , "bottom-right" = "bottom-right",
    "top-right"
  )
}

#' Configure Map UI Controls & 9-Zone Layout Anchoring (`add_control`)
#'
#' Configures built-in map controls and positions them inside `glmap`'s
#' **9-zone directional layout grid** (`x = left | center | right`,
#' `y = top | center | bottom`).
#'
#' Each of the 9 anchor zones (`"top-left"`, `"top-center"`, `"top-right"`,
#' `"center-left"`, `"center-center"`, `"center-right"`, `"bottom-left"`,
#' `"bottom-center"`, `"bottom-right"`) automatically stacks its child controls
#' in a configurable `direction` (`"vertical"` or `"horizontal"`) sorted by
#' `order` (lowest first), so controls, draw tools, legends, scale bar, and
#' attribution labels never overlap!
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param type Control type (`"navigation"`, `"scale"`, `"attribution"`, `"fullscreen"`, `"layer_switcher"`, `"hud"`, `"toolbar"`, `"legends"`, `"draw"`, `"measure"`, `"search"`).
#' @param enabled Logical; whether the control is enabled.
#' @param position One of the 9 anchor positions (`"top-left"`, `"top-center"`, `"top-right"`, `"center-left"`, `"center-center"`, `"center-right"`, `"bottom-left"`, `"bottom-center"`, `"bottom-right"`, or `"topleft"`, `"bottomright"`, etc.).
#' @param direction Layout flow direction for the anchor slot: `"vertical"` (default) or `"horizontal"`.
#' @param order Numeric draw order within the anchor slot (default `10`).
#' @param collapsed Logical; for `"layer_switcher"`, whether the panel starts collapsed as a compact button (default `TRUE`).
#' @export
add_control <- function(
    map,
    type = c("navigation", "scale", "attribution", "fullscreen", "layer_switcher", "hud", "toolbar", "legends", "draw", "measure", "search"),
    enabled = TRUE,
    position = "top-right",
    direction = c("vertical", "horizontal"),
    order = 10,
    collapsed = NULL
) {
  type <- match.arg(type)
  direction <- match.arg(direction)
  pos_norm <- normalize_anchor_position(position)
  cfg <- list(
    enabled = isTRUE(enabled),
    position = pos_norm,
    direction = direction,
    order = as.numeric(order[1])
  )
  if (!is.null(collapsed)) cfg$collapsed <- isTRUE(collapsed)

  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "configureControl", list(type = type, config = cfg)))
  }
  map$x$controls[[type]] <- cfg
  map
}

#' Add a Collapsible Layers & Basemap Control (`add_layers_control`)
#'
#' Drop-in GPU equivalent of `leaflet::addLayersControl()`. Adds a collapsible
#' control (defaulting to `"top-right"` or `"top-left"`) with radio buttons for
#' switching `baseGroups` (`"Light"`, `"Dark"`, `"Satellite"`, etc.) and
#' checkboxes for toggling `overlayGroups` (`"Risks"`, `"Claims"`, `"Precipitation"`, etc.).
#' Also emits `input$<mapId>_groups` in Shiny so existing `leaflet` observers work
#' with zero changes!
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param baseGroups Character vector of basemap group names (default `c("Light", "Dark", "Satellite")`).
#' @param overlayGroups Character vector of overlay group names.
#' @param position Anchor position in the 9-zone layout grid (default `"top-left"`).
#' @param options Options list from [layers_control_options()] (e.g., `list(collapsed = TRUE)`).
#' @param order Numeric draw order within the anchor zone (default `10`).
#' @export
add_layers_control <- function(
    map,
    baseGroups = c("Light", "Dark", "Satellite"),
    overlayGroups = character(0),
    position = "top-left",
    options = layers_control_options(),
    order = 10
) {
  pos_norm <- normalize_anchor_position(position)
  collapsed <- if (is.list(options) && !is.null(options$collapsed)) isTRUE(options$collapsed) else TRUE

  spec <- list(
    enabled = TRUE,
    position = pos_norm,
    order = as.numeric(order[1]),
    collapsed = collapsed,
    baseGroups = as.character(baseGroups),
    overlayGroups = as.character(overlayGroups)
  )

  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setLayersControl", spec))
  }
  map$x$controls$layer_switcher <- spec
  map
}

#' Options for `add_layers_control()` (`layers_control_options`)
#'
#' Drop-in equivalent of `leaflet::layersControlOptions()`.
#'
#' @param collapsed Logical; if `TRUE` (default), the control is collapsed into an icon button and expands on hover/click.
#' @param autoZIndex Logical; kept for compatibility with `leaflet`.
#' @export
layers_control_options <- function(collapsed = TRUE, autoZIndex = TRUE) {
  list(collapsed = isTRUE(collapsed), autoZIndex = isTRUE(autoZIndex))
}

#' Add a Custom Map Legend (`add_legend`)
#'
#' Supports both `glmap` native arguments (`title`, `colors`, `labels`, `domain`, `position`)
#' and `leaflet::addLegend(map, position = "bottomright", pal = pal, values = ~val, title = ...)`
#' positional and formula arguments.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param title Legend title (or `position` string when called positionally like `addLegend(map, "bottomright", ...)`).
#' @param colors Character vector of hex/CSS colors (or a palette function when `pal` is used).
#' @param labels Character vector of category labels (for categorical legends).
#' @param domain Numeric vector `c(min, max)` (for continuous legends).
#' @param position One of the 9 anchor positions (default `"bottom-right"`).
#' @param direction Layout direction (`"vertical"` or `"horizontal"`).
#' @param order Numeric draw order within the anchor zone (default `20`).
#' @param layer_id Optional associated layer ID.
#' @param group Optional associated layer group name (legend hides automatically when group is hidden).
#' @param pal Optional `color_numeric` / `leaflet::colorNumeric` palette function for drop-in `leaflet::addLegend()` compatibility.
#' @param values Optional numeric/categorical values vector or formula (`~val`) when using `pal`.
#' @param opacity Optional numeric opacity.
#' @param layerId Optional alias for `layer_id` (`leaflet` compatibility).
#' @param labFormat Optional label format function (`leaflet` compatibility).
#' @param data Optional dataset used to evaluate `values = ~col` formulas (defaults to map data).
#' @param opacity_slider Optional logical; if `TRUE` (or by default when `group` / `layer_id` points to a map layer and `opacity_slider` is not `FALSE`), renders an interactive layer opacity slider in the legend card.
#' @export
add_legend <- function(
    map,
    title = "Legend",
    colors = NULL,
    labels = NULL,
    domain = NULL,
    position = "bottom-right",
    direction = "vertical",
    order = 20,
    layer_id = NULL,
    group = NULL,
    pal = NULL,
    values = NULL,
    opacity = 1.0,
    layerId = NULL,
    labFormat = NULL,
    data = NULL,
    opacity_slider = NULL
) {
  # Detect positional `add_legend(map, "bottomright", pal = ..., values = ...)`
  pos_tokens <- c("topleft", "topright", "bottomleft", "bottomright", "top-left", "top-right", "bottom-left", "bottom-right", "top-center", "bottom-center", "center-left", "center-right")
  if (is.character(title) && length(title) == 1L && tolower(title) %in% pos_tokens && identical(position, "bottom-right")) {
    position <- title
    title <- if (inherits(values, "formula")) rlang::as_label(rlang::f_rhs(values)) else "Legend"
  }
  if (is.null(title)) title <- ""

  data <- data %||% attr(map$x, "glmap_data")
  if (!is.null(values)) {
    values <- eval_aesthetic(values, data)
  }

  layer_id <- layer_id %||% layerId %||% group %||% next_layer_id("legend")
  pos_norm <- normalize_anchor_position(position)

  if (!is.null(pal) && is.function(pal) && !is.null(values)) {
    col_type <- attr(pal, "colorType") %||% "numeric"
    col_args <- attr(pal, "colorArgs") %||% list()
    if (identical(col_type, "factor") || is.factor(values) || is.character(values)) {
      lvls <- col_args$levels %||% levels(as.factor(values))
      colors <- pal(lvls)
      labels <- if (is.function(labFormat)) labFormat(type = "factor", lvls) else lvls
    } else if (identical(col_type, "bin")) {
      b <- col_args$bins
      if (length(b) <= 1L) b <- pretty(range(as.numeric(values), na.rm = TRUE, finite = TRUE), n = as.integer(b %||% 7L))
      mids <- 0.5 * (b[-length(b)] + b[-1L])
      colors <- pal(mids)
      labels <- if (is.function(labFormat)) {
        labFormat(type = "bin", b)
      } else {
        paste0(format(b[-length(b)], trim = TRUE), " - ", format(b[-1L], trim = TRUE))
      }
    } else if (identical(col_type, "quantile")) {
      probs <- col_args$probs %||% seq(0, 1, length.out = 5L)
      q_cuts <- stats::quantile(as.numeric(values), probs = probs, na.rm = TRUE, names = FALSE)
      mids <- 0.5 * (q_cuts[-length(q_cuts)] + q_cuts[-1L])
      colors <- pal(mids)
      pcts <- paste0(round(probs * 100), "%")
      labels <- paste0(pcts[-length(pcts)], " - ", pcts[-1L])
    } else {
      rng <- range(as.numeric(values), na.rm = TRUE, finite = TRUE)
      if (!all(is.finite(rng))) rng <- c(0, 1)
      domain <- domain %||% rng
      colors <- pal(seq(rng[1], rng[2], length.out = 7L))
    }
  }
  colors <- as.character(colors %||% c("#440154", "#21918c", "#fde725"))

  leg <- list(
    layer_id = as.character(layer_id),
    group = if (!is.null(group)) as.character(group) else NULL,
    type = if (!is.null(labels)) "categorical" else "continuous",
    title = as.character(title),
    colors = colors,
    labels = if (!is.null(labels)) as.character(labels) else NULL,
    domain = if (!is.null(domain)) as.numeric(domain) else c(0, 1),
    position = pos_norm,
    direction = direction,
    order = as.numeric(order[1]),
    opacity_slider = if (is.null(opacity_slider)) !is.null(group) else isTRUE(opacity_slider)
  )
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "addLegend", leg))
  }
  map$x$legends[[length(map$x$legends) + 1L]] <- leg
  map
}

#' Add an Interactive Vector Drawing Toolbar (`add_draw_toolbar`)
#'
#' Drop-in GPU equivalent of `leaflet.extras::addDrawToolbar()` with matching
#' formals and Shiny reactive events!
#'
#' Supports interactive drawing of **Polygons** (click vertices, double-click or
#' click first vertex to close), **Rectangles** (click-drag), **Circles**
#' (click center, drag radius in meters), **Polylines** (click vertices,
#' double-click to finish), and **Markers** (click), plus clearing/deleting drawn
#' shapes.
#'
#' ### Shiny Events Emitted (100% compatible with `leaflet.extras::addDrawToolbar`):
#' For a map with `outputId = "map"`:
#' - `input$map_draw_start`: `list(feature_type = ...)` when a drawing tool is activated.
#' - `input$map_draw_stop`: `list(feature_type = ...)` when drawing finishes or is cancelled.
#' - `input$map_draw_new_feature`: GeoJSON Feature `list(type = "Feature", properties = list(`_leaflet_id` = id, feature_type = "polygon"|"rectangle"|"circle"|"polyline"|"marker", radius = r_meters), geometry = list(type = ..., coordinates = ...), wkt = "POLYGON ((...))", bbox = c(xmin, ymin, xmax, ymax))`.
#' - `input$map_draw_deleted_features`: GeoJSON FeatureCollection of deleted features.
#' - `input$map_draw_all_features`: GeoJSON FeatureCollection of all currently drawn features.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param targetGroup Optional group name for drawn features (default `"drawn_features"`).
#' @param position Toolbar position: `"topleft"`, `"topright"`, `"bottomleft"`, `"bottomright"` (or `"top-left"`, etc.).
#' @param polylineOptions List of options or `TRUE`/`FALSE` to enable/disable the polyline tool (default `TRUE`).
#' @param polygonOptions List of options or `TRUE`/`FALSE` to enable/disable the polygon tool (default `TRUE`).
#' @param circleOptions List of options or `TRUE`/`FALSE` to enable/disable the geodesic circle tool (default `TRUE`).
#' @param rectangleOptions List of options or `TRUE`/`FALSE` to enable/disable the rectangle tool (default `TRUE`).
#' @param markerOptions List of options or `TRUE`/`FALSE` to enable/disable the point marker tool (default `TRUE`).
#' @param circleMarkerOptions List of options or `TRUE`/`FALSE` to enable/disable the circle marker tool (default `FALSE`).
#' @param editOptions List of options or `TRUE`/`FALSE` to enable/disable feature deletion/clearing (default `TRUE`).
#' @param singleFeature Logical; if `TRUE`, drawing a new feature replaces previous drawn features (default `FALSE`).
#' @param direction Layout flow direction for the draw toolbar buttons: `"vertical"` (default) or `"horizontal"`.
#' @param order Numeric draw order within the anchor zone (default `15`).
#' @param toolbar Optional custom button titles created via [draw_toolbar_options()].
#' @return Updated `glmap` widget or `glmap_proxy`.
#' @export
add_draw_toolbar <- function(
    map,
    targetGroup = NULL,
    position = c("topleft", "topright", "bottomleft", "bottomright", "top-left", "top-right", "bottom-left", "bottom-right", "top-center", "bottom-center", "center-left", "center-right"),
    polylineOptions = TRUE,
    polygonOptions = TRUE,
    circleOptions = TRUE,
    rectangleOptions = TRUE,
    markerOptions = TRUE,
    circleMarkerOptions = FALSE,
    editOptions = TRUE,
    singleFeature = FALSE,
    direction = c("vertical", "horizontal"),
    order = 15,
    toolbar = NULL
) {
  pos_norm <- normalize_anchor_position(position[1])
  direction <- match.arg(direction)

  is_enabled <- function(opt) {
    !identical(opt, FALSE) && !is.null(opt)
  }

  spec <- list(
    enabled = TRUE,
    targetGroup = targetGroup %||% "drawn_features",
    position = pos_norm,
    direction = direction,
    order = as.numeric(order[1]),
    tools = list(
      polygon = is_enabled(polygonOptions),
      rectangle = is_enabled(rectangleOptions),
      circle = is_enabled(circleOptions),
      polyline = is_enabled(polylineOptions),
      marker = is_enabled(markerOptions) || is_enabled(circleMarkerOptions),
      edit = is_enabled(editOptions)
    ),
    singleFeature = isTRUE(singleFeature),
    toolbar = toolbar %||% draw_toolbar_options()
  )

  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "addDrawToolbar", spec))
  }
  map$x$draw_toolbar <- spec
  map
}

#' Remove the Interactive Drawing Toolbar (`remove_draw_toolbar`)
#'
#' Drop-in equivalent of `leaflet.extras::removeDrawToolbar()`.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param clearFeatures Logical; whether to also clear all drawn shapes from the map (default `FALSE`).
#' @export
remove_draw_toolbar <- function(map, clearFeatures = FALSE) {
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "removeDrawToolbar", list(clearFeatures = isTRUE(clearFeatures))))
  }
  map$x$draw_toolbar <- NULL
  map
}

#' Configure Custom Tooltip Titles for `add_draw_toolbar()` (`draw_toolbar_options`)
#'
#' Drop-in equivalent of `leaflet.extras::toolbarOptions()`.
#'
#' @param actions Named list of action button tooltips.
#' @param finish Named list of finish button tooltips.
#' @param buttons Named list of tool button tooltips (`polygon`, `rectangle`, `circle`, `polyline`, `marker`).
#' @export
draw_toolbar_options <- function(
    actions = list(title = "Cancel drawing", text = "Cancel"),
    finish = list(title = "Finish drawing", text = "Finish"),
    buttons = list(
      polygon = "Draw a polygon",
      rectangle = "Draw a rectangle",
      circle = "Draw a circle",
      polyline = "Draw a polyline",
      marker = "Draw a marker"
    )
) {
  list(actions = actions, finish = finish, buttons = buttons)
}

#' Add an Interactive Distance & Area Measurement Control (`add_measure`)
#'
#' Drop-in GPU equivalent of `leaflet::addMeasure()`. Adds an interactive
#' measurement widget (defaulting to `"bottom-right"`) that lets users click
#' vertices on the map to measure **geodesic path distance** (`m` / `km` / `mi`)
#' and **geodesic polygon area** (`sq. m` / `ha` / `sq. km` / `acres`) with live
#' segment rubber-banding, double-click to finish, and 1-click Clear.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param position Anchor position in the 9-zone layout grid (default `"bottomright"`).
#' @param primaryLengthUnit Primary length unit (`"meters"`, `"kilometers"`, `"feet"`, `"miles"`).
#' @param secondaryLengthUnit Optional secondary length unit (`"kilometers"`, `"miles"`).
#' @param primaryAreaUnit Primary area unit (`"sqmeters"`, `"hectares"`, `"sqkilometers"`, `"acres"`).
#' @param secondaryAreaUnit Optional secondary area unit.
#' @param activeColor Stroke/vertex color while actively measuring (default `"#38bdf8"`).
#' @param completedColor Stroke/fill color when a measurement is completed (default `"#a855f7"`).
#' @param localization Language code (default `"en"`).
#' @param order Numeric draw order within the anchor zone (default `15`).
#' @return Updated `glmap` widget or `glmap_proxy`.
#' @export
add_measure <- function(
    map,
    position = "bottomright",
    primaryLengthUnit = "meters",
    secondaryLengthUnit = "kilometers",
    primaryAreaUnit = "sqmeters",
    secondaryAreaUnit = NULL,
    activeColor = "#38bdf8",
    completedColor = "#a855f7",
    localization = "en",
    order = 15
) {
  pos_norm <- normalize_anchor_position(position[1])
  spec <- list(
    enabled = TRUE,
    position = pos_norm,
    order = as.numeric(order[1]),
    primaryLengthUnit = as.character(primaryLengthUnit[1]),
    secondaryLengthUnit = if (!is.null(secondaryLengthUnit)) as.character(secondaryLengthUnit[1]) else "kilometers",
    primaryAreaUnit = as.character(primaryAreaUnit[1]),
    secondaryAreaUnit = if (!is.null(secondaryAreaUnit)) as.character(secondaryAreaUnit[1]) else NULL,
    activeColor = as.character(activeColor[1]),
    completedColor = as.character(completedColor[1]),
    localization = as.character(localization[1])
  )
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "addMeasureControl", spec))
  }
  map$x$controls$measure <- spec
  map
}

#' Add an OpenStreetMap Address & Place Search Bar (`add_search_osm`, `search_options`)
#'
#' Drop-in equivalent of `leaflet.extras::addSearchOSM()` and
#' `leaflet.extras::searchOptions()`. Adds an interactive address/place geocoder
#' bar powered by OpenStreetMap Nominatim with autocomplete suggestions, Enter-to-search,
#' smooth camera fly-to, and an optional location pin.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param options Search configuration list created by [search_options()].
#' @param position Anchor position in the 9-zone layout grid (default `"top-left"`).
#' @param order Numeric draw order within the anchor zone (default `5`).
#' @return Updated `glmap` widget or `glmap_proxy`.
#' @export
add_search_osm <- function(
    map,
    options = search_options(),
    position = NULL,
    order = 5
) {
  pos <- position %||% (if (is.list(options) && !is.null(options$position)) options$position else "top-left")
  pos_norm <- normalize_anchor_position(pos[1])
  spec <- list(
    enabled = TRUE,
    position = pos_norm,
    order = as.numeric(order[1]),
    url = (if (is.list(options)) options$url else NULL) %||% "https://nominatim.openstreetmap.org/search?format=json&q={s}",
    zoom = as.numeric((if (is.list(options)) options$zoom else NULL) %||% 15),
    autoCollapse = isTRUE(if (is.list(options) && !is.null(options$autoCollapse)) options$autoCollapse else FALSE),
    textPlaceholder = as.character((if (is.list(options)) options$textPlaceholder else NULL) %||% "Search address or place..."),
    hideMarkerOnCollapse = isTRUE(if (is.list(options) && !is.null(options$hideMarkerOnCollapse)) options$hideMarkerOnCollapse else TRUE)
  )
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "addSearchControl", spec))
  }
  map$x$controls$search <- spec
  map
}

#' @param url Geocoding endpoint URL template containing `{s}` (default Nominatim JSON endpoint).
#' @param zoom Target zoom level when flying to a matched address (default `15`).
#' @param autoCollapse Logical; if `TRUE`, collapses the search input until clicked (default `FALSE`).
#' @param textPlaceholder Placeholder text inside the search input.
#' @param position Anchor position (default `"topleft"`).
#' @param hideMarkerOnCollapse Logical; remove the search pin when cleared (default `TRUE`).
#' @param ... Additional options ignored for `leaflet.extras::searchOptions()` compatibility.
#' @rdname add_search_osm
#' @export
search_options <- function(
    url = "https://nominatim.openstreetmap.org/search?format=json&q={s}",
    zoom = 15,
    autoCollapse = FALSE,
    textPlaceholder = "Search address or place...",
    position = "topleft",
    hideMarkerOnCollapse = TRUE,
    ...
) {
  list(
    url = url,
    zoom = zoom,
    autoCollapse = isTRUE(autoCollapse),
    textPlaceholder = textPlaceholder,
    position = position,
    hideMarkerOnCollapse = isTRUE(hideMarkerOnCollapse)
  )
}

#' Add an Interactive Overview MiniMap (`add_minimap`)
#'
#' Drop-in GPU/Canvas equivalent of `leaflet::addMiniMap()`. Adds a synchronized
#' inset overview map with an interactive aiming rectangle showing the current
#' viewport extent and click-to-pan navigation.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param position Anchor position in the 9-zone layout grid (default `"bottomright"`).
#' @param width,height MiniMap dimensions in pixels (default `150`).
#' @param zoomLevelOffset Numeric zoom offset relative to the main map (default `-5`).
#' @param toggleDisplay Logical; whether to show a collapse/expand button on the MiniMap (default `TRUE`).
#' @param aimingRectOptions Optional styling list for the viewport aiming rectangle.
#' @param order Numeric draw order within the anchor zone (default `80`).
#' @param ... Additional arguments kept for `leaflet::addMiniMap()` compatibility.
#' @return Updated `glmap` widget or `glmap_proxy`.
#' @export
add_minimap <- function(
    map,
    position = "bottomright",
    width = 150,
    height = 150,
    zoomLevelOffset = -5,
    toggleDisplay = TRUE,
    aimingRectOptions = list(color = "#ff7800", weight = 2),
    order = 80,
    ...
) {
  pos_norm <- normalize_anchor_position(position[1])
  spec <- list(
    enabled = TRUE,
    position = pos_norm,
    width = as.numeric(width[1] %||% 150),
    height = as.numeric(height[1] %||% 150),
    zoomLevelOffset = as.numeric(zoomLevelOffset[1] %||% -5),
    toggleDisplay = isTRUE(toggleDisplay),
    aimingColor = as.character((if (is.list(aimingRectOptions)) aimingRectOptions$color else NULL) %||% "#38bdf8"),
    order = as.numeric(order[1])
  )
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "addMiniMap", spec))
  }
  map$x$controls$minimap <- spec
  map
}

#' Add a Coordinate Graticule Grid (`add_graticule`, `add_simple_graticule`)
#'
#' Drop-in GPU equivalent of `leaflet::addGraticule()` and `leaflet::addSimpleGraticule()`.
#' Generates latitude/longitude meridian and parallel lines at the specified `interval`
#' (in degrees) and renders them as a fast WebGL line layer.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param interval Spacing between graticule lines in degrees (default `20`).
#' @param sphere Logical; kept for `leaflet::addGraticule()` compatibility.
#' @param style Styling list (`list(color = "#333", weight = 1, opacity = 0.45)`).
#' @param id Layer ID (default `"graticule"`).
#' @param group Layer group name (default `"Graticule"`).
#' @param ... Additional arguments kept for compatibility.
#' @return Updated `glmap` widget or `glmap_proxy`.
#' @export
add_graticule <- function(
    map,
    interval = 20,
    sphere = FALSE,
    style = list(color = "#64748b", weight = 1, opacity = 0.45),
    id = "graticule",
    group = "Graticule",
    ...
) {
  step <- max(1, as.numeric(interval[1] %||% 20))
  lons <- seq(-180, 180, by = step)
  lats <- seq(-80, 80, by = step)
  lat_seq <- seq(-80, 80, length.out = 65L)
  lon_seq <- seq(-180, 180, length.out = 91L)

  meridians <- lapply(lons, function(x0) {
    structure(cbind(rep(x0, length(lat_seq)), lat_seq), class = c("XY", "LINESTRING", "sfg"))
  })
  parallels <- lapply(lats, function(y0) {
    structure(cbind(lon_seq, rep(y0, length(lon_seq))), class = c("XY", "LINESTRING", "sfg"))
  })
  sfc_grat <- structure(c(meridians, parallels), class = c("sfc_LINESTRING", "sfc"))
  if (requireNamespace("sf", quietly = TRUE)) {
    sf::st_crs(sfc_grat) <- 4326
  }

  col <- (if (is.list(style)) style$color else NULL) %||% "#64748b"
  w <- as.numeric((if (is.list(style)) style$weight else NULL) %||% 1.0)
  op <- as.numeric((if (is.list(style)) style$opacity else NULL) %||% 0.45)

  # Preserve current view bounds so adding a global graticule doesn't override data bounds
  prev_bounds <- map$x$view$bounds
  map <- add_lines(
    map = map,
    data = sfc_grat,
    color = col,
    width = w,
    opacity = op,
    id = id,
    group = group,
    legend = FALSE
  )
  map$x$view$bounds <- prev_bounds
  map
}

#' @rdname add_graticule
#' @export
add_simple_graticule <- function(map, interval = 20, id = "graticule", group = "Graticule", ...) {
  add_graticule(map = map, interval = interval, id = id, group = group, ...)
}

#' Add a Solar Day/Night Terminator Polygon Layer (`add_terminator`)
#'
#' Drop-in GPU equivalent of `leaflet::addTerminator()`. Computes the solar
#' declination and hour angle for `time` (defaults to current UTC time) and
#' renders the night-time hemisphere polygon on the GPU.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param resolution Number of longitude vertices along the terminator curve (default `180L`).
#' @param time POSIXct timestamp or ISO string (defaults to `Sys.time()`).
#' @param fill_color Night polygon fill color (default `"#020617"`).
#' @param fill_opacity Night polygon fill opacity (default `0.38`).
#' @param id Layer ID (default `"terminator"`).
#' @param group Layer group name (default `"Day/Night"`).
#' @param ... Additional arguments kept for compatibility.
#' @return Updated `glmap` widget or `glmap_proxy`.
#' @export
add_terminator <- function(
    map,
    resolution = 180L,
    time = Sys.time(),
    fill_color = "#020617",
    fill_opacity = 0.38,
    id = "terminator",
    group = "Day/Night",
    ...
) {
  t_utc <- as.POSIXlt(time, tz = "UTC")
  doy <- as.numeric(t_utc$yday) + 1.0
  utc_hours <- as.numeric(t_utc$hour) + as.numeric(t_utc$min) / 60.0 + as.numeric(t_utc$sec) / 3600.0

  # Solar declination in radians
  gamma <- 2.0 * pi * (doy - 1.0 + (utc_hours - 12.0) / 24.0) / 365.0
  decl <- 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) -
    0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
  if (abs(decl) < 1e-4) decl <- 1e-4

  # Subsolar longitude
  sun_lon <- (12.0 - utc_hours) * 15.0
  lons <- seq(-180, 180, length.out = max(36L, as.integer(resolution)))
  ha <- (lons - sun_lon) * (pi / 180.0)
  term_lats <- atan(-cos(ha) / tan(decl)) * (180.0 / pi)
  term_lats <- pmax(-84.5, pmin(84.5, term_lats))

  # Close polygon over whichever pole is currently in darkness
  dark_pole_lat <- if (decl > 0) -85.0 else 85.0
  ring <- rbind(
    c(-180.0, dark_pole_lat),
    cbind(lons, term_lats),
    c(180.0, dark_pole_lat),
    c(-180.0, dark_pole_lat)
  )
  poly_sfg <- structure(list(ring), class = c("XY", "POLYGON", "sfg"))
  sfc_term <- structure(list(poly_sfg), class = c("sfc_POLYGON", "sfc"))
  if (requireNamespace("sf", quietly = TRUE)) {
    sf::st_crs(sfc_term) <- 4326
  }

  prev_bounds <- map$x$view$bounds
  map <- add_polygons(
    map = map,
    data = sfc_term,
    fill_color = fill_color,
    fill_opacity = fill_opacity,
    stroke = TRUE,
    line_color = "#38bdf8",
    line_width = 1.2,
    id = id,
    group = group,
    legend = FALSE
  )
  map$x$view$bounds <- prev_bounds
  map
}

#' Leaflet Option Helpers (`highlight_options`, `label_options`, `popup_options`, `provider_tile_options`, `wms_tile_options`)
#'
#' Drop-in equivalents of `leaflet::highlightOptions()`, `leaflet::labelOptions()`,
#' `leaflet::popupOptions()`, `leaflet::providerTileOptions()`, and `leaflet::WMSTileOptions()`.
#'
#' @param stroke,color,weight,opacity,fill,fillColor,fillOpacity,dashArray,bringToFront,sendToBack Hover highlight styling options.
#' @export
highlight_options <- function(
    stroke = NULL,
    color = "#ffffff",
    weight = 3,
    opacity = 1.0,
    fill = NULL,
    fillColor = NULL,
    fillOpacity = 0.75,
    dashArray = NULL,
    bringToFront = TRUE,
    sendToBack = FALSE
) {
  list(
    stroke = stroke,
    color = color,
    weight = weight,
    opacity = opacity,
    fill = fill,
    fillColor = fillColor,
    fillOpacity = fillOpacity,
    dashArray = dashArray,
    bringToFront = isTRUE(bringToFront),
    sendToBack = isTRUE(sendToBack)
  )
}

#' @param interactive,clickable,noHide,permanent,className,direction,offset,textsize,textOnly,style,sticky Label display options.
#' @param ... Additional options kept for `leaflet` compatibility.
#' @rdname highlight_options
#' @export
label_options <- function(
    interactive = FALSE,
    clickable = NULL,
    noHide = FALSE,
    permanent = FALSE,
    className = "",
    direction = "auto",
    offset = c(0, 0),
    opacity = 1,
    textsize = "12px",
    textOnly = FALSE,
    style = NULL,
    sticky = TRUE,
    ...
) {
  list(
    interactive = isTRUE(interactive),
    noHide = isTRUE(noHide) || isTRUE(permanent),
    className = className,
    direction = direction,
    offset = offset,
    opacity = opacity,
    textsize = textsize,
    textOnly = isTRUE(textOnly),
    style = style,
    sticky = isTRUE(sticky)
  )
}

#' @param maxWidth,minWidth,maxHeight,autoPan,keepInView,closeButton,closeOnClick Popup options.
#' @rdname highlight_options
#' @export
popup_options <- function(
    maxWidth = 300,
    minWidth = 50,
    maxHeight = NULL,
    autoPan = TRUE,
    keepInView = FALSE,
    closeButton = TRUE,
    closeOnClick = NULL,
    ...
) {
  list(
    maxWidth = maxWidth,
    minWidth = minWidth,
    maxHeight = maxHeight,
    autoPan = isTRUE(autoPan),
    keepInView = isTRUE(keepInView),
    closeButton = isTRUE(closeButton),
    closeOnClick = closeOnClick
  )
}

#' @rdname highlight_options
#' @export
provider_tile_options <- function(...) {
  list(...)
}

#' @param styles,format,transparent,version WMS tile option parameters.
#' @rdname highlight_options
#' @export
wms_tile_options <- function(styles = "", format = "image/png", transparent = TRUE, version = "1.1.1", ...) {
  list(styles = styles, format = format, transparent = isTRUE(transparent), version = version, ...)
}

#' Save a `glmap` Map to a Standalone HTML File (`gl_save_html`)
#'
#' @param map A `glmap` widget.
#' @param file Output HTML file path.
#' @param selfcontained Logical; whether to bundle JS/CSS assets into a single HTML file.
#' @param title HTML page title.
#' @return Normalized path to the saved HTML file (invisibly).
#' @export
gl_save_html <- function(map, file, selfcontained = FALSE, title = "glmap GPU Map") {
  htmlwidgets::saveWidget(
    widget = map,
    file = file,
    selfcontained = selfcontained,
    title = title
  )
  invisible(normalizePath(file, mustWork = FALSE))
}

#' Capture a High-Resolution Static PNG Screenshot of a `glmap` Widget (`gl_save_png`)
#'
#' Renders a `glmap` widget in headless Chromium (`chromote`) with WebGL2
#' `preserveDrawingBuffer = TRUE` and captures a crisp static `.png` snapshot
#' suitable for Quarto PDF / LaTeX / Word reports, slides, and automated visual testing.
#'
#' @param map A `glmap` widget.
#' @param file Output `.png` file path.
#' @param vwidth,vheight Viewport width and height in pixels (default `1000` x `650`).
#' @param delay Seconds to wait after page load for basemap tiles and GPU textures to settle (default `1.5`).
#' @return Normalized path to the saved `.png` file (invisibly).
#' @export
gl_save_png <- function(map, file, vwidth = 1000, vheight = 650, delay = 1.5) {
  if (!requireNamespace("chromote", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg chromote} is required for {.fn gl_save_png}.")
  }
  tmp_dir <- tempfile("glmap_snap_")
  dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  tmp_html <- file.path(tmp_dir, "index.html")
  map$width <- "100%"
  map$height <- paste0(as.integer(vheight), "px")
  htmlwidgets::saveWidget(map, file = tmp_html, selfcontained = FALSE)

  b <- chromote::ChromoteSession$new(width = as.integer(vwidth), height = as.integer(vheight))
  on.exit(try(b$close(), silent = TRUE), add = TRUE)

  url <- paste0("file:///", gsub("\\\\", "/", normalizePath(tmp_html, mustWork = TRUE)))
  b$Page$navigate(url, wait_ = TRUE)
  Sys.sleep(as.numeric(delay))
  b$screenshot(filename = file, wait_ = TRUE)
  invisible(normalizePath(file, mustWork = FALSE))
}

#' Generate Synthetic Geospatial Benchmark Datasets (`gl_benchmark_data`)
#'
#' Useful for stress-testing 100k-1M+ points, polygons, and rasters.
#'
#' @param n_points Number of points to generate.
#' @param n_polygons Number of polygons to generate.
#' @param raster_dim Integer vector `c(nrow, ncol)` for synthetic DEM raster.
#' @param bbox Bounding box `c(xmin, ymin, xmax, ymax)`.
#' @return A list with `points_df`, `polygons_sf`, and `raster_mat`.
#' @export
gl_benchmark_data <- function(
    n_points = 100000L,
    n_polygons = 2000L,
    raster_dim = c(250L, 250L),
    bbox = c(-74.2, 45.3, -71.0, 47.0)
) {
  n_points <- as.integer(n_points)
  n_polygons <- as.integer(n_polygons)

  # Multi-cluster realistic spatial distribution (e.g. Montreal - Quebec City corridor)
  centers_x <- c(-73.5673, -71.2080, -72.5481, -71.8991, -74.0000)
  centers_y <- c(45.5017,  46.8139,  46.3432,  45.4042,  45.7800)
  cl <- sample.int(length(centers_x), n_points, replace = TRUE, prob = c(0.45, 0.25, 0.12, 0.10, 0.08))

  lon <- centers_x[cl] + stats::rnorm(n_points, 0, 0.18)
  lat <- centers_y[cl] + stats::rnorm(n_points, 0, 0.12)
  val <- sqrt((lon - centers_x[cl])^2 + (lat - centers_y[cl])^2) * 100 + stats::runif(n_points, 0, 25)
  cat_col <- c("Residential", "Commercial", "Industrial", "Sensor", "Transit")[cl]

  points_df <- data.frame(
    lon = lon,
    lat = lat,
    intensity = val,
    category = cat_col,
    stringsAsFactors = FALSE
  )

  # Generate n_polygons fast 6-vertex cells
  px <- stats::runif(n_polygons, bbox[1], bbox[3])
  py <- stats::runif(n_polygons, bbox[2], bbox[4])
  r <- 0.012
  angles <- seq(0, 2 * pi, length.out = 7)[1:6]
  dx <- r * cos(angles)
  dy <- r * sin(angles)

  sfc_poly <- lapply(seq_len(n_polygons), function(i) {
    ring <- cbind(c(px[i] + dx, px[i] + dx[1]), c(py[i] + dy, py[i] + dy[1]))
    structure(list(ring), class = c("XY", "POLYGON", "sfg"))
  })
  class(sfc_poly) <- c("sfc_POLYGON", "sfc")
  attr(sfc_poly, "precision") <- 0
  attr(sfc_poly, "bbox") <- structure(
    c(xmin = min(px) - r, ymin = min(py) - r, xmax = max(px) + r, ymax = max(py) + r),
    class = "bbox"
  )
  attr(sfc_poly, "crs") <- if (requireNamespace("sf", quietly = TRUE)) {
    sf::st_crs(4326)
  } else {
    structure(list(input = "EPSG:4326", wkt = NA_character_), class = "crs")
  }

  polygons_sf <- structure(
    data.frame(
      id = seq_len(n_polygons),
      elevation = round(stats::runif(n_polygons, 20, 850), 1),
      risk_score = round(stats::runif(n_polygons, 0, 100), 2)
    ),
    sf_column = "geometry",
    agr = factor(c(id = NA, elevation = NA, risk_score = NA), levels = c("constant", "aggregate", "identity")),
    class = c("sf", "data.frame")
  )
  polygons_sf$geometry <- sfc_poly

  # Synthetic terrain matrix
  nr <- as.integer(raster_dim[1])
  nc <- as.integer(raster_dim[2])
  gx <- seq(-3, 3, length.out = nc)
  gy <- seq(-3, 3, length.out = nr)
  raster_mat <- outer(gy, gx, function(y, x) {
    350 * exp(-(x^2 + y^2) / 2.2) + 180 * sin(x * 2.1) * cos(y * 1.8) + 120 * exp(-((x - 1.4)^2 + (y + 1.1)^2))
  })

  list(
    points_df = points_df,
    polygons_sf = polygons_sf,
    raster_mat = raster_mat,
    bbox = bbox
  )
}

