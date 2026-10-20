# Evaluate a formula (~col or ~expr), column name string, or direct vector against data
eval_aesthetic <- function(val, data) {
  if (is.null(val)) return(NULL)
  if (inherits(val, "formula")) {
    expr <- rlang::f_rhs(val)
    env <- rlang::f_env(val) %||% parent.frame()
    if (!is.null(data) && is.data.frame(data)) {
      return(rlang::eval_tidy(expr, data = data, env = env))
    }
    return(eval(expr, envir = env))
  }
  if (is.character(val) && length(val) == 1L && !is.null(data) && is.data.frame(data) && val %in% names(data)) {
    return(data[[val]])
  }
  val
}

is_color_string <- function(x) {
  if (!is.character(x) || length(x) == 0L) return(FALSE)
  s <- x[1]
  if (grepl("^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$", s)) return(TRUE)
  if (tolower(s) %in% grDevices::colors()) return(TRUE)
  FALSE
}

resolve_palette_colors <- function(palette = "viridis", n = 256L) {
  if (is.function(palette)) {
    return(palette(n))
  }
  if (length(palette) > 1L) {
    return(grDevices::colorRampPalette(palette)(n))
  }
  pal_name <- tolower(as.character(palette[1]))
  switch(
    pal_name,
    "viridis" = viridisLite::viridis(n),
    "magma"   = viridisLite::magma(n),
    "inferno" = viridisLite::inferno(n),
    "plasma"  = viridisLite::plasma(n),
    "cividis" = viridisLite::cividis(n),
    "turbo"   = viridisLite::turbo(n),
    "mako"    = viridisLite::mako(n),
    "rocket"  = viridisLite::rocket(n),
    "terrain" = grDevices::terrain.colors(n),
    "heat"    = grDevices::heat.colors(n),
    "topo"    = grDevices::topo.colors(n),
    "rdylbu"  = grDevices::hcl.colors(n, "RdYlBu"),
    "spectral"= grDevices::hcl.colors(n, "Spectral"),
    "blues"   = grDevices::hcl.colors(n, "Blues 3", rev = TRUE),
    "reds"    = grDevices::hcl.colors(n, "Reds 3", rev = TRUE),
    grDevices::hcl.colors(n, palette = palette[1])
  )
}

