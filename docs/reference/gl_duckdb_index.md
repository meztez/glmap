# Create a DuckDB Out-of-Core Spatial Query Index (`gl_duckdb_index`)

Wraps a DuckDB connection + table, SQL query, or `.parquet` file so
`glmap` can push bounding-box and SQL filter queries down to DuckDB on
the fly.

## Usage

``` r
gl_duckdb_index(
  con = NULL,
  source,
  lon = "lon",
  lat = "lat",
  color_col = NULL,
  color_fixed = "#00d4ff",
  palette = "viridis",
  opacity = 0.85,
  rad_col = NULL,
  rad_fixed = 4,
  where = NULL,
  max_features = 100000L
)

gx_duckdb_index(
  con = NULL,
  source,
  lon = "lon",
  lat = "lat",
  color_col = NULL,
  color_fixed = "#00d4ff",
  palette = "viridis",
  opacity = 0.85,
  rad_col = NULL,
  rad_fixed = 4,
  where = NULL,
  max_features = 100000L
)
```

## Arguments

- con:

  A `DBIConnection` (DuckDB), or `NULL` if `source` is a
  `.parquet`/`.csv` file path or `data.frame`.

- source:

  A table name, SQL `SELECT` query, `.parquet` file path, or
  `data.frame` to register in DuckDB.

- lon:

  Name of the longitude column (default `"lon"`).

- lat:

  Name of the latitude column (default `"lat"`).

- color_col:

  Optional column name for color mapping.

- color_fixed:

  Fixed hex color when `color_col` is `NULL`.

- palette:

  Color palette name (`"viridis"`, `"plasma"`, `"turbo"`, `"magma"`,
  etc.).

- opacity:

  Point opacity (`0` to `1`).

- rad_col:

  Optional column name for radius mapping.

- rad_fixed:

  Fixed numeric radius when `rad_col` is `NULL`.

- where:

  Optional SQL `WHERE` filter predicate string (e.g.,
  `"intensity > 50 AND category = 'Sensor'"`).

- max_features:

  Maximum features streamed per viewport frame (default `100000L`).

## Value

A `gx_duckdb_index` object.
