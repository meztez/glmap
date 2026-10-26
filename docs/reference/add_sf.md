# Automatically Add an `sf`, `sfc`, or `data.frame` Layer to a `glmap` Map

Inspects the geometry type of `data` (`POINT`, `LINESTRING`, `POLYGON`,
etc.) and routes to
[`add_points()`](https://meztez.github.io/glmap/reference/add_points.md),
[`add_lines()`](https://meztez.github.io/glmap/reference/add_lines.md),
or
[`add_polygons()`](https://meztez.github.io/glmap/reference/add_polygons.md).

## Usage

``` r
add_sf(map, data = NULL, ...)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- data:

  An `sf`, `sfc`, or `data.frame` object (defaults to map data).

- ...:

  Arguments passed on to
  [`add_points()`](https://meztez.github.io/glmap/reference/add_points.md),
  [`add_lines()`](https://meztez.github.io/glmap/reference/add_lines.md),
  or
  [`add_polygons()`](https://meztez.github.io/glmap/reference/add_polygons.md).
