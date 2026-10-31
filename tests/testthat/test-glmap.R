test_that("C++17 binary point packer packs 1,000,000 points in sub-second time", {
  n <- 1000000L
  df <- data.frame(
    lon = seq(-75, -71, length.out = n),
    lat = seq(45, 47, length.out = n)
  )

  t0 <- proc.time()[["elapsed"]]
  raw_buf <- gl_pack_sf_binary(df, lon = "lon", lat = "lat", rgba = c(0L, 212L, 255L, 200L), radius = 4)
  elapsed <- proc.time()[["elapsed"]] - t0

  expect_type(raw_buf, "raw")
  # 48 header + 8M coords + 4M feat_ids + 4M rgba + 4M radius = 20,000,048 bytes
  expect_equal(length(raw_buf), 48L + n * (8L + 4L + 4L + 4L))
  expect_equal(attr(raw_buf, "n_features"), n)
  expect_equal(attr(raw_buf, "n_vertices"), n)
  expect_equal(attr(raw_buf, "geom_type"), "POINT")
  expect_lt(elapsed, 1.5)
})

test_that("C++17 earcut polygon triangulation and sfc binary packing works accurately", {
  skip_if_not_installed("sf")
  bench <- gl_benchmark_data(n_points = 100L, n_polygons = 500L)
  poly_sf <- bench$polygons_sf

  raw_buf <- gl_pack_sf_binary(poly_sf)
  expect_type(raw_buf, "raw")
  expect_equal(attr(raw_buf, "geom_type"), "POLYGON")
  expect_equal(attr(raw_buf, "n_features"), 500L)
  # Each 6-vertex hexagon produces 4 triangles = 12 indices
  expect_equal(attr(raw_buf, "n_indices"), 500L * 12L)
})

test_that("C++17 Float32 raster binary packing works for terra SpatRaster and matrix", {
  mat <- matrix(seq(10, 500, length.out = 100 * 120), nrow = 100, ncol = 120)
  mat[1:5, 1:5] <- NA_real_

  raw_buf <- gl_pack_raster_binary(mat, bbox = c(-74, 45, -72, 46))
  expect_type(raw_buf, "raw")
  expect_equal(attr(raw_buf, "width"), 120L)
  expect_equal(attr(raw_buf, "height"), 100L)
  expect_equal(length(raw_buf), 48L + 100L * 120L * 4L)
  expect_gt(attr(raw_buf, "vmax"), 490)

  if (requireNamespace("terra", quietly = TRUE)) {
    r <- terra::rast(nrows = 60, ncols = 80, xmin = -74, xmax = -72, ymin = 45, ymax = 46, vals = runif(4800, 0, 100))
    rbuf <- gl_pack_raster_binary(r)
    expect_equal(attr(rbuf, "width"), 80L)
    expect_equal(attr(rbuf, "height"), 60L)
  }
})

test_that("C++17 spatial index builds and queries 250k points with LOD sampling", {
  n <- 250000L
  df <- data.frame(
    lon = seq(-75, -70, length.out = n),
    lat = seq(45, 50, length.out = n)
  )
  idx <- gl_spatial_index(df)
  expect_s3_class(idx, "gl_spatial_index")

  hits_all <- gl_query_index(idx, c(-73, 47, -72, 48))
  expect_gt(length(hits_all), 40000L)

  hits_lod <- gl_query_index(idx, c(-73, 47, -72, 48), max_features = 5000L)
  expect_equal(length(hits_lod), 5000L)
})

