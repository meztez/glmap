# Add a GPU LineString / MultiLineString Layer

Add a GPU LineString / MultiLineString Layer

## Usage

``` r
add_lines(
  map,
  data = NULL,
  color = "#38bdf8",
  palette = "viridis",
  width = 2,
  opacity = 0.85,
  popup = NULL,
  label = NULL,
  id = NULL,
  group = NULL,
  legend = TRUE
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- data:

  An `sf`, `sfc`, or `data.frame` object.

- color:

  Color string, formula (`~val`), or column name.

- palette:

  Color palette name (`"viridis"`, `"plasma"`, `"magma"`, `"turbo"`,
  `"Spectral"`, etc.).

- width:

  Line width in pixels (default `2.0`).

- opacity:

  Numeric fill opacity (`0` to `1`).

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
