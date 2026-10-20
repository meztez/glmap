# Add Standalone HTML Popups (`add_popups`)

Drop-in equivalent of
[`leaflet::addPopups()`](https://rstudio.github.io/leaflet/reference/map-layers.html).

## Usage

``` r
add_popups(
  map,
  data = NULL,
  lon = NULL,
  lat = NULL,
  popup = NULL,
  id = NULL,
  group = NULL
)
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
