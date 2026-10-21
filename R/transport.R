# Internal environment for storing active binary buffers, spatial indices, and server handle
.gl_env <- new.env(parent = emptyenv())
.gl_env$buffers <- new.env(parent = emptyenv())
.gl_env$meta <- new.env(parent = emptyenv())
.gl_env$indices <- new.env(parent = emptyenv())
.gl_env$plugins <- new.env(parent = emptyenv())
.gl_env$api_keys <- new.env(parent = emptyenv())
.gl_env$server <- NULL
.gl_env$port <- NULL
.gl_env$counter <- 0L

next_layer_id <- function(prefix = "layer") {
  .gl_env$counter <- .gl_env$counter + 1L
  sprintf("%s_%04d", prefix, .gl_env$counter)
}

#' Start the local zero-copy binary & tile server (`gl_serve_start`)
#'
#' Starts a background `httpuv` daemon server on `127.0.0.1` that streams
#' `GLMP` and `GLMR` binary buffers, gzipped payloads, and dynamic spatial
#' viewport slices directly to the browser without JSON serialization.
#'
#' @param port Optional integer port. If `NULL`, a random available port is chosen.
#' @return The local server base URL (e.g., `"http://127.0.0.1:43210"`).
#' @export
gl_serve_start <- function(port = NULL) {
  if (!is.null(.gl_env$server)) {
    return(sprintf("http://127.0.0.1:%d", .gl_env$port))
  }

  if (is.null(port)) {
    port <- httpuv::randomPort()
  }

  cors_headers <- list(
    "Access-Control-Allow-Origin" = "*",
    "Access-Control-Allow-Methods" = "GET, HEAD, OPTIONS",
    "Access-Control-Allow-Headers" = "Range, Content-Type, Accept, Origin",
    "Access-Control-Expose-Headers" = "Content-Length, Content-Range, X-Glmap-Features",
    "Cache-Control" = "no-cache"
  )

  app <- list(
    call = function(req) {
      if (identical(req$REQUEST_METHOD, "OPTIONS")) {
        return(list(status = 204L, headers = cors_headers, body = raw(0)))
      }

      path <- req$PATH_INFO %||% "/"

      # Status check
      if (identical(path, "/status")) {
        ids <- ls(.gl_env$buffers)
        body <- jsonlite::toJSON(list(
          status = "ok",
          port = .gl_env$port,
          buffers = ids,
          n_buffers = length(ids)
        ), auto_unbox = TRUE)
        hdrs <- cors_headers
        hdrs[["Content-Type"]] <- "application/json"
        return(list(status = 200L, headers = hdrs, body = body))
      }

      # Binary buffer fetch: /buffer/<id>
      if (startsWith(path, "/buffer/")) {
        buf_id <- sub("^/buffer/", "", path)
        if (!exists(buf_id, envir = .gl_env$buffers, inherits = FALSE)) {
          return(list(status = 404L, headers = cors_headers, body = "Buffer not found"))
        }
        raw_buf <- get(buf_id, envir = .gl_env$buffers, inherits = FALSE)

        # Support HTTP Range requests (for PMTiles / COG / partial reads)
        range_hdr <- req$HTTP_RANGE
        if (!is.null(range_hdr) && grepl("^bytes=[0-9]+-[0-9]*$", range_hdr)) {
          parts <- strsplit(sub("^bytes=", "", range_hdr), "-")[[1]]
          start_byte <- as.integer(parts[1])
          end_byte <- if (nzchar(parts[2])) as.integer(parts[2]) else (length(raw_buf) - 1L)
          end_byte <- min(end_byte, length(raw_buf) - 1L)
          if (start_byte <= end_byte && start_byte >= 0L) {
            slice <- raw_buf[(start_byte + 1L):(end_byte + 1L)]
            hdrs <- cors_headers
            hdrs[["Content-Type"]] <- "application/octet-stream"
            hdrs[["Accept-Ranges"]] <- "bytes"
            hdrs[["Content-Range"]] <- sprintf("bytes %d-%d/%d", start_byte, end_byte, length(raw_buf))
            hdrs[["Content-Length"]] <- as.character(length(slice))
            return(list(status = 206L, headers = hdrs, body = slice))
          }
        }

        hdrs <- cors_headers
        hdrs[["Content-Type"]] <- "application/octet-stream"
        hdrs[["Accept-Ranges"]] <- "bytes"
        hdrs[["Content-Length"]] <- as.character(length(raw_buf))
        return(list(status = 200L, headers = hdrs, body = raw_buf))
      }

      # Dynamic spatial index viewport query: /viewport/<id>?bbox=xmin,ymin,xmax,ymax&max=50000
      if (startsWith(path, "/viewport/")) {
        idx_id <- sub("^/viewport/", "", path)
        if (!exists(idx_id, envir = .gl_env$indices, inherits = FALSE)) {
          return(list(status = 404L, headers = cors_headers, body = "Spatial index not found"))
        }
        idx_obj <- get(idx_id, envir = .gl_env$indices, inherits = FALSE)
        qs <- req$QUERY_STRING %||% ""
        params <- parse_query_string(qs)
        bbox_str <- params$bbox %||% "-180,-90,180,90"
        bb <- as.numeric(strsplit(bbox_str, ",")[[1]])
        if (length(bb) < 4 || any(is.na(bb))) bb <- c(-180, -90, 180, 90)
        max_f <- as.integer(params$max %||% "100000")

        sub_buf <- gl_slice_indexed_buffer(idx_obj, bb[1], bb[2], bb[3], bb[4], max_f)
        hdrs <- cors_headers
        hdrs[["Content-Type"]] <- "application/octet-stream"
        hdrs[["Content-Length"]] <- as.character(length(sub_buf))
        return(list(status = 200L, headers = hdrs, body = sub_buf))
      }

      list(status = 404L, headers = cors_headers, body = "Not found")
    }
  )

  .gl_env$server <- httpuv::startDaemonizedServer("127.0.0.1", port, app)
  .gl_env$port <- port
  sprintf("http://127.0.0.1:%d", port)
}

