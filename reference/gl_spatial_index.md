# Build an in-memory C++ spatial index for fast viewport queries (`gl_spatial_index`)

Build an in-memory C++ spatial index for fast viewport queries
(`gl_spatial_index`)

## Usage

``` r
gl_spatial_index(data, grid_res = 64L, lon = NULL, lat = NULL)
```

## Arguments

- data:

  An `sf`, `sfc`, or `data.frame` with `x`/`y` or `lon`/`lat`.

- grid_res:

  Grid resolution along each axis (default `64L`, i.e. 4,096 spatial
  buckets).

- lon:

  Optional longitude column name for `data.frame`.

- lat:

  Optional latitude column name for `data.frame`.

## Value

A `gl_spatial_index` object holding the C++ external pointer and dataset
reference.
