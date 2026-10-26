# Leaflet Option Helpers (`highlight_options`, `label_options`, `popup_options`, `provider_tile_options`, `wms_tile_options`)

Drop-in equivalents of
[`leaflet::highlightOptions()`](https://rstudio.github.io/leaflet/reference/map-layers.html),
[`leaflet::labelOptions()`](https://rstudio.github.io/leaflet/reference/map-options.html),
[`leaflet::popupOptions()`](https://rstudio.github.io/leaflet/reference/map-options.html),
[`leaflet::providerTileOptions()`](https://rstudio.github.io/leaflet/reference/addProviderTiles.html),
and
[`leaflet::WMSTileOptions()`](https://rstudio.github.io/leaflet/reference/map-options.html).

## Usage

``` r
highlight_options(
  stroke = NULL,
  color = "#ffffff",
  weight = 3,
  opacity = 1,
  fill = NULL,
  fillColor = NULL,
  fillOpacity = 0.75,
  dashArray = NULL,
  bringToFront = TRUE,
  sendToBack = FALSE
)

label_options(
  interactive = FALSE,
  clickable = NULL,
  noHide = FALSE,
  permanent = FALSE,
  className = "",
  direction = "auto",
  offset = c(0, 0),
  opacity = 1,
  textsize = "12px",
  textOnly = FALSE,
  style = NULL,
  sticky = TRUE,
  ...
)

popup_options(
  maxWidth = 300,
  minWidth = 50,
  maxHeight = NULL,
  autoPan = TRUE,
  keepInView = FALSE,
  closeButton = TRUE,
  closeOnClick = NULL,
  ...
)

provider_tile_options(...)

wms_tile_options(
  styles = "",
  format = "image/png",
  transparent = TRUE,
  version = "1.1.1",
  ...
)
```

## Arguments

- stroke, color, weight, opacity, fill, fillColor, fillOpacity,
  dashArray, bringToFront, sendToBack:

  Hover highlight styling options.

- interactive, clickable, noHide, permanent, className, direction,
  offset, textsize, textOnly, style, sticky:

  Label display options.

- ...:

  Additional options kept for `leaflet` compatibility.

- maxWidth, minWidth, maxHeight, autoPan, keepInView, closeButton,
  closeOnClick:

  Popup options.

- styles, format, transparent, version:

  WMS tile option parameters.