test_that("Pipeable R API, formula aesthetics, scales, and layers construct valid widget", {
  bench <- gl_benchmark_data(n_points = 5000L, n_polygons = 200L, raster_dim = c(80L, 80L))

  m <- glmap(basemap = "dark") |>
    add_raster(bench$raster_mat, palette = "terrain", hillshade = TRUE, id = "dem") |>
    add_polygons(bench$polygons_sf, fill_color = ~elevation, palette = "viridis", id = "polys") |>
    add_points(bench$points_df, color = ~intensity, radius = ~intensity, palette = "plasma", id = "pts") |>
    add_hexbin(bench$points_df, hex_radius = 0.05, id = "hex") |>
    add_heatmap(bench$points_df, radius = 15, id = "heat") |>
    set_view(-73.56, 45.50, zoom = 8) |>
    use_plugin("measure") |>
    use_plugin("export_png")

  expect_s3_class(m, "glmap")
  expect_s3_class(m, "htmlwidget")
  expect_length(m$x$layers, 5L)
  expect_gte(length(m$x$legends), 3L)
  expect_length(m$x$plugins, 2L)

  # Layer manipulation helpers
  m2 <- set_layer_visibility(m, "heat", FALSE)
  expect_false(m2$x$layers[[5]]$visible)

  m3 <- set_raster_style(m2, "dem", palette = "magma", domain = c(0, 500), hillshade = FALSE)
  expect_equal(m3$x$layers[[1]]$style$palette, "magma")

  m4 <- clear_layer(m3, "hex")
  expect_length(m4$x$layers, 4L)
})

test_that("Local httpuv zero-copy binary server serves full and HTTP Range requests", {
  raw_buf <- gl_pack_sf_binary(
    data.frame(lon = c(-73.5, -73.6), lat = c(45.5, 45.6))
  )
  spec <- glmap:::register_binary_buffer("test_srv_buf", raw_buf, mode = "server")
  expect_equal(spec$mode, "server")
  expect_match(spec$url, "^http://127\\.0\\.0\\.1:[0-9]+/buffer/test_srv_buf$")

  st <- gl_server_status()
  expect_true(st$running)
  expect_true("test_srv_buf" %in% names(st$buffers))

  gl_serve_stop()
  expect_false(gl_server_status()$running)
})

test_that("Shiny proxy and custom plugin registration work seamlessly", {
  register_plugin(
    name = "custom_banner",
    js_init = "function(inst, cfg) { inst._customBanner = cfg.label; }",
    default_config = list(label = "Hello GPU")
  )
  expect_true("custom_banner" %in% list_plugins())

  proxy <- glmap_proxy("my_map") |>
    fly_to(-73.56, 45.50, zoom = 11) |>
    set_raster_style("dem", palette = "turbo", hillshade = TRUE) |>
    clear_layer("old_layer") |>
    use_plugin("custom_banner", config = list(label = "Updated"))

  expect_s3_class(proxy, "glmap_proxy")
  expect_length(proxy$calls, 4L)
  expect_equal(proxy$calls[[1]]$method, "flyTo")
  expect_equal(proxy$calls[[2]]$method, "setRasterStyle")
  expect_equal(proxy$calls[[3]]$method, "clearLayer")
  expect_equal(proxy$calls[[4]]$method, "usePlugin")
})

test_that("wk::xy, wk::wkb, and nanoarrow GeoArrow inputs pack directly into GLMP binary buffers", {
  if (requireNamespace("wk", quietly = TRUE)) {
    pts_wk <- wk::xy(c(-73.5, -73.6, -73.7), c(45.5, 45.6, 45.7))
    buf_wk <- gl_pack_sf_binary(pts_wk)
    expect_type(buf_wk, "raw")
    expect_equal(attr(buf_wk, "n_features"), 3L)
    expect_equal(attr(buf_wk, "geom_type"), "POINT")

    wkb_pts <- wk::as_wkb(pts_wk)
    buf_wkb <- gl_pack_sf_binary(wkb_pts)
    expect_equal(attr(buf_wkb, "n_features"), 3L)
  }

  if (requireNamespace("nanoarrow", quietly = TRUE)) {
    arr <- nanoarrow::as_nanoarrow_array(data.frame(lon = c(-73.5, -73.6), lat = c(45.5, 45.6)))
    buf_na <- gl_pack_sf_binary(arr)
    expect_type(buf_na, "raw")
    expect_equal(attr(buf_na, "n_features"), 2L)
  }
})

