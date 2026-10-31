#' Drop-In `leaflet` & `leaflet.extras` Compatibility Layer
#'
#' @description
#' Provides 100% camelCase function and option aliases (`leaflet()`, `addTiles()`,
#' `addProviderTiles()`, `addMarkers()`, `addAwesomeMarkers()`, `addCircleMarkers()`,
#' `addLabelOnlyMarkers()`, `addPolygons()`, `addPolylines()`, `addCircles()`,
#' `addRectangles()`, `addRasterImage()`, `addLegend()`, `addLayersControl()`,
#' `addMiniMap()`, `addMeasure()`, `addGraticule()`, `addSimpleGraticule()`,
#' `addTerminator()`, `addDrawToolbar()`, `addSearchOSM()`, `setView()`, `fitBounds()`,
#' `flyTo()`, `flyToBounds()`, `setMaxBounds()`, `showGroup()`, `hideGroup()`,
#' `clearGroup()`, `clearShapes()`, `clearMarkers()`, `clearControls()`, `leafletOutput()`,
#' `renderLeaflet()`, `leafletProxy()`, `providers`) so existing R `leaflet` scripts,
#' R Markdown / Quarto documents, and Shiny applications can run on `glmap`'s
#' C++17 + WebGL2 GPU engine with zero or minimal code changes.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param data Optional spatial dataset (`sf`, `sfc`, `SpatRaster`, `data.frame`, `matrix`, or `SharedData`).
#' @param width,height Optional widget dimensions.
#' @param padding Optional viewport padding in pixels.
#' @param options Optional widget or layer options list.
#' @param elementId Optional HTML element ID.
#' @param sizingPolicy Optional `htmlwidgets` sizing policy.
#' @param urlTemplate Optional custom XYZ tile URL template (e.g., `"https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"`).
#' @param attribution Optional attribution HTML string.
#' @param layerId,layer_id Optional layer identifier.
#' @param group Optional layer group name.
#' @param provider Provider name from [gl_providers].
#' @param lng,lon,lat,lng1,lat1,lng2,lat2,bbox,zoom,pitch,bearing,duration Camera and coordinate parameters.
#' @param icon,iconUrl,iconRetinaUrl,iconWidth,iconHeight,iconAnchorX,iconAnchorY,shadowUrl,shadowRetinaUrl,shadowWidth,shadowHeight,shadowAnchorX,shadowAnchorY,popupAnchorX,popupAnchorY,className Marker icon parameters.
#' @param library,markerColor,iconColor,spin,extraClasses,squareMarker,iconRotate,fontFamily,text Awesome marker parameters.
#' @param clusterOptions,clusterId,showCoverageOnHover,zoomToBoundsOnClick,spiderfyOnMaxZoom,disableClusteringAtZoom,maxClusterRadius,freezeAtZoom,render_mode,lod_zoom,id Clustering and GPU marker rendering parameters.
#' @param radius,stroke,color,weight,opacity,fill,fillColor,fillOpacity,dashArray,smoothFactor,palette,fill_color,fill_opacity,line_color,line_width,extrude,legend Shape and point styling parameters.
#' @param popup,popupOptions,label,labelOptions,highlightOptions,maxWidth,minWidth,maxHeight,autoPan,keepInView,closeButton,closeOnClick,interactive,clickable,noHide,permanent,direction,offset,textsize,textOnly,style,sticky,bringToFront,sendToBack Popup, label, and hover highlight parameters.
#' @param x,colors,project,method,maxBytes Raster parameters for `addRasterImage()`.
#' @param baseUrl,layers,styles,format,transparent,version WMS parameters for `addWMSTiles()`.
#' @param title,labels,domain,position,order,pal,values,labFormat,opacity_slider Legend parameters for `addLegend()`.
#' @param baseGroups,overlayGroups,collapsed,autoZIndex Layer control parameters.
#' @param primaryLengthUnit,secondaryLengthUnit,primaryAreaUnit,secondaryAreaUnit,activeColor,completedColor,localization Measurement control parameters.
#' @param zoomLevelOffset,toggleDisplay,aimingRectOptions,interval,sphere,resolution,time MiniMap, Graticule, and Terminator parameters.
#' @param targetGroup,polylineOptions,polygonOptions,circleOptions,rectangleOptions,markerOptions,circleMarkerOptions,editOptions,singleFeature,toolbar,clearFeatures,url,autoCollapse,textPlaceholder,hideMarkerOnCollapse Draw toolbar and OSM search parameters.
#' @param outputId,mapId,session,deferUntilFlush,expr,env,quoted,lhs,rhs Shiny and pipe parameters.
#' @param ... Additional arguments passed to the underlying `glmap` function.
#' @name leaflet_compat
#' @export
leaflet <- function(
    data = NULL,
    width = NULL,
    height = NULL,
    padding = 0,
    options = list(),
    elementId = NULL,
    sizingPolicy = NULL,
    ...
) {
  glmap(
    data = data,
    basemap = "positron",
    width = width %||% "100%",
    height = height,
    elementId = elementId,
    ...
  )
}

