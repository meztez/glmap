# Demo script for `glmap`: High-Performance GPU Geospatial Mapping
library(glmap)

# 1. Generate synthetic Montreal-Quebec City corridor geospatial benchmark dataset
#    (200,000 points, 3,000 polygons, and a 250x250 Float32 DEM raster)
bench <- gl_benchmark_data(
  n_points = 200000L,
  n_polygons = 3000L,
  raster_dim = c(250L, 250L)
)

# 2. Build a multi-layer GPU map using pipeable syntax and formula (~) aesthetics
m <- glmap(basemap = "dark") |>
  add_raster(
    bench$raster_mat,
    palette = "terrain",
    hillshade = TRUE,
    opacity = 0.65,
    group = "GPU Terrain DEM (Float32)"
  ) |>
  add_polygons(
    bench$polygons_sf,
    fill_color = ~elevation,
    palette = "viridis",
    fill_opacity = 0.65,
    group = "C++ Earcut Polygons (3k)"
  ) |>
  add_hexbin(
    bench$points_df,
    hex_radius = 0.035,
    palette = "plasma",
    opacity = 0.75,
    group = "C++ Hexbin Aggregation"
  ) |>
  add_points(
    bench$points_df,
    color = ~intensity,
    palette = "turbo",
    radius = 3.0,
    opacity = 0.85,
    group = "GPU Instanced Points (200k)"
  ) |>
  use_plugin("export_png")

print(m)
