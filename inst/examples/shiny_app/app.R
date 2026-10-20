# Interactive Shiny Dashboard for `glmap`
# Run with: shiny::runApp(system.file("examples/shiny_app", package = "glmap"))

library(shiny)
library(glmap)

bench <- gl_benchmark_data(
  n_points = 150000L,
  n_polygons = 2500L,
  raster_dim = c(250L, 250L)
)

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { background-color: #0b0f19; color: #e2e8f0; font-family: system-ui, sans-serif; }
      .well { background-color: #1e293b; border: 1px solid #334155; border-radius: 10px; }
      h3, h4 { color: #38bdf8; font-weight: 700; }
      pre { background-color: #0f172a; color: #4ade80; border: 1px solid #334155; }
    "))
  ),
  titlePanel("glmap: 60 FPS GPU Geospatial Explorer + Zero-Copy Shiny Proxy"),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("1. Basemap & Camera"),
      selectInput(
        "basemap", "Basemap Provider:",
        choices = c(
          "CARTO Dark Matter" = "CartoDB.DarkMatter",
          "CARTO Positron (Light)" = "CartoDB.Positron",
          "CARTO Voyager" = "CartoDB.Voyager",
          "OpenFreeMap Liberty (Vector)" = "OpenFreeMap.Liberty",
          "Esri World Imagery (Satellite)" = "Esri.WorldImagery",
          "OpenTopoMap" = "OpenTopoMap"
        ),
        selected = "CartoDB.DarkMatter"
      ),
      fluidRow(
        column(6, actionButton("fly_mtl", "Fly Montréal", class = "btn-info btn-block")),
        column(6, actionButton("fly_qc", "Fly Québec", class = "btn-info btn-block"))
      ),
      hr(),
      h4("2. 0ms GPU Raster Shader"),
      selectInput(
        "raster_pal", "Float32 Raster Palette:",
        choices = c("terrain", "viridis", "magma", "plasma", "turbo", "rdylbu"),
        selected = "terrain"
      ),
      checkboxInput("hillshade", "Real-Time GPU Hillshading", value = TRUE),
      sliderInput("raster_opacity", "Raster Opacity:", min = 0, max = 1, value = 0.70, step = 0.05),
      hr(),
      h4("3. Group Visibility (`glmap_proxy`)"),
      checkboxGroupInput(
        "groups", "Visible Layer Groups:",
        choices = c("DEM Raster", "Polygons (2.5k)", "Hexbins", "Points (150k)"),
        selected = c("DEM Raster", "Polygons (2.5k)", "Hexbins", "Points (150k)")
      ),
      hr(),
      h4("4. Live Shiny Telemetry"),
      verbatimTextOutput("telemetry")
    ),
    mainPanel(
      width = 9,
      glmapOutput("map", height = "760px")
    )
  )
)

server <- function(input, output, session) {
  output$map <- renderGlmap({
    glmap(basemap = "CartoDB.DarkMatter") |>
      add_raster(
        bench$raster_mat,
        palette = "terrain",
        hillshade = TRUE,
        opacity = 0.70,
        id = "dem_layer",
        group = "DEM Raster"
      ) |>
      add_polygons(
        bench$polygons_sf,
        fill_color = ~elevation,
        palette = "viridis",
        fill_opacity = 0.65,
        popup = ~paste0("<b>Polygon ID:</b> ", id, "<br/><b>Elevation:</b> ", elevation, " m"),
        id = "poly_layer",
        group = "Polygons (2.5k)"
      ) |>
      add_hexbin(
        bench$points_df,
        hex_radius = 0.035,
        palette = "plasma",
        opacity = 0.75,
        id = "hex_layer",
        group = "Hexbins"
      ) |>
      add_points(
        bench$points_df,
        color = ~intensity,
        palette = "turbo",
        radius = 3.0,
        opacity = 0.85,
        id = "pts_layer",
        group = "Points (150k)"
      ) |>
      use_plugin("export_png")
  })

  # Basemap switch via proxy
  observeEvent(input$basemap, {
    glmap_proxy("map") |> add_provider_tiles(input$basemap)
  }, ignoreInit = TRUE)

  # Camera flyTo animations
  observeEvent(input$fly_mtl, {
    glmap_proxy("map") |> fly_to(lng = -73.5673, lat = 45.5017, zoom = 10)
  })
  observeEvent(input$fly_qc, {
    glmap_proxy("map") |> fly_to(lng = -71.2080, lat = 46.8139, zoom = 10)
  })

  # 0ms GPU raster shader uniform updates
  observeEvent(list(input$raster_pal, input$hillshade), {
    glmap_proxy("map") |>
      set_raster_style("dem_layer", palette = input$raster_pal, hillshade = input$hillshade)
  }, ignoreInit = TRUE)

  observeEvent(input$raster_opacity, {
    glmap_proxy("map") |> set_layer_opacity("dem_layer", input$raster_opacity)
  }, ignoreInit = TRUE)

  # Group visibility toggling (show_group / hide_group)
  observeEvent(input$groups, {
    all_groups <- c("DEM Raster", "Polygons (2.5k)", "Hexbins", "Points (150k)")
    vis <- intersect(all_groups, input$groups)
    hid <- setdiff(all_groups, input$groups)
    proxy <- glmap_proxy("map")
    if (length(vis) > 0) proxy <- show_group(proxy, vis)
    if (length(hid) > 0) proxy <- hide_group(proxy, hid)
  }, ignoreNULL = FALSE, ignoreInit = TRUE)

  output$telemetry <- renderPrint({
    list(
      zoom = input$map_zoom,
      center = input$map_center,
      last_click = input$map_click,
      feature_click = input$map_marker_click %||% input$map_shape_click,
      box_brush_count = if (!is.null(input$map_selected)) input$map_selected$count else 0L
    )
  })
}

shinyApp(ui, server)
