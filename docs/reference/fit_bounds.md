# Fit Map Camera to a Bounding Box `[xmin, ymin, xmax, ymax]` (`fit_bounds`)

Fit Map Camera to a Bounding Box `[xmin, ymin, xmax, ymax]`
(`fit_bounds`)

## Usage

``` r
fit_bounds(map, bbox, padding = 40)
```

## Arguments

- map:

  A `gexplore` widget or `gexplore_proxy`.

- bbox:

  Numeric vector `c(xmin, ymin, xmax, ymax)` or an `sf`/`SpatRaster`
  object.

- padding:

  Viewport padding in pixels (default `40`).
