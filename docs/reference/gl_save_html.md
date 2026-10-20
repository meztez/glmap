# Save a `glmap` Map to a Standalone HTML File (`gl_save_html`)

Save a `glmap` Map to a Standalone HTML File (`gl_save_html`)

## Usage

``` r
gl_save_html(map, file, selfcontained = FALSE, title = "glmap GPU Map")

gx_save_html(map, file, selfcontained = FALSE, title = "glmap GPU Map")
```

## Arguments

- map:

  A `glmap` widget.

- file:

  Output HTML file path.

- selfcontained:

  Logical; whether to bundle JS/CSS assets into a single HTML file.

- title:

  HTML page title.

## Value

Normalized path to the saved HTML file (invisibly).