#' @rdname leaflet_compat
#' @export
leafletOptions <- function(...) {
  list(...)
}

#' @rdname leaflet_compat
#' @export
providers <- gl_providers

#' @rdname leaflet_compat
#' @export
addTiles <- function(
    map,
    urlTemplate = NULL,
    attribution = NULL,
    layerId = NULL,
    group = NULL,
    options = list()
) {
  bm <- if (!is.null(urlTemplate) && nzchar(urlTemplate)) {
    gsub("\\{s\\}", "a", urlTemplate)
  } else {
    "osm"
  }
  if (!is.null(group) && nzchar(group)) {
    cur_bg <- map$x$controls$layer_switcher$baseGroups %||% character(0)
    map$x$controls$layer_switcher$baseGroups <- unique(c(cur_bg, as.character(group)))
  }
  set_basemap(map, basemap = bm)
}

#' @rdname leaflet_compat
#' @export
addProviderTiles <- function(
    map,
    provider,
    layerId = NULL,
    group = NULL,
    options = list()
) {
  if (is.list(options) && !is.null(options$id) && tolower(as.character(provider[1])) == "mapbox") {
    provider <- as.character(options$id[1])
  }
  api_key <- if (is.list(options)) (options$accessToken %||% options$apikey %||% options$key) else NULL
  add_provider_tiles(map, provider = provider, api_key = api_key, layerId = layerId, group = group)
}

#' @rdname leaflet_compat
#' @export
providerTileOptions <- provider_tile_options

#' @rdname leaflet_compat
#' @export
setView <- set_view

#' @rdname leaflet_compat
#' @export
fitBounds <- fit_bounds

#' @rdname leaflet_compat
#' @export
flyTo <- fly_to

#' @rdname leaflet_compat
#' @export
flyToBounds <- fly_to_bounds

#' @rdname leaflet_compat
#' @export
setMaxBounds <- set_max_bounds

#' @rdname leaflet_compat
#' @export
addMarkers <- add_markers

#' @rdname leaflet_compat
#' @export
makeIcon <- make_icon

#' @rdname leaflet_compat
#' @export
iconList <- icon_list

#' @rdname leaflet_compat
#' @export
addAwesomeMarkers <- add_markers

#' @rdname leaflet_compat
#' @export
makeAwesomeIcon <- make_awesome_icon

#' @rdname leaflet_compat
#' @export
awesomeIcons <- awesome_icons

#' @rdname leaflet_compat
#' @export
awesomeIconList <- awesome_icon_list

#' @rdname leaflet_compat
#' @export
markerClusterOptions <- marker_cluster_options