# Resolve color aesthetic into an integer RGBA vector (either length 4 or 4*n)
# plus optional legend metadata
resolve_rgba <- function(
    color = "#1e90ff",
    data = NULL,
    n = 1L,
    opacity = 0.85,
    palette = "viridis",
    na_color = "#808080",
    title = NULL
) {
  alpha_byte <- as.integer(round(max(0, min(1, opacity[1])) * 255))
  val <- eval_aesthetic(color, data)

  if (is.null(val)) {
    val <- "#1e90ff"
  }

  # Constant single color string
  if (length(val) == 1L && is_color_string(val)) {
    rgb_mat <- grDevices::col2rgb(val, alpha = FALSE)
    rgba <- c(as.integer(rgb_mat[1, 1]), as.integer(rgb_mat[2, 1]), as.integer(rgb_mat[3, 1]), alpha_byte)
    return(list(rgba = rgba, legend = NULL))
  }

  # Vector of explicit color strings
  if (is.character(val) && length(val) == n && all(vapply(val[seq_len(min(5L, n))], is_color_string, logical(1)))) {
    rgb_mat <- grDevices::col2rgb(val, alpha = FALSE)
    rgba <- integer(4L * n)
    rgba[seq(1L, 4L * n, by = 4L)] <- rgb_mat[1, ]
    rgba[seq(2L, 4L * n, by = 4L)] <- rgb_mat[2, ]
    rgba[seq(3L, 4L * n, by = 4L)] <- rgb_mat[3, ]
    rgba[seq(4L, 4L * n, by = 4L)] <- alpha_byte
    return(list(rgba = rgba, legend = NULL))
  }

  # Numeric vector -> fast 256-entry LUT mapping (handles 1M+ values in < 15ms)
  if (is.numeric(val)) {
    pal_hex <- resolve_palette_colors(palette, 256L)
    lut_rgb <- grDevices::col2rgb(pal_hex, alpha = FALSE) # 3 x 256
    na_rgb <- grDevices::col2rgb(na_color, alpha = FALSE)

    rng <- range(val, na.rm = TRUE, finite = TRUE)
    if (!all(is.finite(rng)) || rng[1] == rng[2]) {
      rng <- c(0, 1)
      idx <- rep(128L, length(val))
    } else {
      idx <- as.integer(floor(((val - rng[1]) / (rng[2] - rng[1])) * 255)) + 1L
      idx <- pmax(1L, pmin(256L, idx))
    }

    is_na <- is.na(idx)
    idx_safe <- ifelse(is_na, 1L, idx)

    r_vec <- lut_rgb[1, idx_safe]
    g_vec <- lut_rgb[2, idx_safe]
    b_vec <- lut_rgb[3, idx_safe]
    if (any(is_na)) {
      r_vec[is_na] <- na_rgb[1, 1]
      g_vec[is_na] <- na_rgb[2, 1]
      b_vec[is_na] <- na_rgb[3, 1]
    }

    rgba <- as.integer(rbind(r_vec, g_vec, b_vec, rep(alpha_byte, length(val))))
    lbl_title <- title %||% (if (inherits(color, "formula")) rlang::as_label(rlang::f_rhs(color)) else as.character(color[1]))
    legend <- list(
      type = "continuous",
      title = lbl_title,
      domain = rng,
      colors = pal_hex[round(seq(1, 256, length.out = 7))]
    )
    return(list(rgba = rgba, legend = legend))
  }

  # Categorical / factor / character vector
  f <- as.factor(val)
  lvls <- levels(f)
  n_lvls <- max(1L, length(lvls))
  pal_hex <- resolve_palette_colors(palette, max(3L, n_lvls))[seq_len(n_lvls)]
  lut_rgb <- grDevices::col2rgb(pal_hex, alpha = FALSE)
  na_rgb <- grDevices::col2rgb(na_color, alpha = FALSE)

  idx <- as.integer(f)
  is_na <- is.na(idx)
  idx_safe <- ifelse(is_na, 1L, idx)

  r_vec <- lut_rgb[1, idx_safe]
  g_vec <- lut_rgb[2, idx_safe]
  b_vec <- lut_rgb[3, idx_safe]
  if (any(is_na)) {
    r_vec[is_na] <- na_rgb[1, 1]
    g_vec[is_na] <- na_rgb[2, 1]
    b_vec[is_na] <- na_rgb[3, 1]
  }

  rgba <- as.integer(rbind(r_vec, g_vec, b_vec, rep(alpha_byte, length(val))))
  lbl_title <- title %||% (if (inherits(color, "formula")) rlang::as_label(rlang::f_rhs(color)) else as.character(color[1]))
  legend <- list(
    type = "categorical",
    title = lbl_title,
    labels = lvls[seq_len(min(12L, n_lvls))],
    colors = pal_hex[seq_len(min(12L, n_lvls))]
  )
  list(rgba = rgba, legend = legend)
}

resolve_numeric_aesthetic <- function(val, data = NULL, default = 5.0, range_out = c(3, 15)) {
  v <- eval_aesthetic(val, data)
  if (is.null(v)) return(as.numeric(default))
  v <- as.numeric(v)
  if (length(v) == 1L) return(v)
  # If a formula was passed, rescale smoothly into range_out unless raw values are already reasonable
  if (inherits(val, "formula")) {
    rng <- range(v, na.rm = TRUE, finite = TRUE)
    if (all(is.finite(rng)) && rng[2] > rng[1] && (rng[2] > 50 || rng[1] < 0.5)) {
      v <- range_out[1] + ((v - rng[1]) / (rng[2] - rng[1])) * (range_out[2] - range_out[1])
    }
  }
  v[is.na(v)] <- default
  v
}

build_popup_labels <- function(popup, label, data, max_items = 25000L) {
  n <- if (!is.null(data) && is.data.frame(data)) nrow(data) else 0L
  if (n == 0L || n > max_items) return(NULL)
  src <- popup %||% label
  if (is.null(src)) {
    # Pick first 3 non-geometry columns if available
    if (is.data.frame(data)) {
      cols <- setdiff(names(data), attr(data, "sf_column") %||% character(0))
      cols <- utils::head(cols, 4L)
      if (length(cols) == 0L) return(NULL)
      # Only attach compact tooltips for <= 10,000 features by default
      if (n > 10000L) return(NULL)
      parts <- lapply(cols, function(col) paste0("<b>", col, ":</b> ", as.character(data[[col]])))
      return(do.call(paste, c(parts, sep = "<br/>")))
    }
    return(NULL)
  }
  vals <- eval_aesthetic(src, data)
  as.character(vals)
}
