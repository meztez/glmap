# Pack an sf, sfc, or data.frame object into a GLMP binary buffer (`gl_pack_sf_binary`)

Pack an sf, sfc, or data.frame object into a GLMP binary buffer
(`gl_pack_sf_binary`)

## Usage

``` r
gl_pack_sf_binary(
  data,
  lon = NULL,
  lat = NULL,
  rgba = c(30L, 144L, 255L, 210L),
  radius = numeric(0),
  elevation = numeric(0)
)
```

## Arguments

- data:

  An `sf`, `sfc`, or `data.frame` object.

- lon:

  Column name for longitude when `data` is a `data.frame`.

- lat:

  Column name for latitude when `data` is a `data.frame`.

- rgba:

  Integer vector of RGBA bytes (length 4 for constant color or
  `4 * nrow(data)`).

- radius:

  Numeric vector of radii (length 0, 1, or `nrow(data)`).

- elevation:

  Numeric vector of extrusion heights (length 0, 1, or `nrow(data)`).

## Value

A `raw` vector in `GLMP` binary format with attribute `"bbox"` and
`"geom_type"`.
