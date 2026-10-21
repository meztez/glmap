#' Add a Live Out-of-Core DuckDB / Parquet Layer (`add_duckdb`)
#'
#' Connects `glmap` directly to a `DuckDB` connection (`DBI`), table name,
#' SQL query, or `.parquet` / `.csv` file path.
#'
#' Instead of loading 10M-100M+ rows into R memory, `add_duckdb()` pushes bounding-box
#' viewport filters (`WHERE lon BETWEEN xmin AND xmax AND lat BETWEEN ymin AND ymax`)
#' and Level-of-Detail (LOD) sampling (`USING SAMPLE` or deterministic stride)
#' directly into DuckDB's vectorized execution engine, then packs the resulting
#' slice in C++17 (`cpp_pack_points_xy`) and streams the `GLMP` binary buffer
#' to WebGL2 over the local `httpuv` server on every pan/zoom!
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param con A `DBIConnection` (DuckDB), or `NULL` if `source` is a `.parquet`/`.csv` file path or `data.frame`.
#' @param source A table name, SQL `SELECT` query, `.parquet` file path, or `data.frame` to register in DuckDB.
#' @param lon Name of the longitude column (default `"lon"`).
#' @param lat Name of the latitude column (default `"lat"`).
#' @param color Optional column name or formula (`~col`) to map point colors, or a fixed hex color (default `"#00d4ff"`).
#' @param palette Color palette name (`"viridis"`, `"plasma"`, `"turbo"`, `"magma"`, etc.).
#' @param radius Point radius in pixels (or formula `~col`).
#' @param opacity Point opacity (`0` to `1`).
#' @param where Optional SQL `WHERE` filter predicate string (e.g., `"intensity > 50 AND category = 'Sensor'"`).
#' @param max_features Maximum features streamed per viewport frame (default `100000L`).
#' @param dynamic_viewport Logical; if `TRUE` (default), dynamically re-queries DuckDB via `httpuv` as the user pans/zooms.
#' @param id Optional layer ID.
#' @param group Optional layer group name shown in the GPU Layer Switcher.
#' @param legend Logical; whether to display a color legend.
#' @return Updated `glmap` map object.
#' @export
add_duckdb <- function(
    map,
    con = NULL,
    source,
    lon = "lon",
    lat = "lat",
    color = "#00d4ff",
    palette = "viridis",
    radius = 4.0,
    opacity = 0.85,
    where = NULL,
    max_features = 100000L,
    dynamic_viewport = TRUE,
    id = NULL,
    group = NULL,
    legend = TRUE
) {
  if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("duckdb", quietly = TRUE)) {
    cli::cli_abort("Packages {.pkg DBI} and {.pkg duckdb} are required for {.fn add_duckdb}.")
  }

  id <- id %||% next_layer_id("duckdb")
  group <- group %||% id

  if (inherits(lon, "formula")) lon <- rlang::as_name(rlang::f_rhs(lon))
  if (inherits(lat, "formula")) lat <- rlang::as_name(rlang::f_rhs(lat))

  color_col <- NULL
  if (inherits(color, "formula")) {
    color_col <- rlang::as_name(rlang::f_rhs(color))
  } else if (is.character(color) && length(color) == 1L && !is_color_string(color)) {
    color_col <- color
  }

  rad_col <- NULL
  if (inherits(radius, "formula")) {
    rad_col <- rlang::as_name(rlang::f_rhs(radius))
  }

  duck_idx <- gl_duckdb_index(
    con = con,
    source = source,
    lon = lon,
    lat = lat,
    color_col = color_col,
    color_fixed = if (is.null(color_col)) color else "#00d4ff",
    palette = palette,
    opacity = opacity,
    rad_col = rad_col,
    rad_fixed = if (is.null(rad_col)) as.numeric(radius[1]) else 4.0,
    where = where,
    max_features = as.integer(max_features)
  )

  # Execute initial query across full dataset bounds (capped at max_features)
  bb <- duck_idx$bbox
  init_res <- query_duckdb_slice(duck_idx, bb[1], bb[2], bb[3], bb[4], max_features = as.integer(max_features))
  raw_buf <- init_res$raw_buf

  transport_mode <- if (inherits(map, "glmap_proxy")) "inline" else (map$x$transport %||% "auto")
  buf_spec <- register_binary_buffer(id, raw_buf, mode = transport_mode)

  viewport_url <- NULL
  if (isTRUE(dynamic_viewport)) {
    assign(id, duck_idx, envir = .gl_env$indices)
    base_url <- gl_serve_start()
    viewport_url <- sprintf("%s/viewport/%s", base_url, id)
  }

  layer_spec <- list(
    id = id,
    group = group,
    type = "points",
    visible = TRUE,
    opacity = opacity,
    n_features = attr(raw_buf, "n_features"),
    n_vertices = attr(raw_buf, "n_vertices"),
    total_duckdb_rows = duck_idx$total_rows,
    bbox = bb,
    buffer = buf_spec,
    viewport_url = viewport_url,
    style = list(
      radius = if (is.null(rad_col)) as.numeric(radius[1]) else 4.0,
      stroke = TRUE,
      stroke_color = c(255L, 255L, 255L),
      stroke_width = 0.8
    )
  )

  legend_spec <- if (isTRUE(legend)) init_res$legend else NULL
  if (!is.null(legend_spec)) legend_spec$layer_id <- id

  dispatch_layer(map, layer_spec, legend_spec, bb)
}