#' Stop the local zero-copy binary server (`gl_serve_stop`)
#' @export
gl_serve_stop <- function() {
  if (!is.null(.gl_env$server)) {
    try(httpuv::stopServer(.gl_env$server), silent = TRUE)
    .gl_env$server <- NULL
    .gl_env$port <- NULL
  }
  invisible(TRUE)
}

#' Query status of the local binary server and registered buffers (`gl_server_status`)
#' @export
gl_server_status <- function() {
  ids <- ls(.gl_env$buffers)
  sizes <- vapply(ids, function(id) length(get(id, envir = .gl_env$buffers)), numeric(1))
  list(
    running = !is.null(.gl_env$server),
    port = .gl_env$port,
    url = if (!is.null(.gl_env$port)) sprintf("http://127.0.0.1:%d", .gl_env$port) else NULL,
    n_buffers = length(ids),
    total_mb = sum(sizes) / (1024^2),
    buffers = stats::setNames(as.list(sizes), ids)
  )
}

register_binary_buffer <- function(id, raw_buf, mode = c("auto", "inline", "server")) {
  mode <- match.arg(mode)
  assign(id, raw_buf, envir = .gl_env$buffers)

  # Choose transport:
  # - "inline": gzip + base64 embedded in widget payload (works offline, in standalone HTML, RMarkdown, Quarto)
  # - "server": streamed over localhost httpuv (zero base64 overhead in interactive sessions for giant buffers)
  # - "auto": inline gzip+base64 up to 25 MB raw (so saveWidget & static viewers always work seamlessly),
  #           also registers on local httpuv server if active
  use_server <- identical(mode, "server")
  if (use_server) {
    base_url <- gl_serve_start()
    return(list(
      mode = "server",
      id = id,
      url = sprintf("%s/buffer/%s", base_url, id),
      byte_length = length(raw_buf)
    ))
  }

  # Compress with gzip in memory if buffer > 64 KB for 3x-5x smaller HTML & faster transfer
  if (length(raw_buf) > 65536L) {
    compressed <- memCompress(raw_buf, type = "gzip")
    list(
      mode = "inline_gzip",
      id = id,
      data = base64enc::base64encode(compressed),
      byte_length = length(raw_buf),
      compressed_length = length(compressed)
    )
  } else {
    list(
      mode = "inline_raw",
      id = id,
      data = base64enc::base64encode(raw_buf),
      byte_length = length(raw_buf)
    )
  }
}

