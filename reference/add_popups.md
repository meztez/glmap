# Add Standalone HTML Popups (`add_popups`, `clear_popups`)

Drop-in equivalents of `leaflet::addPopups()` and
`leaflet::clearPopups()`. When called on a `glmap_proxy` with a single
`lng`/`lat` and `popup` HTML string (such as lazy on-click popup
generation in Shiny), opens the floating DOM popup card at that exact
geographic coordinate.

## Usage

``` r
add_popups(
  map,
  data = NULL,
  lon = NULL,
  lat = NULL,
  popup = NULL,
  id = NULL,
  group = NULL,
  lng = NULL
)

clear_popups(map)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- data:

  Optional `sf` or `data.frame` object.

- lon, lat:

  Longitude and latitude coordinates or formulas (`~lon`, `~lat`).

- popup:

  Character vector or formula (`~html`) of popup HTML content.

- id:

  Layer ID.

- group:

  Layer group name.

- lng:

  Optional alias for `lon` (`leaflet` compatibility).
