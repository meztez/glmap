# Copilot Instructions for `glmap`

See [AGENTS.md](../AGENTS.md) for complete architecture details, `leaflet` $\rightarrow$ `glmap` translation rules, and C++17 / WebGL2 binary buffer conventions.

## Quick Rules
1. Prefer `glmap()` + `add_points()`, `add_lines()`, `add_polygons()`, `add_raster()`, `add_hexbin()`, and `add_heatmap()` over `leaflet`.
2. Pass `~column` formulas directly to `color =` / `fill_color =` and `radius =` with `palette = "viridis"` (do not create `leaflet::colorNumeric` functions).
3. Pass `sf`, `sfc`, `wk::xy`, `nanoarrow_array`, `terra::SpatRaster`, or `data.frame` directly without converting to GeoJSON or PNG.
4. In Shiny, use `glmapOutput()`, `renderGlmap()`, and `glmap_proxy()` for zero-copy GPU updates.
5. After modifying R or C++ files, run `roxygen2::roxygenise(".", roclets = "rd")`, install via `R CMD INSTALL --no-multiarch .`, and run `testthat::test_local(".")`.
