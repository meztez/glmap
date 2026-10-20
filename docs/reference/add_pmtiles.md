# Add a Cloud-Native PMTiles or Mapbox Vector Tile (MVT) Layer

Add a Cloud-Native PMTiles or Mapbox Vector Tile (MVT) Layer

## Usage

``` r
add_pmtiles(
  map,
  url,
  source_layer = "default",
  layer_type = c("fill", "line", "circle", "fill-extrusion"),
  color = "#38bdf8",
  opacity = 0.75,
  id = NULL,
  group = NULL
)

add_mvt(
  map,
  url,
  source_layer = "default",
  layer_type = c("fill", "line", "circle", "fill-extrusion"),
  color = "#38bdf8",
  opacity = 0.75,
  id = NULL,
  group = NULL
)
```

## Arguments

- map:

  A `gexplore` widget or `gexplore_proxy`.

- url:

  URL to a `.pmtiles` archive or `{z}/{x}/{y}.pbf` vector tile endpoint.

- source_layer:

  Source layer name inside the vector tiles.

- layer_type:

  MapLibre layer type: `"fill"`, `"line"`, `"circle"`, or
  `"fill-extrusion"`.

- color:

  Fill/line/circle color.

- opacity:

  Layer opacity.

- id:

  Layer ID.

- group:

  Layer group name.
