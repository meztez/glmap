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
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param bbox Numeric vector `c(xmin, ymin, xmax, ymax)` or an `sf`/`SpatRaster` object.
#' @param padding Viewport padding in pixels (default `40`).
#' @export
fit_bounds <- function(map, bbox, padding = 40) {
  if (inherits(bbox, c("sf", "sfc"))) {
    bbox <- as.numeric(sf::st_bbox(bbox))
  } else if (inherits(bbox, "SpatRaster")) {
    ext <- as.vector(terra::ext(bbox))
    bbox <- c(unname(ext[1]), unname(ext[3]), unname(ext[2]), unname(ext[4]))
  }
  bbox <- as.numeric(bbox)[1:4]
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
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param title Legend title.
#' @param colors Character vector of hex/CSS colors (or a palette function when `pal` is used).
#' @param labels Character vector of category labels (for categorical legends).
#' @param domain Numeric vector `c(min, max)` (for continuous legends).
#' @param position One of the 9 anchor positions (default `"bottom-right"`).
#' @param direction Layout direction (`"vertical"` or `"horizontal"`).
#' @param order Numeric draw order within the anchor zone (default `20`).
#' @param layer_id Optional associated layer ID.
#' @param group Optional associated layer group name (legend hides automatically when group is hidden).
#' @param pal Optional `leaflet::colorNumeric` palette function for drop-in `leaflet::addLegend()` compatibility.
#' @param values Optional numeric values vector when using `pal`.
#' @param opacity Optional numeric opacity.
#' @param layerId Optional alias for `layer_id` (`leaflet` compatibility).
#' @param labFormat Optional label format function (`leaflet` compatibility).
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
    labFormat = NULL
) {
  layer_id <- layer_id %||% layerId %||% group %||% next_layer_id("legend")
  pos_norm <- normalize_anchor_position(position)

  if (!is.null(pal) && is.function(pal) && !is.null(values)) {
    rng <- range(values, na.rm = TRUE, finite = TRUE)
    if (!all(is.finite(rng))) rng <- c(0, 1)
    domain <- domain %||% rng
    colors <- pal(seq(rng[1], rng[2], length.out = 7L))
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
    order = as.numeric(order[1])
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
#' For a map with `outputId = "geonesis"`:
#' - `input$geonesis_draw_start`: `list(feature_type = ...)` when a drawing tool is activated.
#' - `input$geonesis_draw_stop`: `list(feature_type = ...)` when drawing finishes or is cancelled.
#' - `input$geonesis_draw_new_feature`: GeoJSON Feature `list(type = "Feature", properties = list(`_leaflet_id` = id, feature_type = "polygon"|"rectangle"|"circle"|"polyline"|"marker", radius = r_meters), geometry = list(type = ..., coordinates = ...), wkt = "POLYGON ((...))", bbox = c(xmin, ymin, xmax, ymax))`.
#' - `input$geonesis_draw_deleted_features`: GeoJSON FeatureCollection of deleted features.
#' - `input$geonesis_draw_all_features`: GeoJSON FeatureCollection of all currently drawn features.
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

