# Add a Custom WebGL2 Shader Layer to a `glmap` Map

Enables R developers and extension packages to write custom GLSL vertex
and fragment shaders driven by `GLMP` binary coordinate/attribute
buffers.

## Usage

``` r
add_webgl_shader_layer(
  map,
  data = NULL,
  vertex_shader = NULL,
  fragment_shader = NULL,
  uniforms = list(),
  draw_mode = c("POINTS", "TRIANGLES", "LINES", "LINE_STRIP"),
  id = NULL,
  group = NULL
)
```

## Arguments

- map:

  A `glmap` widget or `glmap_proxy`.

- data:

  Optional `sf`, `sfc`, or `data.frame` packed into a `GLMP` binary
  buffer for the shader.

- vertex_shader:

  Custom GLSL vertex shader source string.

- fragment_shader:

  Custom GLSL fragment shader source string.

- uniforms:

  Named list of uniform values passed to the shader program.

- draw_mode:

  WebGL draw mode: `"POINTS"`, `"LINES"`, `"LINE_STRIP"`, or
  `"TRIANGLES"`.

- id:

  Layer ID.

- group:

  Layer group name.
