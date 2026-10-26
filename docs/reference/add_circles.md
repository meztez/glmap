# Add a Geodesic Circle Layer (`add_circles`)

Drop-in equivalent of
[`leaflet::addCircles()`](https://rstudio.github.io/leaflet/reference/map-layers.html).
Unlike
[`add_points()`](https://meztez.github.io/glmap/reference/add_points.md)
(where `radius` is in screen pixels), `add_circles()` takes `radius` in
**meters** on the ground and builds geodesic polygon rings triangulated
in C++17.

## Usage

``` r
add_circles(
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
  line_width = 1,
  popup = NULL,
  label = NULL,
  n_segments = 24L,
  id = NULL,
  group = NULL,
  legend = TRUE,
  lng = NULL,
  fillColor = NULL,
  fillOpacity = NULL,
  color = NULL,
  weight = NULL,
  opacity = NULL,
  layerId = NULL,
  highlightOptions = NULL,
  labelOptions = NULL
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- data:

  An `sf`, `sfc`, or `data.frame` object.

- lon:

  Optional longitude column name or formula (`~lon`).

- lat:

  Optional latitude column name or formula (`~lat`).

- radius:

  Circle radius in **meters** (single number, formula `~r`, or numeric
  vector; default `500`).

- fill_color:

  Fill color aesthetic (color string, formula `~col`, or column name).

- palette:

  Color palette name (`"viridis"`, `"plasma"`, `"magma"`, `"turbo"`,
  `"Spectral"`, etc.).

- fill_opacity:

  Polygon fill opacity (`0` to `1`).

- stroke:

  Logical; whether to draw a crisp anti-aliased stroke around each
  point.

- line_color:

  Border line color string (default `"#ffffff"`).

- line_width:

  Border line width in pixels (default `1.0`).

- popup:

  Optional formula (`~name`), column name, or character vector for
  click/hover tooltips.

- label:

  Alias for `popup`.

- n_segments:

  Number of vertices per circle ring (default `24L`).

- id:

  Layer ID string.

- group:

  Layer group name shown in the interactive layer switcher.

- legend:

  Logical; whether to automatically add a legend when `color` is mapped
  to data.

- lng:

  Optional alias for `lon` (`leaflet` compatibility).

- fillColor, fillOpacity, color, weight, opacity, layerId,
  highlightOptions, labelOptions:

  Optional
  [`leaflet::addCircles()`](https://rstudio.github.io/leaflet/reference/map-layers.html)
  compatibility parameters.
