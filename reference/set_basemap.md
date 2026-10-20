# Change the Map Basemap Style (`set_basemap`)

Change the Map Basemap Style (`set_basemap`)

## Usage

``` r
set_basemap(map, basemap = "dark", api_key = NULL)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- basemap:

  Basemap name (`"dark"`, `"positron"`, `"voyager"`, `"osm"`,
  `"satellite"`, `"none"`), a provider from
  [gl_providers](https://meztez.github.io/glmap/reference/gl_providers.md),
  or a custom style / tile URL.

- api_key:

  Optional API key string for the provider (or set via
  [`gl_set_api_key()`](https://meztez.github.io/glmap/reference/gl_set_api_key.md)
  / env vars).
