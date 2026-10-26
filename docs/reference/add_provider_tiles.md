# Add or Switch Basemap Provider Tiles (`add_provider_tiles`)

Drop-in equivalent of
[`leaflet::addProviderTiles()`](https://rstudio.github.io/leaflet/reference/addProviderTiles.html).
Accepts short aliases (`"dark"`, `"positron"`, `"voyager"`, `"osm"`,
`"satellite"`, `"topo"`), any provider from
[gl_providers](https://meztez.github.io/glmap/reference/gl_providers.md)
(e.g., `gl_providers$CartoDB.DarkMatter`,
`gl_providers$MapTiler.DatavizDark`,
`gl_providers$Stadia.AlidadeSmoothDark`), a custom MapLibre `style.json`
URL, or a custom `{z}/{x}/{y}` XYZ tile URL template with optional
`{apikey}` / `{key}` / `{access_token}` placeholders!

## Usage

``` r
add_provider_tiles(
  map,
  provider = gl_providers$CartoDB.DarkMatter,
  api_key = NULL,
  key_param = NULL,
  attribution = "",
  layerId = NULL,
  group = NULL,
  options = list()
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- provider:

  Provider name from
  [gl_providers](https://meztez.github.io/glmap/reference/gl_providers.md),
  short alias, style URL, or `{z}/{x}/{y}` tile URL.

- api_key:

  Optional API key string for the provider (or set globally via
  [`gl_set_api_key()`](https://meztez.github.io/glmap/reference/gl_set_api_key.md)
  / env vars).

- key_param:

  Optional query parameter name when appending `api_key` to a URL
  without placeholders (default auto-detected per provider, e.g.,
  `"key"` or `"api_key"`).

- attribution:

  Optional custom attribution string when passing a custom `{z}/{x}/{y}`
  URL.

- layerId, group, options:

  Optional arguments kept for
  [`leaflet::addProviderTiles()`](https://rstudio.github.io/leaflet/reference/addProviderTiles.html)
  compatibility.

## Value

Updated `glmap` object.
