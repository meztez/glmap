# List All Built-in Basemap Tile Providers in `glmap`

Returns a `data.frame` summarizing every built-in vector and raster tile
provider, whether it uses WebGL vector tiles (`vector_gl`) or XYZ raster
tiles (`raster_xyz`), whether an API key is required or optional, and
the environment variable name.

## Usage

``` r
gl_list_providers()
```

## Value

A `data.frame` of available tile providers.
