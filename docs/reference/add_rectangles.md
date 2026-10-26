# Add a Bounding-Box Rectangle Layer (`add_rectangles`)

Drop-in equivalent of
[`leaflet::addRectangles()`](https://rstudio.github.io/leaflet/reference/map-layers.html).

## Usage

``` r
add_rectangles(
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
  legend = FALSE,
  fillColor = NULL,
  fillOpacity = NULL,
  color = NULL,
  weight = NULL,
  opacity = NULL,
  layerId = NULL,
  highlightOptions = NULL
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- data:

  An `sf`, `sfc`, or `data.frame` object.

- lng1, lat1, lng2, lat2:

  Numeric vectors or formulas specifying opposite corners of each
  rectangle.

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

- id:

  Layer ID string.

- group:

  Layer group name shown in the interactive layer switcher.

- legend:

  Logical; whether to automatically add a legend when `color` is mapped
  to data.

- fillColor, fillOpacity, color, weight, opacity, layerId,
  highlightOptions:

  Optional
  [`leaflet::addRectangles()`](https://rstudio.github.io/leaflet/reference/map-layers.html)
  compatibility parameters.
