# Add Custom Icon or Awesome Markers (`add_markers`, `make_icon`, `make_awesome_icon`)

Drop-in GPU/Canvas equivalents of `leaflet::addMarkers()`,
`leaflet::makeIcon()`, and `leaflet::makeAwesomeIcon()`. Supports
per-feature SVG/PNG icon URLs as well as colored pin/badge markers.

Configures how `glmap` balances visual fidelity and 60 FPS GPU
throughput across the three marker rendering engines:

1.  **WebGL2 Texture Atlas (`"atlas"`)**: Packs all unique SVG/PNG icons
    into a single GPU sprite sheet texture and renders 100k+ custom
    icons in 1 `gl.POINTS` draw call.

2.  **Screen-Space Grid Clustering (`"cluster"`)**: Groups nearby
    markers into interactive count badges (`< 10`, `< 100`, `100+`) that
    zoom into cluster bounds on click and render unclustered singletons
    via the GPU Texture Atlas.

3.  **Zoom-Level Level-of-Detail Hybrid (`"lod"`)**: Renders crisp GPU
    SDF points at overview zoom levels and smoothly cross-fades into
    full custom SVG/PNG Texture Atlas icons as you zoom in across
    `lod_zoom`.

## Usage

``` r
add_markers(
  map,
  data = NULL,
  lng = NULL,
  lat = NULL,
  icon = NULL,
  popup = NULL,
  label = NULL,
  group = NULL,
  clusterOptions = NULL,
  render_mode = "auto",
  lod_zoom = NULL,
  id = NULL,
  ...
)

make_icon(iconUrl, iconWidth = 28, iconHeight = 28)

make_awesome_icon(text = "*", markerColor = "blue", iconColor = "#ffffff")

marker_cluster_options(
  showCoverageOnHover = TRUE,
  zoomToBoundsOnClick = TRUE,
  spiderfyOnMaxZoom = TRUE,
  disableClusteringAtZoom = 21,
  maxClusterRadius = 65,
  freezeAtZoom = FALSE
)

icon_render_options(
  mode = c("auto", "atlas", "cluster", "lod", "points"),
  lod_zoom = NULL,
  atlas_cell_px = 64L,
  allow_ui_switcher = TRUE
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- data:

  An `sf`, `sfc`, or `data.frame` object.

- lng:

  Optional alias for `lon` (`leaflet` compatibility).

- lat:

  Optional latitude column name or formula (`~lat`) for `data.frame`.

- icon:

  Optional marker icon specification created by `make_icon()`,
  `make_awesome_icon()`, `leaflet::makeIcon()`, or a character vector /
  formula (`~icon_url`) of SVG/PNG URLs.

- popup:

  Optional formula (`~name`), column name, or character vector for
  click/hover tooltips.

- label:

  Alias for `popup`.

- group:

  Layer group name shown in the interactive layer switcher.

- clusterOptions:

  Optional clustering specification (`leaflet::markerClusterOptions()`
  or `marker_cluster_options()` compatibility).

- render_mode:

  Rendering strategy for markers/icons: `"auto"` (default; dynamically
  combines clustering, zoom-level LOD cross-fade, and WebGL2 Texture
  Atlas sprites based on feature count and `clusterOptions`),
  `"cluster"` (screen-space clustering + GPU singleton sprites), `"lod"`
  (zoom-level Level-of-Detail cross-fade from GPU SDF points at overview
  zooms to full WebGL2 Texture Atlas sprites when zoomed in), `"atlas"`
  (always render 100% of custom icons via the WebGL2 Texture Atlas
  sprite shader in 1 GPU draw call), or `"points"` (pure GPU SDF
  circles). Can also be an `icon_render_options()` object.

- lod_zoom:

  Numeric zoom threshold (e.g. `10`) or 2-element cross-fade range
  `c(9, 11)`. If `NULL`, computed dynamically from feature count
  (`<= 2,500`: `c(0, 0)` always icons; `2,501-15,000`: `c(8.5, 10.5)`;
  `> 15,000`: `c(10.0, 12.0)`).

- id:

  Layer ID string.

- ...:

  Additional arguments passed to
  [`add_points()`](https://meztez.github.io/glmap/reference/add_points.md).

- iconUrl:

  URL or relative path (e.g. inside Shiny `www/`) to an SVG or PNG icon.

- iconWidth, iconHeight:

  Icon dimensions in pixels (default `28`).

- text:

  Optional short symbol or glyph text inside the awesome marker pin.

- markerColor:

  Marker pin color (e.g., `"red"`, `"blue"`, `"orange"`, `"green"`,
  `"purple"`).

- iconColor:

  Inner glyph color (default `"#ffffff"`).

- showCoverageOnHover:

  Logical; highlight cluster bounds on hover.

- zoomToBoundsOnClick:

  Logical; zoom to cluster bounds when clicked (default `TRUE`).

- spiderfyOnMaxZoom:

  Logical; expand overlapping points at max zoom.

- disableClusteringAtZoom:

  Numeric zoom level at or above which individual markers/icons are
  shown directly (default `15`).

- maxClusterRadius:

  Maximum radius in pixels that a cluster will cover (default `65`).

- freezeAtZoom:

  Optional zoom level to freeze clusters.

- mode:

  Strategy name: `"auto"` (default; dynamically selects based on
  `clusterOptions` and feature count `n`), `"atlas"`, `"cluster"`,
  `"lod"`, or `"points"`.

- atlas_cell_px:

  Resolution in pixels of each sprite slot in the GPU Texture Atlas
  (default `64L`).

- allow_ui_switcher:

  Logical; if `TRUE` (default), exposes a compact mode selector in the
  map's layer control so users can switch between `Auto`, `Cluster`,
  `LOD`, and `GPU Atlas` live.
