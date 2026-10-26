# Clear All Data Layers from a Map (`clear_layers`, `clear_shapes`, `clear_markers`, `clear_controls`, `remove_shape`, `remove_marker`)

Clear All Data Layers from a Map (`clear_layers`, `clear_shapes`,
`clear_markers`, `clear_controls`, `remove_shape`, `remove_marker`)

## Usage

``` r
clear_layers(map)

clear_shapes(map)

clear_markers(map)

clear_controls(map)

remove_shape(map, layerId)

remove_marker(map, layerId)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- layerId:

  Character vector of layer ID(s) to remove.
