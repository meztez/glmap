#' Basemap Tile Providers Catalog (`gl_providers`)
#'
#' The `glmap` equivalent of `leaflet::providers`. Provides autocomplete-friendly
#' access to open-source Vector GL styles (MapLibre GL JSON), global XYZ Raster
#' tile providers, and commercial/optional-API-key providers (CARTO, OpenFreeMap,
#' OpenStreetMap, Esri, OpenTopoMap, USGS, MapTiler, Stadia/Stamen, Thunderforest,
#' Jawg, and Mapbox).
#'
#' All providers support optional API key injection via `api_key = "..."`,
#' [gl_set_api_key()], or environment variables (`CARTO_API_KEY`, `MAPTILER_API_KEY`,
#' `STADIA_API_KEY`, `THUNDERFOREST_API_KEY`, `JAWG_API_KEY`, `MAPBOX_ACCESS_TOKEN`).
#'
#' @examples
#' gl_providers$CartoDB.DarkMatter
#' gl_providers$CartoDB.Positron
#' gl_providers$Esri.WorldImagery
#' gl_providers$OpenFreeMap.Liberty
#' gl_providers$MapTiler.DatavizDark
#' gl_providers$Stadia.AlidadeSmoothDark
#'
#' @export
gl_providers <- list(
  CartoDB = list(
    DarkMatter = "CartoDB.DarkMatter",
    DarkMatterNoLabels = "CartoDB.DarkMatterNoLabels",
    Positron = "CartoDB.Positron",
    PositronNoLabels = "CartoDB.PositronNoLabels",
    Voyager = "CartoDB.Voyager",
    VoyagerNoLabels = "CartoDB.VoyagerNoLabels"
  ),
  CartoDB.DarkMatter = "CartoDB.DarkMatter",
  CartoDB.DarkMatterNoLabels = "CartoDB.DarkMatterNoLabels",
  CartoDB.Positron = "CartoDB.Positron",
  CartoDB.PositronNoLabels = "CartoDB.PositronNoLabels",
  CartoDB.Voyager = "CartoDB.Voyager",
  CartoDB.VoyagerNoLabels = "CartoDB.VoyagerNoLabels",

  OpenFreeMap = list(
    Liberty = "OpenFreeMap.Liberty",
    Bright = "OpenFreeMap.Bright",
    Positron = "OpenFreeMap.Positron",
    Dark = "OpenFreeMap.Dark"
  ),
  OpenFreeMap.Liberty = "OpenFreeMap.Liberty",
  OpenFreeMap.Bright = "OpenFreeMap.Bright",
  OpenFreeMap.Positron = "OpenFreeMap.Positron",
  OpenFreeMap.Dark = "OpenFreeMap.Dark",

  OpenStreetMap = list(
    Mapnik = "OpenStreetMap.Mapnik",
    HOT = "OpenStreetMap.HOT",
    France = "OpenStreetMap.France"
  ),
  OpenStreetMap.Mapnik = "OpenStreetMap.Mapnik",
  OpenStreetMap.HOT = "OpenStreetMap.HOT",
  OpenStreetMap.France = "OpenStreetMap.France",

  OpenTopoMap = "OpenTopoMap",

  Esri = list(
    WorldImagery = "Esri.WorldImagery",
    WorldTopoMap = "Esri.WorldTopoMap",
    WorldStreetMap = "Esri.WorldStreetMap",
    WorldTerrain = "Esri.WorldTerrain",
    WorldShadedRelief = "Esri.WorldShadedRelief",
    OceanBasemap = "Esri.OceanBasemap",
    NatGeoWorldMap = "Esri.NatGeoWorldMap",
    WorldGrayCanvas = "Esri.WorldGrayCanvas"
  ),
  Esri.WorldImagery = "Esri.WorldImagery",
  Esri.WorldTopoMap = "Esri.WorldTopoMap",
  Esri.WorldStreetMap = "Esri.WorldStreetMap",
  Esri.WorldTerrain = "Esri.WorldTerrain",
  Esri.WorldShadedRelief = "Esri.WorldShadedRelief",
  Esri.OceanBasemap = "Esri.OceanBasemap",
  Esri.NatGeoWorldMap = "Esri.NatGeoWorldMap",
  Esri.WorldGrayCanvas = "Esri.WorldGrayCanvas",

  USGS = list(
    USTopo = "USGS.USTopo",
    USImagery = "USGS.USImagery",
    USImageryTopo = "USGS.USImageryTopo"
  ),
  USGS.USTopo = "USGS.USTopo",
  USGS.USImagery = "USGS.USImagery",
  USGS.USImageryTopo = "USGS.USImageryTopo",

  MapTiler = list(
    Streets = "MapTiler.Streets",
    Dataviz = "MapTiler.Dataviz",
    DatavizDark = "MapTiler.DatavizDark",
    Backdrop = "MapTiler.Backdrop",
    Satellite = "MapTiler.Satellite",
    Outdoor = "MapTiler.Outdoor"
  ),
  MapTiler.Streets = "MapTiler.Streets",
  MapTiler.Dataviz = "MapTiler.Dataviz",
  MapTiler.DatavizDark = "MapTiler.DatavizDark",
  MapTiler.Backdrop = "MapTiler.Backdrop",
  MapTiler.Satellite = "MapTiler.Satellite",
  MapTiler.Outdoor = "MapTiler.Outdoor",

  Stadia = list(
    AlidadeSmooth = "Stadia.AlidadeSmooth",
    AlidadeSmoothDark = "Stadia.AlidadeSmoothDark",
    AlidadeSatellite = "Stadia.AlidadeSatellite",
    Outdoors = "Stadia.Outdoors",
    StamenToner = "Stadia.StamenToner",
    StamenTerrain = "Stadia.StamenTerrain",
    StamenWatercolor = "Stadia.StamenWatercolor"
  ),
  Stadia.AlidadeSmooth = "Stadia.AlidadeSmooth",
  Stadia.AlidadeSmoothDark = "Stadia.AlidadeSmoothDark",
  Stadia.AlidadeSatellite = "Stadia.AlidadeSatellite",
  Stadia.Outdoors = "Stadia.Outdoors",
  Stadia.StamenToner = "Stadia.StamenToner",
  Stadia.StamenTerrain = "Stadia.StamenTerrain",
  Stadia.StamenWatercolor = "Stadia.StamenWatercolor",

  Thunderforest = list(
    Landscape = "Thunderforest.Landscape",
    Outdoors = "Thunderforest.Outdoors",
    TransportDark = "Thunderforest.TransportDark"
  ),
  Thunderforest.Landscape = "Thunderforest.Landscape",
  Thunderforest.Outdoors = "Thunderforest.Outdoors",
  Thunderforest.TransportDark = "Thunderforest.TransportDark",

  Jawg = list(
    Streets = "Jawg.Streets",
    Dark = "Jawg.Dark",
    Terrain = "Jawg.Terrain"
  ),
  Jawg.Streets = "Jawg.Streets",
  Jawg.Dark = "Jawg.Dark",
  Jawg.Terrain = "Jawg.Terrain",

  Mapbox = list(
    Streets = "Mapbox.Streets",
    Dark = "Mapbox.Dark",
    Light = "Mapbox.Light",
    Satellite = "Mapbox.Satellite"
  ),
  Mapbox.Streets = "Mapbox.Streets",
  Mapbox.Dark = "Mapbox.Dark",
  Mapbox.Light = "Mapbox.Light",
  Mapbox.Satellite = "Mapbox.Satellite",

  Blank = list(
    Dark = "none",
    Light = "blank_light"
  )
)

