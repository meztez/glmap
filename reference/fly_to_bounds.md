# Smoothly Animate Camera to Bounding Box (`fly_to_bounds`)

Drop-in equivalent of `leaflet::flyToBounds()`.

## Usage

``` r
fly_to_bounds(map, bbox, padding = 40, duration = 1600)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- bbox:

  Numeric vector `c(xmin, ymin, xmax, ymax)` or an `sf`/`SpatRaster`
  object.

- padding:

  Viewport padding in pixels (default `40`).

- duration:

  Animation duration in milliseconds (default `1600`).
