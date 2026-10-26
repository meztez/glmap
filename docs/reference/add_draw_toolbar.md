# Add an Interactive Vector Drawing Toolbar (`add_draw_toolbar`)

Drop-in GPU equivalent of
[`leaflet.extras::addDrawToolbar()`](https://trafficonese.github.io/leaflet.extras/reference/draw.html)
with matching formals and Shiny reactive events!

## Usage

``` r
add_draw_toolbar(
  map,
  targetGroup = NULL,
  position = c("topleft", "topright", "bottomleft", "bottomright", "top-left",
    "top-right", "bottom-left", "bottom-right", "top-center", "bottom-center",
    "center-left", "center-right"),
  polylineOptions = TRUE,
  polygonOptions = TRUE,
  circleOptions = TRUE,
  rectangleOptions = TRUE,
  markerOptions = TRUE,
  circleMarkerOptions = FALSE,
  editOptions = TRUE,
  singleFeature = FALSE,
  direction = c("vertical", "horizontal"),
  order = 15,
  toolbar = NULL
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- targetGroup:

  Optional group name for drawn features (default `"drawn_features"`).

- position:

  Toolbar position: `"topleft"`, `"topright"`, `"bottomleft"`,
  `"bottomright"` (or `"top-left"`, etc.).

- polylineOptions:

  List of options or `TRUE`/`FALSE` to enable/disable the polyline tool
  (default `TRUE`).

- polygonOptions:

  List of options or `TRUE`/`FALSE` to enable/disable the polygon tool
  (default `TRUE`).

- circleOptions:

  List of options or `TRUE`/`FALSE` to enable/disable the geodesic
  circle tool (default `TRUE`).

- rectangleOptions:

  List of options or `TRUE`/`FALSE` to enable/disable the rectangle tool
  (default `TRUE`).

- markerOptions:

  List of options or `TRUE`/`FALSE` to enable/disable the point marker
  tool (default `TRUE`).

- circleMarkerOptions:

  List of options or `TRUE`/`FALSE` to enable/disable the circle marker
  tool (default `FALSE`).

- editOptions:

  List of options or `TRUE`/`FALSE` to enable/disable feature
  deletion/clearing (default `TRUE`).

- singleFeature:

  Logical; if `TRUE`, drawing a new feature replaces previous drawn
  features (default `FALSE`).

- direction:

  Layout flow direction for the draw toolbar buttons: `"vertical"`
  (default) or `"horizontal"`.

- order:

  Numeric draw order within the anchor zone (default `15`).

- toolbar:

  Optional custom button titles created via
  [`draw_toolbar_options()`](https://meztez.github.io/glmap/reference/draw_toolbar_options.md).

## Value

Updated `glmap` widget or `glmap_proxy`.

## Details

Supports interactive drawing of **Polygons** (click vertices,
double-click or click first vertex to close), **Rectangles**
(click-drag), **Circles** (click center, drag radius in meters),
**Polylines** (click vertices, double-click to finish), and **Markers**
(click), plus clearing/deleting drawn shapes.

### Shiny Events Emitted (100% compatible with [`leaflet.extras::addDrawToolbar`](https://trafficonese.github.io/leaflet.extras/reference/draw.html)):

For a map with `outputId = "map"`:

- `input$map_draw_start`: `list(feature_type = ...)` when a drawing tool
  is activated.

- `input$map_draw_stop`: `list(feature_type = ...)` when drawing
  finishes or is cancelled.

- `input$map_draw_new_feature`: GeoJSON Feature
  `list(type = "Feature", properties = list(`\_leaflet_id` = id, feature_type = "polygon"|"rectangle"|"circle"|"polyline"|"marker", radius = r_meters), geometry = list(type = ..., coordinates = ...), wkt = "POLYGON ((...))", bbox = c(xmin, ymin, xmax, ymax))`.

- `input$map_draw_deleted_features`: GeoJSON FeatureCollection of
  deleted features.

- `input$map_draw_all_features`: GeoJSON FeatureCollection of all
  currently drawn features.
