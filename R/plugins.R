#' Register a Reusable `glmap` Extension Plugin
#'
#' Allows external R packages (such as `glmap.extras`, `glmap.deck`, or custom
#' internal packages) to register JavaScript/CSS dependencies and initialization
#' hooks that have full access to the `MapLibre GL` instance, WebGL2 context,
#' and `glmap` binary buffer store.
#'
#' @param name Unique plugin identifier string (e.g., `"minimap"`, `"turf"`, `"pulse_markers"`).
#' @param js_init JavaScript function body or expression `(function(instance, config) { ... })`
#'   executed when the plugin is attached to a map.
#' @param css Optional CSS stylesheet string injected by the plugin.
#' @param dependencies Optional list of `htmltools::htmlDependency` objects.
#' @param default_config Optional default configuration list passed to `js_init`.
#' @return Invisibly returns the registered plugin specification.
#' @export
register_plugin <- function(
    name,
    js_init,
    css = NULL,
    dependencies = NULL,
    default_config = list()
) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    cli::cli_abort("`name` must be a non-empty string.")
  }
  spec <- list(
    name = name,
    js_init = as.character(js_init),
    css = css,
    dependencies = dependencies,
    default_config = default_config
  )
  assign(name, spec, envir = .gl_env$plugins)
  invisible(spec)
}

#' Attach a Registered or Inline Plugin to a `glmap` Map
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param name Name of a registered plugin (see [register_plugin()] and [list_plugins()]).
#' @param config Named list of options merged into the plugin's `default_config`.
#' @param js_init Optional ad-hoc JavaScript initialization function string if `name` is not pre-registered.
#' @param css Optional ad-hoc CSS string.
#' @param dependencies Optional list of `htmltools::htmlDependency` objects.
#' @export
use_plugin <- function(
    map,
    name,
    config = list(),
    js_init = NULL,
    css = NULL,
    dependencies = NULL
) {
  init_built_in_plugins()

  if (exists(name, envir = .gl_env$plugins, inherits = FALSE)) {
    reg <- get(name, envir = .gl_env$plugins, inherits = FALSE)
    js_init <- js_init %||% reg$js_init
    css <- css %||% reg$css
    dependencies <- dependencies %||% reg$dependencies
    merged_cfg <- utils::modifyList(reg$default_config %||% list(), config %||% list())
  } else if (!is.null(js_init)) {
    merged_cfg <- config %||% list()
  } else {
    cli::cli_abort("Plugin {.val {name}} is not registered. Use {.fn register_plugin} or supply `js_init`.")
  }

  plugin_entry <- list(
    name = name,
    js_init = js_init,
    css = css,
    config = merged_cfg
  )

  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "usePlugin", plugin_entry))
  }

  map$x$plugins[[length(map$x$plugins) + 1L]] <- plugin_entry
  if (!is.null(dependencies)) {
    if (inherits(dependencies, "html_dependency")) {
      dependencies <- list(dependencies)
    }
    map$dependencies <- c(map$dependencies %||% list(), dependencies)
  }
  map
}

#' List Available `glmap` Plugins
#'
#' @return Character vector of registered plugin names.
#' @export
list_plugins <- function() {
  init_built_in_plugins()
  ls(.gl_env$plugins)
}

