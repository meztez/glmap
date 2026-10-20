# Add a Custom Map Legend

Add a Custom Map Legend

## Usage

``` r
add_legend(map, title, colors, labels = NULL, domain = NULL, layer_id = NULL)
```

## Arguments

- map:

  A `gexplore` widget or `gexplore_proxy`.

- title:

  Legend title.

- colors:

  Character vector of hex/CSS colors.

- labels:

  Character vector of category labels (for categorical legends).

- domain:

  Numeric vector `c(min, max)` (for continuous legends).

- layer_id:

  Optional associated layer ID.
