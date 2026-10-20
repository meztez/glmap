# Convert a `glmap` Selection or Bounds Event into a WKT Polygon (`gl_bbox_to_wkt`)

Converts either a numeric vector `c(xmin, ymin, xmax, ymax)` or a Shiny
`input$map_selected` / `input$map_bounds` list directly into an
`EPSG:4326` `POLYGON ((...))` WKT string ready for Snowflake
`ST_WITHIN(GEOGRAPHY, TO_GEOGRAPHY(?))` or DuckDB Spatial
`ST_Intersects(geom, ST_GeomFromText(?))`.

## Usage

``` r
gl_bbox_to_wkt(x)
```

## Arguments

- x:

  A numeric vector `c(xmin, ymin, xmax, ymax)`, or a list from
  `input$map_selected` / `input$map_bounds`.

## Value

A single WKT `POLYGON ((...))` character string.
