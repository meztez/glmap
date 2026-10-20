# Migrating from leaflet to glmap (For Humans & AI Agents)

## Overview

🌱 ELI5 (3 Golden Rules to Switch from Leaflet)\
Switching an existing R script or Shiny app from `leaflet` to `glmap`
takes three simple habits:

1.  Replace `leaflet() |> addProviderTiles(…)` with
    **`glmap(basemap = “dark”)`** (or `“positron”`).
2.  Delete `pal <- colorNumeric(…)` and `addLegend(…)`—just pass
    **`color = ~column, palette = “viridis”`** directly into
    [`add_points()`](https://meztez.github.io/glmap/reference/add_points.md)
    or
    [`add_polygons()`](https://meztez.github.io/glmap/reference/add_polygons.md).
3.  In Shiny, replace `leafletOutput` / `renderLeaflet` / `leafletProxy`
    with **`glmapOutput` / `renderGlmap` / `glmap_proxy`**.

⚙️ Technical Mode (API & Reactivity Mapping)\
`glmap` was designed so that R users and AI coding agents familiar with
`leaflet` can transition immediately while gaining **100x–500x faster
C++17 binary serialization** and **60 FPS WebGL2 GPU rendering**. All
functions use consistent `snake_case`, evaluate tidy/formula aesthetics
(`~expr`) via C/R 256-entry RGB lookup tables, and emit
`leaflet`-compatible Shiny input events (`_click`, `_bounds`, `_zoom`,
`_marker_click`, `_shape_click`).

------------------------------------------------------------------------

## Complete Function-by-Function Mapping

| `leaflet` Function | `glmap` Function | Key Parameter Differences |
|:---|:---|:---|
| `leaflet(data)` | `glmap(data, basemap = "dark")` | Includes basemap out of the box (`"dark"`, `"positron"`, `"voyager"`, `"osm"`, `"satellite"`) |
| [`addTiles()`](https://rstudio.github.io/leaflet/reference/map-layers.html) / [`addProviderTiles()`](https://rstudio.github.io/leaflet/reference/addProviderTiles.html) | `set_basemap("positron")` | Or set `basemap =` directly in [`glmap()`](https://meztez.github.io/glmap/reference/glmap.md) |
| [`addCircleMarkers()`](https://rstudio.github.io/leaflet/reference/map-layers.html) / [`addMarkers()`](https://rstudio.github.io/leaflet/reference/map-layers.html) | [`add_points()`](https://meztez.github.io/glmap/reference/add_points.md) | `lng` $`\rightarrow`$`lon`, `fillOpacity` $`\rightarrow`$`opacity`, pass `color = ~col, palette = "viridis"` directly |
| [`addLabelOnlyMarkers()`](https://rstudio.github.io/leaflet/reference/map-layers.html) | [`add_labels()`](https://meztez.github.io/glmap/reference/add_labels.md) | `label` $`\rightarrow`$`text` |
| [`addPolylines()`](https://rstudio.github.io/leaflet/reference/map-layers.html) | [`add_lines()`](https://meztez.github.io/glmap/reference/add_lines.md) | `weight` $`\rightarrow`$`width` |
| [`addPolygons()`](https://rstudio.github.io/leaflet/reference/map-layers.html) | [`add_polygons()`](https://meztez.github.io/glmap/reference/add_polygons.md) | `fillColor` $`\rightarrow`$`fill_color`, `fillOpacity` $`\rightarrow`$`fill_opacity`, `color` $`\rightarrow`$`line_color`, `weight` $`\rightarrow`$`line_width` |
| [`addRasterImage()`](https://rstudio.github.io/leaflet/reference/addRasterImage.html) | [`add_raster()`](https://meztez.github.io/glmap/reference/add_raster.md) | Streams raw `Float32` values to GPU shader; supports `hillshade = TRUE` and live UI palette switching |
| `addHeatmap()` (`leaflet.extras`) | [`add_heatmap()`](https://meztez.github.io/glmap/reference/add_heatmap.md) | Built-in WebGL2 additive Gaussian kernel shader |
| *(No built-in equivalent)* | [`add_hexbin()`](https://meztez.github.io/glmap/reference/add_hexbin.md) | Built-in C++17 64-bit hexagonal spatial aggregation for 1M+ points |
| `setView(lng, lat, zoom)` | `set_view(lng, lat, zoom, pitch, bearing)` | Supports 3D camera `pitch` and `bearing` |
| `flyTo(lng, lat, zoom)` | `fly_to(lng, lat, zoom, pitch, bearing)` | Smooth WebGL camera animation |
| `fitBounds(lng1, lat1, lng2, lat2)` | `fit_bounds(c(xmin, ymin, xmax, ymax))` | Also accepts an `sf` or `SpatRaster` object directly |
| [`leafletOutput()`](https://rstudio.github.io/leaflet/reference/map-shiny.html) / [`renderLeaflet()`](https://rstudio.github.io/leaflet/reference/map-shiny.html) | [`glmapOutput()`](https://meztez.github.io/glmap/reference/glmapOutput.md) / [`renderGlmap()`](https://meztez.github.io/glmap/reference/renderGlmap.md) | Drop-in Shiny UI & Server replacements |
| [`leafletProxy()`](https://rstudio.github.io/leaflet/reference/leafletProxy.html) | [`glmap_proxy()`](https://meztez.github.io/glmap/reference/glmap_proxy.md) | Supports [`clear_layer()`](https://meztez.github.io/glmap/reference/clear_layer.md), [`clear_layers()`](https://meztez.github.io/glmap/reference/clear_layers.md), [`set_layer_visibility()`](https://meztez.github.io/glmap/reference/set_layer_visibility.md), [`set_layer_opacity()`](https://meztez.github.io/glmap/reference/set_layer_opacity.md), [`set_raster_style()`](https://meztez.github.io/glmap/reference/set_raster_style.md), [`set_filter()`](https://meztez.github.io/glmap/reference/set_filter.md) |

------------------------------------------------------------------------

## Side-by-Side Migration Examples

### Example 1: Polygons Colored by a Continuous Attribute

#### `leaflet`

``` r

library(leaflet)

pal <- colorNumeric("viridis", domain = nc$BIR74)

leaflet(nc) |>
  addProviderTiles(providers$CartoDB.Positron) |>
  addPolygons(
    fillColor = ~pal(BIR74),
    fillOpacity = 0.75,
    color = "#ffffff",
    weight = 1,
    popup = ~NAME
  ) |>
  addLegend("bottomright", pal = pal, values = ~BIR74, title = "Births 1974")
```

#### `glmap`

``` r

library(glmap)

glmap(nc, basemap = "positron") |>
  add_polygons(
    fill_color = ~BIR74,
    palette = "viridis",
    fill_opacity = 0.75,
    line_color = "#ffffff",
    line_width = 1,
    popup = ~NAME
  )
```

------------------------------------------------------------------------

### Example 2: `terra::SpatRaster` with Live Interactive Shader Controls

#### `leaflet`

``` r

# Projects and renders a static PNG in R on the CPU; changing colors requires re-running R
pal <- colorNumeric("terrain", values(dem), na.color = "transparent")
leaflet() |>
  addTiles() |>
  addRasterImage(dem, colors = pal, opacity = 0.8)
```

#### `glmap`

``` r

# Uploads raw Float32 values to GPU texture; user can switch palettes & toggle hillshade at 0ms in browser
glmap(basemap = "dark") |>
  add_raster(dem, palette = "terrain", hillshade = TRUE, opacity = 0.8)
```
