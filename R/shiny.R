#' Create a Shiny Proxy for a `glmap` Map Widget
#'
#' Allows updating an existing `glmap` map in a running Shiny application
#' (adding/removing layers, updating GPU raster colormaps/contrast, flying to
#' bounds, or filtering millions of features on the GPU) without re-rendering
#' the base map widget.
#'
#' @param outputId The ID of the `glmapOutput` control in the Shiny UI.
#' @param session The Shiny `session` object (defaults to `shiny::getDefaultReactiveDomain()`).
#' @param data Optional default data object associated with proxy calls.
#' @param deferUntilFlush Logical; whether to buffer commands until after the next reactive flush.
#' @return A `glmap_proxy` object that can be piped into `add_*()`, `clear_layer()`, `fly_to()`, etc.
#' @export
glmap_proxy <- function(
    outputId,
    session = NULL,
    data = NULL,
    deferUntilFlush = TRUE
) {
  if (is.null(session)) {
    if (requireNamespace("shiny", quietly = TRUE)) {
      session <- shiny::getDefaultReactiveDomain()
    }
  }
  if (!is.null(session) && inherits(session, " shiny_scope")) {
    outputId <- session$ns(outputId)
  } else if (!is.null(session) && is.function(session$ns) && !startsWith(outputId, session$ns(""))) {
    outputId <- session$ns(outputId)
  }

  x_holder <- list(transport = "inline")
  attr(x_holder, "glmap_data") <- data
  state_env <- new.env(parent = emptyenv())
  state_env$queue <- list()
  state_env$flush_registered <- FALSE

  structure(
    list(
      id = outputId,
      session = session,
      deferUntilFlush = isTRUE(deferUntilFlush),
      x = x_holder,
      calls = list(),
      state = state_env
    ),
    class = c("glmap_proxy", "glmap_proxy")
  )
}



invoke_proxy_method <- function(proxy, method, args = list()) {
  msg <- list(
    id = proxy$id,
    call = list(
      method = method,
      args = args
    )
  )

  # Record call on proxy object (useful for unit testing and offline inspection)
  proxy$calls[[length(proxy$calls) + 1L]] <- msg$call

  sess <- proxy$session
  if (!is.null(sess) && is.function(sess$sendCustomMessage)) {
    if (isTRUE(proxy$deferUntilFlush) && is.function(sess$onFlushed) && is.environment(proxy$state)) {
      proxy$state$queue[[length(proxy$state$queue) + 1L]] <- msg
      if (!isTRUE(proxy$state$flush_registered)) {
        proxy$state$flush_registered <- TRUE
        st <- proxy$state
        sess$onFlushed(function() {
          q <- st$queue
          st$queue <- list()
          st$flush_registered <- FALSE
          for (m in q) {
            sess$sendCustomMessage("glmap-proxy", m)
          }
        }, once = TRUE)
      }
    } else {
      sess$sendCustomMessage("glmap-proxy", msg)
    }
  }
  proxy
}

#' Clear a Single Layer by ID
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param id Layer ID to remove.
#' @export
clear_layer <- function(map, id) {
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "clearLayer", list(id = as.character(id))))
  }
  map$x$layers <- Filter(function(l) !identical(l$id, id), map$x$layers)
  map$x$legends <- Filter(function(lg) !identical(lg$layer_id, id), map$x$legends)
  map
}

#' Clear All Data Layers from a Map
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @export
clear_layers <- function(map) {
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "clearLayers", list()))
  }
  map$x$layers <- list()
  map$x$legends <- list()
  map
}

#' Toggle Layer Visibility
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param id Layer ID.
#' @param visible Logical (`TRUE` or `FALSE`).
#' @export
set_layer_visibility <- function(map, id, visible = TRUE) {
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setLayerVisibility", list(id = as.character(id), visible = isTRUE(visible))))
  }
  for (i in seq_along(map$x$layers)) {
    if (identical(map$x$layers[[i]]$id, id)) {
      map$x$layers[[i]]$visible <- isTRUE(visible)
    }
  }
  map
}

#' Update Layer Opacity Dynamically
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param id Layer ID.
#' @param opacity Numeric opacity (`0` to `1`).
#' @export
set_layer_opacity <- function(map, id, opacity = 0.85) {
  opacity <- max(0, min(1, as.numeric(opacity[1])))
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setLayerOpacity", list(id = as.character(id), opacity = opacity)))
  }
  for (i in seq_along(map$x$layers)) {
    if (identical(map$x$layers[[i]]$id, id)) {
      map$x$layers[[i]]$opacity <- opacity
    }
  }
  map
}

