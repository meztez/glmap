# Configure Map UI Controls & 9-Zone Layout Anchoring (`add_control`)

Configures built-in map controls and positions them inside `glmap`'s
**9-zone directional layout grid** (`x = left | center | right`,
`y = top | center | bottom`).

## Usage

``` r
add_control(
  map,
  type = c("navigation", "scale", "attribution", "fullscreen", "layer_switcher", "hud",
    "toolbar", "legends", "draw", "measure", "search"),
  enabled = TRUE,
  position = "top-right",
  direction = c("vertical", "horizontal"),
  order = 10,
  collapsed = NULL
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- type:

  Control type (`"navigation"`, `"scale"`, `"attribution"`,
  `"fullscreen"`, `"layer_switcher"`, `"hud"`, `"toolbar"`, `"legends"`,
  `"draw"`, `"measure"`, `"search"`).

- enabled:

  Logical; whether the control is enabled.

- position:

  One of the 9 anchor positions (`"top-left"`, `"top-center"`,
  `"top-right"`, `"center-left"`, `"center-center"`, `"center-right"`,
  `"bottom-left"`, `"bottom-center"`, `"bottom-right"`, or `"topleft"`,
  `"bottomright"`, etc.).

- direction:

  Layout flow direction for the anchor slot: `"vertical"` (default) or
  `"horizontal"`.

- order:

  Numeric draw order within the anchor slot (default `10`).

- collapsed:

  Logical; for `"layer_switcher"`, whether the panel starts collapsed as
  a compact button (default `TRUE`).

## Details

Each of the 9 anchor zones (`"top-left"`, `"top-center"`, `"top-right"`,
`"center-left"`, `"center-center"`, `"center-right"`, `"bottom-left"`,
`"bottom-center"`, `"bottom-right"`) automatically stacks its child
controls in a configurable `direction` (`"vertical"` or `"horizontal"`)
sorted by `order` (lowest first), so controls, draw tools, legends,
scale bar, and attribution labels never overlap!