parse_query_string <- function(qs) {
  qs <- sub("^\\?", "", qs)
  if (!nzchar(qs)) return(list())
  parts <- strsplit(qs, "&", fixed = TRUE)[[1]]
  out <- list()
  for (p in parts) {
    kv <- strsplit(p, "=", fixed = TRUE)[[1]]
    if (length(kv) >= 2) {
      out[[utils::URLdecode(kv[1])]] <- utils::URLdecode(paste(kv[-1], collapse = "="))
    }
  }
  out
}

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Pack an sf, sfc, or data.frame object into a GLMP binary buffer (`gl_pack_sf_binary`)
#'
#' @param data An `sf`, `sfc`, or `data.frame` object.
#' @param lon Column name for longitude when `data` is a `data.frame`.
#' @param lat Column name for latitude when `data` is a `data.frame`.
#' @param rgba Integer vector of RGBA bytes (length 4 for constant color or `4 * nrow(data)`).
#' @param radius Numeric vector of radii (length 0, 1, or `nrow(data)`).
#' @param elevation Numeric vector of extrusion heights (length 0, 1, or `nrow(data)`).
#' @return A `raw` vector in `GLMP` binary format with attribute `"bbox"` and `"geom_type"`.
#' @export
gl_pack_sf_binary <- function(
    data,
    lon = NULL,
    lat = NULL,
    rgba = c(30L, 144L, 255L, 210L),
    radius = numeric(0),
    elevation = numeric(0)
) {
  rgba <- as.integer(rgba)
  radius <- as.numeric(radius)
  elevation <- as.numeric(elevation)

  # Fast path 0a: wk::xy / wk_rcrd point vectors (zero-copy direct double arrays)
  if (inherits(data, "wk_xy")) {
    un <- unclass(data)
    raw_buf <- cpp_pack_points_xy(as.numeric(un$x), as.numeric(un$y), rgba, radius, elevation)
    hdr <- read_glmp_header(raw_buf)
    attr(raw_buf, "bbox") <- hdr$bbox
    attr(raw_buf, "geom_type") <- "POINT"
    attr(raw_buf, "n_features") <- hdr$n_features
    attr(raw_buf, "n_vertices") <- hdr$n_vertices
    return(raw_buf)
  }

  # Fast path 0b: nanoarrow_array / nanoarrow_array_stream (GeoArrow / Arrow tabular or point struct)
  if (inherits(data, c("nanoarrow_array", "nanoarrow_array_stream")) && requireNamespace("nanoarrow", quietly = TRUE)) {
    df_conv <- tryCatch(as.data.frame(data), error = function(e) NULL)
    if (!is.null(df_conv) && is.data.frame(df_conv)) {
      return(gl_pack_sf_binary(df_conv, lon = lon, lat = lat, rgba = rgba, radius = radius, elevation = elevation))
    }
  }

  # Fast path 0c: wk::wkb / wk::wkt vectors
  if (inherits(data, c("wk_wkb", "wk_wkt")) && requireNamespace("wk", quietly = TRUE)) {
    coords_df <- wk::wk_coords(data)
    if (length(unique(coords_df$feature_id)) == nrow(coords_df)) {
      raw_buf <- cpp_pack_points_xy(as.numeric(coords_df$x), as.numeric(coords_df$y), rgba, radius, elevation)
      hdr <- read_glmp_header(raw_buf)
      attr(raw_buf, "bbox") <- hdr$bbox
      attr(raw_buf, "geom_type") <- "POINT"
      attr(raw_buf, "n_features") <- hdr$n_features
      attr(raw_buf, "n_vertices") <- hdr$n_vertices
      return(raw_buf)
    } else if (requireNamespace("sf", quietly = TRUE)) {
      data <- sf::st_as_sfc(data)
    }
  }

  # Fast path 0d: terra::SpatVector or legacy sp::Spatial* objects
  if (inherits(data, "SpatVector") && requireNamespace("sf", quietly = TRUE)) {
    data <- sf::st_as_sf(data)
  } else if (inherits(data, "Spatial") && requireNamespace("sf", quietly = TRUE)) {
    data <- sf::st_as_sf(data)
  } else if (inherits(data, "sfg") && requireNamespace("sf", quietly = TRUE)) {
    data <- sf::st_sfc(data)
  }

  # Fast path 1: data.frame / tibble / data.table with numeric lon/lat columns or embedded wk_xy column
  if (!inherits(data, c("sf", "sfc")) && is.data.frame(data)) {
    # Check if data.frame has a wk_xy / sfc geometry column
    for (col_nm in names(data)) {
      if (inherits(data[[col_nm]], "wk_xy")) {
        return(gl_pack_sf_binary(data[[col_nm]], rgba = rgba, radius = radius, elevation = elevation))
      }
      if (inherits(data[[col_nm]], "sfc")) {
        return(gl_pack_sf_binary(data[[col_nm]], rgba = rgba, radius = radius, elevation = elevation))
      }
    }
    if (is.null(lon) || is.null(lat)) {
      nms <- names(data)
      lon <- lon %||% nms[match(TRUE, tolower(nms) %in% c("lon", "lng", "long", "longitude", "x"))]
      lat <- lat %||% nms[match(TRUE, tolower(nms) %in% c("lat", "latitude", "y"))]
      if (is.na(lon) || is.na(lat)) {
        cli::cli_abort("Could not auto-detect `lon` and `lat` columns in `data.frame`. Please supply `lon` and `lat`.")
      }
    }
    x <- as.numeric(data[[lon]])
    y <- as.numeric(data[[lat]])
    raw_buf <- cpp_pack_points_xy(x, y, rgba, radius, elevation)
    hdr <- read_glmp_header(raw_buf)
    attr(raw_buf, "bbox") <- hdr$bbox
    attr(raw_buf, "geom_type") <- "POINT"
    attr(raw_buf, "n_features") <- hdr$n_features
    attr(raw_buf, "n_vertices") <- hdr$n_vertices
    return(raw_buf)
  }

  # Path 2: sf or sfc object
  sfc <- if (inherits(data, "sf")) sf::st_geometry(data) else data
  if (!inherits(sfc, "sfc")) {
    cli::cli_abort("`data` must be an {.cls sf}, {.cls sfc}, or {.cls data.frame} object.")
  }

  # Transform to EPSG:4326 if CRS is projected and valid
  if (requireNamespace("sf", quietly = TRUE)) {
    is_ll <- tryCatch(sf::st_is_longlat(sfc), error = function(e) NA)
    if (identical(is_ll, FALSE)) {
      sfc <- tryCatch(sf::st_transform(sfc, 4326), error = function(e) sfc)
    }
  }

  cls <- class(sfc)[1]
  geom_type_int <- if (grepl("POINT", cls, fixed = TRUE)) {
    1L
  } else if (grepl("LINE", cls, fixed = TRUE)) {
    2L
  } else if (grepl("POLYGON", cls, fixed = TRUE)) {
    3L
  } else {
    # Mixed GEOMETRY: inspect first element
    if (length(sfc) > 0) {
      c1 <- class(sfc[[1]])[2] %||% ""
      if (grepl("POINT", c1)) 1L else if (grepl("LINE", c1)) 2L else 3L
    } else {
      1L
    }
  }

  raw_buf <- cpp_pack_sfc_binary(sfc, geom_type_int, rgba, radius, elevation)
  hdr <- read_glmp_header(raw_buf)
  attr(raw_buf, "bbox") <- hdr$bbox
  attr(raw_buf, "geom_type") <- c("POINT", "LINESTRING", "POLYGON")[geom_type_int]
  attr(raw_buf, "n_features") <- hdr$n_features
  attr(raw_buf, "n_vertices") <- hdr$n_vertices
  attr(raw_buf, "n_indices") <- hdr$n_indices
  raw_buf
}

