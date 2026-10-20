# Create a High-Performance GPU Map Widget (`glmap`)

Initializes a `glmap` WebGL2 + MapLibre GL interactive map widget. If
`data` is supplied (`sf`, `sfc`, `SpatRaster`, `SpatVector`,
[`wk::xy`](https://paleolimbot.github.io/wk/reference/xy.html),
`nanoarrow`, `data.frame`, or
[`crosstalk::SharedData`](https://rdrr.io/pkg/crosstalk/man/SharedData.html)),
`glmap()` automatically inspects its type and adds the appropriate GPU
layer unless layers are added downstream via pipes (`|>`).

## Usage

``` r
glmap(
  data = NULL,
  basemap = "dark",
  api_key = NULL,
  center = NULL,
  zoom = NULL,
  pitch = 0,
  bearing = 0,
  projection = c("mercator", "globe"),
  transport = c("auto", "inline", "server"),
  width = "100%",
  height = NULL,
  elementId = NULL,
  auto_layer = TRUE,
  ...
)
```

## Arguments

- data:

  Optional default spatial dataset (`sf`, `sfc`, `SpatRaster`,
  `data.frame`, or `SharedData`).

- basemap:

  Basemap style name (`"dark"`, `"positron"`, `"voyager"`, `"osm"`,
  `"satellite"`, `"none"`), a provider from
  [gl_providers](https://meztez.github.io/glmap/reference/gl_providers.md),
  or a custom MapLibre style URL / `{z}/{x}/{y}` template.

- api_key:

  Optional API key string for the basemap provider (can also be
  configured globally via
  [`gl_set_api_key()`](https://meztez.github.io/glmap/reference/gl_set_api_key.md)
  or environment variables such as `CARTO_API_KEY`, `MAPTILER_API_KEY`,
  `STADIA_API_KEY`).

- center:

  Numeric vector `c(lon, lat)` for initial map center. Auto-computed
  from layers if `NULL`.

- zoom:

  Numeric initial zoom level.

- pitch:

  Numeric initial tilt angle in degrees (`0` to `85`).

- bearing:

  Numeric initial rotation bearing in degrees.

- projection:

  Map projection: `"mercator"` (default) or `"globe"`.

- transport:

  Binary transport mode: `"auto"` (inline gzipped binary up to 25 MB,
  works in static HTML & Viewer), `"server"` (streams via local `httpuv`
  binary range server), or `"inline"`.

- width:

  Widget width (CSS units).

- height:

  Widget height (CSS units).

- elementId:

  Optional HTML element ID.

- auto_layer:

  Logical; if `TRUE` and `data` is provided, automatically adds a
  default GPU layer when the map is printed/rendered if no explicit
  `add_*()` layers were called.

- ...:

  Additional arguments passed to the default layer when
  `auto_layer = TRUE`.

## Value

An `htmlwidget` object of class `c("glmap", "glmap", "htmlwidget")`.
