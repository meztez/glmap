# Copilot Instructions for glmap

See [AGENTS.md](https://meztez.github.io/AGENTS.md) for complete
architecture details, `leaflet` $`\rightarrow`$`glmap` translation
rules, and C++17 / WebGL2 binary buffer conventions.

## Quick Rules

1.  Prefer
    [`glmap()`](https://meztez.github.io/glmap/reference/glmap.md) +
    [`add_points()`](https://meztez.github.io/glmap/reference/add_points.md),
    [`add_lines()`](https://meztez.github.io/glmap/reference/add_lines.md),
    [`add_polygons()`](https://meztez.github.io/glmap/reference/add_polygons.md),
    [`add_raster()`](https://meztez.github.io/glmap/reference/add_raster.md),
    [`add_hexbin()`](https://meztez.github.io/glmap/reference/add_hexbin.md),
    and
    [`add_heatmap()`](https://meztez.github.io/glmap/reference/add_heatmap.md)
    over `leaflet`.
2.  Pass `~column` formulas directly to `color =` / `fill_color =` and
    `radius =` with `palette = "viridis"` (do not create
    [`leaflet::colorNumeric`](https://rstudio.github.io/leaflet/reference/colorNumeric.html)
    functions).
3.  Pass `sf`, `sfc`,
    [`wk::xy`](https://paleolimbot.github.io/wk/reference/xy.html),
    `nanoarrow_array`,
    [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html),
    or `data.frame` directly without converting to GeoJSON or PNG.
4.  In Shiny, use
    [`glmapOutput()`](https://meztez.github.io/glmap/reference/glmapOutput.md),
    [`renderGlmap()`](https://meztez.github.io/glmap/reference/renderGlmap.md),
    and
    [`glmap_proxy()`](https://meztez.github.io/glmap/reference/glmap_proxy.md)
    for zero-copy GPU updates.
5.  After modifying R or C++ files, run
    `roxygen2::roxygenise(".", roclets = "rd")`, install via
    `R CMD INSTALL --no-multiarch .`, and run
    `testthat::test_local(".")`.
