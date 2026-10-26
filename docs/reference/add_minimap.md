# Add an Interactive Overview MiniMap (`add_minimap`)

Drop-in GPU/Canvas equivalent of
[`leaflet::addMiniMap()`](https://rstudio.github.io/leaflet/reference/addMiniMap.html).
Adds a synchronized inset overview map with an interactive aiming
rectangle showing the current viewport extent and click-to-pan
navigation.

## Usage

``` r
add_minimap(
  map,
  position = "bottomright",
  width = 150,
  height = 150,
  zoomLevelOffset = -5,
  toggleDisplay = TRUE,
  aimingRectOptions = list(color = "#ff7800", weight = 2),
  order = 80,
  ...
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- position:

  Anchor position in the 9-zone layout grid (default `"bottomright"`).

- width, height:

  MiniMap dimensions in pixels (default `150`).

- zoomLevelOffset:

  Numeric zoom offset relative to the main map (default `-5`).

- toggleDisplay:

  Logical; whether to show a collapse/expand button on the MiniMap
  (default `TRUE`).

- aimingRectOptions:

  Optional styling list for the viewport aiming rectangle.

- order:

  Numeric draw order within the anchor zone (default `80`).

- ...:

  Additional arguments kept for
  [`leaflet::addMiniMap()`](https://rstudio.github.io/leaflet/reference/addMiniMap.html)
  compatibility.

## Value

Updated `glmap` widget or `glmap_proxy`.
