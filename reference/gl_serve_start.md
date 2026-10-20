# Start the local zero-copy binary & tile server (`gl_serve_start`)

Starts a background `httpuv` daemon server on `127.0.0.1` that streams
`GLMP` and `GLMR` binary buffers, gzipped payloads, and dynamic spatial
viewport slices directly to the browser without JSON serialization.

## Usage

``` r
gl_serve_start(port = NULL)
```

## Arguments

- port:

  Optional integer port. If `NULL`, a random available port is chosen.

## Value

The local server base URL (e.g., `"http://127.0.0.1:43210"`).
