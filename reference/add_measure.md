# Add an Interactive Distance & Area Measurement Control (`add_measure`)

Drop-in GPU equivalent of `leaflet::addMeasure()`. Adds an interactive
measurement widget (defaulting to `"bottom-right"`) that lets users
click vertices on the map to measure **geodesic path distance** (`m` /
`km` / `mi`) and **geodesic polygon area** (`sq. m` / `ha` / `sq. km` /
`acres`) with live segment rubber-banding, double-click to finish, and
1-click Clear.

## Usage

``` r
add_measure(
  map,
  position = "bottomright",
  primaryLengthUnit = "meters",
  secondaryLengthUnit = "kilometers",
  primaryAreaUnit = "sqmeters",
  secondaryAreaUnit = NULL,
  activeColor = "#38bdf8",
  completedColor = "#a855f7",
  localization = "en",
  order = 15
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- position:

  Anchor position in the 9-zone layout grid (default `"bottomright"`).

- primaryLengthUnit:

  Primary length unit (`"meters"`, `"kilometers"`, `"feet"`, `"miles"`).

- secondaryLengthUnit:

  Optional secondary length unit (`"kilometers"`, `"miles"`).

- primaryAreaUnit:

  Primary area unit (`"sqmeters"`, `"hectares"`, `"sqkilometers"`,
  `"acres"`).

- secondaryAreaUnit:

  Optional secondary area unit.

- activeColor:

  Stroke/vertex color while actively measuring (default `"#38bdf8"`).

- completedColor:

  Stroke/fill color when a measurement is completed (default
  `"#a855f7"`).

- localization:

  Language code (default `"en"`).

- order:

  Numeric draw order within the anchor zone (default `15`).

## Value

Updated `glmap` widget or `glmap_proxy`.
