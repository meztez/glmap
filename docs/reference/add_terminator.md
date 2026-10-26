# Add a Solar Day/Night Terminator Polygon Layer (`add_terminator`)

Drop-in GPU equivalent of
[`leaflet::addTerminator()`](https://rstudio.github.io/leaflet/reference/addTerminator.html).
Computes the solar declination and hour angle for `time` (defaults to
current UTC time) and renders the night-time hemisphere polygon on the
GPU.

## Usage

``` r
add_terminator(
  map,
  resolution = 180L,
  time = Sys.time(),
  fill_color = "#020617",
  fill_opacity = 0.38,
  id = "terminator",
  group = "Day/Night",
  ...
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- resolution:

  Number of longitude vertices along the terminator curve (default
  `180L`).

- time:

  POSIXct timestamp or ISO string (defaults to
  [`Sys.time()`](https://rdrr.io/r/base/Sys.time.html)).

- fill_color:

  Night polygon fill color (default `"#020617"`).

- fill_opacity:

  Night polygon fill opacity (default `0.38`).

- id:

  Layer ID (default `"terminator"`).

- group:

  Layer group name (default `"Day/Night"`).

- ...:

  Additional arguments kept for compatibility.

## Value

Updated `glmap` widget or `glmap_proxy`.
