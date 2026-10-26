# Add a Collapsible Layers & Basemap Control (`add_layers_control`)

Drop-in GPU equivalent of
[`leaflet::addLayersControl()`](https://rstudio.github.io/leaflet/reference/addLayersControl.html).
Adds a collapsible control (defaulting to `"top-right"` or `"top-left"`)
with radio buttons for switching `baseGroups` (`"Light"`, `"Dark"`,
`"Satellite"`, etc.) and checkboxes for toggling `overlayGroups`
(`"Risks"`, `"Claims"`, `"Precipitation"`, etc.). Also emits
`input$<mapId>_groups` in Shiny so existing `leaflet` observers work
with zero changes!

## Usage

``` r
add_layers_control(
  map,
  baseGroups = c("Light", "Dark", "Satellite"),
  overlayGroups = character(0),
  position = "top-left",
  options = layers_control_options(),
  order = 10
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- baseGroups:

  Character vector of basemap group names (default
  `c("Light", "Dark", "Satellite")`).

- overlayGroups:

  Character vector of overlay group names.

- position:

  Anchor position in the 9-zone layout grid (default `"top-left"`).

- options:

  Options list from
  [`layers_control_options()`](https://meztez.github.io/glmap/reference/layers_control_options.md)
  (e.g., `list(collapsed = TRUE)`).

- order:

  Numeric draw order within the anchor zone (default `10`).
