# Add a Custom Map Legend (`add_legend`)

Supports both `glmap` native arguments (`title`, `colors`, `labels`,
`domain`, `position`) and
`leaflet::addLegend(map, position = "bottomright", pal = pal, values = ~val, title = ...)`
positional and formula arguments.

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
  labFormat = NULL,
  data = NULL
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- title:

  Legend title (or `position` string when called positionally like
  `addLegend(map, "bottomright", ...)`).

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

  Optional `color_numeric` /
  [`leaflet::colorNumeric`](https://rstudio.github.io/leaflet/reference/colorNumeric.html)
  palette function for drop-in
  [`leaflet::addLegend()`](https://rstudio.github.io/leaflet/reference/addLegend.html)
  compatibility.

- values:

  Optional numeric/categorical values vector or formula (`~val`) when
  using `pal`.

- opacity:

  Optional numeric opacity.

- layerId:

  Optional alias for `layer_id` (`leaflet` compatibility).

- labFormat:

  Optional label format function (`leaflet` compatibility).

- data:

  Optional dataset used to evaluate `values = ~col` formulas (defaults
  to map data).
