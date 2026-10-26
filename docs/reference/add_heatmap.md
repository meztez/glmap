# Add a GPU Additive Kernel Density Heatmap Layer

Add a GPU Additive Kernel Density Heatmap Layer

## Usage

``` r
add_heatmap(
  map,
  data = NULL,
  lon = NULL,
  lat = NULL,
  weight = NULL,
  radius = 18,
  intensity = 1,
  palette = "inferno",
  opacity = 0.8,
  id = NULL,
  group = NULL
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

  Optional weight column or formula (`~weight`).

- radius:

  Point radius in pixels (single number, formula `~size`, or numeric
  vector).

- intensity:

  Numeric intensity multiplier (default `1.0`).

- palette:

  Color palette name (`"viridis"`, `"plasma"`, `"magma"`, `"turbo"`,
  `"Spectral"`, etc.).

- opacity:

  Numeric fill opacity (`0` to `1`).

- id:

  Layer ID string.

- group:

  Layer group name shown in the interactive layer switcher.