test_that("DuckDB out-of-core spatial viewport pushdown and SQL filtering work seamlessly", {
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit({
    gl_serve_stop()
    DBI::dbDisconnect(con, shutdown = TRUE)
  }, add = TRUE)

  df <- data.frame(
    lon = seq(-74, -71, length.out = 50000L),
    lat = seq(45, 47, length.out = 50000L),
    intensity = seq(1, 100, length.out = 50000L)
  )
  DBI::dbWriteTable(con, "sensors", df, overwrite = TRUE)

  m <- glmap(basemap = "dark") |>
    add_duckdb(
      con = con,
      source = "sensors",
      lon = "lon",
      lat = "lat",
      color = ~intensity,
      where = "intensity >= 50",
      max_features = 10000L,
      id = "duck_pts"
    )

  expect_s3_class(m, "glmap")
  expect_equal(m$x$layers[[1]]$total_duckdb_rows, sum(df$intensity >= 50))
  expect_equal(m$x$layers[[1]]$n_features, 10000L)
  expect_match(m$x$layers[[1]]$viewport_url, "^http://127\\.0\\.0\\.1:[0-9]+/viewport/duck_pts$")

  # Test viewport slice directly
  idx_obj <- get("duck_pts", envir = glmap:::.gl_env$indices)
  slice_buf <- glmap:::gl_slice_indexed_buffer(idx_obj, -72.5, 46.0, -71.5, 46.8, max_features = 5000L)
  expect_type(slice_buf, "raw")
  expect_gt(attr(slice_buf, "n_features"), 1000L)
  expect_lte(attr(slice_buf, "n_features"), 5000L)
})

test_that("terra::SpatVector and terra::SpatRaster objects are supported directly", {
  if (requireNamespace("terra", quietly = TRUE)) {
    v <- terra::vect(cbind(c(-73.5, -73.6), c(45.5, 45.6)), type = "points", crs = "EPSG:4326")
    m_v <- glmap(v)
    expect_s3_class(m_v, "glmap")
    buf_v <- gl_pack_sf_binary(v)
    expect_equal(attr(buf_v, "n_features"), 2L)

    rl <- terra::rast(nrows = 20, ncols = 20, xmin = -74, xmax = -72, ymin = 45, ymax = 46, vals = runif(400, 10, 100))
    buf_rl <- gl_pack_raster_binary(rl)
    expect_equal(attr(buf_rl, "width"), 20L)
  }
})

test_that("GLMap/earstrip.hpp in C++17 accurately triangulates complex polygons with interior holes and self-intersections", {
  skip_if_not_installed("sf")

  # 1. Outer square with an interior square hole
  outer_ring <- rbind(c(-74, 45), c(-70, 45), c(-70, 49), c(-74, 49), c(-74, 45))
  hole_ring  <- rbind(c(-73, 46), c(-73, 48), c(-71, 48), c(-71, 46), c(-73, 46))
  poly_with_hole <- sf::st_polygon(list(outer_ring, hole_ring))
  sfc_donut <- sf::st_sfc(poly_with_hole, crs = 4326)
  sf_donut <- sf::st_sf(id = 1L, height = 120.0, geometry = sfc_donut)

  raw_buf <- gl_pack_sf_binary(sf_donut, elevation = 120.0)
  expect_type(raw_buf, "raw")
  expect_equal(attr(raw_buf, "n_features"), 1L)
  expect_gte(attr(raw_buf, "n_indices"), 24L)

  # 2. Self-intersecting bowtie / figure-8 polygon (handled by earstrip CDT fallback with Steiner point)
  bowtie_ring <- rbind(c(-74, 45), c(-70, 49), c(-70, 45), c(-74, 49), c(-74, 45))
  sfc_bowtie <- sf::st_sfc(sf::st_polygon(list(bowtie_ring)), crs = 4326)
  raw_bowtie <- gl_pack_sf_binary(sfc_bowtie)
  expect_type(raw_bowtie, "raw")
  expect_gte(attr(raw_bowtie, "n_indices"), 6L)
  # Verify Steiner points are isolated in ring_starts so border strokes never connect across the polygon
  n_verts_bt <- readBin(raw_bowtie[13:16], "integer", n = 1, size = 4)
  n_rings_bt <- readBin(raw_bowtie[21:24], "integer", n = 1, size = 4)
  off_bt <- 48L + n_verts_bt * 8L + n_verts_bt * 4L
  rs_bt <- readBin(raw_bowtie[(off_bt + 1L):(off_bt + n_rings_bt * 4L)], "integer", n = n_rings_bt, size = 4L)
  expect_equal(rs_bt[1], 0L)
  expect_equal(rs_bt[2], 5L) # Original 5-vertex ring closes cleanly before any Steiner point
})