#' Pack a terra SpatRaster or matrix into a GLMR Float32 binary buffer (`gl_pack_raster_binary`)
#'
#' @param raster A `terra::SpatRaster` object, or a numeric `matrix`.
#' @param max_cells Maximum number of cells to stream (downsamples overview if exceeded).
#' @param bands Integer vector of band indices to include (default `1L`).
#' @param bbox Numeric vector `c(xmin, ymin, xmax, ymax)` when `raster` is a matrix.
#' @return A `raw` vector in `GLMR` Float32 binary format with metadata attributes.
#' @export
gl_pack_raster_binary <- function(
    raster,
    max_cells = 1000000L,
    bands = 1L,
    bbox = c(-75, 45, -71, 48)
) {
  if (inherits(raster, c("RasterLayer", "RasterStack", "RasterBrick")) && requireNamespace("terra", quietly = TRUE)) {
    raster <- terra::rast(raster)
  } else if (inherits(raster, "stars") && requireNamespace("terra", quietly = TRUE)) {
    raster <- terra::rast(raster)
  }

  if (inherits(raster, "SpatRaster")) {
    if (!requireNamespace("terra", quietly = TRUE)) {
      cli::cli_abort("Package {.pkg terra} is required to pack {.cls SpatRaster} objects.")
    }
    r <- raster[[bands]]
    ncell_total <- terra::ncell(r)
    if (ncell_total > max_cells) {
      fact <- ceiling(sqrt(ncell_total / max_cells))
      if (fact > 1L) {
        r <- terra::aggregate(r, fact = fact, fun = "mean", na.rm = TRUE)
      }
    }
    crs <- terra::crs(r)
    if (nzchar(crs) && !terra::is.lonlat(r)) {
      r <- terra::project(r, "EPSG:4326")
    }
    width <- terra::ncol(r)
    height <- terra::nrow(r)
    n_bands <- terra::nlyr(r)
    ext <- as.vector(terra::ext(r)) # xmin, xmax, ymin, ymax
    bb <- c(unname(ext[1]), unname(ext[3]), unname(ext[2]), unname(ext[4]))
    vals <- as.numeric(terra::values(r, mat = FALSE))
  } else if (is.matrix(raster) || (is.numeric(raster) && length(dim(raster)) == 2L)) {
    raster <- as.matrix(raster)
    height <- nrow(raster)
    width <- ncol(raster)
    n_bands <- 1L
    bb <- as.numeric(bbox)
    # Row-major top-to-bottom order matching terra::values
    vals <- as.numeric(t(raster))
  } else {
    cli::cli_abort("`raster` must be a {.cls SpatRaster} or numeric {.cls matrix}.")
  }

  nodata <- -999999.0
  raw_buf <- cpp_pack_raster_float32(vals, as.integer(width), as.integer(height), as.integer(n_bands), bb, nodata)
  hdr <- read_glmr_header(raw_buf)
  attr(raw_buf, "bbox") <- hdr$bbox
  attr(raw_buf, "width") <- hdr$width
  attr(raw_buf, "height") <- hdr$height
  attr(raw_buf, "n_bands") <- hdr$n_bands
  attr(raw_buf, "vmin") <- hdr$vmin
  attr(raw_buf, "vmax") <- hdr$vmax
  raw_buf
}

