# Remove the Interactive Drawing Toolbar (`remove_draw_toolbar`)

Drop-in equivalent of
[`leaflet.extras::removeDrawToolbar()`](https://trafficonese.github.io/leaflet.extras/reference/draw.html).

## Usage

``` r
remove_draw_toolbar(map, clearFeatures = FALSE)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- clearFeatures:

  Logical; whether to also clear all drawn shapes from the map (default
  `FALSE`).
