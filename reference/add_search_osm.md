# Add an OpenStreetMap Address & Place Search Bar (`add_search_osm`, `search_options`)

Drop-in equivalent of `leaflet.extras::addSearchOSM()` and
`leaflet.extras::searchOptions()`. Adds an interactive address/place
geocoder bar powered by OpenStreetMap Nominatim with autocomplete
suggestions, Enter-to-search, smooth camera fly-to, and an optional
location pin.

## Usage

``` r
add_search_osm(map, options = search_options(), position = NULL, order = 5)

search_options(
  url = "https://nominatim.openstreetmap.org/search?format=json&q={s}",
  zoom = 15,
  autoCollapse = FALSE,
  textPlaceholder = "Search address or place...",
  position = "topleft",
  hideMarkerOnCollapse = TRUE,
  ...
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- options:

  Search configuration list created by `search_options()`.

- position:

  Anchor position (default `"topleft"`).

- order:

  Numeric draw order within the anchor zone (default `5`).

- url:

  Geocoding endpoint URL template containing `{s}` (default Nominatim
  JSON endpoint).

- zoom:

  Target zoom level when flying to a matched address (default `15`).

- autoCollapse:

  Logical; if `TRUE`, collapses the search input until clicked (default
  `FALSE`).

- textPlaceholder:

  Placeholder text inside the search input.

- hideMarkerOnCollapse:

  Logical; remove the search pin when cleared (default `TRUE`).

- ...:

  Additional options ignored for `leaflet.extras::searchOptions()`
  compatibility.

## Value

Updated `glmap` widget or `glmap_proxy`.