read_glmp_header <- function(raw_buf) {
  con <- rawConnection(raw_buf[1:48], "rb")
  on.exit(close(con), add = TRUE)
  magic <- rawToChar(readBin(con, "raw", 4))
  version <- readBin(con, "integer", 1, size = 2, signed = FALSE, endian = "little")
  geom_type <- readBin(con, "integer", 1, size = 2, signed = FALSE, endian = "little")
  ints <- readBin(con, "integer", 6, size = 4, endian = "little")
  bbox <- readBin(con, "numeric", 4, size = 4, endian = "little")
  list(
    magic = magic,
    version = version,
    geom_type = geom_type,
    n_features = ints[1],
    n_vertices = ints[2],
    n_indices = ints[3],
    n_ring_starts = ints[4],
    has_radius = ints[5],
    has_elevation = ints[6],
    bbox = bbox
  )
}

read_glmr_header <- function(raw_buf) {
  con <- rawConnection(raw_buf[1:48], "rb")
  on.exit(close(con), add = TRUE)
  magic <- rawToChar(readBin(con, "raw", 4))
  version <- readBin(con, "integer", 1, size = 2, signed = FALSE, endian = "little")
  n_bands <- readBin(con, "integer", 1, size = 2, signed = FALSE, endian = "little")
  dims <- readBin(con, "integer", 2, size = 4, endian = "little")
  floats <- readBin(con, "numeric", 7, size = 4, endian = "little")
  list(
    magic = magic,
    version = version,
    n_bands = n_bands,
    width = dims[1],
    height = dims[2],
    bbox = floats[1:4],
    vmin = floats[5],
    vmax = floats[6],
    nodata = floats[7]
  )
}