test_that("add_labels, 3D polygon extrusion, categorical color scales, and camera controls work", {
  df <- data.frame(
    lon = c(-73.56, -71.20, -72.54),
    lat = c(45.50, 46.81, 46.34),
    city = c("Montreal", "Quebec", "Trois-Rivieres"),
    region = factor(c("West", "East", "Center"))
  )

  bench <- gl_benchmark_data(n_points = 50L, n_polygons = 20L)

  m <- glmap(basemap = "positron", projection = "globe") |>
    add_polygons(bench$polygons_sf, fill_color = ~elevation, extrude = ~elevation, id = "poly3d") |>
    add_points(df, color = ~region, radius = 6, popup = ~city, id = "cities") |>
    add_labels(df, text = ~city, size = 13, id = "city_labels") |>
    set_terrain(exaggeration = 1.5) |>
    set_projection("mercator") |>
    fit_bounds(c(-74.5, 45.0, -70.5, 47.2))

  expect_s3_class(m, "glmap")
  expect_s3_class(m, "glmap")
  expect_length(m$x$layers, 3L)
  expect_true(m$x$layers[[1]]$style$extruded)
  expect_equal(m$x$layers[[3]]$type, "labels")
  expect_equal(m$x$layers[[3]]$labels, c("Montreal", "Quebec", "Trois-Rivieres"))
  expect_equal(m$x$legends[[2]]$type, "categorical")
  expect_true(m$x$terrain$enabled)
})

test_that("gl_providers catalog and add_provider_tiles work across Vector GL and XYZ Raster sources", {
  provs <- gl_list_providers()
  expect_s3_class(provs, "data.frame")
  expect_gte(nrow(provs), 40L)

  m1 <- glmap() |> add_provider_tiles(gl_providers$Esri.WorldImagery)
  expect_equal(m1$x$basemap_name, "Esri.WorldImagery")
  expect_equal(m1$x$basemap$type, "raster")
  expect_false(m1$x$basemap$api_key_configured)

  m2 <- glmap() |> add_provider_tiles(gl_providers$OpenFreeMap.Liberty)
  expect_equal(m2$x$basemap$type, "vector_gl")

  m3 <- glmap() |> add_provider_tiles("https://tile.openstreetmap.org/{z}/{x}/{y}.png")
  expect_equal(m3$x$basemap$type, "raster")

  # Test optional API key injection on CartoDB (both style_url and fallback raster tiles)
  m_carto_key <- glmap(basemap = gl_providers$CartoDB.DarkMatter, api_key = "my_carto_key_123")
  expect_true(m_carto_key$x$basemap$api_key_configured)
  expect_match(m_carto_key$x$basemap$style_url, "\\?key=my_carto_key_123$")
  expect_match(m_carto_key$x$basemap$tiles[1], "\\?key=my_carto_key_123$")

  # Test gl_set_api_key / gl_get_api_key global registry and URL {apikey} placeholder replacement
  gl_set_api_key("maptiler", "mt_secret_999")
  on.exit(gl_set_api_key("maptiler", NULL), add = TRUE)
  expect_equal(gl_get_api_key("MapTiler.DatavizDark"), "mt_secret_999")

  m_mt <- glmap() |> add_provider_tiles(gl_providers$MapTiler.DatavizDark)
  expect_true(m_mt$x$basemap$api_key_configured)
  expect_equal(m_mt$x$basemap$style_url, "https://api.maptiler.com/maps/dataviz-dark/style.json?key=mt_secret_999")

  # Test custom URL with {apikey} placeholder when key is provided vs omitted
  m_cust_key <- glmap() |> add_provider_tiles("https://tiles.example.com/{z}/{x}/{y}.png?apikey={apikey}", api_key = "abc")
  expect_equal(m_cust_key$x$basemap$tiles[1], "https://tiles.example.com/{z}/{x}/{y}.png?apikey=abc")

  m_cust_nokey <- glmap() |> add_provider_tiles("https://tiles.example.com/{z}/{x}/{y}.png?apikey={apikey}")
  expect_equal(m_cust_nokey$x$basemap$tiles[1], "https://tiles.example.com/{z}/{x}/{y}.png")
})

