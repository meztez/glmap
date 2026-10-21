# Configure Custom Tooltip Titles for `add_draw_toolbar()` (`draw_toolbar_options`)

Drop-in equivalent of `leaflet.extras::toolbarOptions()`.

## Usage

``` r
draw_toolbar_options(
  actions = list(title = "Cancel drawing", text = "Cancel"),
  finish = list(title = "Finish drawing", text = "Finish"),
  buttons = list(polygon = "Draw a polygon", rectangle = "Draw a rectangle", circle =
    "Draw a circle", polyline = "Draw a polyline", marker = "Draw a marker")
)
```

## Arguments

- actions:

  Named list of action button tooltips.

- finish:

  Named list of finish button tooltips.

- buttons:

  Named list of tool button tooltips (`polygon`, `rectangle`, `circle`,
  `polyline`, `marker`).
