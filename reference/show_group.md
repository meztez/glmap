# Show, Hide, or Clear Layers by Group Name (`show_group`, `hide_group`, `clear_group`)

Drop-in equivalents of `leaflet::showGroup()`, `leaflet::hideGroup()`,
and `leaflet::clearGroup()`.

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
