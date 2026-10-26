# Capture a High-Resolution Static PNG Screenshot of a `glmap` Widget (`gl_save_png`)

Renders a `glmap` widget in headless Chromium (`chromote`) with WebGL2
`preserveDrawingBuffer = TRUE` and captures a crisp static `.png`
snapshot suitable for Quarto PDF / LaTeX / Word reports, slides, and
automated visual testing.

## Usage

``` r
gl_save_png(map, file, vwidth = 1000, vheight = 650, delay = 1.5)
```

## Arguments

- map:

  A `glmap` widget.

- file:

  Output `.png` file path.

- vwidth, vheight:

  Viewport width and height in pixels (default `1000` x `650`).

- delay:

  Seconds to wait after page load for basemap tiles and GPU textures to
  settle (default `1.5`).

## Value

Normalized path to the saved `.png` file (invisibly).
