# Add a Custom Map Legend (`add_legend`)

Add a Custom Map Legend (`add_legend`)

## Usage

``` r
add_legend(
  map,
  title = "Legend",
  colors = NULL,
  labels = NULL,
  domain = NULL,
  position = "bottom-right",
  direction = "vertical",
  order = 20,
  layer_id = NULL,
  group = NULL,
  pal = NULL,
  values = NULL,
  opacity = 1,
  layerId = NULL,
  labFormat = NULL
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- title:

  Legend title.

- colors:

  Character vector of hex/CSS colors (or a palette function when `pal`
  is used).

- labels:

  Character vector of category labels (for categorical legends).

- domain:

  Numeric vector `c(min, max)` (for continuous legends).

- position:

  One of the 9 anchor positions (default `"bottom-right"`).

- direction:

  Layout direction (`"vertical"` or `"horizontal"`).

- order:

  Numeric draw order within the anchor zone (default `20`).

- layer_id:

  Optional associated layer ID.

- group:

  Optional associated layer group name (legend hides automatically when
  group is hidden).

- pal:

  Optional `leaflet::colorNumeric` palette function for drop-in
  `leaflet::addLegend()` compatibility.

- values:

  Optional numeric values vector when using `pal`.

- opacity:

  Optional numeric opacity.

- layerId:

  Optional alias for `layer_id` (`leaflet` compatibility).

- labFormat:

  Optional label format function (`leaflet` compatibility).
