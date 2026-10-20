# Shiny Server Render Function for `glmap`

Shiny Server Render Function for `glmap`

## Usage

``` r
renderGlmap(expr, env = parent.frame(), quoted = FALSE)

renderGexplore(expr, env = parent.frame(), quoted = FALSE)
```

## Arguments

- expr:

  An expression that generates a `glmap` widget.

- env:

  The environment in which to evaluate `expr`.

- quoted:

  Is `expr` a quoted expression (`with quote()`)?