#' @rdname leaflet_compat
#' @export
addCircleMarkers <- function(
    map,
    lng = NULL,
    lat = NULL,
    radius = 6,
    layerId = NULL,
    group = NULL,
    stroke = TRUE,
    color = "#03F",
    weight = 1.5,
    opacity = 0.85,
    fill = TRUE,
    fillColor = NULL,
    fillOpacity = 0.8,
    dashArray = NULL,
    popup = NULL,
    popupOptions = NULL,
    label = NULL,
    labelOptions = NULL,
    options = list(),
    clusterOptions = NULL,
    clusterId = NULL,
    data = NULL,
    palette = "viridis",
    ...
) {
  # Support calling addCircleMarkers(map, data = df, color = "red") or addCircleMarkers(map, ~long, ~lat)
  if (is.data.frame(lng) || inherits(lng, c("sf", "sfc", "SharedData"))) {
    data <- lng
    lng <- NULL
  }
  eff_fill <- fillColor %||% color
  eff_stroke <- if (!is.null(fillColor) && is.character(color) && length(color) == 1L) color else "#ffffff"
  add_points(
    map = map,
    data = data,
    lon = lng,
    lat = lat,
    color = eff_fill,
    palette = palette,
    radius = radius,
    opacity = if (identical(fill, FALSE)) 0.1 else (fillOpacity %||% opacity),
    stroke = stroke,
    stroke_color = eff_stroke,
    stroke_width = weight,
    popup = popup,
    label = label,
    clusterOptions = clusterOptions,
    layerId = layerId,
    group = group,
    labelOptions = labelOptions,
    ...
  )
}

#' @rdname leaflet_compat
#' @export
addLabelOnlyMarkers <- function(
    map,
    lng = NULL,
    lat = NULL,
    label = NULL,
    layerId = NULL,
    group = NULL,
    icon = NULL,
    labelOptions = NULL,
    options = list(),
    clusterOptions = NULL,
    clusterId = NULL,
    data = NULL,
    ...
) {
  if (is.data.frame(lng) || inherits(lng, c("sf", "sfc", "SharedData"))) {
    data <- lng
    lng <- NULL
  }
  txt_size <- if (is.list(labelOptions) && !is.null(labelOptions$textsize)) {
    as.numeric(gsub("[^0-9.]", "", as.character(labelOptions$textsize)))
  } else {
    12
  }
  if (is.na(txt_size) || txt_size <= 0) txt_size <- 12
  txt_col <- if (is.list(labelOptions) && is.list(labelOptions$style) && !is.null(labelOptions$style$color)) {
    as.character(labelOptions$style$color)
  } else {
    "#f8fafc"
  }
  add_labels(
    map = map,
    data = data,
    text = label,
    lon = lng,
    lat = lat,
    size = txt_size,
    color = txt_col,
    id = if (length(layerId) == 1L) as.character(layerId) else NULL,
    group = group
  )
}

#' @rdname leaflet_compat
#' @export
addPolygons <- add_polygons

#' @rdname leaflet_compat
#' @export
addPolylines <- add_lines

#' @rdname leaflet_compat
#' @export
addCircles <- function(
    map,
    lng = NULL,
    lat = NULL,
    radius = 500,
    layerId = NULL,
    group = NULL,
    stroke = TRUE,
    color = "#03F",
    weight = 1.5,
    opacity = 0.8,
    fill = TRUE,
    fillColor = NULL,
    fillOpacity = 0.45,
    dashArray = NULL,
    popup = NULL,
    popupOptions = NULL,
    label = NULL,
    labelOptions = NULL,
    options = list(),
    highlightOptions = NULL,
    data = NULL,
    palette = "viridis",
    ...
) {
  if (is.data.frame(lng) || inherits(lng, c("sf", "sfc", "SharedData"))) {
    data <- lng
    lng <- NULL
  }
  add_circles(
    map = map,
    data = data,
    lon = lng,
    lat = lat,
    radius = radius,
    fill_color = fillColor %||% color,
    palette = palette,
    fill_opacity = if (identical(fill, FALSE)) 0.0 else (fillOpacity %||% opacity),
    stroke = stroke,
    line_color = if (is.character(color) && length(color) == 1L && is_color_string(color)) color else "#e2e8f0",
    line_width = weight,
    popup = popup,
    label = label,
    layerId = layerId,
    group = group,
    highlightOptions = highlightOptions,
    labelOptions = labelOptions,
    ...
  )
}

#' @rdname leaflet_compat
#' @export
addRectangles <- add_rectangles

#' @rdname leaflet_compat
#' @export
addPopups <- add_popups

#' @rdname leaflet_compat
#' @export
clearPopups <- clear_popups

#' @rdname leaflet_compat
#' @export
popupOptions <- popup_options

#' @rdname leaflet_compat
#' @export
labelOptions <- label_options

#' @rdname leaflet_compat
#' @export
highlightOptions <- highlight_options

