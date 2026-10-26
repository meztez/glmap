# Add a Coordinate Graticule Grid (`add_graticule`, `add_simple_graticule`)

Drop-in GPU equivalent of
[`leaflet::addGraticule()`](https://rstudio.github.io/leaflet/reference/addGraticule.html)
and
[`leaflet::addSimpleGraticule()`](https://rstudio.github.io/leaflet/reference/addSimpleGraticule.html).
Generates latitude/longitude meridian and parallel lines at the
specified `interval` (in degrees) and renders them as a fast WebGL line
layer.

## Usage

``` r
add_graticule(
  map,
  interval = 20,
  sphere = FALSE,
  style = list(color = "#64748b", weight = 1, opacity = 0.45),
  id = "graticule",
  group = "Graticule",
  ...
)

add_simple_graticule(
  map,
  interval = 20,
  id = "graticule",
  group = "Graticule",
  ...
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- interval:

  Spacing between graticule lines in degrees (default `20`).

- sphere:

  Logical; kept for
  [`leaflet::addGraticule()`](https://rstudio.github.io/leaflet/reference/addGraticule.html)
  compatibility.

- style:

  Styling list (`list(color = "#333", weight = 1, opacity = 0.45)`).

- id:

  Layer ID (default `"graticule"`).

- group:

  Layer group name (default `"Graticule"`).

- ...:

  Additional arguments kept for compatibility.

## Value

Updated `glmap` widget or `glmap_proxy`.
