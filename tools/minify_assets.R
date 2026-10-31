#!/usr/bin/env Rscript
# Minify glmap JavaScript and CSS assets from inst/js-src/ into inst/htmlwidgets/
# Usage: Rscript tools/minify_assets.R

minify_glmap_assets <- function(pkg_dir = ".") {
  src_js_path <- file.path(pkg_dir, "inst", "js-src", "glmap.js")
  out_js_path <- file.path(pkg_dir, "inst", "htmlwidgets", "glmap.js")
  src_css_path <- file.path(pkg_dir, "inst", "js-src", "glmap.css")
  out_css_path <- file.path(pkg_dir, "inst", "htmlwidgets", "lib", "glmap-gl", "glmap.css")

  if (!file.exists(src_js_path)) {
    stop("Source JS not found at: ", src_js_path, call. = FALSE)
  }
  if (!requireNamespace("V8", quietly = TRUE)) {
    stop("Package 'V8' is required to run the Terser minification pipeline.", call. = FALSE)
  }

  js_raw <- paste(readLines(src_js_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  ctx <- V8::v8()
  terser_cache <- file.path(tempdir(), "terser-5.39.0.bundle.min.js")
  if (!file.exists(terser_cache)) {
    utils::download.file(
      "https://cdn.jsdelivr.net/npm/terser@5.39.0/dist/bundle.min.js",
      destfile = terser_cache,
      quiet = TRUE,
      mode = "wb"
    )
  }
  ctx$source(terser_cache)
  ctx$assign("src_code", js_raw)
  ctx$eval("
    var min_result = null;
    var min_err = null;
    Terser.minify(src_code, {
      compress: { passes: 2 },
      mangle: { reserved: ['GLMapInstance', 'HTMLWidgets', 'Shiny', 'maplibregl'] },
      format: { comments: false }
    }).then(function(res) {
      min_result = res.code;
    }).catch(function(err) {
      min_err = String(err);
    });
  ")
  min_err <- ctx$get("min_err")
  if (!is.null(min_err) && nzchar(min_err)) {
    stop("Terser minification failed: ", min_err, call. = FALSE)
  }
  js_min <- ctx$get("min_result")
  if (is.null(js_min) || !nzchar(js_min)) {
    stop("Terser returned empty output.", call. = FALSE)
  }

  writeLines(js_min, out_js_path, useBytes = TRUE)
  src_bytes <- file.info(src_js_path)$size
  out_bytes <- file.info(out_js_path)$size
  message(sprintf(
    "JS minified: %s (%s KB) -> %s (%s KB, -%.1f%%)",
    src_js_path, round(src_bytes / 1024, 1),
    out_js_path, round(out_bytes / 1024, 1),
    100 * (1 - out_bytes / src_bytes)
  ))

  if (file.exists(src_css_path)) {
    css_raw <- paste(readLines(src_css_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    css_min <- gsub("/\\*[\\s\\S]*?\\*/", "", css_raw, perl = TRUE)
    css_min <- gsub("\\s+", " ", css_min, perl = TRUE)
    css_min <- gsub("\\s*([{}:;,>~])\\s*", "\\1", css_min, perl = TRUE)
    css_min <- gsub(";\\}", "}", trimws(css_min), perl = TRUE)
    writeLines(css_min, out_css_path, useBytes = TRUE)
    css_src_b <- file.info(src_css_path)$size
    css_out_b <- file.info(out_css_path)$size
    message(sprintf(
      "CSS minified: %s (%s KB) -> %s (%s KB, -%.1f%%)",
      src_css_path, round(css_src_b / 1024, 1),
      out_css_path, round(css_out_b / 1024, 1),
      100 * (1 - css_out_b / css_src_b)
    ))
  }

  # Sync pkgdown docs copies if present
  docs_js <- Sys.glob(file.path(pkg_dir, "docs", "articles", "*_files", "glmap-binding-*", "glmap.js"))
  for (f in docs_js) {
    file.copy(out_js_path, f, overwrite = TRUE)
  }
  docs_css <- Sys.glob(file.path(pkg_dir, "docs", "articles", "*_files", "glmap-gl-*", "glmap.css"))
  for (f in docs_css) {
    file.copy(out_css_path, f, overwrite = TRUE)
  }

  invisible(list(js_path = out_js_path, css_path = out_css_path))
}

if (sys.nframe() == 0L) {
  minify_glmap_assets(".")
}