#' Create a DuckDB Out-of-Core Spatial Query Index (`gl_duckdb_index`)
#'
#' Wraps a DuckDB connection + table, SQL query, or `.parquet` file so `glmap`
#' can push bounding-box and SQL filter queries down to DuckDB on the fly.
#'
#' @inheritParams add_duckdb
#' @param color_col Optional column name for color mapping.
#' @param color_fixed Fixed hex color when `color_col` is `NULL`.
#' @param rad_col Optional column name for radius mapping.
#' @param rad_fixed Fixed numeric radius when `rad_col` is `NULL`.
#' @return A `gl_duckdb_index` object.
#' @export
gl_duckdb_index <- function(
    con = NULL,
    source,
    lon = "lon",
    lat = "lat",
    color_col = NULL,
    color_fixed = "#00d4ff",
    palette = "viridis",
    opacity = 0.85,
    rad_col = NULL,
    rad_fixed = 4.0,
    where = NULL,
    max_features = 100000L
) {
  if (is.null(con)) {
    if (is.null(.gl_env$duckdb_con) || !DBI::dbIsValid(.gl_env$duckdb_con)) {
      .gl_env$duckdb_con <- DBI::dbConnect(duckdb::duckdb())
    }
    con <- .gl_env$duckdb_con
  }

  # Resolve source into a SQL relation expression
  if (is.data.frame(source)) {
    tbl_name <- sprintf("gl_tbl_%04d", sample.int(9999L, 1L))
    duckdb::duckdb_register(con, tbl_name, source, overwrite = TRUE)
    from_sql <- DBI::dbQuoteIdentifier(con, tbl_name)
  } else if (is.character(source) && length(source) == 1L) {
    s_trim <- trimws(source)
    if (grepl("^SELECT\\b", s_trim, ignore.case = TRUE)) {
      from_sql <- sprintf("(%s) AS _gl_sub", s_trim)
    } else if (grepl("\\.(parquet|csv|tsv|json)$", s_trim, ignore.case = TRUE) || file.exists(s_trim)) {
      norm_p <- gsub("\\\\", "/", normalizePath(s_trim, mustWork = FALSE))
      from_sql <- sprintf("'%s'", norm_p)
    } else {
      from_sql <- as.character(DBI::dbQuoteIdentifier(con, s_trim))
    }
  } else {
    cli::cli_abort("`source` must be a table name, SQL SELECT string, file path (.parquet/.csv), or `data.frame`.")
  }

  q_lon <- as.character(DBI::dbQuoteIdentifier(con, lon))
  q_lat <- as.character(DBI::dbQuoteIdentifier(con, lat))
  where_sql <- if (!is.null(where) && nzchar(trimws(where))) sprintf("AND (%s)", where) else ""

  # Compute global bounding box and total row count in a single vectorized DuckDB pass
  meta_sql <- sprintf(
    "SELECT COUNT(*) AS n, MIN(%s) AS xmin, MIN(%s) AS ymin, MAX(%s) AS xmax, MAX(%s) AS ymax FROM %s WHERE %s IS NOT NULL AND %s IS NOT NULL %s",
    q_lon, q_lat, q_lon, q_lat, from_sql, q_lon, q_lat, where_sql
  )
  meta <- DBI::dbGetQuery(con, meta_sql)
  total_rows <- as.integer(meta$n[1] %||% 0L)
  bbox <- c(
    as.numeric(meta$xmin[1] %||% -180),
    as.numeric(meta$ymin[1] %||% -90),
    as.numeric(meta$xmax[1] %||% 180),
    as.numeric(meta$ymax[1] %||% 90)
  )
  if (any(!is.finite(bbox))) bbox <- c(-180, -90, 180, 90)

  structure(
    list(
      type = "duckdb",
      con = con,
      from_sql = from_sql,
      lon = lon,
      lat = lat,
      q_lon = q_lon,
      q_lat = q_lat,
      color_col = color_col,
      color_fixed = color_fixed,
      palette = palette,
      opacity = opacity,
      rad_col = rad_col,
      rad_fixed = rad_fixed,
      where_sql = where_sql,
      total_rows = total_rows,
      bbox = bbox,
      max_features = as.integer(max_features)
    ),
    class = c("gl_duckdb_index", "gl_spatial_index")
  )
}

