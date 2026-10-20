# Pack a terra SpatRaster or matrix into a GLMR Float32 binary buffer (`gl_pack_raster_binary`)

Pack a terra SpatRaster or matrix into a GLMR Float32 binary buffer
(`gl_pack_raster_binary`)

## Usage

``` r
gl_pack_raster_binary(
  raster,
  max_cells = 1000000L,
  bands = 1L,
  bbox = c(-75, 45, -71, 48)
)
```

## Arguments

- raster:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  object, or a numeric `matrix`.

- max_cells:

  Maximum number of cells to stream (downsamples overview if exceeded).

- bands:

  Integer vector of band indices to include (default `1L`).

- bbox:

  Numeric vector `c(xmin, ymin, xmax, ymax)` when `raster` is a matrix.

## Value

A `raw` vector in `GLMR` Float32 binary format with metadata attributes.
