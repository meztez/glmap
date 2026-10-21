# Add Custom Icon or Awesome Markers (`add_markers`, `make_icon`, `make_awesome_icon`)

Drop-in GPU/Canvas equivalents of `leaflet::addMarkers()`,
`leaflet::makeIcon()`, and `leaflet::makeAwesomeIcon()`. Supports
per-feature SVG/PNG icon URLs (such as Geonesis product icons
`bateau1.svg`, `habitation1.svg`, `auto1.svg`) as well as colored
pin/badge markers.

## Usage

``` r
add_markers(
  map,
  data = NULL,
  lng = NULL,
  lat = NULL,
  icon = NULL,
  popup = NULL,
  label = NULL,
  group = NULL,
  clusterOptions = NULL,
  id = NULL,
  ...
)

make_icon(iconUrl, iconWidth = 28, iconHeight = 28)

make_awesome_icon(text = "●", markerColor = "blue", iconColor = "#ffffff")
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- data:

  An `sf`, `sfc`, or `data.frame` object.

- lng:

  Optional alias for `lon` (`leaflet` compatibility).

- lat:

  Optional latitude column name or formula (`~lat`) for `data.frame`.

- icon:

  Optional marker icon specification created by `make_icon()`,
  `make_awesome_icon()`, `leaflet::makeIcon()`, or a character vector /
  formula (`~icon_url`) of SVG/PNG URLs.

- popup:

  Optional formula (`~name`), column name, or character vector for
  click/hover tooltips.

- label:

  Alias for `popup`.

- group:

  Layer group name shown in the interactive layer switcher.

- clusterOptions:

  Optional clustering specification (`leaflet::markerClusterOptions()`
  compatibility).

- id:

  Layer ID string.

- ...:

  Additional arguments passed to
  [`add_points()`](https://meztez.github.io/glmap/reference/add_points.md).

- iconUrl:

  URL or relative path (e.g. inside Shiny `www/`) to an SVG or PNG icon.

- iconWidth, iconHeight:

  Icon dimensions in pixels (default `28`).

- text:

  Optional short symbol or glyph text inside the awesome marker pin.

- markerColor:

  Marker pin color (e.g., `"red"`, `"blue"`, `"orange"`, `"green"`,
  `"purple"`).

- iconColor:

  Inner glyph color (default `"#ffffff"`).
