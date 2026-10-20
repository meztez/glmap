# Register a Reusable `glmap` Extension Plugin

Allows external R packages (such as `glmap.extras`, `glmap.deck`, or
custom internal packages) to register JavaScript/CSS dependencies and
initialization hooks that have full access to the `MapLibre GL`
instance, WebGL2 context, and `glmap` binary buffer store.

## Usage

``` r
register_plugin(
  name,
  js_init,
  css = NULL,
  dependencies = NULL,
  default_config = list()
)
```

## Arguments

- name:

  Unique plugin identifier string (e.g., `"minimap"`, `"turf"`,
  `"pulse_markers"`).

- js_init:

  JavaScript function body or expression
  `(function(instance, config) { ... })` executed when the plugin is
  attached to a map.

- css:

  Optional CSS stylesheet string injected by the plugin.

- dependencies:

  Optional list of
  [`htmltools::htmlDependency`](https://rstudio.github.io/htmltools/reference/htmlDependency.html)
  objects.

- default_config:

  Optional default configuration list passed to `js_init`.

## Value

Invisibly returns the registered plugin specification.
