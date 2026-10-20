# Add a GPU Text / Symbol Label Layer (`add_labels`)

Renders crisp halo-outlined text labels anchored to `sf` points, polygon
centroids, or `data.frame` coordinates.

## Usage

``` r
add_labels(
  map,
  data = NULL,
  text,
  lon = NULL,
  lat = NULL,
  size = 12,
  color = "#f8fafc",
  halo_color = "#0f172a",
  id = NULL,
  group = NULL
)
```

## Arguments

- map:

  A `gexplore` widget or `gexplore_proxy`.

- data:

  An `sf`, `sfc`, or `data.frame` object.

- text:

  Formula (`~name`), column name string, or character vector of label
  texts.

- lon:

  Optional longitude column name or formula (`~lon`).

- lat:

  Optional latitude column name or formula (`~lat`).

- size:

  Font size in pixels (default `12`).

- color:

  Text color (default `"#f8fafc"`).

- halo_color:

  Halo outline color for contrast (default `"#0f172a"`).

- id:

  Layer ID.

- group:

  Layer group name.
