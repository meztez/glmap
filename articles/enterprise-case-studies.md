# Enterprise Case Studies: Upgrading Actuarial & Geospatial Platforms to glmap

## Overview

🌱 ELI5 (Real-World Impact in Production Apps)  
When an insurance or environmental team builds a big Shiny dashboard
with `leaflet`, they quickly hit a wall:

- They have to cap policies on the map at 5,000 or 10,000 dots
  (`max_markers`) because drawing all 200,000 policies crashes the
  browser.
- They have to load 4 different helper packages (`leaflet`, `leafem`,
  `leaflet.extras`, `leafpop`) and write custom JavaScript workarounds
  just to make polygons and popups work.

With **`glmap`**, one package replaces all four. Underwriters and
actuaries can see **every single policy, claim, flood zone, building
footprint, and rainfall grid at once**, draw a box around any
neighborhood, and get instant Total Insured Value (TIV) exposure!

⚙️ Technical Mode (Enterprise Architecture Transformation)  
In production R + Shiny deployments (`Geonesis` catastrophe exposure and
`Terrascope` S3 asset lifecycle management), `Leaflet.js` forces
developers to either cap Snowflake queries (`LIMIT max_markers` +
[`markerClusterOptions()`](https://rstudio.github.io/leaflet/reference/map-options.html))
or write custom `session$registerDataObj()` + `geojson-vt` workarounds.
Replacing the rendering tier with `glmap` eliminates 4 package
dependencies (`leaflet`, `leafem`, `leaflet.extras`, `leafpop`), cuts R
worker CPU blocking by **15x–40x**, and connects directly to Snowflake /
DuckDB Spatial via
[`gl_bbox_to_wkt()`](https://meztez.github.io/glmap/reference/gl_bbox_to_wkt.md)
and
[`gl_popup_table()`](https://meztez.github.io/glmap/reference/gl_popup_table.md).

------------------------------------------------------------------------

## Case Study 1: Catastrophe & Underwriting Exposure Platform (`Geonesis`)

### Before (`leaflet` + `leafem` + `leaflet.extras` + `leafpop`)

In the legacy `leaflet` architecture, the application had to: 1. Import
4 separate mapping packages and manually concatenate `?key=...` onto
CARTO tile URLs. 2. Cap policy (`ALL_RISKS_GEO`) and claim
(`ALL_CLAIMS_GEO`) queries with `max_markers` and group them into DOM
marker clusters
([`markerClusterOptions()`](https://rstudio.github.io/leaflet/reference/map-options.html)),
hiding true spatial TIV concentration until max zoom. 3. Convert `terra`
rainfall rasters to custom RGB hex vectors
([`grDevices::col2rgb`](https://rdrr.io/r/grDevices/col2rgb.html)) on
the R CPU. 4. Serialize entire `flood_zones.geojson` and
`perimeters.geojson` layers over the Shiny WebSocket on toggle.

### After (`glmap` GPU Edition)

1.  **Single-Call API Key Setup**:

    ``` r

    library(glmap)
    gl_set_api_key("carto", Sys.getenv("CARTO_API_KEY"))
    ```

2.  **Full-Portfolio GPU Rendering + C++17 Hexagonal TIV Accumulation**:
    Instead of hiding policies behind DOM marker clusters, `glmap`
    renders both a C++17 hexagonal TIV accumulation surface
    (`add_hexbin(weight = ~TOTAL_INSURED_VALUE)`) and the individual
    instanced GPU policy points
    ([`add_points()`](https://meztez.github.io/glmap/reference/add_points.md))
    at 60 FPS:

    ``` r

    glmap_proxy("geonesis") |>
      clear_group(c("Risks", "Claims", "TIV Hexbins")) |>
      add_hexbin(
        risks_df, lon = "LONGITUDE", lat = "LATITUDE",
        weight = ~TOTAL_INSURED_VALUE, hex_radius = 0.04,
        palette = "plasma", group = "TIV Hexbins"
      ) |>
      add_points(
        risks_df, lon = "LONGITUDE", lat = "LATITUDE",
        color = ~TOTAL_INSURED_VALUE, palette = "viridis",
        radius = 3.0, group = "Risks"
      ) |>
      add_points(
        claims_df, lon = "LONGITUDE", lat = "LATITUDE",
        color = "#f97316", radius = 5.0,
        popup = gl_popup_table(claims_df, zcol = 1:6),
        group = "Claims"
      )
    ```

3.  **Direct Box-Brush to Snowflake / DuckDB Spatial `WKT`
    ([`gl_bbox_to_wkt()`](https://meztez.github.io/glmap/reference/gl_bbox_to_wkt.md))**:
    When an underwriter drags a selection box using `glmap`’s built-in
    **Box Brush** tool, `input$geonesis_selected` emits both the brushed
    feature indices and a ready-to-bind `EPSG:4326` `POLYGON ((...))`
    WKT string (`gl_bbox_to_wkt(input$geonesis_selected)`) for Snowflake
    `ST_WITHIN(GEOGRAPHY, TO_GEOGRAPHY(?))` or DuckDB
    `ST_Intersects(geom, ST_GeomFromText(?))`.

------------------------------------------------------------------------

## Case Study 2: S3 Geospatial Asset & Release Workstation (`Terrascope`)

### Before (Custom `geojson-vt` + `session$registerDataObj()` Workaround)

Because `leaflet` could not render large `.geojson`, `.fgdb`, or `.tif`
release artifacts in `Terrascope`, the viewer previously required custom
JavaScript injection (`geojson-vt.min.js`) and manual
`session$registerDataObj()` gzip endpoints—and still could not
dynamically re-color or hillshade `Float32` GeoTIFF hazard rasters in
the browser.

### After (`glmap` Universal Asset Previewer)

With `glmap`, any S3 asset (`.tif`, `.parquet`, `.fgdb`, `.geojson`) is
previewed on the GPU in a single function:

``` r

terrascope_preview_asset_gpu <- function(asset_path, color_col = NULL, palette = "viridis") {
  ext <- tolower(tools::file_ext(asset_path))
  m <- glmap(basemap = gl_providers$CartoDB.DarkMatter)

  if (ext %in% c("tif", "tiff", "geotiff")) {
    # Streams raw Float32 raster to WebGL2 with 0ms live palette & hillshade controls
    m |> add_raster(terra::rast(asset_path), palette = "terrain", hillshade = TRUE)
  } else if (ext == "parquet") {
    # Pushes viewport bounding box directly into DuckDB / GeoParquet
    m |> add_duckdb(source = asset_path, color = color_col %||% "#00d4ff", palette = palette)
  } else {
    # Triangulates polygons in C++17 (mapbox/earcut.h) and packs GLMP binary buffer
    v <- sf::st_read(asset_path, quiet = TRUE)
    m |> add_sf(v, fill_color = color_col %||% "#38bdf8", popup = gl_popup_table(v))
  }
}
```
