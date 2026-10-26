# Leaflet-Compatible Color Palette Functions (`color_numeric`, `color_bin`, `color_quantile`, `color_factor`, `label_format`)

Drop-in equivalents of
[`leaflet::colorNumeric()`](https://rstudio.github.io/leaflet/reference/colorNumeric.html),
[`leaflet::colorBin()`](https://rstudio.github.io/leaflet/reference/colorNumeric.html),
[`leaflet::colorQuantile()`](https://rstudio.github.io/leaflet/reference/colorNumeric.html),
[`leaflet::colorFactor()`](https://rstudio.github.io/leaflet/reference/colorNumeric.html),
and
[`leaflet::labelFormat()`](https://rstudio.github.io/leaflet/reference/addLegend.html).
While `glmap` natively supports passing
`color = ~col, palette = "viridis"` directly to layer functions without
creating manual palette functions, these functions allow existing
`leaflet` scripts and Shiny apps that construct
`pal <- colorNumeric(...)` and call
`addPolygons(fillColor = ~pal(val)) |> addLegend(pal = pal, values = ~val)`
to run with zero code modifications.

## Usage

``` r
color_numeric(
  palette,
  domain,
  na.color = "#808080",
  alpha = FALSE,
  reverse = FALSE
)

color_bin(
  palette,
  domain,
  bins = 7,
  pretty = TRUE,
  na.color = "#808080",
  alpha = FALSE,
  reverse = FALSE,
  right = FALSE
)

color_quantile(
  palette,
  domain,
  n = 4,
  probs = seq(0, 1, length.out = n + 1),
  na.color = "#808080",
  alpha = FALSE,
  reverse = FALSE,
  right = FALSE
)

color_factor(
  palette,
  domain = NULL,
  levels = NULL,
  ordered = FALSE,
  na.color = "#808080",
  alpha = FALSE,
  reverse = FALSE
)

label_format(
  prefix = "",
  suffix = "",
  between = " - ",
  digits = 3,
  big.mark = ",",
  transform = identity
)

colorNumeric(
  palette,
  domain,
  na.color = "#808080",
  alpha = FALSE,
  reverse = FALSE
)

colorBin(
  palette,
  domain,
  bins = 7,
  pretty = TRUE,
  na.color = "#808080",
  alpha = FALSE,
  reverse = FALSE,
  right = FALSE
)

colorQuantile(
  palette,
  domain,
  n = 4,
  probs = seq(0, 1, length.out = n + 1),
  na.color = "#808080",
  alpha = FALSE,
  reverse = FALSE,
  right = FALSE
)

colorFactor(
  palette,
  domain = NULL,
  levels = NULL,
  ordered = FALSE,
  na.color = "#808080",
  alpha = FALSE,
  reverse = FALSE
)

labelFormat(
  prefix = "",
  suffix = "",
  between = " - ",
  digits = 3,
  big.mark = ",",
  transform = identity
)
```

## Arguments

- palette:

  Color palette name (`"viridis"`, `"YlOrRd"`, `"Blues"`, `"RdYlBu"`,
  etc.), character vector of hex/named colors, or palette function.

- domain:

  Numeric or categorical vector (or range) defining the input domain.

- na.color:

  Color string used for `NA` values (default `"#808080"`).

- alpha:

  Logical; whether to preserve alpha channel (default `FALSE`).

- reverse:

  Logical; whether to reverse the color ramp (default `FALSE`).

- bins:

  Numeric vector of explicit cut breaks or single integer number of bins
  (default `7`).

- pretty:

  Logical; whether to use
  [`pretty()`](https://rdrr.io/r/base/pretty.html) breaks when `bins` is
  a single number (default `TRUE`).

- right:

  Logical; whether intervals are closed on the right (default `FALSE`).

- n:

  Number of equal-count quantile bins (default `4`).

- probs:

  Optional numeric vector of quantile probabilities in `[0, 1]`.

- levels:

  Optional character vector of factor levels.

- ordered:

  Logical; whether levels are ordered (default `FALSE`).

- prefix, suffix:

  Optional string prefix/suffix for legend labels.

- between:

  Separator string between bin bounds (default `" - "`).

- digits:

  Number of significant digits for numeric legend formatting.

- big.mark:

  Thousands separator (default `","`).

- transform:

  Optional function applied to numeric values before formatting.

## Value

A palette function carrying `"paletteType"`, `"colorArgs"`, and
`"domain"` attributes compatible with both
[`glmap::add_legend()`](https://meztez.github.io/glmap/reference/add_legend.md)
and
[`leaflet::addLegend()`](https://rstudio.github.io/leaflet/reference/addLegend.html).
