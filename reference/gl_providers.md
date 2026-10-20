# Basemap Tile Providers Catalog (`gl_providers`)

The `glmap` equivalent of
[`leaflet::providers`](https://rstudio.github.io/leaflet/reference/providers.html).
Provides autocomplete-friendly access to open-source Vector GL styles
(MapLibre GL JSON), global XYZ Raster tile providers, and
commercial/optional-API-key providers (CARTO, OpenFreeMap,
OpenStreetMap, Esri, OpenTopoMap, USGS, MapTiler, Stadia/Stamen,
Thunderforest, Jawg, and Mapbox).

## Usage

``` r
gl_providers
```

## Details

All providers support optional API key injection via `api_key = "..."`,
[`gl_set_api_key()`](https://meztez.github.io/glmap/reference/gl_set_api_key.md),
or environment variables (`CARTO_API_KEY`, `MAPTILER_API_KEY`,
`STADIA_API_KEY`, `THUNDERFOREST_API_KEY`, `JAWG_API_KEY`,
`MAPBOX_ACCESS_TOKEN`).

## Examples

``` r
gl_providers$CartoDB.DarkMatter
#> [1] "CartoDB.DarkMatter"
gl_providers$CartoDB.Positron
#> [1] "CartoDB.Positron"
gl_providers$Esri.WorldImagery
#> [1] "Esri.WorldImagery"
gl_providers$OpenFreeMap.Liberty
#> [1] "OpenFreeMap.Liberty"
gl_providers$MapTiler.DatavizDark
#> [1] "MapTiler.DatavizDark"
gl_providers$Stadia.AlidadeSmoothDark
#> [1] "Stadia.AlidadeSmoothDark"
```
