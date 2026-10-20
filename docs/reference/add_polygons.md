# Add a Pre-Triangulated GPU Polygon / MultiPolygon Layer

Triangulates polygons in C++17 (`earcut`) and streams triangle index
buffers and ring outlines directly to WebGL2 vertex buffers (zero JS
`earcut` overhead).

## Usage

``` r
add_polygons(
  map,
  data = NULL,
  fill_color = "#3b82f6",
  palette = "viridis",
  fill_opacity = 0.7,
  stroke = TRUE,
  line_color = "#e2e8f0",
  line_width = 1,
  extrude = NULL,
  popup = NULL,
  label = NULL,
  id = NULL,
  group = NULL,
  legend = TRUE
)
```

## Arguments

- map:

  A `gexplore` widget or `gexplore_proxy`.

- data:

  An `sf`, `sfc`, or `data.frame` object.

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

- extrude:

  Optional 3D extrusion height aesthetic (formula `~height`, column
  name, or numeric).

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