#' Build an in-memory C++ spatial index for fast viewport queries (`gl_spatial_index`)
#'
#' @param data An `sf`, `sfc`, or `data.frame` with `x`/`y` or `lon`/`lat`.
#' @param grid_res Grid resolution along each axis (default `64L`, i.e. 4,096 spatial buckets).
#' @param lon Optional longitude column name for `data.frame`.
#' @param lat Optional latitude column name for `data.frame`.
#' @return A `gl_spatial_index` object holding the C++ external pointer and dataset reference.
#' @export
gl_spatial_index <- function(data, grid_res = 64L, lon = NULL, lat = NULL) {
  if (is.data.frame(data) && !inherits(data, "sf")) {
    nms <- names(data)
    lon <- lon %||% nms[match(TRUE, tolower(nms) %in% c("lon", "lng", "long", "longitude", "x"))]
    lat <- lat %||% nms[match(TRUE, tolower(nms) %in% c("lat", "latitude", "y"))]
    x <- as.numeric(data[[lon]])
    y <- as.numeric(data[[lat]])
    ptr <- cpp_build_spatial_index(x, y, x, y, as.integer(grid_res))
    idx_obj <- structure(
      list(
        ptr = ptr,
        type = "points_df",
        x = x,
        y = y,
        n = length(x),
        bbox = c(min(x, na.rm = TRUE), min(y, na.rm = TRUE), max(x, na.rm = TRUE), max(y, na.rm = TRUE))
      ),
      class = "gl_spatial_index"
    )
    return(idx_obj)
  }

  sfc <- if (inherits(data, "sf")) sf::st_geometry(data) else data
  if (inherits(sfc[[1]], "POINT")) {
    coords <- sf::st_coordinates(sfc)
    x <- coords[, 1]
    y <- coords[, 2]
    ptr <- cpp_build_spatial_index(x, y, x, y, as.integer(grid_res))
  } else {
    bbs <- vapply(sfc, function(g) as.numeric(sf::st_bbox(g)), numeric(4))
    ptr <- cpp_build_spatial_index(bbs[1, ], bbs[2, ], bbs[3, ], bbs[4, ], as.integer(grid_res))
  }

  bb <- as.numeric(sf::st_bbox(sfc))
  structure(
    list(
      ptr = ptr,
      type = "sfc",
      sfc = sfc,
      n = length(sfc),
      bbox = bb
    ),
    class = "gl_spatial_index"
  )
}

#' Query a spatial index for features intersecting a bounding box (`gl_query_index`)
#'
#' @param index A `gl_spatial_index` object created by [gl_spatial_index()].
#' @param bbox Numeric vector `c(xmin, ymin, xmax, ymax)`.
#' @param max_features Optional cap on returned features (uses deterministic stride LOD sampling).
#' @return Integer vector of 1-based feature indices.
#' @export
gl_query_index <- function(index, bbox, max_features = 0L) {
  if (!inherits(index, "gl_spatial_index")) {
    cli::cli_abort("`index` must be a {.cls gl_spatial_index} object.")
  }
  cpp_query_spatial_index(
    index$ptr,
    as.numeric(bbox[1]),
    as.numeric(bbox[2]),
    as.numeric(bbox[3]),
    as.numeric(bbox[4]),
    as.integer(max_features)
  )
}

gl_slice_indexed_buffer <- function(idx_obj, xmin, ymin, xmax, ymax, max_features = 100000L) {
  if (inherits(idx_obj, "gl_duckdb_index") || identical(idx_obj$type, "duckdb")) {
    return(query_duckdb_slice(idx_obj, xmin, ymin, xmax, ymax, max_features = as.integer(max_features))$raw_buf)
  }
  hits <- cpp_query_spatial_index(idx_obj$ptr, xmin, ymin, xmax, ymax, as.integer(max_features))
  if (identical(idx_obj$type, "points_df")) {
    if (length(hits) == 0L) {
      return(cpp_pack_points_xy(numeric(0), numeric(0), c(30L, 144L, 255L, 200L), numeric(0), numeric(0)))
    }
    rgba <- idx_obj$rgba %||% c(30L, 144L, 255L, 200L)
    if (length(rgba) == 4L * idx_obj$n) {
      idx4 <- as.vector(outer(0:3, (hits - 1L) * 4L + 1L, `+`))
      rgba <- rgba[idx4]
    }
    rad <- idx_obj$radius %||% numeric(0)
    if (length(rad) == idx_obj$n) rad <- rad[hits]
    return(cpp_pack_points_xy(idx_obj$x[hits], idx_obj$y[hits], rgba, rad, numeric(0)))
  }
  gl_pack_sf_binary(idx_obj$sfc[hits], rgba = idx_obj$rgba %||% c(30L, 144L, 255L, 200L))
}