test_that("Superuser leaflet parity functions (add_circles, add_rectangles, add_popups, add_wms_tiles, group controls) work", {
  df <- data.frame(
    lon = c(-73.56, -71.20),
    lat = c(45.50, 46.81),
    name = c("Montreal", "Quebec"),
    rad_m = c(5000, 8000)
  )

  m <- glmap(df) |>
    add_wms_tiles("https://geo.weather.gc.ca/geomet", layers = "RADAR_1KM_RRAI", group = "Weather") |>
    add_rectangles(lng1 = -74, lat1 = 45, lng2 = -71, lat2 = 47, group = "Bounds") |>
    add_circles(radius = ~rad_m, fill_color = "#38bdf8", group = "Buffers") |>
    add_popups(popup = ~name, group = "Labels") |>
    set_max_bounds(c(-80, 40, -60, 55)) |>
    fly_to_bounds(c(-74, 45, -71, 47))

  expect_s3_class(m, "glmap")
  expect_length(m$x$layers, 4L)
  expect_equal(m$x$layers[[1]]$type, "wms")
  expect_match(m$x$layers[[1]]$wms_url, "BBOX=\\{bbox-epsg-3857\\}")

  # Test group controls on widget
  m_hid <- hide_group(m, c("Weather", "Buffers"))
  expect_false(m_hid$x$layers[[1]]$visible)
  expect_false(m_hid$x$layers[[3]]$visible)

  m_shw <- show_group(m_hid, "Weather")
  expect_true(m_shw$x$layers[[1]]$visible)

  m_clr <- clear_group(m_shw, "Bounds")
  expect_length(m_clr$x$layers, 3L)

  # Test group controls on glmap_proxy
  prx <- glmap_proxy("map") |>
    hide_group("Weather") |>
    show_group("Weather") |>
    clear_group("Bounds") |>
    fly_to_bounds(c(-74, 45, -71, 47)) |>
    set_max_bounds(c(-80, 40, -60, 55))

  expect_length(prx$calls, 5L)
  expect_equal(prx$calls[[1]]$method, "setGroupVisibility")
  expect_equal(prx$calls[[3]]$method, "clearGroup")
  expect_equal(prx$calls[[4]]$method, "flyToBounds")

  # Test gl_popup_table and gl_bbox_to_wkt helpers
  tbl_html <- gl_popup_table(df, zcol = c("name", "rad_m"))
  expect_length(tbl_html, 2L)
  expect_match(tbl_html[1], "<table")
  expect_match(tbl_html[1], "Montreal")

  wkt_str <- gl_bbox_to_wkt(c(-74, 45, -71, 47))
  expect_match(wkt_str, "^POLYGON \\(\\(-74\\.000000 45\\.000000")

  # Test add_draw_toolbar and remove_draw_toolbar (leaflet.extras parity)
  m_draw <- glmap() |>
    add_draw_toolbar(
      position = "bottomleft",
      polylineOptions = FALSE,
      circleMarkerOptions = FALSE,
      markerOptions = FALSE,
      toolbar = draw_toolbar_options(
        buttons = list(
          polygon = "Draw polygon AOI",
          rectangle = "Draw rectangle AOI",
          circle = "Draw circle AOI"
        )
      )
    )
  expect_true(m_draw$x$draw_toolbar$enabled)
  expect_equal(m_draw$x$draw_toolbar$position, "bottom-left")
  expect_true(m_draw$x$draw_toolbar$tools$polygon)
  expect_true(m_draw$x$draw_toolbar$tools$rectangle)
  expect_true(m_draw$x$draw_toolbar$tools$circle)
  expect_false(m_draw$x$draw_toolbar$tools$polyline)
  expect_false(m_draw$x$draw_toolbar$tools$marker)

  m_nodraw <- remove_draw_toolbar(m_draw, clearFeatures = TRUE)
  expect_null(m_nodraw$x$draw_toolbar)

  # Test all 3 GPU icon/marker rendering strategies (atlas, cluster, lod) + dynamic defaults
  df_small <- data.frame(lon = runif(500, -74, -71), lat = runif(500, 45, 47), icon_url = rep(c("a.svg", "b.svg"), 250))
  m_small <- glmap(df_small) |> add_markers(lng = ~lon, lat = ~lat, icon = ~icon_url, id = "small_icons")
  expect_equal(m_small$x$layers[[1]]$style$render$mode, "atlas")
  expect_equal(m_small$x$layers[[1]]$style$render$lod_max_zoom, 0)

  df_large <- data.frame(lon = runif(5000, -74, -71), lat = runif(5000, 45, 47), icon_url = rep(c("a.svg", "b.svg"), 2500))
  m_large <- glmap(df_large) |> add_markers(lng = ~lon, lat = ~lat, icon = ~icon_url, id = "large_icons")
  expect_equal(m_large$x$layers[[1]]$style$render$mode, "lod")
  expect_equal(m_large$x$layers[[1]]$style$render$lod_min_zoom, 8.5)
  expect_equal(m_large$x$layers[[1]]$style$render$lod_max_zoom, 10.5)

  m_clust <- glmap(df_large) |>
    add_markers(lng = ~lon, lat = ~lat, icon = ~icon_url, clusterOptions = marker_cluster_options(), id = "clust_icons")
  expect_equal(m_clust$x$layers[[1]]$style$render$mode, "cluster")
  expect_true(m_clust$x$layers[[1]]$style$cluster$enabled)

  m_sw <- set_marker_mode(m_clust, "clust_icons", mode = "lod", lod_zoom = c(9, 11))
  expect_equal(m_sw$x$layers[[1]]$style$render$mode, "lod")
  expect_equal(m_sw$x$layers[[1]]$style$render$lod_min_zoom, 9)

  # Test add_measure and add_search_osm (leaflet + leaflet.extras parity)
  m_meas <- glmap() |>
    add_measure(position = "bottomright", primaryLengthUnit = "meters", primaryAreaUnit = "sqmeters") |>
    add_search_osm(options = search_options(autoCollapse = FALSE))
  expect_true(m_meas$x$controls$measure$enabled)
  expect_equal(m_meas$x$controls$measure$position, "bottom-right")
  expect_true(m_meas$x$controls$search$enabled)
  expect_equal(m_meas$x$controls$search$position, "top-left")
  expect_null(m_meas$x$controls$toolbar)

  # Test add_legend opacity_slider option
  m_leg <- glmap() |>
    add_legend(
      title = "Concentration",
      colors = c("#eef9ea", "#26004e"),
      labels = c("Low", "High"),
      group = "Concentration & Perils"
    )
  expect_true(m_leg$x$legends[[1]]$opacity_slider)
})

