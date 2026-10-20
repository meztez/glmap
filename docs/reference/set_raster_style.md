# Live-Update a GPU Raster Layer's Colormap, Contrast Range, or Hillshading (0ms GPU Update)

Updates uniforms and the 1D LUT texture in the WebGL2 raster fragment
shader without re-transferring the underlying Float32 raster values.

## Usage

``` r
set_raster_style(map, id, palette = NULL, domain = NULL, hillshade = NULL)
```

## Arguments

- map:

  A `gexplore` widget or `gexplore_proxy`.

- id:

  Raster layer ID.

- palette:

  New palette name (`"viridis"`, `"magma"`, `"turbo"`, `"terrain"`,
  `"RdYlBu"`).

- domain:

  Optional numeric `c(vmin, vmax)` contrast stretch limits.

- hillshade:

  Optional logical to toggle real-time GPU hillshading.
