# Fit Map Camera to a Bounding Box `[xmin, ymin, xmax, ymax]` (`fit_bounds`)

Supports both `fit_bounds(map, c(xmin, ymin, xmax, ymax))` (or an
`sf`/`SpatRaster` object) and
`leaflet::fitBounds(map, lng1, lat1, lng2, lat2)` 4-argument calls
(including formulas `~min(long)`).

## Usage

``` r
fit_bounds(map, bbox, lat1 = NULL, lng2 = NULL, lat2 = NULL, padding = 40)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- bbox:

  Numeric vector `c(xmin, ymin, xmax, ymax)`, `sf`/`SpatRaster` object,
  or `lng1`.

- lat1:

  Optional `lat1` when called with 4 coordinate arguments
  (`lng1, lat1, lng2, lat2`).

- lng2:

  Optional `lng2` when called with 4 coordinate arguments.

- lat2:

  Optional `lat2` when called with 4 coordinate arguments.

- padding:

  Viewport padding in pixels (default `40`).