#' Set or Retrieve a Provider API Key (`gl_set_api_key` / `gl_get_api_key`)
#'
#' Configures an API key for tile providers such as `"carto"` (`CartoDB`),
#' `"maptiler"`, `"stadia"`, `"thunderforest"`, `"jawg"`, `"mapbox"`, or `"esri"`.
#' Once set, all subsequent calls to [glmap()], [set_basemap()], and
#' [add_provider_tiles()] automatically inject the key into the provider's
#' style URL and tile URLs.
#'
#' @param provider Provider family name (e.g., `"carto"`, `"maptiler"`, `"stadia"`,
#'   `"thunderforest"`, `"jawg"`, `"mapbox"`, `"esri"`), or a named list of keys.
#' @param api_key API key string (or `NULL` to clear).
#' @return Invisibly returns the stored key(s).
#' @export
gl_set_api_key <- function(provider, api_key = NULL) {
  if (is.list(provider)) {
    for (nm in names(provider)) {
      gl_set_api_key(nm, provider[[nm]])
    }
    return(invisible(provider))
  }
  fam <- normalize_provider_family(provider)
  if (is.null(api_key) || !nzchar(as.character(api_key[1]))) {
    if (exists(fam, envir = .gl_env$api_keys, inherits = FALSE)) {
      rm(list = fam, envir = .gl_env$api_keys)
    }
    return(invisible(NULL))
  }
  val <- as.character(api_key[1])
  assign(fam, val, envir = .gl_env$api_keys)
  invisible(val)
}

