# Add a GPU Instanced Point Layer (Handles 1M+ Points at 60 FPS)

Streams points as a zero-copy `GLMP` binary `Float32Array` buffer
directly to a custom WebGL2 instanced point shader (with anti-aliased
SDF circles, stroke outlines, variable radius, and interactive picking).

## Usage

``` r
add_points(
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
  stroke_width = 1,
  popup = NULL,
  label = NULL,
  icon = NULL,
  clusterOptions = NULL,
  id = NULL,
  group = NULL,
  dynamic_viewport = FALSE,
  legend = TRUE,
  lng = NULL
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- data:

  An `sf`, `sfc`, or `data.frame` object.

- lon:

  Optional longitude column name or formula (`~lon`) for `data.frame`.

- lat:

  Optional latitude column name or formula (`~lat`) for `data.frame`.

- color:

  Color string, formula (`~val`), or column name.

- palette:

  Color palette name (`"viridis"`, `"plasma"`, `"magma"`, `"turbo"`,
  `"Spectral"`, etc.).

- radius:

  Point radius in pixels (single number, formula `~size`, or numeric
  vector).

- opacity:

  Numeric fill opacity (`0` to `1`).

- stroke:

  Logical; whether to draw a crisp anti-aliased stroke around each
  point.

- stroke_color:

  Stroke color string (default `"#ffffff"`).

- stroke_width:

  Stroke width in pixels (default `1.0`).

- popup:

  Optional formula (`~name`), column name, or character vector for
  click/hover tooltips.

- label:

  Alias for `popup`.

- icon:

  Optional marker icon specification created by
  [`make_icon()`](https://meztez.github.io/glmap/reference/add_markers.md),
  [`make_awesome_icon()`](https://meztez.github.io/glmap/reference/add_markers.md),
  `leaflet::makeIcon()`, or a character vector / formula (`~icon_url`)
  of SVG/PNG URLs.

- clusterOptions:

  Optional clustering specification (`leaflet::markerClusterOptions()`
  compatibility).

- id:

  Layer ID string.

- group:

  Layer group name shown in the interactive layer switcher.

- dynamic_viewport:

  Logical; if `TRUE`, builds an in-memory C++ spatial index and streams
  only the visible viewport slice via the local `httpuv` server.

- legend:

  Logical; whether to automatically add a legend when `color` is mapped
  to data.

- lng:

  Optional alias for `lon` (`leaflet` compatibility).

## Value

Updated `glmap` map object.
