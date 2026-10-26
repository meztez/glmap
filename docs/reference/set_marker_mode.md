# Dynamically Switch Marker / Icon Rendering Strategy in Shiny (`set_marker_mode`)

Live-switches a marker or point layer between `"auto"`, `"cluster"`
(screen-space clustering + GPU singletons), `"lod"` (zoom-level
Level-of-Detail cross-fade between GPU SDF dots and WebGL2 Texture Atlas
icons), `"atlas"` (always render 100% of custom icons via WebGL2 Texture
Atlas), and `"points"` (GPU SDF circles) in 0 ms without re-sending
point coordinates.

## Usage

``` r
set_marker_mode(
  map,
  id,
  mode = c("auto", "cluster", "lod", "atlas", "points"),
  lod_zoom = NULL,
  disable_clustering_at_zoom = NULL
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- id:

  Layer ID or group name.

- mode:

  Rendering mode: `"auto"`, `"cluster"`, `"lod"`, `"atlas"`, or
  `"points"`.

- lod_zoom:

  Optional numeric zoom threshold or `c(fade_start, fade_end)` range for
  `"lod"`.

- disable_clustering_at_zoom:

  Optional numeric zoom level at which clusters expand into individual
  icons.