#' @rdname gl_set_api_key
#' @export
gl_get_api_key <- function(provider) {
  fam <- normalize_provider_family(provider)
  if (exists(fam, envir = .gl_env$api_keys, inherits = FALSE)) {
    val <- get(fam, envir = .gl_env$api_keys, inherits = FALSE)
    if (!is.null(val) && nzchar(val)) return(val)
  }

  # Check R options: options(glmap.api_keys = list(carto = "...")) or options(glmap.carto.key = "...")
  opt_list <- getOption("glmap.api_keys")
  if (is.list(opt_list) && !is.null(opt_list[[fam]]) && nzchar(opt_list[[fam]])) {
    return(as.character(opt_list[[fam]]))
  }
  opt_single <- getOption(sprintf("glmap.%s_api_key", fam)) %||% getOption(sprintf("glmap.%s.key", fam))
  if (!is.null(opt_single) && nzchar(opt_single)) {
    return(as.character(opt_single))
  }

  # Check standard environment variables
  env_map <- list(
    carto         = c("CARTO_API_KEY", "CARTODB_API_KEY", "GLMAP_CARTO_API_KEY"),
    maptiler      = c("MAPTILER_API_KEY", "MAPTILER_KEY", "GLMAP_MAPTILER_API_KEY"),
    stadia        = c("STADIA_API_KEY", "STADIA_MAPS_API_KEY", "GLMAP_STADIA_API_KEY"),
    thunderforest = c("THUNDERFOREST_API_KEY", "GLMAP_THUNDERFOREST_API_KEY"),
    jawg          = c("JAWG_API_KEY", "JAWG_ACCESS_TOKEN", "GLMAP_JAWG_API_KEY"),
    mapbox        = c("MAPBOX_ACCESS_TOKEN", "MAPBOX_API_KEY", "GLMAP_MAPBOX_API_KEY"),
    esri          = c("ESRI_API_KEY", "ARCGIS_API_KEY", "GLMAP_ESRI_API_KEY")
  )
  vars <- env_map[[fam]] %||% toupper(sprintf("%s_API_KEY", fam))
  for (v in vars) {
    ev <- Sys.getenv(v, unset = "")
    if (nzchar(ev)) return(ev)
  }
  NULL
}

normalize_provider_family <- function(provider) {
  p <- tolower(as.character(provider[1]))
  if (grepl("^(dark|positron|light|voyager|carto)", p)) return("carto")
  if (grepl("^maptiler", p)) return("maptiler")
  if (grepl("^(stadia|stamen)", p)) return("stadia")
  if (grepl("^thunderforest", p)) return("thunderforest")
  if (grepl("^jawg", p)) return("jawg")
  if (grepl("^mapbox", p)) return("mapbox")
  if (grepl("^(esri|satellite)", p)) return("esri")
  if (grepl("^openfreemap", p)) return("openfreemap")
  if (grepl("^(osm|openstreetmap)", p)) return("osm")
  if (grepl("^(topo|opentopomap)", p)) return("opentopomap")
  if (grepl("^usgs", p)) return("usgs")
  p
}

