# Add an OGC Web Map Service (WMS) Raster Tile Layer (`add_wms_tiles`)

Drop-in equivalent of
[`leaflet::addWMSTiles()`](https://rstudio.github.io/leaflet/reference/map-layers.html).
Connects to enterprise OGC WMS endpoints (GeoServer, MapServer, ArcGIS
Enterprise, gouvernement du Québec / MSC GeoMet) using
`{bbox-epsg-3857}` tile requests in MapLibre GL.

## Usage

``` r
add_wms_tiles(
  map,
  base_url,
  layers,
  styles = "",
  format = "image/png",
  transparent = TRUE,
  version = "1.1.1",
  tile_size = 256L,
  opacity = 0.8,
  api_key = NULL,
  id = NULL,
  group = NULL
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- base_url:

  Base WMS service URL (e.g., `"https://geo.weather.gc.ca/geomet"`).

- layers:

  Comma-separated WMS layer names (e.g., `"RADAR_1KM_RRAI"`).

- styles:

  Optional WMS styles parameter (default `""`).

- format:

  Image MIME type (default `"image/png"`).

- transparent:

  Logical; whether to request transparent background (default `TRUE`).

- version:

  WMS version (default `"1.1.1"` or `"1.3.0"`).

- tile_size:

  Tile size in pixels (default `256L`).

- opacity:

  Layer opacity (`0` to `1`).

- api_key:

  Optional API key appended to the WMS request URL.

- id:

  Layer ID.

- group:

  Layer group name.