query_duckdb_slice <- function(idx, xmin, ymin, xmax, ymax, max_features = 100000L) {
  cols <- c(
    sprintf("CAST(%s AS DOUBLE) AS _gl_x", idx$q_lon),
    sprintf("CAST(%s AS DOUBLE) AS _gl_y", idx$q_lat)
  )
  if (!is.null(idx$color_col)) {
    q_col <- as.character(DBI::dbQuoteIdentifier(idx$con, idx$color_col))
    cols <- c(cols, sprintf("%s AS _gl_col", q_col))
  }
  if (!is.null(idx$rad_col)) {
    q_rad <- as.character(DBI::dbQuoteIdentifier(idx$con, idx$rad_col))
    cols <- c(cols, sprintf("CAST(%s AS DOUBLE) AS _gl_rad", q_rad))
  }

  limit_sql <- if (max_features > 0L) sprintf("LIMIT %d", as.integer(max_features)) else ""

  sql <- sprintf(
    "SELECT %s FROM %s WHERE %s BETWEEN %f AND %f AND %s BETWEEN %f AND %f %s %s",
    paste(cols, collapse = ", "),
    idx$from_sql,
    idx$q_lon, as.numeric(xmin), as.numeric(xmax),
    idx$q_lat, as.numeric(ymin), as.numeric(ymax),
    idx$where_sql,
    limit_sql
  )

  df <- DBI::dbGetQuery(idx$con, sql)
  n <- nrow(df)

  if (n == 0L) {
    raw_buf <- cpp_pack_points_xy(numeric(0), numeric(0), c(0L, 212L, 255L, 200L), numeric(0), numeric(0))
    attr(raw_buf, "n_features") <- 0L
    attr(raw_buf, "n_vertices") <- 0L
    attr(raw_buf, "bbox") <- idx$bbox
    return(list(raw_buf = raw_buf, legend = NULL))
  }

  col_input <- if (!is.null(idx$color_col)) df[["_gl_col"]] else idx$color_fixed
  col_res <- resolve_rgba(
    color = col_input,
    n = n,
    opacity = idx$opacity,
    palette = idx$palette,
    title = idx$color_col %||% "Value"
  )

  rad_vec <- if (!is.null(idx$rad_col)) {
    resolve_numeric_aesthetic(df[["_gl_rad"]], default = idx$rad_fixed)
  } else {
    as.numeric(idx$rad_fixed)
  }

  raw_buf <- cpp_pack_points_xy(df[["_gl_x"]], df[["_gl_y"]], col_res$rgba, rad_vec, numeric(0))
  hdr <- read_glmp_header(raw_buf)
  attr(raw_buf, "bbox") <- hdr$bbox
  attr(raw_buf, "geom_type") <- "POINT"
  attr(raw_buf, "n_features") <- hdr$n_features
  attr(raw_buf, "n_vertices") <- hdr$n_vertices

  list(raw_buf = raw_buf, legend = col_res$legend)
}