# Inject optional API key into URL template (supports {apikey}, {api_key}, {key},
# {access_token}, {token} placeholders OR appends provider-appropriate query parameter)
inject_url_api_key <- function(urls, api_key = NULL, param_name = "key") {
  if (is.null(urls) || length(urls) == 0L) return(urls)
  has_placeholder <- any(grepl("\\{(apikey|api_key|key|access_token|token)\\}", urls, ignore.case = TRUE))

  if (is.null(api_key) || !nzchar(as.character(api_key[1]))) {
    if (has_placeholder) {
      # Strip ?key={apikey} or &key={apikey} cleanly if key was not supplied
      cleaned <- gsub("([?&])[^=&?]+=(\\{(apikey|api_key|key|access_token|token)\\})", "", urls, ignore.case = TRUE)
      cleaned <- gsub("\\{(apikey|api_key|key|access_token|token)\\}", "", cleaned, ignore.case = TRUE)
      cleaned <- gsub("\\?&", "?", cleaned)
      cleaned <- sub("[?&]$", "", cleaned)
      return(cleaned)
    }
    return(urls)
  }

  key_enc <- utils::URLencode(as.character(api_key[1]), reserved = TRUE)
  if (has_placeholder) {
    return(gsub("\\{(apikey|api_key|key|access_token|token)\\}", key_enc, urls, ignore.case = TRUE))
  }

  # Otherwise append ?<param_name>=<key> or &<param_name>=<key>
  vapply(urls, function(u) {
    if (!nzchar(u)) return(u)
    sep <- if (grepl("\\?", u)) "&" else "?"
    sprintf("%s%s%s=%s", u, sep, param_name, key_enc)
  }, character(1), USE.NAMES = FALSE)
}

#' List All Built-in Basemap Tile Providers in `glmap`
#'
#' Returns a `data.frame` summarizing every built-in vector and raster tile provider,
#' whether it uses WebGL vector tiles (`vector_gl`) or XYZ raster tiles (`raster_xyz`),
#' whether an API key is required or optional, and the environment variable name.
#'
#' @return A `data.frame` of available tile providers.
#' @export
gl_list_providers <- function() {
  data.frame(
    provider = c(
      "dark", "positron", "voyager", "osm", "satellite", "topo", "none",
      "CartoDB.DarkMatter", "CartoDB.DarkMatterNoLabels",
      "CartoDB.Positron", "CartoDB.PositronNoLabels",
      "CartoDB.Voyager", "CartoDB.VoyagerNoLabels",
      "OpenFreeMap.Liberty", "OpenFreeMap.Bright", "OpenFreeMap.Positron", "OpenFreeMap.Dark",
      "OpenStreetMap.Mapnik", "OpenStreetMap.HOT",
      "OpenTopoMap",
      "Esri.WorldImagery", "Esri.WorldTopoMap", "Esri.WorldStreetMap",
      "Esri.WorldShadedRelief", "Esri.OceanBasemap", "Esri.WorldGrayCanvas",
      "USGS.USTopo", "USGS.USImagery",
      "MapTiler.Streets", "MapTiler.Dataviz", "MapTiler.DatavizDark", "MapTiler.Satellite",
      "Stadia.AlidadeSmooth", "Stadia.AlidadeSmoothDark", "Stadia.StamenToner", "Stadia.StamenTerrain",
      "Thunderforest.Landscape", "Thunderforest.Outdoors", "Thunderforest.TransportDark",
      "Jawg.Streets", "Jawg.Dark",
      "Mapbox.Streets", "Mapbox.Dark", "Mapbox.Satellite"
    ),
    type = c(
      "vector_gl", "vector_gl", "vector_gl", "raster_xyz", "raster_xyz", "raster_xyz", "blank",
      "vector_gl", "raster_xyz",
      "vector_gl", "raster_xyz",
      "vector_gl", "raster_xyz",
      "vector_gl", "vector_gl", "vector_gl", "vector_gl",
      "raster_xyz", "raster_xyz",
      "raster_xyz",
      "raster_xyz", "raster_xyz", "raster_xyz",
      "raster_xyz", "raster_xyz", "raster_xyz",
      "raster_xyz", "raster_xyz",
      "vector_gl", "vector_gl", "vector_gl", "vector_gl",
      "vector_gl", "vector_gl", "raster_xyz", "raster_xyz",
      "raster_xyz", "raster_xyz", "raster_xyz",
      "raster_xyz", "raster_xyz",
      "raster_xyz", "raster_xyz", "raster_xyz"
    ),
    api_key_required = c(
      rep(FALSE, 28),
      rep(TRUE, 16)
    ),
    api_key_optional = c(
      TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE,
      rep(TRUE, 6),
      rep(FALSE, 7),
      rep(TRUE, 6),
      FALSE, FALSE,
      rep(TRUE, 16)
    ),
    env_var = c(
      "CARTO_API_KEY", "CARTO_API_KEY", "CARTO_API_KEY", "", "ESRI_API_KEY", "", "",
      rep("CARTO_API_KEY", 6),
      rep("", 7),
      rep("ESRI_API_KEY", 6),
      "", "",
      rep("MAPTILER_API_KEY", 4),
      rep("STADIA_API_KEY", 4),
      rep("THUNDERFOREST_API_KEY", 3),
      rep("JAWG_API_KEY", 2),
      rep("MAPBOX_ACCESS_TOKEN", 3)
    ),
    stringsAsFactors = FALSE
  )
}

