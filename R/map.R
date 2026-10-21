#' Create a High-Performance GPU Map Widget (`glmap`)
#'
#' Initializes a `glmap` WebGL2 + MapLibre GL interactive map widget.
#' If `data` is supplied (`sf`, `sfc`, `SpatRaster`, `SpatVector`, `wk::xy`, `nanoarrow`,
#' `data.frame`, or `crosstalk::SharedData`), `glmap()` automatically inspects its type
#' and adds the appropriate GPU layer unless layers are added downstream via pipes (`|>`).
#'
#' @param data Optional default spatial dataset (`sf`, `sfc`, `SpatRaster`, `data.frame`, or `SharedData`).
#' @param basemap Basemap style name (`"dark"`, `"positron"`, `"voyager"`, `"osm"`, `"satellite"`, `"none"`),
#'   a provider from [gl_providers], or a custom MapLibre style URL / `{z}/{x}/{y}` template.
#' @param api_key Optional API key string for the basemap provider (can also be configured globally via
#'   [gl_set_api_key()] or environment variables such as `CARTO_API_KEY`, `MAPTILER_API_KEY`, `STADIA_API_KEY`).
#' @param center Numeric vector `c(lon, lat)` for initial map center. Auto-computed from layers if `NULL`.
#' @param zoom Numeric initial zoom level.
#' @param pitch Numeric initial tilt angle in degrees (`0` to `85`).
#' @param bearing Numeric initial rotation bearing in degrees.
#' @param projection Map projection: `"mercator"` (default) or `"globe"`.
#' @param transport Binary transport mode: `"auto"` (inline gzipped binary up to 25 MB, works in static HTML & Viewer),
#'   `"server"` (streams via local `httpuv` binary range server), or `"inline"`.
#' @param width Widget width (CSS units).
#' @param height Widget height (CSS units).
#' @param elementId Optional HTML element ID.
#' @param auto_layer Logical; if `TRUE` and `data` is provided, automatically adds a default GPU layer
#'   when the map is printed/rendered if no explicit `add_*()` layers were called.
#' @param ... Additional arguments passed to the default layer when `auto_layer = TRUE`.
#' @return An `htmlwidget` object of class `c("glmap", "glmap", "htmlwidget")`.
#' @export
glmap <- function(
    data = NULL,
    basemap = "dark",
    api_key = NULL,
    center = NULL,
    zoom = NULL,
    pitch = 0,
    bearing = 0,
    projection = c("mercator", "globe"),
    transport = c("auto", "inline", "server"),
    width = "100%",
    height = NULL,
    elementId = NULL,
    auto_layer = TRUE,
    ...
) {
  projection <- match.arg(projection)
  transport <- match.arg(transport)

  # Unwrap crosstalk::SharedData if provided
  crosstalk_group <- NULL
  crosstalk_keys <- NULL
  crosstalk_deps <- NULL
  raw_data <- data

  if (inherits(data, "SharedData")) {
    crosstalk_group <- data$groupName()
    crosstalk_keys <- data$key()
    raw_data <- data$origData()
    if (requireNamespace("crosstalk", quietly = TRUE)) {
      crosstalk_deps <- crosstalk::crosstalkLibs()
    }
  }

  x <- list(
    basemap = resolve_basemap_spec(basemap, api_key = api_key),
    basemap_name = if (is.character(basemap) && length(basemap) == 1L) basemap else "custom",
    view = list(
      center = center,
      zoom = zoom,
      pitch = pitch,
      bearing = bearing,
      projection = projection,
      bounds = NULL
    ),
    transport = transport,
    layers = list(),
    controls = list(
      navigation = list(enabled = TRUE, position = "top-right", direction = "vertical", order = 10),
      layer_switcher = list(
        enabled = TRUE,
        position = "top-left",
        direction = "vertical",
        order = 10,
        collapsed = TRUE,
        baseGroups = c("Light", "Dark", "Satellite"),
        overlayGroups = character(0)
      ),
      scale = list(enabled = TRUE, position = "bottom-left", direction = "horizontal", order = 90),
      hud = list(enabled = TRUE, position = "bottom-center", direction = "horizontal", order = 20),
      legends = list(enabled = TRUE, position = "bottom-right", direction = "vertical", order = 20),
      attribution = list(enabled = TRUE, position = "bottom-right", direction = "horizontal", order = 100)
    ),
    legends = list(),
    terrain = NULL,
    crosstalk = if (!is.null(crosstalk_group)) list(group = crosstalk_group, keys = as.character(crosstalk_keys)) else NULL,
    plugins = list()
  )

  attr(x, "glmap_data") <- raw_data
  attr(x, "glmap_auto_args") <- list(...)
  attr(x, "glmap_auto_layer") <- isTRUE(auto_layer)

  pre_render <- function(widget) {
    # If user passed `glmap(my_sf)` without adding explicit layers, auto-add layer now
    if (length(widget$x$layers) == 0L && isTRUE(attr(widget$x, "glmap_auto_layer"))) {
      d <- attr(widget$x, "glmap_data")
      if (!is.null(d)) {
        extra <- attr(widget$x, "glmap_auto_args") %||% list()
        if (inherits(d, c("SpatRaster", "RasterLayer", "RasterStack", "RasterBrick", "stars")) || is.matrix(d) || (is.numeric(d) && length(dim(d)) == 2L)) {
          widget <- do.call(add_raster, c(list(map = widget, raster = d), extra))
        } else {
          widget <- do.call(add_sf, c(list(map = widget, data = d), extra))
        }
      }
    }
    # Strip heavy R attributes before htmlwidgets serializes `x`
    attr(widget$x, "glmap_data") <- NULL
    attr(widget$x, "glmap_auto_args") <- NULL
    attr(widget$x, "glmap_auto_layer") <- NULL
    widget
  }

  w <- htmlwidgets::createWidget(
    name = "glmap",
    x = x,
    width = width,
    height = height,
    package = "glmap",
    elementId = elementId,
    dependencies = crosstalk_deps,
    preRenderHook = pre_render,
    sizingPolicy = htmlwidgets::sizingPolicy(
      defaultWidth = "100%",
      defaultHeight = 600,
      viewer.defaultHeight = "100%",
      viewer.defaultWidth = "100%",
      viewer.fill = TRUE,
      browser.fill = TRUE,
      browser.padding = 0,
      knitr.figure = FALSE,
      knitr.defaultWidth = "100%",
      knitr.defaultHeight = "520px"
    )
  )
  class(w) <- unique(c("glmap", "glmap", class(w)))
  w
}