test_that("Full drop-in camelCase leaflet & leaflet.extras compatibility API works end-to-end", {
  df <- data.frame(
    long = c(-73.56, -71.20, -72.54, -71.89),
    lat = c(45.50, 46.81, 46.34, 45.40),
    mag = c(4.1, 5.2, 4.7, 5.8),
    group = c("A", "B", "A", "B"),
    zip = c("H1A", "G1R", "G9A", "J1H"),
    stringsAsFactors = FALSE
  )

  pal_num <- colorNumeric("viridis", domain = df$mag)
  pal_bin <- colorBin("YlOrRd", domain = df$mag, bins = c(4, 4.5, 5.0, 6.0))
  pal_qnt <- colorQuantile("Blues", domain = df$mag, n = 2)
  pal_fac <- colorFactor(c("#22c55e", "#ef4444"), domain = df$group)

  expect_length(pal_num(df$mag), 4L)
  expect_length(pal_bin(df$mag), 4L)
  expect_length(pal_qnt(df$mag), 4L)
  expect_equal(pal_fac(c("A", "B")), c("#22c55e", "#ef4444"))

  lf_fmt <- labelFormat(prefix = "$", suffix = "k")
  expect_equal(lf_fmt("numeric", c(10, 20)), c("$10k", "$20k"))

  ic_set <- iconList(
    A = makeIcon("a.png", iconWidth = 24, iconHeight = 24),
    B = makeIcon("b.png", iconWidth = 32, iconHeight = 32)
  )
  sub_ic <- ic_set[df$group]
  expect_s3_class(sub_ic, "gl_icon")
  expect_equal(sub_ic$iconUrl, c("a.png", "b.png", "a.png", "b.png"))

  aw_ic <- awesomeIcons(icon = "ios-close", markerColor = c("green", "red", "green", "orange"))
  expect_s3_class(aw_ic, "gl_awesome_icon")

  outline <- df[chull(df$long, df$lat), ]

  m_compat <- leaflet(df) %>%
    addTiles(group = "OSM") %>%
    addProviderTiles(providers$CartoDB.Positron, group = "Positron") %>%
    setView(lng = -72.5, lat = 46.0, zoom = 7) %>%
    fitBounds(~min(long), ~min(lat), ~max(long), ~max(lat)) %>%
    addCircles(
      ~long, ~lat, ~10^mag / 5,
      layerId = ~zip,
      fillColor = ~pal_bin(mag),
      group = "Circles"
    ) %>%
    addCircleMarkers(
      ~long, ~lat,
      radius = 6,
      color = ~pal_fac(group),
      label = ~zip,
      labelOptions = labelOptions(noHide = TRUE, textsize = "13px"),
      group = "Markers"
    ) %>%
    addAwesomeMarkers(~long, ~lat, icon = aw_ic, group = "Awesome") %>%
    addPolygons(
      data = outline,
      lng = ~long, lat = ~lat,
      fill = FALSE,
      weight = 2,
      color = "#facc15",
      highlightOptions = highlightOptions(weight = 4, color = "#ffffff", bringToFront = TRUE),
      group = "Hull"
    ) %>%
    addSimpleGraticule(interval = 20) %>%
    addTerminator() %>%
    addMiniMap(width = 120, height = 120, position = "bottomright") %>%
    addLegend("bottomright", pal = pal_bin, values = ~mag, title = "Magnitude") %>%
    addLayersControl(
      baseGroups = c("OSM", "Positron"),
      overlayGroups = c("Circles", "Markers", "Awesome", "Hull"),
      options = layersControlOptions(collapsed = FALSE)
    )

  expect_s3_class(m_compat, "glmap")
  expect_true(m_compat$x$controls$minimap$enabled)
  expect_false(m_compat$x$controls$layer_switcher$collapsed)
  expect_equal(m_compat$x$layers[[1]]$feature_ids, df$zip)
  expect_false(m_compat$x$layers[[5]]$style$fill)
  expect_true(m_compat$x$layers[[5]]$style$highlight$enabled)

  # Proxy clearShapes / clearMarkers / clearControls
  prx <- leafletProxy("map", data = df) %>%
    clearShapes() %>%
    clearMarkers() %>%
    clearControls() %>%
    removeShape("H1A")
  expect_s3_class(prx, "glmap_proxy")
  expect_equal(prx$calls[[1]]$method, "clearShapes")
  expect_equal(prx$calls[[2]]$method, "clearMarkers")
  expect_equal(prx$calls[[3]]$method, "clearControls")
  expect_equal(prx$calls[[4]]$method, "clearLayer")

  # Verify popup vs label separation on polygons and points, and scalar popup recycling
  poly_sf <- gl_benchmark_data(n_points = 10L, n_polygons = 5L)$polygons_sf
  poly_sf$hover_txt <- paste0("Hover #", seq_len(nrow(poly_sf)))
  poly_sf$click_txt <- paste0("Click #", seq_len(nrow(poly_sf)))
  m_pop <- glmap(poly_sf) |>
    add_polygons(label = ~hover_txt, popup = ~click_txt, id = "poly_pop") |>
    add_polygons(label = ~hover_txt, popup = "Static Popup", id = "poly_static")
  expect_equal(m_pop$x$layers[[1]]$tooltips, poly_sf$hover_txt)
  expect_equal(m_pop$x$layers[[1]]$popups, poly_sf$click_txt)
  expect_equal(m_pop$x$layers[[2]]$popups, rep("Static Popup", nrow(poly_sf)))

  # Verify unminified source is retained in js-src/ while htmlwidgets/ serves the minified binding
  src_js <- system.file("js-src", "glmap.js", package = "glmap")
  min_js <- system.file("htmlwidgets", "glmap.js", package = "glmap")
  expect_true(nzchar(src_js) && file.exists(src_js))
  expect_true(nzchar(min_js) && file.exists(min_js))
  expect_lt(file.info(min_js)$size, file.info(src_js)$size * 0.70)
  min_code <- paste(readLines(min_js, warn = FALSE), collapse = "\n")
  expect_match(min_code, "GLMapInstance")
  expect_match(min_code, "clearGroup")
  expect_match(min_code, "setGroupVisibility")
})




