#' Set Map Camera View (Center, Zoom, Pitch, Bearing)
#'
#' @param map A `gexplore` widget or `gexplore_proxy`.
#' @param lng Longitude of center.
#' @param lat Latitude of center.
#' @param zoom Zoom level (`0` to `22`).
#' @param pitch Pitch tilt in degrees (`0` to `85`).
#' @param bearing Rotation bearing in degrees.
#' @export
set_view <- function(map, lng, lat, zoom = 10, pitch = 0, bearing = 0) {
  if (inherits(map, "gexplore_proxy")) {
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
  if (inherits(map, "gexplore_proxy")) {
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
  if (inherits(map, "gexplore_proxy")) {
    return(invoke_proxy_method(map, "setMaxBounds", list(max_bounds = bbox)))
  }
  map$x$view$max_bounds <- bbox
  map
}

#' Fit Map Camera to a Bounding Box `[xmin, ymin, xmax, ymax]` (`fit_bounds`)
#'
#' @param map A `gexplore` widget or `gexplore_proxy`.
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
  if (inherits(map, "gexplore_proxy")) {
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
  if (inherits(map, "gexplore_proxy")) {
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
  if (inherits(map, "gexplore_proxy")) {
    return(invoke_proxy_method(map, "setBasemap", list(basemap = spec, name = basemap)))
  }
  map$x$basemap <- spec
  map$x$basemap_name <- as.character(basemap[1])
  map
}

#' Enable 3D Terrain Elevation on the Map
#'
#' @param map A `gexplore` widget or `gexplore_proxy`.
#' @param exaggeration Vertical exaggeration factor (default `1.5`).
#' @param source_url Optional Terrarium/Mapbox DEM tile URL.
#' @export
set_terrain <- function(map, exaggeration = 1.5, source_url = NULL) {
  terrain_spec <- list(
    enabled = exaggeration > 0,
    exaggeration = as.numeric(exaggeration),
    source_url = source_url %||% "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
  )
  if (inherits(map, "gexplore_proxy")) {
    return(invoke_proxy_method(map, "setTerrain", terrain_spec))
  }
  map$x$terrain <- terrain_spec
  map
}

#' Set Map Projection (`"mercator"` or `"globe"`)
#'
#' @param map A `gexplore` widget or `gexplore_proxy`.
#' @param projection Either `"mercator"` or `"globe"`.
#' @export
set_projection <- function(map, projection = c("mercator", "globe")) {
  projection <- match.arg(projection)
  if (inherits(map, "gexplore_proxy")) {
    return(invoke_proxy_method(map, "setProjection", list(projection = projection)))
  }
  map$x$view$projection <- projection
  map
}

#' Configure Map UI Controls
#'
#' @param map A `gexplore` widget.
#' @param type Control type (`"navigation"`, `"scale"`, `"fullscreen"`, `"layer_switcher"`, `"hud"`, `"draw"`, `"measure"`).
#' @param enabled Logical; whether the control is enabled.
#' @param position Control corner (`"top-left"`, `"top-right"`, `"bottom-left"`, `"bottom-right"`).
#' @export
add_control <- function(
    map,
    type = c("navigation", "scale", "fullscreen", "layer_switcher", "hud", "draw", "measure"),
    enabled = TRUE,
    position = "top-right"
) {
  type <- match.arg(type)
  map$x$controls[[type]] <- list(enabled = isTRUE(enabled), position = position)
  map
}

#' Add a Custom Map Legend
#'
#' @param map A `gexplore` widget or `gexplore_proxy`.
#' @param title Legend title.
#' @param colors Character vector of hex/CSS colors.
#' @param labels Character vector of category labels (for categorical legends).
#' @param domain Numeric vector `c(min, max)` (for continuous legends).
#' @param layer_id Optional associated layer ID.
#' @export
add_legend <- function(map, title, colors, labels = NULL, domain = NULL, layer_id = NULL) {
  leg <- list(
    layer_id = layer_id %||% next_layer_id("legend"),
    type = if (!is.null(labels)) "categorical" else "continuous",
    title = title,
    colors = as.character(colors),
    labels = if (!is.null(labels)) as.character(labels) else NULL,
    domain = if (!is.null(domain)) as.numeric(domain) else c(0, 1)
  )
  if (inherits(map, "gexplore_proxy")) {
    return(invoke_proxy_method(map, "addLegend", leg))
  }
  map$x$legends[[length(map$x$legends) + 1L]] <- leg
  map
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
#' Useful for stress-testing 100k–1M+ points, polygons, and rasters.
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

#' @rdname gl_save_html
#' @export
gx_save_html <- gl_save_html

#' @rdname gl_benchmark_data
#' @export
gx_benchmark_data <- gl_benchmark_data

