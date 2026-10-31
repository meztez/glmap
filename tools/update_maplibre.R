#!/usr/bin/env Rscript
# Check for newer releases of MapLibre GL JS on npm/unpkg, update bundled assets
# in inst/htmlwidgets/lib/maplibre-gl/ and inst/htmlwidgets/glmap.yaml, and write
# machine-readable status outputs for GitHub Actions.
#
# Usage:
#   Rscript tools/update_maplibre.R [--target=<version>] [--check-only]

update_maplibre_assets <- function(pkg_dir = ".", target_version = NULL, check_only = FALSE) {
  yaml_path <- file.path(pkg_dir, "inst", "htmlwidgets", "glmap.yaml")
  js_path   <- file.path(pkg_dir, "inst", "htmlwidgets", "lib", "maplibre-gl", "maplibre-gl.js")
  css_path  <- file.path(pkg_dir, "inst", "htmlwidgets", "lib", "maplibre-gl", "maplibre-gl.css")

  if (!file.exists(yaml_path)) {
    stop("glmap.yaml not found at: ", yaml_path, call. = FALSE)
  }

  yaml_lines <- readLines(yaml_path, warn = FALSE, encoding = "UTF-8")
  ver_idx <- grep("^\\s*version:\\s*[0-9]+\\.[0-9]+\\.[0-9]+", yaml_lines)
  if (!length(ver_idx)) {
    stop("Could not locate maplibre-gl version line in glmap.yaml", call. = FALSE)
  }
  current_version <- trimws(sub("^\\s*version:\\s*", "", yaml_lines[ver_idx[1L]]))

  if (is.null(target_version) || !nzchar(target_version)) {
    npm_meta <- jsonlite::fromJSON("https://registry.npmjs.org/maplibre-gl/latest")
    target_version <- as.character(npm_meta$version[1L])
  }

  is_newer <- utils::compareVersion(target_version, current_version) > 0L
  message(sprintf("MapLibre GL JS: current = %s | latest = %s | update_needed = %s",
                  current_version, target_version, is_newer))

  gh_out <- Sys.getenv("GITHUB_OUTPUT", unset = "")
  write_gh_output <- function(key, val) {
    if (nzchar(gh_out)) {
      cat(sprintf("%s=%s\n", key, val), file = gh_out, append = TRUE)
    }
  }

  write_gh_output("current_version", current_version)
  write_gh_output("latest_version", target_version)

  if (!is_newer || isTRUE(check_only)) {
    write_gh_output("updated", "false")
    return(invisible(list(
      updated = FALSE,
      current_version = current_version,
      latest_version = target_version
    )))
  }

  js_url  <- sprintf("https://unpkg.com/maplibre-gl@%s/dist/maplibre-gl.js", target_version)
  css_url <- sprintf("https://unpkg.com/maplibre-gl@%s/dist/maplibre-gl.css", target_version)

  tmp_js  <- tempfile(fileext = ".js")
  tmp_css <- tempfile(fileext = ".css")
  on.exit(unlink(c(tmp_js, tmp_css), force = TRUE), add = TRUE)

  message("Downloading ", js_url, " ...")
  utils::download.file(js_url, destfile = tmp_js, quiet = TRUE, mode = "wb")
  message("Downloading ", css_url, " ...")
  utils::download.file(css_url, destfile = tmp_css, quiet = TRUE, mode = "wb")

  if (!file.exists(tmp_js) || file.info(tmp_js)$size < 100000) {
    stop("Downloaded maplibre-gl.js is unexpectedly small or missing.", call. = FALSE)
  }
  if (!file.exists(tmp_css) || file.info(tmp_css)$size < 1000) {
    stop("Downloaded maplibre-gl.css is unexpectedly small or missing.", call. = FALSE)
  }

  file.copy(tmp_js, js_path, overwrite = TRUE)
  file.copy(tmp_css, css_path, overwrite = TRUE)

  yaml_lines[ver_idx[1L]] <- sub(current_version, target_version, yaml_lines[ver_idx[1L]], fixed = TRUE)
  writeLines(yaml_lines, yaml_path, useBytes = TRUE)

  # Sync any pre-rendered pkgdown article copies if present
  docs_js <- Sys.glob(file.path(pkg_dir, "docs", "articles", "*_files", "maplibre-gl-*", "maplibre-gl.js"))
  for (f in docs_js) file.copy(js_path, f, overwrite = TRUE)
  docs_css <- Sys.glob(file.path(pkg_dir, "docs", "articles", "*_files", "maplibre-gl-*", "maplibre-gl.css"))
  for (f in docs_css) file.copy(css_path, f, overwrite = TRUE)

  write_gh_output("updated", "true")
  message(sprintf("Updated MapLibre GL JS from %s to %s.", current_version, target_version))

  invisible(list(
    updated = TRUE,
    current_version = current_version,
    latest_version = target_version
  ))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  chk <- "--check-only" %in% args
  tgt_arg <- grep("^--target=", args, value = TRUE)
  tgt <- if (length(tgt_arg)) sub("^--target=", "", tgt_arg[1L]) else NULL
  update_maplibre_assets(".", target_version = tgt, check_only = chk)
}