#' Add a Custom WebGL2 Shader Layer to a `glmap` Map
#'
#' Enables R developers and extension packages to write custom GLSL vertex and
#' fragment shaders driven by `GLMP` binary coordinate/attribute buffers.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param data Optional `sf`, `sfc`, or `data.frame` packed into a `GLMP` binary buffer for the shader.
#' @param vertex_shader Custom GLSL vertex shader source string.
#' @param fragment_shader Custom GLSL fragment shader source string.
#' @param uniforms Named list of uniform values passed to the shader program.
#' @param draw_mode WebGL draw mode: `"POINTS"`, `"LINES"`, `"LINE_STRIP"`, or `"TRIANGLES"`.
#' @param id Layer ID.
#' @param group Layer group name.
#' @export
add_webgl_shader_layer <- function(
    map,
    data = NULL,
    vertex_shader = NULL,
    fragment_shader = NULL,
    uniforms = list(),
    draw_mode = c("POINTS", "TRIANGLES", "LINES", "LINE_STRIP"),
    id = NULL,
    group = NULL
) {
  draw_mode <- match.arg(draw_mode)
  id <- id %||% next_layer_id("shader")
  group <- group %||% id

  buf_spec <- NULL
  bbox <- NULL
  n_features <- 0L
  n_vertices <- 0L

  if (!is.null(data)) {
    raw_buf <- gl_pack_sf_binary(data)
    transport_mode <- if (inherits(map, "glmap_proxy")) "inline" else (map$x$transport %||% "auto")
    buf_spec <- register_binary_buffer(id, raw_buf, mode = transport_mode)
    bbox <- attr(raw_buf, "bbox")
    n_features <- attr(raw_buf, "n_features")
    n_vertices <- attr(raw_buf, "n_vertices")
  }

  layer_spec <- list(
    id = id,
    group = group,
    type = "custom_shader",
    visible = TRUE,
    opacity = 1.0,
    n_features = n_features,
    n_vertices = n_vertices,
    bbox = bbox,
    buffer = buf_spec,
    vertex_shader = vertex_shader,
    fragment_shader = fragment_shader,
    uniforms = uniforms,
    draw_mode = draw_mode
  )

  dispatch_layer(map, layer_spec, NULL, bbox)
}

#' Add a Custom Deck.gl / External Layer Specification
#'
#' Allows R extension packages to dispatch arbitrary `deck.gl` or `MapLibre`
#' custom layer specifications fed by `GLMP` binary buffers or JSON props.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param deck_type Deck.gl layer class name (e.g., `"ArcLayer"`, `"ScatterplotLayer"`, `"TripsLayer"`, `"PathLayer"`).
#' @param data Optional `sf` or `data.frame` packed into a binary buffer.
#' @param props Named list of layer properties.
#' @param id Layer ID.
#' @param group Layer group name.
#' @export
add_deck_layer <- function(
    map,
    deck_type,
    data = NULL,
    props = list(),
    id = NULL,
    group = NULL
) {
  id <- id %||% next_layer_id("deck")
  group <- group %||% id

  buf_spec <- NULL
  bbox <- NULL
  if (!is.null(data)) {
    raw_buf <- gl_pack_sf_binary(data)
    transport_mode <- if (inherits(map, "glmap_proxy")) "inline" else (map$x$transport %||% "auto")
    buf_spec <- register_binary_buffer(id, raw_buf, mode = transport_mode)
    bbox <- attr(raw_buf, "bbox")
  }

  layer_spec <- list(
    id = id,
    group = group,
    type = "deck_layer",
    deck_type = as.character(deck_type),
    visible = TRUE,
    opacity = props$opacity %||% 0.85,
    bbox = bbox,
    buffer = buf_spec,
    props = props
  )

  dispatch_layer(map, layer_spec, NULL, bbox)
}

init_built_in_plugins <- function() {
  if (exists("measure", envir = .gl_env$plugins, inherits = FALSE)) return(invisible())

  # 1. Interactive geodesic distance measurement tool
  register_plugin(
    name = "measure",
    default_config = list(position = "top-right", units = "km"),
    js_init = "function(instance, config) {
      if (instance && typeof instance.enableMeasureTool === 'function') {
        instance.enableMeasureTool(config);
      }
    }"
  )

  # 2. Interactive bounding-box / lasso selection & spatial query plugin
  register_plugin(
    name = "lasso_select",
    default_config = list(color = "#38bdf8"),
    js_init = "function(instance, config) {
      if (instance && typeof instance.enableBoxSelect === 'function') {
        instance.enableBoxSelect(config);
      }
    }"
  )

  # 3. Mini-map overview plugin
  register_plugin(
    name = "minimap",
    default_config = list(width = 160, height = 110, zoom_offset = -4),
    js_init = "function(instance, config) {
      if (instance && typeof instance.enableMiniMap === 'function') {
        instance.enableMiniMap(config);
      }
    }"
  )

  # 4. Screenshot / high-DPI PNG export button plugin
  register_plugin(
    name = "export_png",
    default_config = list(filename = "glmap-map.png"),
    js_init = "function(instance, config) {
      if (instance && typeof instance.enableExportButton === 'function') {
        instance.enableExportButton(config);
      }
    }"
  )
}
