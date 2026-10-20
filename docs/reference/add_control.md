# Configure Map UI Controls

Configure Map UI Controls

## Usage

``` r
add_control(
  map,
  type = c("navigation", "scale", "fullscreen", "layer_switcher", "hud", "draw",
    "measure"),
  enabled = TRUE,
  position = "top-right"
)
```

## Arguments

- map:

  A `gexplore` widget.

- type:

  Control type (`"navigation"`, `"scale"`, `"fullscreen"`,
  `"layer_switcher"`, `"hud"`, `"draw"`, `"measure"`).

- enabled:

  Logical; whether the control is enabled.

- position:

  Control corner (`"top-left"`, `"top-right"`, `"bottom-left"`,
  `"bottom-right"`).