resolve_basemap_spec <- function(basemap = "dark", api_key = NULL, key_param = NULL, attribution = "") {
  if (is.list(basemap)) return(basemap)
  raw_str <- as.character(basemap[1])
  b <- tolower(raw_str)
  fam <- normalize_provider_family(raw_str)
  eff_key <- api_key %||% gl_get_api_key(fam)

  default_param <- key_param %||% switch(
    fam,
    "carto" = "key",
    "maptiler" = "key",
    "stadia" = "api_key",
    "thunderforest" = "apikey",
    "jawg" = "access-token",
    "mapbox" = "access_token",
    "esri" = "token",
    "key"
  )

  finalize_spec <- function(spec) {
    if (!is.null(spec$style_url) && nzchar(spec$style_url)) {
      spec$style_url <- inject_url_api_key(spec$style_url, eff_key, default_param)
    }
    if (!is.null(spec$tiles) && length(spec$tiles) > 0L) {
      spec$tiles <- inject_url_api_key(spec$tiles, eff_key, default_param)
    }
    spec$api_key_configured <- !is.null(eff_key) && nzchar(eff_key)
    spec
  }

  # Direct custom XYZ raster tile URL template (contains {z} and {x} and {y})
  if (grepl("\\{z\\}", raw_str) && grepl("\\{x\\}", raw_str) && grepl("\\{y\\}", raw_str)) {
    return(finalize_spec(list(
      type = "raster",
      tiles = c(raw_str),
      bg = "#0e1117",
      attribution = attribution
    )))
  }

  spec <- switch(
    b,
    "dark" = ,
    "cartodb.darkmatter" = list(
      type = "carto",
      style_url = "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json",
      tiles = c(
        "https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png",
        "https://b.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png",
        "https://c.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png"
      ),
      bg = "#0e1117",
      attribution = "&copy; OpenStreetMap contributors &copy; CARTO"
    ),
    "cartodb.darkmatternolabels" = list(
      type = "raster",
      tiles = c("https://a.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}@2x.png"),
      bg = "#0e1117",
      attribution = "&copy; OpenStreetMap contributors &copy; CARTO"
    ),
    "positron" = ,
    "light" = ,
    "cartodb.positron" = list(
      type = "carto",
      style_url = "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json",
      tiles = c(
        "https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png",
        "https://b.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png",
        "https://c.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png"
      ),
      bg = "#f4f6f8",
      attribution = "&copy; OpenStreetMap contributors &copy; CARTO"
    ),
    "cartodb.positronnolabels" = list(
      type = "raster",
      tiles = c("https://a.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}@2x.png"),
      bg = "#f4f6f8",
      attribution = "&copy; OpenStreetMap contributors &copy; CARTO"
    ),
    "voyager" = ,
    "cartodb.voyager" = list(
      type = "carto",
      style_url = "https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json",
      tiles = c(
        "https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png",
        "https://b.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png"
      ),
      bg = "#eef2f5",
      attribution = "&copy; OpenStreetMap contributors &copy; CARTO"
    ),
    "cartodb.voyagernolabels" = list(
      type = "raster",
      tiles = c("https://a.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}@2x.png"),
      bg = "#eef2f5",
      attribution = "&copy; OpenStreetMap contributors &copy; CARTO"
    ),
    "openfreemap.liberty" = list(
      type = "vector_gl",
      style_url = "https://tiles.openfreemap.org/styles/liberty",
      bg = "#eef2f5",
      attribution = "&copy; OpenFreeMap &copy; OpenMapTiles &copy; OpenStreetMap"
    ),
    "openfreemap.bright" = list(
      type = "vector_gl",
      style_url = "https://tiles.openfreemap.org/styles/bright",
      bg = "#f8fafc",
      attribution = "&copy; OpenFreeMap &copy; OpenMapTiles &copy; OpenStreetMap"
    ),
    "openfreemap.positron" = list(
      type = "vector_gl",
      style_url = "https://tiles.openfreemap.org/styles/positron",
      bg = "#f4f6f8",
      attribution = "&copy; OpenFreeMap &copy; OpenMapTiles &copy; OpenStreetMap"
    ),
    "openfreemap.dark" = list(
      type = "vector_gl",
      style_url = "https://tiles.openfreemap.org/styles/dark",
      bg = "#0e1117",
      attribution = "&copy; OpenFreeMap &copy; OpenMapTiles &copy; OpenStreetMap"
    ),
    "osm" = ,
    "openstreetmap" = ,
    "openstreetmap.mapnik" = list(
      type = "raster",
      tiles = c("https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
      bg = "#e5e3df",
      attribution = "&copy; OpenStreetMap contributors"
    ),
    "openstreetmap.hot" = list(
      type = "raster",
      tiles = c("https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png"),
      bg = "#e5e3df",
      attribution = "&copy; OpenStreetMap contributors, HOT"
    ),
    "openstreetmap.france" = list(
      type = "raster",
      tiles = c("https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png"),
      bg = "#e5e3df",
      attribution = "&copy; OpenStreetMap France"
    ),
    "topo" = ,
    "opentopomap" = list(
      type = "raster",
      tiles = c("https://a.tile.opentopomap.org/{z}/{x}/{y}.png"),
      bg = "#f2efe9",
      attribution = "&copy; OpenTopoMap (CC-BY-SA)"
    ),
    "satellite" = ,
    "esri.worldimagery" = list(
      type = "raster",
      tiles = c("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"),
      bg = "#070b12",
      attribution = "Tiles &copy; Esri"
    ),
    "esri.worldtopomap" = list(
      type = "raster",
      tiles = c("https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}"),
      bg = "#f4f6f8",
      attribution = "Tiles &copy; Esri"
    ),
    "esri.worldstreetmap" = list(
      type = "raster",
      tiles = c("https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}"),
      bg = "#f4f6f8",
      attribution = "Tiles &copy; Esri"
    ),
    "esri.worldterrain" = list(
      type = "raster",
      tiles = c("https://server.arcgisonline.com/ArcGIS/rest/services/World_Terrain_Base/MapServer/tile/{z}/{y}/{x}"),
      bg = "#f4f6f8",
      attribution = "Tiles &copy; Esri"
    ),
    "esri.worldshadedrelief" = list(
      type = "raster",
      tiles = c("https://server.arcgisonline.com/ArcGIS/rest/services/World_Shaded_Relief/MapServer/tile/{z}/{y}/{x}"),
      bg = "#e2e8f0",
      attribution = "Tiles &copy; Esri"
    ),
    "esri.oceanbasemap" = list(
      type = "raster",
      tiles = c("https://server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}"),
      bg = "#0c4a6e",
      attribution = "Tiles &copy; Esri"
    ),
    "esri.natgeoworldmap" = list(
      type = "raster",
      tiles = c("https://server.arcgisonline.com/ArcGIS/rest/services/NatGeo_World_Map/MapServer/tile/{z}/{y}/{x}"),
      bg = "#f4f6f8",
      attribution = "Tiles &copy; Esri &copy; National Geographic"
    ),
    "esri.worldgraycanvas" = list(
      type = "raster",
      tiles = c("https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}"),
      bg = "#e5e7eb",
      attribution = "Tiles &copy; Esri"
    ),
    "usgs.ustopo" = list(
      type = "raster",
      tiles = c("https://basemap.nationalmap.gov/arcgis/rest/services/USGSTopo/MapServer/tile/{z}/{y}/{x}"),
      bg = "#f4f6f8",
      attribution = "Tiles courtesy of the U.S. Geological Survey"
    ),
    "usgs.usimagery" = list(
      type = "raster",
      tiles = c("https://basemap.nationalmap.gov/arcgis/rest/services/USGSImageryOnly/MapServer/tile/{z}/{y}/{x}"),
      bg = "#070b12",
      attribution = "Tiles courtesy of the U.S. Geological Survey"
    ),
    "usgs.usimagerytopo" = list(
      type = "raster",
      tiles = c("https://basemap.nationalmap.gov/arcgis/rest/services/USGSImageryTopo/MapServer/tile/{z}/{y}/{x}"),
      bg = "#070b12",
      attribution = "Tiles courtesy of the U.S. Geological Survey"
    ),
    "maptiler.streets" = list(
      type = "vector_gl",
      style_url = "https://api.maptiler.com/maps/streets-v2/style.json?key={apikey}",
      bg = "#f4f6f8",
      attribution = "&copy; MapTiler &copy; OpenStreetMap contributors"
    ),
    "maptiler.dataviz" = list(
      type = "vector_gl",
      style_url = "https://api.maptiler.com/maps/dataviz/style.json?key={apikey}",
      bg = "#f4f6f8",
      attribution = "&copy; MapTiler &copy; OpenStreetMap contributors"
    ),
    "maptiler.datavizdark" = list(
      type = "vector_gl",
      style_url = "https://api.maptiler.com/maps/dataviz-dark/style.json?key={apikey}",
      bg = "#0e1117",
      attribution = "&copy; MapTiler &copy; OpenStreetMap contributors"
    ),
    "maptiler.backdrop" = list(
      type = "vector_gl",
      style_url = "https://api.maptiler.com/maps/backdrop/style.json?key={apikey}",
      bg = "#e5e7eb",
      attribution = "&copy; MapTiler &copy; OpenStreetMap contributors"
    ),
    "maptiler.satellite" = list(
      type = "vector_gl",
      style_url = "https://api.maptiler.com/maps/satellite/style.json?key={apikey}",
      bg = "#070b12",
      attribution = "&copy; MapTiler"
    ),
    "maptiler.outdoor" = list(
      type = "vector_gl",
      style_url = "https://api.maptiler.com/maps/outdoor-v2/style.json?key={apikey}",
      bg = "#eef2f5",
      attribution = "&copy; MapTiler &copy; OpenStreetMap contributors"
    ),
    "stadia.alidadesmooth" = list(
      type = "vector_gl",
      style_url = "https://tiles.stadiamaps.com/styles/alidade_smooth.json?api_key={apikey}",
      bg = "#f4f6f8",
      attribution = "&copy; Stadia Maps &copy; OpenMapTiles &copy; OpenStreetMap"
    ),
    "stadia.alidadesmoothdark" = list(
      type = "vector_gl",
      style_url = "https://tiles.stadiamaps.com/styles/alidade_smooth_dark.json?api_key={apikey}",
      bg = "#0e1117",
      attribution = "&copy; Stadia Maps &copy; OpenMapTiles &copy; OpenStreetMap"
    ),
    "stadia.alidadesatellite" = list(
      type = "vector_gl",
      style_url = "https://tiles.stadiamaps.com/styles/alidade_satellite.json?api_key={apikey}",
      bg = "#070b12",
      attribution = "&copy; Stadia Maps"
    ),
    "stadia.outdoors" = list(
      type = "vector_gl",
      style_url = "https://tiles.stadiamaps.com/styles/outdoors.json?api_key={apikey}",
      bg = "#eef2f5",
      attribution = "&copy; Stadia Maps &copy; OpenMapTiles &copy; OpenStreetMap"
    ),
    "stadia.stamentoner" = list(
      type = "raster",
      tiles = c("https://tiles.stadiamaps.com/tiles/stamen_toner/{z}/{x}/{y}@2x.png?api_key={apikey}"),
      bg = "#ffffff",
      attribution = "&copy; Stadia Maps &copy; Stamen Design &copy; OpenStreetMap"
    ),
    "stadia.stamenterrain" = list(
      type = "raster",
      tiles = c("https://tiles.stadiamaps.com/tiles/stamen_terrain/{z}/{x}/{y}@2x.png?api_key={apikey}"),
      bg = "#f4f6f8",
      attribution = "&copy; Stadia Maps &copy; Stamen Design &copy; OpenStreetMap"
    ),
    "stadia.stamenwatercolor" = list(
      type = "raster",
      tiles = c("https://tiles.stadiamaps.com/tiles/stamen_watercolor/{z}/{x}/{y}.jpg?api_key={apikey}"),
      bg = "#f8fafc",
      attribution = "&copy; Stadia Maps &copy; Stamen Design"
    ),
    "thunderforest.landscape" = list(
      type = "raster",
      tiles = c("https://tile.thunderforest.com/landscape/{z}/{x}/{y}.png?apikey={apikey}"),
      bg = "#f4f6f8",
      attribution = "&copy; Thunderforest &copy; OpenStreetMap contributors"
    ),
    "thunderforest.outdoors" = list(
      type = "raster",
      tiles = c("https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png?apikey={apikey}"),
      bg = "#f4f6f8",
      attribution = "&copy; Thunderforest &copy; OpenStreetMap contributors"
    ),
    "thunderforest.transportdark" = list(
      type = "raster",
      tiles = c("https://tile.thunderforest.com/transport-dark/{z}/{x}/{y}.png?apikey={apikey}"),
      bg = "#0e1117",
      attribution = "&copy; Thunderforest &copy; OpenStreetMap contributors"
    ),
    "jawg.streets" = list(
      type = "raster",
      tiles = c("https://tile.jawg.io/jawg-streets/{z}/{x}/{y}@2x.png?access-token={apikey}"),
      bg = "#f4f6f8",
      attribution = "&copy; Jawg Maps &copy; OpenStreetMap contributors"
    ),
    "jawg.dark" = list(
      type = "raster",
      tiles = c("https://tile.jawg.io/jawg-dark/{z}/{x}/{y}@2x.png?access-token={apikey}"),
      bg = "#0e1117",
      attribution = "&copy; Jawg Maps &copy; OpenStreetMap contributors"
    ),
    "jawg.terrain" = list(
      type = "raster",
      tiles = c("https://tile.jawg.io/jawg-terrain/{z}/{x}/{y}@2x.png?access-token={apikey}"),
      bg = "#f4f6f8",
      attribution = "&copy; Jawg Maps &copy; OpenStreetMap contributors"
    ),
    "mapbox.streets" = list(
      type = "raster",
      tiles = c("https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={apikey}"),
      bg = "#f4f6f8",
      attribution = "&copy; Mapbox &copy; OpenStreetMap"
    ),
    "mapbox.dark" = list(
      type = "raster",
      tiles = c("https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}@2x?access_token={apikey}"),
      bg = "#0e1117",
      attribution = "&copy; Mapbox &copy; OpenStreetMap"
    ),
    "mapbox.light" = list(
      type = "raster",
      tiles = c("https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/256/{z}/{x}/{y}@2x?access_token={apikey}"),
      bg = "#f4f6f8",
      attribution = "&copy; Mapbox &copy; OpenStreetMap"
    ),
    "mapbox.satellite" = list(
      type = "raster",
      tiles = c("https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}@2x?access_token={apikey}"),
      bg = "#070b12",
      attribution = "&copy; Mapbox"
    ),
    "blank_light" = list(
      type = "none",
      tiles = character(0),
      bg = "#f8fafc",
      attribution = ""
    ),
    "none" = list(
      type = "none",
      tiles = character(0),
      bg = "#0b0f17",
      attribution = ""
    ),
    list(
      type = "custom_url",
      style_url = raw_str,
      bg = "#0e1117",
      attribution = attribution
    )
  )

  finalize_spec(spec)
}

update_map_bounds <- function(map, bbox) {
  if (inherits(map, "glmap_proxy")) return(map)
  if (is.null(bbox) || length(bbox) < 4 || any(!is.finite(bbox))) return(map)
  cur <- map$x$view$bounds
  if (is.null(cur)) {
    map$x$view$bounds <- as.numeric(bbox)
  } else {
    map$x$view$bounds <- c(
      min(cur[1], bbox[1]),
      min(cur[2], bbox[2]),
      max(cur[3], bbox[3]),
      max(cur[4], bbox[4])
    )
  }
  map
}

dispatch_layer <- function(map, layer_spec, legend_spec = NULL, bbox = NULL) {
  if (inherits(map, "glmap_proxy")) {
    invoke_proxy_method(map, "addLayer", list(layer = layer_spec, legend = legend_spec, bbox = bbox))
    return(map)
  }
  map$x$layers[[length(map$x$layers) + 1L]] <- layer_spec
  if (!is.null(legend_spec)) {
    map$x$legends[[length(map$x$legends) + 1L]] <- legend_spec
  }
  map <- update_map_bounds(map, bbox)
  map
}

#' Automatically Add an `sf`, `sfc`, or `data.frame` Layer to a `glmap` Map
#'
#' Inspects the geometry type of `data` (`POINT`, `LINESTRING`, `POLYGON`, etc.)
#' and routes to [add_points()], [add_lines()], or [add_polygons()].
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param data An `sf`, `sfc`, or `data.frame` object (defaults to map data).
#' @param ... Arguments passed on to [add_points()], [add_lines()], or [add_polygons()].
#' @export
add_sf <- function(map, data = NULL, ...) {
  data <- data %||% attr(map$x, "glmap_data")
  if (is.null(data)) cli::cli_abort("No `data` supplied to {.fn add_sf}.")
  if (inherits(data, "SharedData")) data <- data$origData()
  if (inherits(data, c("SpatVector", "Spatial")) && requireNamespace("sf", quietly = TRUE)) {
    data <- sf::st_as_sf(data)
  } else if (inherits(data, "sfg") && requireNamespace("sf", quietly = TRUE)) {
    data <- sf::st_sfc(data)
  }

  if (!inherits(data, c("sf", "sfc")) && is.data.frame(data)) {
    return(add_points(map, data = data, ...))
  }
  sfc <- if (inherits(data, "sf")) data[[attr(data, "sf_column") %||% "geometry"]] else data
  cls <- class(sfc)[1]
  if (grepl("POINT", cls, fixed = TRUE)) {
    add_points(map, data = data, ...)
  } else if (grepl("LINE", cls, fixed = TRUE)) {
    add_lines(map, data = data, ...)
  } else {
    add_polygons(map, data = data, ...)
  }
}

#' Add a GPU Instanced Point Layer (Handles 1M+ Points at 60 FPS)
#'
#' Streams points as a zero-copy `GLMP` binary `Float32Array` buffer directly to
#' a custom WebGL2 instanced point shader (with anti-aliased SDF circles, stroke
#' outlines, variable radius, and interactive picking).
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param data An `sf`, `sfc`, or `data.frame` object.
#' @param lon Optional longitude column name or formula (`~lon`) for `data.frame`.
#' @param lat Optional latitude column name or formula (`~lat`) for `data.frame`.
#' @param color Color string, formula (`~val`), or column name.
#' @param palette Color palette name (`"viridis"`, `"plasma"`, `"magma"`, `"turbo"`, `"Spectral"`, etc.).
#' @param radius Point radius in pixels (single number, formula `~size`, or numeric vector).
#' @param opacity Numeric fill opacity (`0` to `1`).
#' @param stroke Logical; whether to draw a crisp anti-aliased stroke around each point.
#' @param stroke_color Stroke color string (default `"#ffffff"`).
#' @param stroke_width Stroke width in pixels (default `1.0`).
#' @param popup Optional formula (`~name`), column name, or character vector for click/hover tooltips.
#' @param label Alias for `popup`.
#' @param icon Optional marker icon specification created by [make_icon()], [make_awesome_icon()],
#'   `leaflet::makeIcon()`, or a character vector / formula (`~icon_url`) of SVG/PNG URLs.
#' @param clusterOptions Optional clustering specification (`leaflet::markerClusterOptions()` or
#'   [marker_cluster_options()] compatibility).
#' @param render_mode Rendering strategy for markers/icons: `"auto"` (default; dynamically combines
#'   clustering, zoom-level LOD cross-fade, and WebGL2 Texture Atlas sprites based on feature count
#'   and `clusterOptions`), `"cluster"` (screen-space clustering + GPU singleton sprites),
#'   `"lod"` (zoom-level Level-of-Detail cross-fade from GPU SDF points at overview zooms to full
#'   WebGL2 Texture Atlas sprites when zoomed in), `"atlas"` (always render 100% of custom icons via
#'   the WebGL2 Texture Atlas sprite shader in 1 GPU draw call), or `"points"` (pure GPU SDF circles).
#'   Can also be an [icon_render_options()] object.
#' @param lod_zoom Numeric zoom threshold (or `c(fade_start, fade_end)`) for Level-of-Detail (`"lod"` / `"auto"`)
#'   transition between fast GPU SDF circles and full custom SVG/PNG Texture Atlas icons. When `NULL` (default),
#'   dynamically adapts to dataset size (`<= 2,500` markers: `0` i.e. always full icons; `2,500-15,000`: `c(8.5, 10.5)`;
#'   `> 15,000`: `c(10, 12)`).
#' @param id Layer ID string.
#' @param group Layer group name shown in the interactive layer switcher.
#' @param dynamic_viewport Logical; if `TRUE`, builds an in-memory C++ spatial index and streams
#'   only the visible viewport slice via the local `httpuv` server.
#' @param legend Logical; whether to automatically add a legend when `color` is mapped to data.
#' @param lng Optional alias for `lon` (`leaflet` compatibility).
#' @return Updated `glmap` map object.
#' @export
add_points <- function(
    map,
    data = NULL,
    lon = NULL,
    lat = NULL,
    color = "#00d4ff",
    palette = "viridis",
    radius = 5,
    opacity = 0.85,
    stroke = TRUE,
    stroke_color = "#ffffff",
    stroke_width = 1.0,
    popup = NULL,
    label = NULL,
    icon = NULL,
    clusterOptions = NULL,
    render_mode = "auto",
    lod_zoom = NULL,
    id = NULL,
    group = NULL,
    dynamic_viewport = FALSE,
    legend = TRUE,
    lng = NULL
) {
  data <- data %||% attr(map$x, "glmap_data")
  if (is.null(data)) cli::cli_abort("`data` must be provided to {.fn add_points}.")
  if (inherits(data, "SharedData")) data <- data$origData()

  lon <- lon %||% lng
  id <- id %||% next_layer_id("points")
  group <- group %||% id

  if (inherits(lon, "formula")) lon <- rlang::as_name(rlang::f_rhs(lon))
  if (inherits(lat, "formula")) lat <- rlang::as_name(rlang::f_rhs(lat))
  if (inherits(data, c("SpatVector", "Spatial")) && requireNamespace("sf", quietly = TRUE)) {
    data <- sf::st_as_sf(data)
  }

  n <- if (inherits(data, "sfc")) length(data) else nrow(data)
  col_res <- resolve_rgba(color = color, data = data, n = n, opacity = opacity, palette = palette)
  rad_vec <- resolve_numeric_aesthetic(radius, data = data, default = 5.0, range_out = c(2.5, 16))

  raw_buf <- gl_pack_sf_binary(
    data = data,
    lon = lon,
    lat = lat,
    rgba = col_res$rgba,
    radius = rad_vec
  )

  transport_mode <- if (inherits(map, "glmap_proxy")) "inline" else (map$x$transport %||% "auto")
  buf_spec <- register_binary_buffer(id, raw_buf, mode = transport_mode)

  viewport_url <- NULL
  if (isTRUE(dynamic_viewport)) {
    idx_obj <- gl_spatial_index(data, lon = lon, lat = lat)
    idx_obj$rgba <- col_res$rgba
    idx_obj$radius <- rad_vec
    assign(id, idx_obj, envir = .gl_env$indices)
    base_url <- gl_serve_start()
    viewport_url <- sprintf("%s/viewport/%s", base_url, id)
  }

  stroke_rgb <- as.integer(grDevices::col2rgb(stroke_color, alpha = FALSE)[, 1])
  tooltips <- build_popup_labels(popup, label, data)
  icon_spec <- resolve_icon_spec(icon, data, n)
  cluster_spec <- resolve_cluster_spec(clusterOptions, n = n, render_mode = render_mode)
  render_spec <- resolve_icon_render_spec(
    render_mode = render_mode,
    lod_zoom = lod_zoom,
    n = n,
    has_icons = !is.null(icon_spec),
    has_cluster = !is.null(cluster_spec)
  )

  layer_spec <- list(
    id = id,
    group = group,
    type = "points",
    visible = TRUE,
    opacity = opacity,
    n_features = attr(raw_buf, "n_features"),
    n_vertices = attr(raw_buf, "n_vertices"),
    bbox = attr(raw_buf, "bbox"),
    buffer = buf_spec,
    viewport_url = viewport_url,
    style = list(
      radius = if (length(rad_vec) == 1L) rad_vec else 5.0,
      stroke = isTRUE(stroke),
      stroke_color = stroke_rgb,
      stroke_width = as.numeric(stroke_width),
      icons = icon_spec,
      cluster = cluster_spec,
      render = render_spec
    ),
    tooltips = tooltips
  )

  legend_spec <- if (isTRUE(legend)) col_res$legend else NULL
  if (!is.null(legend_spec)) {
    legend_spec$layer_id <- id
    legend_spec$group <- group
  }

  dispatch_layer(map, layer_spec, legend_spec, attr(raw_buf, "bbox"))
}

#' Add Custom Icon or Awesome Markers (`add_markers`, `make_icon`, `make_awesome_icon`)
#'
#' Drop-in GPU/Canvas equivalents of `leaflet::addMarkers()`, `leaflet::makeIcon()`,
#' and `leaflet::makeAwesomeIcon()`. Supports per-feature SVG/PNG icon URLs (such as
#' Geonesis product icons `bateau1.svg`, `habitation1.svg`, `auto1.svg`) as well as
#' colored pin/badge markers.
#'
#' @inheritParams add_points
#' @param ... Additional arguments passed to [add_points()].
#' @export
add_markers <- function(
    map,
    data = NULL,
    lng = NULL,
    lat = NULL,
    icon = NULL,
    popup = NULL,
    label = NULL,
    group = NULL,
    clusterOptions = NULL,
    render_mode = "auto",
    lod_zoom = NULL,
    id = NULL,
    ...
) {
  add_points(
    map = map,
    data = data,
    lon = lng,
    lat = lat,
    icon = icon,
    popup = popup,
    label = label,
    group = group,
    clusterOptions = clusterOptions,
    render_mode = render_mode,
    lod_zoom = lod_zoom,
    id = id %||% next_layer_id("markers"),
    legend = FALSE,
    ...
  )
}

#' @param iconUrl URL or relative path (e.g. inside Shiny `www/`) to an SVG or PNG icon.
#' @param iconWidth,iconHeight Icon dimensions in pixels (default `28`).
#' @rdname add_markers
#' @export
make_icon <- function(iconUrl, iconWidth = 28, iconHeight = 28) {
  structure(
    list(
      iconUrl = as.character(iconUrl),
      iconWidth = as.numeric(iconWidth[1]),
      iconHeight = as.numeric(iconHeight[1])
    ),
    class = c("gl_icon", "leaflet_icon")
  )
}

#' @param text Optional short symbol or glyph text inside the awesome marker pin.
#' @param markerColor Marker pin color (e.g., `"red"`, `"blue"`, `"orange"`, `"green"`, `"purple"`).
#' @param iconColor Inner glyph color (default `"#ffffff"`).
#' @rdname add_markers
#' @export
make_awesome_icon <- function(text = "*", markerColor = "blue", iconColor = "#ffffff") {
  structure(
    list(
      type = "awesome",
      text = as.character(text),
      markerColor = as.character(markerColor),
      iconColor = as.character(iconColor),
      iconWidth = 28,
      iconHeight = 34
    ),
    class = c("gl_awesome_icon", "leaflet_awesome_icon")
  )
}

#' @param showCoverageOnHover Logical; highlight cluster bounds on hover.
#' @param zoomToBoundsOnClick Logical; zoom to cluster bounds when clicked (default `TRUE`).
#' @param spiderfyOnMaxZoom Logical; expand overlapping points at max zoom.
#' @param disableClusteringAtZoom Numeric zoom level at or above which individual markers/icons are shown directly (default `15`).
#' @param maxClusterRadius Maximum radius in pixels that a cluster will cover (default `65`).
#' @param freezeAtZoom Optional zoom level to freeze clusters.
#' @rdname add_markers
#' @export
marker_cluster_options <- function(
    showCoverageOnHover = TRUE,
    zoomToBoundsOnClick = TRUE,
    spiderfyOnMaxZoom = TRUE,
    disableClusteringAtZoom = 15,
    maxClusterRadius = 65,
    freezeAtZoom = FALSE
) {
  structure(
    list(
      enabled = TRUE,
      showCoverageOnHover = isTRUE(showCoverageOnHover),
      zoomToBoundsOnClick = isTRUE(zoomToBoundsOnClick),
      spiderfyOnMaxZoom = isTRUE(spiderfyOnMaxZoom),
      disableClusteringAtZoom = if (is.numeric(disableClusteringAtZoom)) as.numeric(disableClusteringAtZoom[1]) else 15,
      maxClusterRadius = as.numeric(maxClusterRadius[1] %||% 65),
      freezeAtZoom = freezeAtZoom
    ),
    class = c("gl_cluster_options", "markerClusterOptions")
  )
}

resolve_cluster_spec <- function(clusterOptions, n = 0L, render_mode = "auto") {
  mode_str <- if (is.character(render_mode)) tolower(render_mode[1]) else if (is.list(render_mode) && !is.null(render_mode$mode)) tolower(render_mode$mode[1]) else "auto"
  if (identical(clusterOptions, FALSE)) return(NULL)
  if (is.null(clusterOptions)) {
    if (identical(mode_str, "cluster")) {
      return(unclass(marker_cluster_options()))
    }
    return(NULL)
  }
  if (isTRUE(clusterOptions)) {
    return(unclass(marker_cluster_options()))
  }
  if (is.list(clusterOptions)) {
    return(list(
      enabled = TRUE,
      zoomToBoundsOnClick = isTRUE(clusterOptions$zoomToBoundsOnClick %||% TRUE),
      disableClusteringAtZoom = as.numeric(clusterOptions$disableClusteringAtZoom %||% 15),
      maxClusterRadius = as.numeric(clusterOptions$maxClusterRadius %||% 65)
    ))
  }
  NULL
}

#' Configure GPU Icon & Marker Rendering Strategy (`icon_render_options`)
#'
#' Configures how `glmap` balances visual fidelity and 60 FPS GPU throughput across
#' the three marker rendering engines:
#' 1. **WebGL2 Texture Atlas (`"atlas"`)**: Packs all unique SVG/PNG icons into a single
#'    GPU sprite sheet texture and renders 100k+ custom icons in 1 `gl.POINTS` draw call.
#' 2. **Screen-Space Grid Clustering (`"cluster"`)**: Groups nearby markers into interactive
#'    count badges (`< 10`, `< 100`, `100+`) that zoom into cluster bounds on click and render
#'    unclustered singletons via the GPU Texture Atlas.
#' 3. **Zoom-Level Level-of-Detail Hybrid (`"lod"`)**: Renders crisp GPU SDF points at overview
#'    zoom levels and smoothly cross-fades into full custom SVG/PNG Texture Atlas icons as you
#'    zoom in across `lod_zoom`.
#'
#' @param mode Strategy name: `"auto"` (default; dynamically selects based on `clusterOptions`
#'   and feature count `n`), `"atlas"`, `"cluster"`, `"lod"`, or `"points"`.
#' @param lod_zoom Numeric zoom threshold (e.g. `10`) or 2-element cross-fade range `c(9, 11)`.
#'   If `NULL`, computed dynamically from feature count (`<= 2,500`: `c(0, 0)` always icons;
#'   `2,501-15,000`: `c(8.5, 10.5)`; `> 15,000`: `c(10.0, 12.0)`).
#' @param atlas_cell_px Resolution in pixels of each sprite slot in the GPU Texture Atlas (default `64L`).
#' @param allow_ui_switcher Logical; if `TRUE` (default), exposes a compact mode selector in the
#'   map's layer control so users can switch between `Auto`, `Cluster`, `LOD`, and `GPU Atlas` live.
#' @rdname add_markers
#' @export
icon_render_options <- function(
    mode = c("auto", "atlas", "cluster", "lod", "points"),
    lod_zoom = NULL,
    atlas_cell_px = 64L,
    allow_ui_switcher = TRUE
) {
  mode <- match.arg(mode)
  structure(
    list(
      mode = mode,
      lod_zoom = if (!is.null(lod_zoom)) as.numeric(lod_zoom) else NULL,
      atlas_cell_px = as.integer(atlas_cell_px[1] %||% 64L),
      allow_ui_switcher = isTRUE(allow_ui_switcher)
    ),
    class = "gl_icon_render_options"
  )
}

resolve_icon_render_spec <- function(render_mode = "auto", lod_zoom = NULL, n = 0L, has_icons = FALSE, has_cluster = FALSE) {
  allow_ui <- TRUE
  cell_px <- 64L
  if (inherits(render_mode, "gl_icon_render_options") || is.list(render_mode)) {
    lod_zoom <- lod_zoom %||% render_mode$lod_zoom
    cell_px <- as.integer(render_mode$atlas_cell_px %||% 64L)
    allow_ui <- isTRUE(render_mode$allow_ui_switcher %||% TRUE)
    mode_str <- tolower(as.character(render_mode$mode %||% "auto")[1])
  } else {
    mode_str <- tolower(as.character(render_mode %||% "auto")[1])
  }

  # Dynamic LOD zoom range based on dataset scale n when not explicitly provided
  if (is.null(lod_zoom)) {
    if (n <= 2500L) {
      lod_range <- c(0.0, 0.0) # Small/medium dataset: GPU atlas renders 100% of icons at all zooms
    } else if (n <= 15000L) {
      lod_range <- c(8.5, 10.5) # Smooth cross-fade between zoom 8.5 and 10.5
    } else {
      lod_range <- c(10.0, 12.0) # Large dataset (15k-1M+): SDF dots at provincial view -> icons at city view
    }
  } else if (length(lod_zoom) == 1L) {
    z0 <- as.numeric(lod_zoom[1])
    lod_range <- if (z0 <= 0) c(0.0, 0.0) else c(max(0.0, z0 - 1.0), z0 + 0.5)
  } else {
    lod_range <- c(as.numeric(lod_zoom[1]), as.numeric(lod_zoom[2]))
  }

  # Resolve effective default strategy when mode == "auto"
  effective_mode <- mode_str
  if (identical(mode_str, "auto")) {
    if (isTRUE(has_cluster)) {
      effective_mode <- "cluster"
    } else if (isTRUE(has_icons)) {
      effective_mode <- if (n > 2500L) "lod" else "atlas"
    } else {
      effective_mode <- "points"
    }
  }

  list(
    requested_mode = mode_str,
    mode = effective_mode,
    lod_min_zoom = lod_range[1],
    lod_max_zoom = lod_range[2],
    atlas_cell_px = cell_px,
    allow_ui_switcher = allow_ui
  )
}

resolve_icon_spec <- function(icon, data, n) {
  if (is.null(icon) || n == 0L) return(NULL)
  if (inherits(icon, "formula")) {
    icon <- eval_aesthetic(icon, data)
  }
  if (is.character(icon)) {
    icon <- make_icon(iconUrl = icon, iconWidth = 28, iconHeight = 28)
  }
  if (is.list(icon) && !is.null(icon$iconUrl)) {
    urls <- as.character(icon$iconUrl)
    f <- as.factor(urls)
    atlas <- levels(f)
    idx0 <- as.integer(f) - 1L
    return(list(
      type = "url",
      atlas = as.list(atlas),
      indices = if (length(idx0) == 1L) idx0 else as.integer(idx0),
      width = as.numeric(icon$iconWidth[1] %||% 28),
      height = as.numeric(icon$iconHeight[1] %||% 28)
    ))
  }
  if (inherits(icon, c("gl_awesome_icon", "leaflet_awesome_icon")) || (is.list(icon) && identical(icon$type, "awesome"))) {
    return(list(
      type = "awesome",
      text = as.character(icon$text[1] %||% "*"),
      markerColor = as.character(icon$markerColor[1] %||% "#0284c7"),
      iconColor = as.character(icon$iconColor[1] %||% "#ffffff"),
      width = as.numeric(icon$iconWidth[1] %||% 28),
      height = as.numeric(icon$iconHeight[1] %||% 34)
    ))
  }
  NULL
}

#' Add a GPU LineString / MultiLineString Layer
#'
#' @inheritParams add_points
#' @param width Line width in pixels (default `2.0`).
#' @export
add_lines <- function(
    map,
    data = NULL,
    color = "#38bdf8",
    palette = "viridis",
    width = 2.0,
    opacity = 0.85,
    popup = NULL,
    label = NULL,
    id = NULL,
    group = NULL,
    legend = TRUE
) {
  data <- data %||% attr(map$x, "glmap_data")
  if (is.null(data)) cli::cli_abort("`data` must be provided to {.fn add_lines}.")
  if (inherits(data, "SharedData")) data <- data$origData()

  id <- id %||% next_layer_id("lines")
  group <- group %||% id

  n <- if (inherits(data, "sfc")) length(data) else nrow(data)
  col_res <- resolve_rgba(color = color, data = data, n = n, opacity = opacity, palette = palette)
  w_vec <- resolve_numeric_aesthetic(width, data = data, default = 2.0, range_out = c(1, 8))

  raw_buf <- gl_pack_sf_binary(
    data = data,
    rgba = col_res$rgba,
    radius = w_vec
  )

  transport_mode <- if (inherits(map, "glmap_proxy")) "inline" else (map$x$transport %||% "auto")
  buf_spec <- register_binary_buffer(id, raw_buf, mode = transport_mode)
  tooltips <- build_popup_labels(popup, label, data)

  layer_spec <- list(
    id = id,
    group = group,
    type = "lines",
    visible = TRUE,
    opacity = opacity,
    n_features = attr(raw_buf, "n_features"),
    n_vertices = attr(raw_buf, "n_vertices"),
    bbox = attr(raw_buf, "bbox"),
    buffer = buf_spec,
    style = list(
      width = if (length(w_vec) == 1L) w_vec else 2.0
    ),
    tooltips = tooltips
  )

  legend_spec <- if (isTRUE(legend)) col_res$legend else NULL
  if (!is.null(legend_spec)) legend_spec$layer_id <- id

  dispatch_layer(map, layer_spec, legend_spec, attr(raw_buf, "bbox"))
}

#' Add a Pre-Triangulated GPU Polygon / MultiPolygon Layer
#'
#' Triangulates polygons in C++17 (`earcut`) and streams triangle index buffers
#' and ring outlines directly to WebGL2 vertex buffers (zero JS `earcut` overhead).
#'
#' @inheritParams add_points
#' @param fill_color Fill color aesthetic (color string, formula `~col`, or column name).
#' @param fill_opacity Polygon fill opacity (`0` to `1`).
#' @param line_color Border line color string (default `"#ffffff"`).
#' @param line_width Border line width in pixels (default `1.0`).
#' @param extrude Optional 3D extrusion height aesthetic (formula `~height`, column name, or numeric).
#' @export
add_polygons <- function(
    map,
    data = NULL,
    fill_color = "#3b82f6",
    palette = "viridis",
    fill_opacity = 0.7,
    stroke = TRUE,
    line_color = "#e2e8f0",
    line_width = 1.0,
    extrude = NULL,
    popup = NULL,
    label = NULL,
    id = NULL,
    group = NULL,
    legend = TRUE
) {
  data <- data %||% attr(map$x, "glmap_data")
  if (is.null(data)) cli::cli_abort("`data` must be provided to {.fn add_polygons}.")
  if (inherits(data, "SharedData")) data <- data$origData()

  id <- id %||% next_layer_id("polygons")
  group <- group %||% id

  if (inherits(data, c("SpatVector", "Spatial")) && requireNamespace("sf", quietly = TRUE)) {
    data <- sf::st_as_sf(data)
  }
  n <- if (inherits(data, "sfc")) length(data) else nrow(data)
  col_res <- resolve_rgba(color = fill_color, data = data, n = n, opacity = fill_opacity, palette = palette)
  elev_vec <- if (!is.null(extrude)) resolve_numeric_aesthetic(extrude, data = data, default = 0) else numeric(0)

  raw_buf <- gl_pack_sf_binary(
    data = data,
    rgba = col_res$rgba,
    elevation = elev_vec
  )

  transport_mode <- if (inherits(map, "glmap_proxy")) "inline" else (map$x$transport %||% "auto")
  buf_spec <- register_binary_buffer(id, raw_buf, mode = transport_mode)
  line_rgb <- as.integer(grDevices::col2rgb(line_color, alpha = FALSE)[, 1])
  tooltips <- build_popup_labels(popup, label, data)

  layer_spec <- list(
    id = id,
    group = group,
    type = "polygons",
    visible = TRUE,
    opacity = fill_opacity,
    n_features = attr(raw_buf, "n_features"),
    n_vertices = attr(raw_buf, "n_vertices"),
    n_indices = attr(raw_buf, "n_indices"),
    bbox = attr(raw_buf, "bbox"),
    buffer = buf_spec,
    style = list(
      stroke = isTRUE(stroke),
      line_color = line_rgb,
      line_width = as.numeric(line_width),
      extruded = length(elev_vec) > 0L
    ),
    tooltips = tooltips
  )

  legend_spec <- if (isTRUE(legend)) col_res$legend else NULL
  if (!is.null(legend_spec)) legend_spec$layer_id <- id

  dispatch_layer(map, layer_spec, legend_spec, attr(raw_buf, "bbox"))
}

#' Add a GPU Fragment-Shader Raster Layer for `terra::SpatRaster`
#'
#' Streams raw Float32 raster values (`GLMR` binary packet) directly into a
#' WebGL2 `R32F` floating-point texture. Colormapping, hillshading, min/max
#' contrast stretching, thresholding, and live pixel value inspection happen
#' entirely on the GPU in 0 ms without re-rendering PNGs in R.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param raster A `terra::SpatRaster` or numeric `matrix`.
#' @param palette Color palette name (`"viridis"`, `"terrain"`, `"magma"`, `"turbo"`, `"plasma"`, `"RdYlBu"`).
#' @param opacity Raster opacity (`0` to `1`).
#' @param domain Optional numeric `c(min, max)` value range for colormap stretching.
#' @param hillshade Logical; whether to compute real-time GPU surface normal hillshading in the fragment shader.
#' @param max_cells Maximum raster cells before automatic overview aggregation (default `1,000,000`).
#' @param bands Integer band index or indices to stream.
#' @param bbox Bounding box `c(xmin, ymin, xmax, ymax)` when `raster` is a plain matrix.
#' @param id Layer ID string.
#' @param group Layer group name.
#' @param legend Logical; whether to display a color ramp legend and interactive GPU raster controls.
#' @param shader_controls Controls which interactive GPU shader widgets are shown inside the raster
#'   legend card. Pass `TRUE` (default) to show all (`c("palette", "hillshade", "opacity")`),
#'   `FALSE` to hide all interactive shader controls (keeping only the color ramp legend), or a
#'   character vector / named list selecting any subset of `"palette"`, `"hillshade"`, and `"opacity"`.
#' @export
add_raster <- function(
    map,
    raster = NULL,
    palette = "viridis",
    opacity = 0.85,
    domain = NULL,
    hillshade = FALSE,
    max_cells = 1000000L,
    bands = 1L,
    bbox = c(-75, 45, -71, 48),
    id = NULL,
    group = NULL,
    legend = TRUE,
    shader_controls = TRUE
) {
  raster <- raster %||% attr(map$x, "glmap_data")
  if (is.null(raster)) cli::cli_abort("`raster` must be provided to {.fn add_raster}.")

  id <- id %||% next_layer_id("raster")
  group <- group %||% id

  raw_buf <- gl_pack_raster_binary(raster, max_cells = max_cells, bands = bands, bbox = bbox)
  transport_mode <- if (inherits(map, "glmap_proxy")) "inline" else (map$x$transport %||% "auto")
  buf_spec <- register_binary_buffer(id, raw_buf, mode = transport_mode)

  vmin <- attr(raw_buf, "vmin")
  vmax <- attr(raw_buf, "vmax")
  if (!is.null(domain) && length(domain) == 2L && all(is.finite(domain))) {
    vmin <- as.numeric(domain[1])
    vmax <- as.numeric(domain[2])
  }

  pal_hex <- resolve_palette_colors(palette, 256L)
  lut_rgba <- as.integer(grDevices::col2rgb(pal_hex, alpha = TRUE))
  lut_rgb <- as.integer(grDevices::col2rgb(pal_hex, alpha = FALSE))

  ctrl_spec <- resolve_raster_shader_controls(shader_controls)

  layer_spec <- list(
    id = id,
    group = group,
    type = "raster",
    visible = TRUE,
    opacity = opacity,
    width = attr(raw_buf, "width"),
    height = attr(raw_buf, "height"),
    n_bands = attr(raw_buf, "n_bands"),
    bbox = attr(raw_buf, "bbox"),
    vmin = vmin,
    vmax = vmax,
    buffer = buf_spec,
    style = list(
      palette = if (length(palette) == 1L && is.character(palette)) as.character(palette[1]) else "custom",
      lut_rgba = lut_rgba,
      lut_rgb = lut_rgb,
      hillshade = isTRUE(hillshade),
      vmin = vmin,
      vmax = vmax,
      shader_controls = ctrl_spec
    )
  )

  legend_spec <- if (isTRUE(legend)) {
    # Strip trailing alpha from legend CSS gradient stops so the legend bar itself remains readable
    leg_cols <- substr(pal_hex[round(seq(1, 256, length.out = 7))], 1L, 7L)
    list(
      layer_id = id,
      group = group,
      type = "continuous",
      title = group,
      domain = c(vmin, vmax),
      colors = leg_cols,
      is_raster = TRUE,
      shader_controls = ctrl_spec
    )
  } else {
    NULL
  }

  dispatch_layer(map, layer_spec, legend_spec, attr(raw_buf, "bbox"))
}

resolve_raster_shader_controls <- function(shader_controls) {
  if (is.null(shader_controls) || identical(shader_controls, FALSE)) {
    return(list(enabled = FALSE, palette = FALSE, hillshade = FALSE, opacity = FALSE))
  }
  if (isTRUE(shader_controls)) {
    return(list(enabled = TRUE, palette = TRUE, hillshade = TRUE, opacity = TRUE))
  }
  if (is.character(shader_controls)) {
    sc <- tolower(shader_controls)
    return(list(
      enabled = length(sc) > 0L,
      palette = "palette" %in% sc,
      hillshade = "hillshade" %in% sc,
      opacity = "opacity" %in% sc
    ))
  }
  if (is.list(shader_controls)) {
    pal <- isTRUE(shader_controls$palette %||% TRUE)
    hs <- isTRUE(shader_controls$hillshade %||% TRUE)
    op <- isTRUE(shader_controls$opacity %||% TRUE)
    return(list(
      enabled = pal || hs || op,
      palette = pal,
      hillshade = hs,
      opacity = op
    ))
  }
  list(enabled = TRUE, palette = TRUE, hillshade = TRUE, opacity = TRUE)
}

#' Add a C++ Accelerated Hexagonal Binning Layer for 1M+ Points
#'
#' Aggregates millions of points into hexagonal spatial bins in C++17 in milliseconds
#' and renders them on the GPU with color and optional 3D extrusion mapped to count or weight.
#'
#' @inheritParams add_points
#' @param weight Optional numeric column/formula to average inside each hex cell.
#' @param hex_radius Hexagon radius in degrees (default `0.03`).
#' @param extrude Logical; if `TRUE`, extrudes hex bins based on point count.
#' @export
add_hexbin <- function(
    map,
    data = NULL,
    lon = NULL,
    lat = NULL,
    weight = NULL,
    hex_radius = 0.03,
    palette = "plasma",
    opacity = 0.85,
    extrude = FALSE,
    id = NULL,
    group = NULL,
    legend = TRUE
) {
  data <- data %||% attr(map$x, "glmap_data")
  if (is.null(data)) cli::cli_abort("`data` must be provided to {.fn add_hexbin}.")
  if (inherits(data, "SharedData")) data <- data$origData()

  id <- id %||% next_layer_id("hexbin")
  group <- group %||% id

  if (inherits(data, c("sf", "sfc"))) {
    sfc <- if (inherits(data, "sf")) sf::st_geometry(data) else data
    coords <- sf::st_coordinates(sfc)
    x <- coords[, 1]
    y <- coords[, 2]
  } else {
    nms <- names(data)
    if (inherits(lon, "formula")) lon <- rlang::as_name(rlang::f_rhs(lon))
    if (inherits(lat, "formula")) lat <- rlang::as_name(rlang::f_rhs(lat))
    lon <- lon %||% nms[match(TRUE, tolower(nms) %in% c("lon", "lng", "long", "longitude", "x"))]
    lat <- lat %||% nms[match(TRUE, tolower(nms) %in% c("lat", "latitude", "y"))]
    x <- as.numeric(data[[lon]])
    y <- as.numeric(data[[lat]])
  }

  w_vec <- if (!is.null(weight)) as.numeric(eval_aesthetic(weight, data)) else numeric(0)
  bins <- cpp_hexbin_aggregate(x, y, w_vec, as.numeric(hex_radius))

  # Build hexagon polygons around each aggregated center
  angles <- seq(0, 2 * pi, length.out = 7)[1:6] + pi / 6
  dx <- hex_radius * cos(angles)
  dy <- hex_radius * sin(angles)

  n_bins <- length(bins$x)
  sfc_hex <- lapply(seq_len(n_bins), function(i) {
    cx <- bins$x[i]
    cy <- bins$y[i]
    ring <- cbind(c(cx + dx, cx + dx[1]), c(cy + dy, cy + dy[1]))
    structure(list(ring), class = c("XY", "POLYGON", "sfg"))
  })
  class(sfc_hex) <- c("sfc_POLYGON", "sfc")

  metric <- if (length(w_vec) > 0L) bins$mean_weight else as.numeric(bins$count)
  col_res <- resolve_rgba(
    color = metric,
    n = n_bins,
    opacity = opacity,
    palette = palette,
    title = if (length(w_vec) > 0L) "Mean Weight" else "Point Count"
  )

  elev <- if (isTRUE(extrude)) as.numeric(bins$count) else numeric(0)
  raw_buf <- cpp_pack_sfc_binary(sfc_hex, 3L, col_res$rgba, numeric(0), elev)
  hdr <- read_glmp_header(raw_buf)
  transport_mode <- if (inherits(map, "glmap_proxy")) "inline" else (map$x$transport %||% "auto")
  buf_spec <- register_binary_buffer(id, raw_buf, mode = transport_mode)

  tooltips <- sprintf("<b>Count:</b> %d<br/><b>Value:</b> %.2f", bins$count, metric)

  layer_spec <- list(
    id = id,
    group = group,
    type = "polygons",
    visible = TRUE,
    opacity = opacity,
    n_features = hdr$n_features,
    n_vertices = hdr$n_vertices,
    n_indices = hdr$n_indices,
    bbox = hdr$bbox,
    buffer = buf_spec,
    style = list(
      stroke = TRUE,
      line_color = c(15L, 23L, 42L),
      line_width = 0.75,
      extruded = isTRUE(extrude)
    ),
    tooltips = if (n_bins <= 20000L) tooltips else NULL
  )

  legend_spec <- if (isTRUE(legend)) col_res$legend else NULL
  if (!is.null(legend_spec)) legend_spec$layer_id <- id

  dispatch_layer(map, layer_spec, legend_spec, hdr$bbox)
}

#' Add a GPU Additive Kernel Density Heatmap Layer
#'
#' @inheritParams add_points
#' @param weight Optional weight column or formula (`~weight`).
#' @param intensity Numeric intensity multiplier (default `1.0`).
#' @export
add_heatmap <- function(
    map,
    data = NULL,
    lon = NULL,
    lat = NULL,
    weight = NULL,
    radius = 18,
    intensity = 1.0,
    palette = "inferno",
    opacity = 0.8,
    id = NULL,
    group = NULL
) {
  data <- data %||% attr(map$x, "glmap_data")
  if (is.null(data)) cli::cli_abort("`data` must be provided to {.fn add_heatmap}.")
  if (inherits(data, "SharedData")) data <- data$origData()

  id <- id %||% next_layer_id("heatmap")
  group <- group %||% id

  if (inherits(lon, "formula")) lon <- rlang::as_name(rlang::f_rhs(lon))
  if (inherits(lat, "formula")) lat <- rlang::as_name(rlang::f_rhs(lat))

  n <- if (inherits(data, "sfc")) length(data) else nrow(data)
  col_res <- resolve_rgba(color = weight %||% "#ff6b00", data = data, n = n, opacity = opacity, palette = palette)
  rad_vec <- resolve_numeric_aesthetic(radius, data = data, default = 18.0)

  raw_buf <- gl_pack_sf_binary(
    data = data,
    lon = lon,
    lat = lat,
    rgba = col_res$rgba,
    radius = rad_vec
  )

  transport_mode <- if (inherits(map, "glmap_proxy")) "inline" else (map$x$transport %||% "auto")
  buf_spec <- register_binary_buffer(id, raw_buf, mode = transport_mode)

  layer_spec <- list(
    id = id,
    group = group,
    type = "heatmap",
    visible = TRUE,
    opacity = opacity,
    n_features = attr(raw_buf, "n_features"),
    n_vertices = attr(raw_buf, "n_vertices"),
    bbox = attr(raw_buf, "bbox"),
    buffer = buf_spec,
    style = list(
      radius = as.numeric(radius[1]),
      intensity = as.numeric(intensity[1]),
      palette = as.character(palette[1])
    )
  )

  dispatch_layer(map, layer_spec, NULL, attr(raw_buf, "bbox"))
}

#' Add a Cloud-Native PMTiles or Mapbox Vector Tile (MVT) Layer
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param url URL to a `.pmtiles` archive or `{z}/{x}/{y}.pbf` vector tile endpoint.
#' @param source_layer Source layer name inside the vector tiles.
#' @param layer_type MapLibre layer type: `"fill"`, `"line"`, `"circle"`, or `"fill-extrusion"`.
#' @param color Fill/line/circle color.
#' @param opacity Layer opacity.
#' @param id Layer ID.
#' @param group Layer group name.
#' @export
add_pmtiles <- function(
    map,
    url,
    source_layer = "default",
    layer_type = c("fill", "line", "circle", "fill-extrusion"),
    color = "#38bdf8",
    opacity = 0.75,
    id = NULL,
    group = NULL
) {
  layer_type <- match.arg(layer_type)
  id <- id %||% next_layer_id("pmtiles")
  group <- group %||% id

  layer_spec <- list(
    id = id,
    group = group,
    type = "pmtiles",
    visible = TRUE,
    opacity = opacity,
    url = url,
    source_layer = source_layer,
    layer_type = layer_type,
    style = list(color = color, opacity = opacity)
  )
  dispatch_layer(map, layer_spec)
}

#' @rdname add_pmtiles
#' @export
add_mvt <- function(
    map,
    url,
    source_layer = "default",
    layer_type = c("fill", "line", "circle", "fill-extrusion"),
    color = "#38bdf8",
    opacity = 0.75,
    id = NULL,
    group = NULL
) {
  layer_type <- match.arg(layer_type)
  id <- id %||% next_layer_id("mvt")
  group <- group %||% id

  layer_spec <- list(
    id = id,
    group = group,
    type = "mvt",
    visible = TRUE,
    opacity = opacity,
    url = url,
    source_layer = source_layer,
    layer_type = layer_type,
    style = list(color = color, opacity = opacity)
  )
  dispatch_layer(map, layer_spec)
}

#' Add a Raw GeoJSON URL or Object Layer
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param geojson A GeoJSON string, list, or URL.
#' @param color Feature color.
#' @param opacity Feature opacity.
#' @param id Layer ID.
#' @param group Layer group.
#' @export
add_geojson <- function(map, geojson, color = "#22c55e", opacity = 0.75, id = NULL, group = NULL) {
  id <- id %||% next_layer_id("geojson")
  group <- group %||% id
  layer_spec <- list(
    id = id,
    group = group,
    type = "geojson",
    visible = TRUE,
    opacity = opacity,
    geojson = geojson,
    style = list(color = color, opacity = opacity)
  )
  dispatch_layer(map, layer_spec)
}

#' Add a GPU Text / Symbol Label Layer (`add_labels`)
#'
#' Renders crisp halo-outlined text labels anchored to `sf` points, polygon centroids,
#' or `data.frame` coordinates.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param data An `sf`, `sfc`, or `data.frame` object.
#' @param text Formula (`~name`), column name string, or character vector of label texts.
#' @param lon Optional longitude column name or formula (`~lon`).
#' @param lat Optional latitude column name or formula (`~lat`).
#' @param size Font size in pixels (default `12`).
#' @param color Text color (default `"#f8fafc"`).
#' @param halo_color Halo outline color for contrast (default `"#0f172a"`).
#' @param id Layer ID.
#' @param group Layer group name.
#' @export
add_labels <- function(
    map,
    data = NULL,
    text,
    lon = NULL,
    lat = NULL,
    size = 12,
    color = "#f8fafc",
    halo_color = "#0f172a",
    id = NULL,
    group = NULL
) {
  data <- data %||% attr(map$x, "glmap_data")
  if (is.null(data)) cli::cli_abort("`data` must be provided to {.fn add_labels}.")
  if (inherits(data, "SharedData")) data <- data$origData()

  id <- id %||% next_layer_id("labels")
  group <- group %||% id

  labels_vec <- as.character(eval_aesthetic(text, data))

  if (inherits(data, c("sf", "sfc", "SpatVector", "Spatial"))) {
    if (inherits(data, c("SpatVector", "Spatial")) && requireNamespace("sf", quietly = TRUE)) {
      data <- sf::st_as_sf(data)
    }
    sfc <- if (inherits(data, "sf")) sf::st_geometry(data) else data
    pts <- suppressWarnings(sf::st_point_on_surface(sfc))
    coords <- sf::st_coordinates(pts)
    x <- as.numeric(coords[, 1])
    y <- as.numeric(coords[, 2])
  } else {
    nms <- names(data)
    if (inherits(lon, "formula")) lon <- rlang::as_name(rlang::f_rhs(lon))
    if (inherits(lat, "formula")) lat <- rlang::as_name(rlang::f_rhs(lat))
    lon <- lon %||% nms[match(TRUE, tolower(nms) %in% c("lon", "lng", "long", "longitude", "x"))]
    lat <- lat %||% nms[match(TRUE, tolower(nms) %in% c("lat", "latitude", "y"))]
    x <- as.numeric(data[[lon]])
    y <- as.numeric(data[[lat]])
  }

  raw_buf <- cpp_pack_points_xy(x, y, c(255L, 255L, 255L, 255L), as.numeric(size[1]), numeric(0))
  hdr <- read_glmp_header(raw_buf)
  transport_mode <- if (inherits(map, "glmap_proxy")) "inline" else (map$x$transport %||% "auto")
  buf_spec <- register_binary_buffer(id, raw_buf, mode = transport_mode)

  layer_spec <- list(
    id = id,
    group = group,
    type = "labels",
    visible = TRUE,
    opacity = 1.0,
    n_features = hdr$n_features,
    n_vertices = hdr$n_vertices,
    bbox = hdr$bbox,
    buffer = buf_spec,
    labels = labels_vec,
    style = list(
      size = as.numeric(size[1]),
      color = color,
      halo_color = halo_color
    )
  )

  dispatch_layer(map, layer_spec, NULL, hdr$bbox)
}

#' Add a Geodesic Circle Layer (`add_circles`)
#'
#' Drop-in equivalent of `leaflet::addCircles()`. Unlike [add_points()] (where
#' `radius` is in screen pixels), `add_circles()` takes `radius` in **meters**
#' on the ground and builds geodesic polygon rings triangulated in C++17.
#'
#' @inheritParams add_polygons
#' @param lon Optional longitude column name or formula (`~lon`).
#' @param lat Optional latitude column name or formula (`~lat`).
#' @param radius Circle radius in **meters** (single number, formula `~r`, or numeric vector; default `500`).
#' @param n_segments Number of vertices per circle ring (default `24L`).
#' @export
add_circles <- function(
    map,
    data = NULL,
    lon = NULL,
    lat = NULL,
    radius = 500,
    fill_color = "#38bdf8",
    palette = "viridis",
    fill_opacity = 0.65,
    stroke = TRUE,
    line_color = "#e2e8f0",
    line_width = 1.0,
    popup = NULL,
    label = NULL,
    n_segments = 24L,
    id = NULL,
    group = NULL,
    legend = TRUE
) {
  data <- data %||% attr(map$x, "glmap_data")
  if (is.null(data)) cli::cli_abort("`data` must be provided to {.fn add_circles}.")
  if (inherits(data, "SharedData")) data <- data$origData()

  if (inherits(data, c("sf", "sfc", "SpatVector", "Spatial"))) {
    if (inherits(data, c("SpatVector", "Spatial")) && requireNamespace("sf", quietly = TRUE)) {
      data <- sf::st_as_sf(data)
    }
    sfc <- if (inherits(data, "sf")) sf::st_geometry(data) else data
    coords <- sf::st_coordinates(sfc)
    x <- as.numeric(coords[, 1])
    y <- as.numeric(coords[, 2])
  } else {
    nms <- names(data)
    if (inherits(lon, "formula")) lon <- rlang::as_name(rlang::f_rhs(lon))
    if (inherits(lat, "formula")) lat <- rlang::as_name(rlang::f_rhs(lat))
    lon <- lon %||% nms[match(TRUE, tolower(nms) %in% c("lon", "lng", "long", "longitude", "x"))]
    lat <- lat %||% nms[match(TRUE, tolower(nms) %in% c("lat", "latitude", "y"))]
    x <- as.numeric(data[[lon]])
    y <- as.numeric(data[[lat]])
  }

  n <- length(x)
  r_m <- eval_aesthetic(radius, data)
  r_m <- if (length(r_m) == 1L) rep(as.numeric(r_m), n) else as.numeric(r_m)

  angles <- seq(0, 2 * pi, length.out = as.integer(n_segments) + 1L)
  cos_a <- cos(angles)
  sin_a <- sin(angles)

  sfc_circles <- lapply(seq_len(n), function(i) {
    dy <- (r_m[i] / 111320.0) * sin_a
    dx <- (r_m[i] / (111320.0 * pmax(0.1, cos(y[i] * pi / 180.0)))) * cos_a
    ring <- cbind(x[i] + dx, y[i] + dy)
    structure(list(ring), class = c("XY", "POLYGON", "sfg"))
  })
  class(sfc_circles) <- c("sfc_POLYGON", "sfc")

  sf_wrap <- if (is.data.frame(data)) {
    d <- as.data.frame(data)
    d$geometry <- sfc_circles
    structure(d, sf_column = "geometry", class = c("sf", "data.frame"))
  } else {
    sfc_circles
  }

  add_polygons(
    map = map,
    data = sf_wrap,
    fill_color = fill_color,
    palette = palette,
    fill_opacity = fill_opacity,
    stroke = stroke,
    line_color = line_color,
    line_width = line_width,
    popup = popup,
    label = label,
    id = id %||% next_layer_id("circles"),
    group = group,
    legend = legend
  )
}

#' Add a Bounding-Box Rectangle Layer (`add_rectangles`)
#'
#' Drop-in equivalent of `leaflet::addRectangles()`.
#'
#' @inheritParams add_polygons
#' @param lng1,lat1,lng2,lat2 Numeric vectors or formulas specifying opposite corners of each rectangle.
#' @export
add_rectangles <- function(
    map,
    data = NULL,
    lng1,
    lat1,
    lng2,
    lat2,
    fill_color = "#38bdf8",
    palette = "viridis",
    fill_opacity = 0.55,
    stroke = TRUE,
    line_color = "#e2e8f0",
    line_width = 1.5,
    popup = NULL,
    label = NULL,
    id = NULL,
    group = NULL,
    legend = FALSE
) {
  data <- data %||% attr(map$x, "glmap_data")
  x1 <- as.numeric(eval_aesthetic(lng1, data))
  y1 <- as.numeric(eval_aesthetic(lat1, data))
  x2 <- as.numeric(eval_aesthetic(lng2, data))
  y2 <- as.numeric(eval_aesthetic(lat2, data))
  n <- length(x1)

  sfc_rect <- lapply(seq_len(n), function(i) {
    ring <- rbind(
      c(x1[i], y1[i]),
      c(x2[i], y1[i]),
      c(x2[i], y2[i]),
      c(x1[i], y2[i]),
      c(x1[i], y1[i])
    )
    structure(list(ring), class = c("XY", "POLYGON", "sfg"))
  })
  class(sfc_rect) <- c("sfc_POLYGON", "sfc")

  add_polygons(
    map = map,
    data = sfc_rect,
    fill_color = fill_color,
    palette = palette,
    fill_opacity = fill_opacity,
    stroke = stroke,
    line_color = line_color,
    line_width = line_width,
    popup = popup,
    label = label,
    id = id %||% next_layer_id("rectangles"),
    group = group,
    legend = legend
  )
}

#' Add Standalone HTML Popups (`add_popups`)
#'
#' Drop-in equivalent of `leaflet::addPopups()`.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param data Optional `sf` or `data.frame` object.
#' @param lon,lat Longitude and latitude coordinates or formulas (`~lon`, `~lat`).
#' @param popup Character vector or formula (`~html`) of popup HTML content.
#' @param id Layer ID.
#' @param group Layer group name.
#' @export
add_popups <- function(
    map,
    data = NULL,
    lon = NULL,
    lat = NULL,
    popup = NULL,
    id = NULL,
    group = NULL
) {
  add_labels(
    map = map,
    data = data,
    text = popup,
    lon = lon,
    lat = lat,
    id = id %||% next_layer_id("popups"),
    group = group
  )
}

#' Add an OGC Web Map Service (WMS) Raster Tile Layer (`add_wms_tiles`)
#'
#' Drop-in equivalent of `leaflet::addWMSTiles()`. Connects to enterprise OGC
#' WMS endpoints (GeoServer, MapServer, ArcGIS Enterprise, gouvernement du Quebec /
#' MSC GeoMet) using `{bbox-epsg-3857}` tile requests in MapLibre GL.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param base_url Base WMS service URL (e.g., `"https://geo.weather.gc.ca/geomet"`).
#' @param layers Comma-separated WMS layer names (e.g., `"RADAR_1KM_RRAI"`).
#' @param styles Optional WMS styles parameter (default `""`).
#' @param format Image MIME type (default `"image/png"`).
#' @param transparent Logical; whether to request transparent background (default `TRUE`).
#' @param version WMS version (default `"1.1.1"` or `"1.3.0"`).
#' @param tile_size Tile size in pixels (default `256L`).
#' @param opacity Layer opacity (`0` to `1`).
#' @param api_key Optional API key appended to the WMS request URL.
#' @param id Layer ID.
#' @param group Layer group name.
#' @export
add_wms_tiles <- function(
    map,
    base_url,
    layers,
    styles = "",
    format = "image/png",
    transparent = TRUE,
    version = "1.1.1",
    tile_size = 256L,
    opacity = 0.8,
    api_key = NULL,
    id = NULL,
    group = NULL
) {
  id <- id %||% next_layer_id("wms")
  group <- group %||% id

  srs_param <- if (identical(version, "1.3.0")) "CRS=EPSG:3857" else "SRS=EPSG:3857"
  sep <- if (grepl("\\?", base_url)) "&" else "?"
  wms_template <- sprintf(
    "%s%sSERVICE=WMS&VERSION=%s&REQUEST=GetMap&LAYERS=%s&STYLES=%s&FORMAT=%s&TRANSPARENT=%s&%s&WIDTH=%d&HEIGHT=%d&BBOX={bbox-epsg-3857}",
    sub("[?&]$", "", base_url),
    sep,
    version,
    utils::URLencode(as.character(layers[1]), reserved = TRUE),
    utils::URLencode(as.character(styles[1]), reserved = TRUE),
    utils::URLencode(as.character(format[1]), reserved = TRUE),
    if (isTRUE(transparent)) "TRUE" else "FALSE",
    srs_param,
    as.integer(tile_size),
    as.integer(tile_size)
  )
  if (!is.null(api_key) && nzchar(api_key)) {
    wms_template <- inject_url_api_key(wms_template, api_key, "apikey")
  }

  layer_spec <- list(
    id = id,
    group = group,
    type = "wms",
    visible = TRUE,
    opacity = as.numeric(opacity[1]),
    wms_url = wms_template,
    tile_size = as.integer(tile_size)
  )

  dispatch_layer(map, layer_spec)
}
