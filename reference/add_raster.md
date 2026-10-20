# Add a GPU Fragment-Shader Raster Layer for `terra::SpatRaster`

Streams raw Float32 raster values (`GLMR` binary packet) directly into a
WebGL2 `R32F` floating-point texture. Colormapping, hillshading, min/max
contrast stretching, thresholding, and live pixel value inspection
happen entirely on the GPU in 0 ms without re-rendering PNGs in R.

## Usage

``` r
add_raster(
  map,
  raster = NULL,
  palette = "viridis",
  opacity = 0.85,
  domain = NULL,
  hillshade = FALSE,
  max_cells = 1000000L,
  bands = 1L,
  bbox = c(-75, 45, -71, 48),
  id = NULL,
  group = NULL,
  legend = TRUE
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- raster:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or numeric `matrix`.

- palette:

  Color palette name (`"viridis"`, `"terrain"`, `"magma"`, `"turbo"`,
  `"plasma"`, `"RdYlBu"`).

- opacity:

  Raster opacity (`0` to `1`).

- domain:

  Optional numeric `c(min, max)` value range for colormap stretching.

- hillshade:

  Logical; whether to compute real-time GPU surface normal hillshading
  in the fragment shader.

- max_cells:

  Maximum raster cells before automatic overview aggregation (default
  `1,000,000`).

- bands:

  Integer band index or indices to stream.

- bbox:

  Bounding box `c(xmin, ymin, xmax, ymax)` when `raster` is a plain
  matrix.

- id:

  Layer ID string.

- group:

  Layer group name.

- legend:

  Logical; whether to display a color ramp legend and interactive GPU
  raster controls.
