# Create a Shiny Proxy for a `glmap` Map Widget

Allows updating an existing `glmap` map in a running Shiny application
(adding/removing layers, updating GPU raster colormaps/contrast, flying
to bounds, or filtering millions of features on the GPU) without
re-rendering the base map widget.

## Usage

``` r
glmap_proxy(outputId, session = NULL, data = NULL, deferUntilFlush = TRUE)

gexplore_proxy(outputId, session = NULL, data = NULL, deferUntilFlush = TRUE)
```

## Arguments

- outputId:

  The ID of the `glmapOutput` control in the Shiny UI.

- session:

  The Shiny `session` object (defaults to
  [`shiny::getDefaultReactiveDomain()`](https://rdrr.io/pkg/shiny/man/domains.html)).

- data:

  Optional default data object associated with proxy calls.

- deferUntilFlush:

  Logical; whether to buffer commands until after the next reactive
  flush.

## Value

A `glmap_proxy` object that can be piped into `add_*()`,
[`clear_layer()`](https://meztez.github.io/glmap/reference/clear_layer.md),
[`fly_to()`](https://meztez.github.io/glmap/reference/fly_to.md), etc.
