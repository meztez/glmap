# Add a Live Out-of-Core DuckDB / Parquet Layer (`add_duckdb`)

Connects `glmap` directly to a `DuckDB` connection (`DBI`), table name,
SQL query, or `.parquet` / `.csv` file path.

## Usage

``` r
add_duckdb(
  map,
  con = NULL,
  source,
  lon = "lon",
  lat = "lat",
  color = "#00d4ff",
  palette = "viridis",
  radius = 4,
  opacity = 0.85,
  where = NULL,
  max_features = 100000L,
  dynamic_viewport = TRUE,
  id = NULL,
  group = NULL,
  legend = TRUE
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

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

- color:

  Optional column name or formula (`~col`) to map point colors, or a
  fixed hex color (default `"#00d4ff"`).

- palette:

  Color palette name (`"viridis"`, `"plasma"`, `"turbo"`, `"magma"`,
  etc.).

- radius:

  Point radius in pixels (or formula `~col`).

- opacity:

  Point opacity (`0` to `1`).

- where:

  Optional SQL `WHERE` filter predicate string (e.g.,
  `"intensity > 50 AND category = 'Sensor'"`).

- max_features:

  Maximum features streamed per viewport frame (default `100000L`).

- dynamic_viewport:

  Logical; if `TRUE` (default), dynamically re-queries DuckDB via
  `httpuv` as the user pans/zooms.

- id:

  Optional layer ID.

- group:

  Optional layer group name shown in the GPU Layer Switcher.

- legend:

  Logical; whether to display a color legend.

## Value

Updated `glmap` map object.

## Details

Instead of loading 10M-100M+ rows into R memory, `add_duckdb()` pushes
bounding-box viewport filters
(`WHERE lon BETWEEN xmin AND xmax AND lat BETWEEN ymin AND ymax`) and
Level-of-Detail (LOD) sampling (`USING SAMPLE` or deterministic stride)
directly into DuckDB's vectorized execution engine, then packs the
resulting slice in C++17 (`cpp_pack_points_xy`) and streams the `GLMP`
binary buffer to WebGL2 over the local `httpuv` server on every
pan/zoom!
