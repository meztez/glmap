# Restrict Map Panning to Maximum Bounding Box (`set_max_bounds`)

Drop-in equivalent of `leaflet::setMaxBounds()`.

## Usage

``` r
set_max_bounds(map, bbox)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- bbox:

  Numeric vector `c(xmin, ymin, xmax, ymax)` or `sf`/`SpatRaster`.
