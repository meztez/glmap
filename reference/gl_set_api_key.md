# Set or Retrieve a Provider API Key (`gl_set_api_key` / `gl_get_api_key`)

Configures an API key for tile providers such as `"carto"` (`CartoDB`),
`"maptiler"`, `"stadia"`, `"thunderforest"`, `"jawg"`, `"mapbox"`, or
`"esri"`. Once set, all subsequent calls to
[`glmap()`](https://meztez.github.io/glmap/reference/glmap.md),
[`set_basemap()`](https://meztez.github.io/glmap/reference/set_basemap.md),
and
[`add_provider_tiles()`](https://meztez.github.io/glmap/reference/add_provider_tiles.md)
automatically inject the key into the provider's style URL and tile
URLs.

## Usage

``` r
gl_set_api_key(provider, api_key = NULL)

gl_get_api_key(provider)
```

## Arguments

- provider:

  Provider family name (e.g., `"carto"`, `"maptiler"`, `"stadia"`,
  `"thunderforest"`, `"jawg"`, `"mapbox"`, `"esri"`), or a named list of
  keys.

- api_key:

  API key string (or `NULL` to clear).

## Value

Invisibly returns the stored key(s).