#' Add or Switch Basemap Provider Tiles (`add_provider_tiles`)
#'
#' Drop-in equivalent of `leaflet::addProviderTiles()`. Accepts short aliases
#' (`"dark"`, `"positron"`, `"voyager"`, `"osm"`, `"satellite"`, `"topo"`),
#' any provider from [gl_providers] (e.g., `gl_providers$CartoDB.DarkMatter`,
#' `gl_providers$MapTiler.DatavizDark`, `gl_providers$Stadia.AlidadeSmoothDark`),
#' a custom MapLibre `style.json` URL, or a custom `{z}/{x}/{y}` XYZ tile URL
#' template with optional `{apikey}` / `{key}` / `{access_token}` placeholders!
#'
#' @param map A `glmap` widget or `glmap_proxy`.
#' @param provider Provider name from [gl_providers], short alias, style URL, or `{z}/{x}/{y}` tile URL.
#' @param api_key Optional API key string for the provider (or set globally via [gl_set_api_key()] / env vars).
#' @param key_param Optional query parameter name when appending `api_key` to a URL without placeholders (default auto-detected per provider, e.g., `"key"` or `"api_key"`).
#' @param attribution Optional custom attribution string when passing a custom `{z}/{x}/{y}` URL.
#' @param layerId,group,options Optional arguments kept for `leaflet::addProviderTiles()` compatibility.
#' @return Updated `glmap` object.
#' @export
add_provider_tiles <- function(
    map,
    provider = gl_providers$CartoDB.DarkMatter,
    api_key = NULL,
    key_param = NULL,
    attribution = "",
    layerId = NULL,
    group = NULL,
    options = list()
) {
  if (is.list(options) && !is.null(options$id) && tolower(as.character(provider[1])) == "mapbox") {
    provider <- as.character(options$id[1])
  }
  api_key <- api_key %||% (if (is.list(options)) (options$accessToken %||% options$apikey %||% options$key) else NULL)
  if (!is.null(group) && nzchar(group)) {
    cur_bg <- map$x$controls$layer_switcher$baseGroups %||% character(0)
    map$x$controls$layer_switcher$baseGroups <- unique(c(cur_bg, as.character(group)))
  }
  spec <- resolve_basemap_spec(provider, api_key = api_key, key_param = key_param, attribution = attribution)
  if (inherits(map, "glmap_proxy")) {
    return(invoke_proxy_method(map, "setBasemap", list(basemap = spec, name = as.character(provider[1]))))
  }
  map$x$basemap <- spec
  map$x$basemap_name <- as.character(provider[1])
  map
}