#' @rdname leaflet_compat
#' @export
addRasterImage <- function(
    map,
    x,
    colors = "Spectral",
    opacity = 0.85,
    attribution = NULL,
    layerId = NULL,
    group = NULL,
    project = TRUE,
    method = c("auto", "bilinear", "ngb"),
    maxBytes = 4 * 1024 * 1024,
    ...
) {
  pal <- if (is.function(colors)) {
    col_args <- attr(colors, "colorArgs")
    if (!is.null(col_args$palette)) col_args$palette else "Spectral"
  } else {
    colors
  }
  add_raster(
    map = map,
    raster = x,
    palette = pal,
    opacity = opacity,
    id = layerId,
    group = group,
    ...
  )
}

#' @rdname leaflet_compat
#' @export
addWMSTiles <- function(
    map,
    baseUrl,
    layerId = NULL,
    group = NULL,
    options = wms_tile_options(),
    attribution = NULL,
    layers = ""
) {
  fmt <- (if (is.list(options)) options$format else NULL) %||% "image/png"
  trans <- if (is.list(options) && !is.null(options$transparent)) isTRUE(options$transparent) else TRUE
  ver <- (if (is.list(options)) options$version else NULL) %||% "1.1.1"
  st <- (if (is.list(options)) options$styles else NULL) %||% ""
  add_wms_tiles(
    map = map,
    base_url = baseUrl,
    layers = layers,
    styles = st,
    format = fmt,
    transparent = trans,
    version = ver,
    id = layerId,
    group = group
  )
}

#' @rdname leaflet_compat
#' @export
WMSTileOptions <- wms_tile_options

#' @rdname leaflet_compat
#' @export
addLegend <- add_legend

#' @rdname leaflet_compat
#' @export
addLayersControl <- add_layers_control

#' @rdname leaflet_compat
#' @export
layersControlOptions <- layers_control_options

#' @rdname leaflet_compat
#' @export
addMeasure <- add_measure

#' @rdname leaflet_compat
#' @export
addMiniMap <- add_minimap

#' @rdname leaflet_compat
#' @export
addGraticule <- add_graticule

#' @rdname leaflet_compat
#' @export
addSimpleGraticule <- add_simple_graticule

#' @rdname leaflet_compat
#' @export
addTerminator <- add_terminator

#' @rdname leaflet_compat
#' @export
addDrawToolbar <- add_draw_toolbar

#' @rdname leaflet_compat
#' @export
removeDrawToolbar <- remove_draw_toolbar

#' @rdname leaflet_compat
#' @export
addSearchOSM <- add_search_osm

#' @rdname leaflet_compat
#' @export
searchOptions <- search_options

#' @rdname leaflet_compat
#' @export
showGroup <- show_group

#' @rdname leaflet_compat
#' @export
hideGroup <- hide_group

#' @rdname leaflet_compat
#' @export
clearGroup <- clear_group

#' @rdname leaflet_compat
#' @export
clearShapes <- clear_shapes

#' @rdname leaflet_compat
#' @export
clearMarkers <- clear_markers

#' @rdname leaflet_compat
#' @export
clearControls <- clear_controls

#' @rdname leaflet_compat
#' @export
removeShape <- remove_shape

#' @rdname leaflet_compat
#' @export
removeMarker <- remove_marker

#' @rdname leaflet_compat
#' @export
leafletOutput <- glmapOutput

#' @rdname leaflet_compat
#' @export
`%>%` <- function(lhs, rhs) {
  rhs_expr <- substitute(rhs)
  env <- parent.frame()
  if (is.call(rhs_expr)) {
    call_list <- as.list(rhs_expr)
    new_call <- as.call(c(list(call_list[[1L]], lhs), call_list[-1L]))
    eval(new_call, envir = env)
  } else {
    fn <- eval(rhs_expr, envir = env)
    fn(lhs)
  }
}

#' @rdname leaflet_compat
#' @export
renderLeaflet <- renderGlmap

#' @rdname leaflet_compat
#' @export
leafletProxy <- function(mapId, session = NULL, data = NULL, deferUntilFlush = TRUE) {
  glmap_proxy(outputId = mapId, session = session, data = data, deferUntilFlush = deferUntilFlush)
}
