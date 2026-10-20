# glmap — AI Agent & Developer Instructions (AGENTS.md)

This document provides deterministic rules for AI coding agents (GitHub
Copilot, Claude Code, Cursor, etc.) and human developers when writing
new geospatial visualizations, migrating `leaflet` / `mapview` code to
`glmap`, or extending the `glmap` package itself.

------------------------------------------------------------------------

## 1. Golden Rules When Generating R Mapping Code with `glmap`

1.  **Use [`glmap()`](https://meztez.github.io/glmap/reference/glmap.md)
    as the primary entry point**
    ([`gexplore()`](https://meztez.github.io/glmap/reference/glmap.md)
    and [`gx_map()`](https://meztez.github.io/glmap/reference/glmap.md)
    are also supported as aliases).
2.  **Never construct manual palette functions
    ([`leaflet::colorNumeric`](https://rstudio.github.io/leaflet/reference/colorNumeric.html),
    `colorFactor`, `colorBin`)**:
    - In `glmap`, pass the column formula (`~col_name`) or column name
      string (`"col_name"`) directly to `color =` or `fill_color =`,
      along with `palette = "viridis"` (or `"plasma"`, `"magma"`,
      `"turbo"`, `"terrain"`, `"rdylbu"`, `"Spectral"`).
    - `glmap` automatically computes a 256-entry RGB lookup table in
      R/C++ and attaches a matching continuous or categorical legend
      automatically.
3.  **Never convert `sf` to GeoJSON or
    [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
    to PNG before calling `glmap`**:
    - Pass `sf`, `sfc`,
      [`wk::xy`](https://paleolimbot.github.io/wk/reference/xy.html),
      [`wk::wkb`](https://paleolimbot.github.io/wk/reference/wkb.html),
      `nanoarrow_array`,
      [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html),
      [`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html),
      `stars`, or `data.frame` objects **directly** to
      [`glmap()`](https://meztez.github.io/glmap/reference/glmap.md),
      [`add_sf()`](https://meztez.github.io/glmap/reference/add_sf.md),
      [`add_points()`](https://meztez.github.io/glmap/reference/add_points.md),
      [`add_lines()`](https://meztez.github.io/glmap/reference/add_lines.md),
      [`add_polygons()`](https://meztez.github.io/glmap/reference/add_polygons.md),
      or
      [`add_raster()`](https://meztez.github.io/glmap/reference/add_raster.md).
    - C++17 functions (`cpp_pack_points_xy`, `cpp_pack_sfc_binary`,
      `cpp_pack_raster_float32`) extract coordinates and triangulate
      polygons (including interior holes via `mapbox/earcut.hpp`)
      directly from R memory pointers.
4.  **Choose the right transport mode for dataset scale**:
    - **Up to ~500k features / standalone HTML / Quarto / RMarkdown**:
      Keep the default `transport = "auto"` (uses `zlib`-compressed
      binary inline buffers decoded via browser `DecompressionStream`).
    - **500k to 10M+ features in interactive R / Shiny sessions**: Use
      `transport = "server"` or
      `add_points(..., dynamic_viewport = TRUE)` so the C++17 spatial
      index
      ([`gl_spatial_index()`](https://meztez.github.io/glmap/reference/gl_spatial_index.md))
      streams only the visible bounding box over `httpuv` (`127.0.0.1`).
    - **10M to 100M+ rows in DuckDB or `.parquet` files**: Use
      `add_duckdb(con, source = "file.parquet", lon = "lon", lat = "lat", color = ~val, where = "...")`
      to push bounding-box and SQL `WHERE` filters directly into
      DuckDB’s vectorized engine without loading the full table into R
      memory.
5.  **In Shiny apps, always use
    [`glmap_proxy()`](https://meztez.github.io/glmap/reference/glmap_proxy.md)
    for incremental updates**:
    - Never re-run
      [`renderGlmap()`](https://meztez.github.io/glmap/reference/renderGlmap.md)
      just to change a raster palette, toggle hillshading, hide a layer,
      or move the camera.
    - Use
      `glmap_proxy("map_id") |> set_raster_style("layer_id", palette = ..., hillshade = ...)`
      for 0 ms GPU uniform updates.

------------------------------------------------------------------------

## 2. Deterministic `leaflet` $`\rightarrow`$`glmap` Refactoring Rules for Agents

When asked to migrate an R script or Shiny app from `leaflet` to
`glmap`, apply these exact transformations:

| `leaflet` Pattern | Replace With (`glmap`) | Notes |
|:---|:---|:---|
| [`library(leaflet)`](https://rstudio.github.io/leaflet/) | [`library(glmap)`](https://meztez.github.io/glmap/) | Drop `leafgl` / `leafem` imports as well |
| `leaflet(data)` | `glmap(data, basemap = "dark")` | Or `basemap = "positron"` for light mode |
| `|> addTiles()` | `|> set_basemap("osm")` | Or pass `basemap = "osm"` to [`glmap()`](https://meztez.github.io/glmap/reference/glmap.md) |
| `|> addProviderTiles(providers$CartoDB.Positron)` | `|> set_basemap("positron")` | Supported: `"dark"`, `"positron"`, `"voyager"`, `"osm"`, `"satellite"`, `"none"` |
| `|> addCircleMarkers(lng = ~x, lat = ~y, radius = 5, color = ~pal(z), fillOpacity = 0.8)` | `|> add_points(lon = ~x, lat = ~y, radius = 5, color = ~z, palette = "viridis", opacity = 0.8)` | Delete `pal <- colorNumeric(...)` |
| `|> addMarkers(lng = ~x, lat = ~y, popup = ~lbl)` | `|> add_points(lon = ~x, lat = ~y, popup = ~lbl)` | Rendered on WebGL2 GPU |
| `|> addLabelOnlyMarkers(lng = ~x, lat = ~y, label = ~lbl)` | `|> add_labels(lon = ~x, lat = ~y, text = ~lbl)` | Crisp halo-outlined labels |
| `|> addPolylines(data = lines_sf, color = "blue", weight = 2)` | `|> add_lines(data = lines_sf, color = "blue", width = 2)` | Note `weight` $`\rightarrow`$`width` |
| `|> addPolygons(data = poly_sf, fillColor = ~pal(v), fillOpacity = 0.7, color = "white", weight = 1)` | `|> add_polygons(data = poly_sf, fill_color = ~v, palette = "viridis", fill_opacity = 0.7, line_color = "white", line_width = 1)` | C++17 `mapbox/earcut` triangulates automatically |
| `|> addRasterImage(r, colors = pal, opacity = 0.8)` | `|> add_raster(r, palette = "terrain", opacity = 0.8, hillshade = TRUE)` | Uploads raw `Float32` texture to GPU |
| `|> addLegend(...)` | *(Remove unless custom legend needed)* | Legends are auto-generated when `color` / `fill_color` is mapped; use [`add_legend()`](https://meztez.github.io/glmap/reference/add_legend.md) only for custom overrides |
| `|> addLayersControl(...)` | *(Remove)* | Interactive GPU Layer Switcher is enabled by default |
| `|> setView(lng, lat, zoom)` | `|> set_view(lng, lat, zoom)` | Snake_case |
| `|> fitBounds(lng1, lat1, lng2, lat2)` | `|> fit_bounds(c(lng1, lat1, lng2, lat2))` | Also accepts `sf` or `SpatRaster` directly |
| `leafletOutput("map", height = 600)` | `glmapOutput("map", height = "600px")` | Shiny UI |
| `renderLeaflet({ ... })` | `renderGlmap({ ... })` | Shiny Server |
| `leafletProxy("map") |> clearShapes()` | `glmap_proxy("map") |> clear_layers()` | Or `clear_layer("id")` |
| `leafletProxy("map") |> hideGroup("g")` | `glmap_proxy("map") |> set_layer_visibility("g", FALSE)` | Instant GPU toggle |

------------------------------------------------------------------------

## 3. Repository Architecture (For Agents Modifying `gexplore` Internals)

- **`src/gexplore_cpp.cpp` & `src/cpp11.cpp`**:
  - C++17 backend using `cpp11`.
  - Binary packet formats:
    - `GEXP` (48-byte packed header + `Float32` coords + `Uint32` vertex
      feature IDs + `Uint32` ring starts + `Uint32` earcut triangle
      indices + `Uint8` RGBA + optional `Float32` radius & elevation).
    - `GEXR` (48-byte packed header + `Float32` raster band values).
  - Note: On Windows without `decor` installed, keep `src/cpp11.cpp` and
    `R/cpp11.R` synchronized manually when adding new
    `[[cpp11::register]]` functions, and compile via
    `R CMD INSTALL --no-multiarch .`.
- **`R/transport.R`**:
  - [`gx_pack_sf_binary()`](https://meztez.github.io/glmap/reference/gl_pack_sf_binary.md)
    (supports `sf`, `sfc`, `wk_xy`, `wk_wkb`, `wk_wkt`,
    `nanoarrow_array`, `data.frame`),
    [`gx_pack_raster_binary()`](https://meztez.github.io/glmap/reference/gl_pack_raster_binary.md)
    (supports
    [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
    and `matrix`),
    [`gx_spatial_index()`](https://meztez.github.io/glmap/reference/gl_spatial_index.md),
    and `httpuv` daemon server
    ([`gx_serve_start()`](https://meztez.github.io/glmap/reference/gl_serve_start.md),
    [`gx_serve_stop()`](https://meztez.github.io/glmap/reference/gl_serve_stop.md)).
- **`R/map.R`, `R/scales.R`, `R/controls.R`**:
  - User-facing pipeable API
    ([`gexplore()`](https://meztez.github.io/glmap/reference/glmap.md),
    [`add_sf()`](https://meztez.github.io/glmap/reference/add_sf.md),
    [`add_points()`](https://meztez.github.io/glmap/reference/add_points.md),
    [`add_lines()`](https://meztez.github.io/glmap/reference/add_lines.md),
    [`add_polygons()`](https://meztez.github.io/glmap/reference/add_polygons.md),
    [`add_raster()`](https://meztez.github.io/glmap/reference/add_raster.md),
    [`add_hexbin()`](https://meztez.github.io/glmap/reference/add_hexbin.md),
    [`add_heatmap()`](https://meztez.github.io/glmap/reference/add_heatmap.md),
    [`add_pmtiles()`](https://meztez.github.io/glmap/reference/add_pmtiles.md),
    [`add_mvt()`](https://meztez.github.io/glmap/reference/add_pmtiles.md)).
- **`R/plugins.R` & `R/shiny.R`**:
  - Extension registry
    ([`register_plugin()`](https://meztez.github.io/glmap/reference/register_plugin.md),
    [`use_plugin()`](https://meztez.github.io/glmap/reference/use_plugin.md),
    [`add_webgl_shader_layer()`](https://meztez.github.io/glmap/reference/add_webgl_shader_layer.md),
    [`add_deck_layer()`](https://meztez.github.io/glmap/reference/add_deck_layer.md))
    and Shiny proxy
    ([`gexplore_proxy()`](https://meztez.github.io/glmap/reference/glmap_proxy.md)).
- **`inst/htmlwidgets/gexplore.js`**:
  - Zero-dependency WebGL2 + MapLibre GL JS engine, `GEXP`/`GEXR` binary
    parser, `DecompressionStream("deflate")` decoder, custom GLSL
    shaders (SDF instanced points, triangulated polygon mesh, additive
    Gaussian heatmap, multi-band `Float32` raster LUT + surface-normal
    hillshader), and interactive Measure / Box Brush / PNG Export tools.
