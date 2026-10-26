# Add a Custom Deck.gl / External Layer Specification

Allows R extension packages to dispatch arbitrary `deck.gl` or
`MapLibre` custom layer specifications fed by `GLMP` binary buffers or
JSON props.

## Usage

``` r
add_deck_layer(
  map,
  deck_type,
  data = NULL,
  props = list(),
  id = NULL,
  group = NULL
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- deck_type:

  Deck.gl layer class name (e.g., `"ArcLayer"`, `"ScatterplotLayer"`,
  `"TripsLayer"`, `"PathLayer"`).

- data:

  Optional `sf` or `data.frame` packed into a binary buffer.

- props:

  Named list of layer properties.

- id:

  Layer ID.

- group:

  Layer group name.
