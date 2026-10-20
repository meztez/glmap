# Query a spatial index for features intersecting a bounding box (`gl_query_index`)

Query a spatial index for features intersecting a bounding box
(`gl_query_index`)

## Usage

``` r
gl_query_index(index, bbox, max_features = 0L)

gx_query_index(index, bbox, max_features = 0L)
```

## Arguments

- index:

  A `gx_spatial_index` object created by
  [`gl_spatial_index()`](https://meztez.github.io/glmap/reference/gl_spatial_index.md).

- bbox:

  Numeric vector `c(xmin, ymin, xmax, ymax)`.

- max_features:

  Optional cap on returned features (uses deterministic stride LOD
  sampling).

## Value

Integer vector of 1-based feature indices.
