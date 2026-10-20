# Show, Hide, or Clear Layers by Group Name (`show_group`, `hide_group`, `clear_group`)

Drop-in equivalents of
[`leaflet::showGroup()`](https://rstudio.github.io/leaflet/reference/showGroup.html),
[`leaflet::hideGroup()`](https://rstudio.github.io/leaflet/reference/showGroup.html),
and
[`leaflet::clearGroup()`](https://rstudio.github.io/leaflet/reference/remove.html).

## Usage

``` r
show_group(map, group)

hide_group(map, group)

clear_group(map, group)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- group:

  Character vector of group name(s).
