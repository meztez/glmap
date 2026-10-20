# Add a C++ Accelerated Hexagonal Binning Layer for 1M+ Points

Aggregates millions of points into hexagonal spatial bins in C++17 in
milliseconds and renders them on the GPU with color and optional 3D
extrusion mapped to count or weight.

## Usage

``` r
add_hexbin(
  map,
  data = NULL,
  lon = NULL,
  lat = NULL,
  weight = NULL,
  hex_radius = 0.03,
  palette = "plasma",
  opacity = 0.85,
  extrude = FALSE,
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

- lon:

  Optional longitude column name or formula (`~lon`) for `data.frame`.

- lat:

  Optional latitude column name or formula (`~lat`) for `data.frame`.

- weight:

  Optional numeric column/formula to average inside each hex cell.

- hex_radius:

  Hexagon radius in degrees (default `0.03`).

- palette:

  Color palette name (`"viridis"`, `"plasma"`, `"magma"`, `"turbo"`,
  `"Spectral"`, etc.).

- opacity:

  Numeric fill opacity (`0` to `1`).

- extrude:

  Logical; if `TRUE`, extrudes hex bins based on point count.

- id:

  Layer ID string.

- group:

  Layer group name shown in the interactive layer switcher.

- legend:

  Logical; whether to automatically add a legend when `color` is mapped
  to data.
