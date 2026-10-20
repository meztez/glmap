# Generate Compact HTML Table Popups (`gl_popup_table`)

Drop-in GPU-friendly replacement for `leafpop::popupTable()`. Formats
selected columns of an `sf`, `SpatVector`, or `data.frame` into compact,
styled HTML tables suitable for `popup = gl_popup_table(df)` in
[`add_points()`](https://meztez.github.io/glmap/reference/add_points.md),
[`add_polygons()`](https://meztez.github.io/glmap/reference/add_polygons.md),
or
[`add_lines()`](https://meztez.github.io/glmap/reference/add_lines.md).

## Usage

``` r
gl_popup_table(data, zcol = NULL, row_numbers = FALSE, feature_id = FALSE)
```

## Arguments

- data:

  An `sf`, `SpatVector`, or `data.frame` object.

- zcol:

  Optional integer or character vector of columns to include (defaults
  to up to 8 non-geometry columns).

- row_numbers:

  Logical; kept for compatibility with `leafpop::popupTable()` (default
  `FALSE`).

- feature_id:

  Logical; kept for compatibility with `leafpop::popupTable()` (default
  `FALSE`).

## Value

A character vector of HTML table strings (one per row in `data`).
