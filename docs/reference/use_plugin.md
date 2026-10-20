# Attach a Registered or Inline Plugin to a `gexplore` Map

Attach a Registered or Inline Plugin to a `gexplore` Map

## Usage

``` r
use_plugin(
  map,
  name,
  config = list(),
  js_init = NULL,
  css = NULL,
  dependencies = NULL
)
```

## Arguments

- map:

  A `gexplore` widget or `gexplore_proxy`.

- name:

  Name of a registered plugin (see
  [`register_plugin()`](https://meztez.github.io/glmap/reference/register_plugin.md)
  and
  [`list_plugins()`](https://meztez.github.io/glmap/reference/list_plugins.md)).

- config:

  Named list of options merged into the plugin's `default_config`.

- js_init:

  Optional ad-hoc JavaScript initialization function string if `name` is
  not pre-registered.

- css:

  Optional ad-hoc CSS string.

- dependencies:

  Optional list of
  [`htmltools::htmlDependency`](https://rstudio.github.io/htmltools/reference/htmlDependency.html)
  objects.