#' Live-Update a GPU Raster Layer's Colormap, Contrast Range, or Hillshading (0ms GPU Update)
#'
#' Updates uniforms and the 1D LUT texture in the WebGL2 raster fragment shader
#' without re-transferring the underlying Float32 raster values.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param id Raster layer ID.
#' @param palette New palette name (`"viridis"`, `"magma"`, `"turbo"`, `"terrain"`, `"RdYlBu"`).
#' @param domain Optional numeric `c(vmin, vmax)` contrast stretch limits.
#' @param hillshade Optional logical to toggle real-time GPU hillshading.
#' @param opacity Optional numeric opacity (`0` to `1`).
#' @param shader_controls Optional specification (`TRUE`, `FALSE`, character vector, or list)
#'   controlling which interactive GPU shader controls are shown in the raster legend card.
#' @export
set_raster_style <- function(map, id, palette = NULL, domain = NULL, hillshade = NULL, opacity = NULL, shader_controls = NULL) {
  lut_rgba <- NULL
  lut_rgb <- NULL
  if (!is.null(palette)) {
    pal_hex <- resolve_palette_colors(palette, 256L)
    lut_rgba <- as.integer(grDevices::col2rgb(pal_hex, alpha = TRUE))
    lut_rgb <- as.integer(grDevices::col2rgb(pal_hex, alpha = FALSE))
  }

  ctrl_spec <- if (!is.null(shader_controls)) resolve_raster_shader_controls(shader_controls) else NULL

  style_patch <- list(
    id = as.character(id),
    palette = if (!is.null(palette) && length(palette) == 1L) as.character(palette[1]) else if (!is.null(palette)) "custom" else NULL,
    lut_rgba = lut_rgba,
    lut_rgb = lut_rgb,
    vmin = if (!is.null(domain)) as.numeric(domain[1]) else NULL,
    vmax = if (!is.null(domain)) as.numeric(domain[2]) else NULL,
    hillshade = if (!is.null(hillshade)) isTRUE(hillshade) else NULL,
    opacity = if (!is.null(opacity)) max(0, min(1, as.numeric(opacity[1]))) else NULL,
    shader_controls = ctrl_spec
  )

  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setRasterStyle", style_patch))
  }

  for (i in seq_along(map$x$layers)) {
    if (identical(map$x$layers[[i]]$id, id)) {
      if (!is.null(palette)) map$x$layers[[i]]$style$palette <- style_patch$palette
      if (!is.null(lut_rgba)) map$x$layers[[i]]$style$lut_rgba <- lut_rgba
      if (!is.null(lut_rgb)) map$x$layers[[i]]$style$lut_rgb <- lut_rgb
      if (!is.null(domain)) {
        map$x$layers[[i]]$style$vmin <- as.numeric(domain[1])
        map$x$layers[[i]]$style$vmax <- as.numeric(domain[2])
      }
      if (!is.null(hillshade)) map$x$layers[[i]]$style$hillshade <- isTRUE(hillshade)
      if (!is.null(opacity)) map$x$layers[[i]]$opacity <- style_patch$opacity
      if (!is.null(ctrl_spec)) map$x$layers[[i]]$style$shader_controls <- ctrl_spec
    }
  }
  map
}

#' Filter Visible Features by Index on the GPU
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param id Layer ID.
#' @param indices Integer vector of 1-based feature indices to keep visible (or `NULL` to reset).
#' @export
set_filter <- function(map, id, indices = NULL) {
  idx0 <- if (!is.null(indices)) as.integer(indices) - 1L else NULL
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setFilter", list(id = as.character(id), indices = idx0)))
  }
  for (i in seq_along(map$x$layers)) {
    if (identical(map$x$layers[[i]]$id, id)) {
      map$x$layers[[i]]$filter_indices <- idx0
    }
  }
  map
}

#' Show, Hide, or Clear Layers by Group Name (`show_group`, `hide_group`, `clear_group`)
#'
#' Drop-in equivalents of `leaflet::showGroup()`, `leaflet::hideGroup()`, and
#' `leaflet::clearGroup()`.
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param group Character vector of group name(s).
#' @export
show_group <- function(map, group) {
  group <- as.character(group)
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setGroupVisibility", list(group = group, visible = TRUE)))
  }
  for (i in seq_along(map$x$layers)) {
    if (map$x$layers[[i]]$group %in% group || map$x$layers[[i]]$id %in% group) {
      map$x$layers[[i]]$visible <- TRUE
    }
  }
  map
}

#' @rdname show_group
#' @export
hide_group <- function(map, group) {
  group <- as.character(group)
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setGroupVisibility", list(group = group, visible = FALSE)))
  }
  for (i in seq_along(map$x$layers)) {
    if (map$x$layers[[i]]$group %in% group || map$x$layers[[i]]$id %in% group) {
      map$x$layers[[i]]$visible <- FALSE
    }
  }
  map
}

#' @rdname show_group
#' @export
clear_group <- function(map, group) {
  group <- as.character(group)
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "clearGroup", list(group = group)))
  }
  removed_ids <- vapply(
    Filter(function(l) l$group %in% group || l$id %in% group, map$x$layers),
    function(l) l$id,
    character(1)
  )
  map$x$layers <- Filter(function(l) !(l$group %in% group || l$id %in% group), map$x$layers)
  map$x$legends <- Filter(function(lg) !(lg$layer_id %in% removed_ids), map$x$legends)
  map
}

#' Shiny UI Output for `glmap`
#'
#' @param outputId Output variable name.
#' @param width Widget width (default `"100%"`).
#' @param height Widget height (default `"600px"`).
#' @export
glmapOutput <- function(outputId, width = "100%", height = "600px") {
  htmlwidgets::shinyWidgetOutput(outputId, "glmap", width, height, package = "glmap")
}


#' Shiny Server Render Function for `glmap`
#'
#' @param expr An expression that generates a `glmap` widget.
#' @param env The environment in which to evaluate `expr`.
#' @param quoted Is `expr` a quoted expression (`with quote()`)?
#' @export
renderGlmap <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) {
    expr <- substitute(expr)
  }
  htmlwidgets::shinyRenderWidget(expr, glmapOutput, env, quoted = TRUE)
}
