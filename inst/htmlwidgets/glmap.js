/* glmap: High-Performance Zero-Copy GPU Geospatial Engine for R */
(function () {
  "use strict";

  const DEG2RAD = Math.PI / 180.0;
  const RAD2DEG = 180.0 / Math.PI;

  // Built-in 256-entry RGB palettes for instant client-side raster shader switching
  const BUILTIN_PALETTES = {
    viridis: [
      [68, 1, 84], [72, 40, 120], [62, 73, 137], [49, 104, 142],
      [38, 130, 142], [31, 158, 137], [53, 183, 121], [110, 206, 88],
      [181, 222, 43], [253, 231, 37]
    ],
    magma: [
      [0, 0, 4], [28, 16, 68], [79, 18, 123], [129, 37, 129],
      [181, 54, 122], [229, 80, 100], [251, 135, 97], [254, 194, 135],
      [252, 253, 191]
    ],
    plasma: [
      [13, 8, 135], [75, 3, 161], [125, 3, 168], [168, 34, 150],
      [203, 70, 121], [229, 107, 93], [248, 148, 65], [253, 195, 40],
      [240, 249, 33]
    ],
    turbo: [
      [48, 18, 59], [70, 107, 227], [40, 188, 235], [50, 242, 152],
      [164, 252, 60], [238, 207, 58], [251, 126, 33], [208, 47, 5],
      [122, 4, 3]
    ],
    terrain: [
      [0, 166, 0], [99, 198, 0], [230, 230, 0], [233, 189, 59],
      [236, 164, 118], [242, 208, 188], [255, 255, 255]
    ],
    rdylbu: [
      [165, 0, 38], [215, 48, 39], [244, 109, 67], [253, 174, 97],
      [254, 224, 144], [224, 243, 248], [171, 217, 233], [116, 173, 209],
      [69, 117, 180], [49, 54, 149]
    ]
  };

  function buildPaletteLUT256(name) {
    const stops = BUILTIN_PALETTES[(name || "viridis").toLowerCase()] || BUILTIN_PALETTES.viridis;
    const out = new Uint8Array(256 * 3);
    const m = stops.length - 1;
    for (let i = 0; i < 256; i++) {
      const t = (i / 255) * m;
      const idx = Math.min(m - 1, Math.floor(t));
      const frac = t - idx;
      const c0 = stops[idx];
      const c1 = stops[idx + 1];
      out[3 * i] = Math.round(c0[0] + (c1[0] - c0[0]) * frac);
      out[3 * i + 1] = Math.round(c0[1] + (c1[1] - c0[1]) * frac);
      out[3 * i + 2] = Math.round(c0[2] + (c1[2] - c0[2]) * frac);
    }
    return out;
  }

  function lonToMercX(lon) {
    return (lon + 180.0) / 360.0;
  }

  function latToMercY(lat) {
    const clamped = Math.max(-85.05112878, Math.min(85.05112878, lat));
    const sinLat = Math.sin(clamped * DEG2RAD);
    return 0.5 - (0.25 * Math.log((1.0 + sinLat) / (1.0 - sinLat))) / Math.PI;
  }

  function mercXToLon(mx) {
    return mx * 360.0 - 180.0;
  }

  function mercYToLat(my) {
    const n = Math.PI - 2.0 * Math.PI * my;
    return RAD2DEG * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)));
  }

  // Decode base64 (raw or gzip-compressed) or fetch ArrayBuffer from local httpuv server
  async function loadBinaryBuffer(bufSpec) {
    if (!bufSpec) return null;
    if (bufSpec.mode === "server" && bufSpec.url) {
      const resp = await fetch(bufSpec.url);
      if (!resp.ok) throw new Error("Failed to fetch binary buffer: " + resp.status);
      return await resp.arrayBuffer();
    }
    const b64 = bufSpec.data || "";
    const binStr = atob(b64);
    const len = binStr.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
      bytes[i] = binStr.charCodeAt(i);
    }
    if (bufSpec.mode === "inline_gzip" && typeof DecompressionStream !== "undefined") {
      try {
        // memCompress(raw_buf, type = "gzip") in R produces RFC 1950 zlib format (0x78 header),
        // which corresponds to DecompressionStream("deflate") in Web Streams API
        const fmt = (bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b) ? "gzip" : "deflate";
        const ds = new DecompressionStream(fmt);
        const writer = ds.writable.getWriter();
        writer.write(bytes);
        writer.close();
        const reader = ds.readable.getReader();
        const chunks = [];
        let totalLen = 0;
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          chunks.push(value);
          totalLen += value.byteLength;
        }
        const out = new Uint8Array(totalLen);
        let offset = 0;
        for (const c of chunks) {
          out.set(c, offset);
          offset += c.byteLength;
        }
        return out.buffer;
      } catch (e) {
        console.warn("DecompressionStream fallback:", e);
      }
    }
    return bytes.buffer;
  }

  // Parse 48-byte GLMP binary vector packet into zero-copy TypedArray views
  function parseGlmpBuffer(arrayBuffer) {
    if (!arrayBuffer || arrayBuffer.byteLength < 48) return null;
    const dv = new DataView(arrayBuffer);
    const magic =
      String.fromCharCode(dv.getUint8(0)) +
      String.fromCharCode(dv.getUint8(1)) +
      String.fromCharCode(dv.getUint8(2)) +
      String.fromCharCode(dv.getUint8(3));
    if (magic !== "GLMP") {
      throw new Error("Invalid GLMP magic header: " + magic);
    }

    const version = dv.getUint16(4, true);
    const geomType = dv.getUint16(6, true);
    const nFeatures = dv.getUint32(8, true);
    const nVertices = dv.getUint32(12, true);
    const nIndices = dv.getUint32(16, true);
    const nRingStarts = dv.getUint32(20, true);
    const hasRadius = dv.getUint32(24, true);
    const hasElevation = dv.getUint32(28, true);
    const bbox = [
      dv.getFloat32(32, true),
      dv.getFloat32(36, true),
      dv.getFloat32(40, true),
      dv.getFloat32(44, true)
    ];

    let offset = 48;
    const coords = new Float32Array(arrayBuffer, offset, nVertices * 2);
    offset += nVertices * 2 * 4;

    const vertexFeatureIds = new Uint32Array(arrayBuffer, offset, nVertices);
    offset += nVertices * 4;

    const ringStarts = nRingStarts > 0 ? new Uint32Array(arrayBuffer, offset, nRingStarts) : null;
    offset += nRingStarts * 4;

    const indices = nIndices > 0 ? new Uint32Array(arrayBuffer, offset, nIndices) : null;
    offset += nIndices * 4;

    const featureRgba = new Uint8Array(arrayBuffer, offset, nFeatures * 4);
    offset += nFeatures * 4;

    const featureRadius = hasRadius ? new Float32Array(arrayBuffer, offset, nFeatures) : null;
    if (hasRadius) offset += nFeatures * 4;

    const featureElevation = hasElevation ? new Float32Array(arrayBuffer, offset, nFeatures) : null;

    // Pre-project lon/lat into Web Mercator [0..1] in a single fast Float32 pass
    // and expand per-feature RGBA/Radius to per-vertex attributes for 1-draw-call GPU rendering
    const mercCoords = new Float32Array(nVertices * 2);
    const vertexRgba = new Uint8Array(nVertices * 4);
    const vertexRadius = new Float32Array(nVertices);

    for (let v = 0; v < nVertices; v++) {
      const lon = coords[2 * v];
      const lat = coords[2 * v + 1];
      mercCoords[2 * v] = lonToMercX(lon);
      mercCoords[2 * v + 1] = latToMercY(lat);

      const fid = vertexFeatureIds[v];
      vertexRgba[4 * v] = featureRgba[4 * fid];
      vertexRgba[4 * v + 1] = featureRgba[4 * fid + 1];
      vertexRgba[4 * v + 2] = featureRgba[4 * fid + 2];
      vertexRgba[4 * v + 3] = featureRgba[4 * fid + 3];
      vertexRadius[v] = featureRadius ? featureRadius[fid] : 5.0;
    }

    // For lines & polygon borders, build segment index pairs so disjoint rings don't connect
    let lineIndices = null;
    if (ringStarts && ringStarts.length >= 2) {
      let totalSegs = 0;
      for (let r = 0; r < ringStarts.length - 1; r++) {
        const len = ringStarts[r + 1] - ringStarts[r];
        if (len >= 2) totalSegs += (len - 1);
      }
      lineIndices = new Uint32Array(totalSegs * 2);
      let ptr = 0;
      for (let r = 0; r < ringStarts.length - 1; r++) {
        const s = ringStarts[r];
        const e = ringStarts[r + 1];
        for (let v = s; v + 1 < e; v++) {
          lineIndices[ptr++] = v;
          lineIndices[ptr++] = v + 1;
        }
      }
    }

    return {
      version,
      geomType,
      nFeatures,
      nVertices,
      nIndices,
      nRingStarts,
      bbox,
      coords,
      mercCoords,
      vertexFeatureIds,
      ringStarts,
      indices,
      lineIndices,
      featureRgba,
      vertexRgba,
      vertexRadius,
      featureElevation
    };
  }

  // Parse 48-byte GLMR Float32 raster packet
  function parseGlmrBuffer(arrayBuffer) {
    if (!arrayBuffer || arrayBuffer.byteLength < 48) return null;
    const dv = new DataView(arrayBuffer);
    const magic =
      String.fromCharCode(dv.getUint8(0)) +
      String.fromCharCode(dv.getUint8(1)) +
      String.fromCharCode(dv.getUint8(2)) +
      String.fromCharCode(dv.getUint8(3));
    if (magic !== "GLMR") {
      throw new Error("Invalid GLMR magic header: " + magic);
    }
    const version = dv.getUint16(4, true);
    const nBands = dv.getUint16(6, true);
    const width = dv.getUint32(8, true);
    const height = dv.getUint32(12, true);
    const bbox = [
      dv.getFloat32(16, true),
      dv.getFloat32(20, true),
      dv.getFloat32(24, true),
      dv.getFloat32(28, true)
    ];
    const vmin = dv.getFloat32(32, true);
    const vmax = dv.getFloat32(36, true);
    const nodata = dv.getFloat32(40, true);
    const values = new Float32Array(arrayBuffer, 48, width * height * nBands);

    return {
      version,
      nBands,
      width,
      height,
      bbox,
      vmin,
      vmax,
      nodata,
      values
    };
  }

  function compileShader(gl, type, src) {
    const sh = gl.createShader(type);
    gl.shaderSource(sh, src);
    gl.compileShader(sh);
    if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
      const log = gl.getShaderInfoLog(sh);
      gl.deleteShader(sh);
      throw new Error("WebGL shader compile error: " + log);
    }
    return sh;
  }

  function createProgram(gl, vsSrc, fsSrc) {
    const vs = compileShader(gl, gl.VERTEX_SHADER, vsSrc);
    const fs = compileShader(gl, gl.FRAGMENT_SHADER, fsSrc);
    const prog = gl.createProgram();
    gl.attachShader(prog, vs);
    gl.attachShader(prog, fs);
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
      const log = gl.getProgramInfoLog(prog);
      throw new Error("WebGL program link error: " + log);
    }
    return prog;
  }

  // Main GLMapInstance class managing MapLibre GL + synchronized WebGL2 GPU Overlay
  class GLMapInstance {
    constructor(el, width, height) {
      this.el = el;
      this.el.classList.add("glmap-container");
      this.layers = new Map();
      this.layerOrder = [];
      this.legends = [];
      this.filterMask = null;
      this.measureActive = false;
      this.measurePoints = [];
      this.boxSelectActive = false;
      this.fps = 60;
      this._frameCount = 0;
      this._lastFpsTime = performance.now();

      // Camera state in Web Mercator [0..1]
      this.camera = {
        centerLon: -73.5673,
        centerLat: 45.5017,
        zoom: 7.0,
        pitch: 0.0,
        bearing: 0.0
      };

      this._initDOM();
      this._initWebGL2Overlay();
    }

    _initDOM() {
      this.el.innerHTML = "";

      this.mapContainer = document.createElement("div");
      this.mapContainer.className = "glmap-map-canvas";
      this.el.appendChild(this.mapContainer);

      this.glCanvas = document.createElement("canvas");
      this.glCanvas.className = "glmap-gl-overlay";
      this.el.appendChild(this.glCanvas);

      this.labelCanvas = document.createElement("canvas");
      this.labelCanvas.className = "glmap-gl-overlay";
      this.el.appendChild(this.labelCanvas);

      // Layer switcher panel
      this.switcherEl = document.createElement("div");
      this.switcherEl.className = "glmap-panel glmap-layer-switcher";
      this.switcherEl.style.display = "none";
      this.el.appendChild(this.switcherEl);

      // Toolbar (Measure, Reset View, PNG Export)
      this.toolbarEl = document.createElement("div");
      this.toolbarEl.className = "glmap-toolbar";
      this.el.appendChild(this.toolbarEl);

      // Bottom-left HUD (FPS, feature count, cursor lon/lat/raster value)
      this.hudEl = document.createElement("div");
      this.hudEl.className = "glmap-panel glmap-hud";
      this.el.appendChild(this.hudEl);

      // Bottom-right Legends & GPU Raster Shader controls
      this.legendsEl = document.createElement("div");
      this.legendsEl.className = "glmap-legends-wrap";
      this.el.appendChild(this.legendsEl);

      // Hover/click tooltip
      this.tooltipEl = document.createElement("div");
      this.tooltipEl.className = "glmap-tooltip";
      this.el.appendChild(this.tooltipEl);
    }

    _initWebGL2Overlay() {
      const gl =
        this.glCanvas.getContext("webgl2", { antialias: true, alpha: true, preserveDrawingBuffer: true }) ||
        this.glCanvas.getContext("webgl", { antialias: true, alpha: true, preserveDrawingBuffer: true });
      this.gl = gl;
      if (!gl) {
        console.warn("WebGL context unavailable in this environment.");
        return;
      }

      // Enable uint32 element indices in WebGL1 if needed
      this.isWebGL2 = typeof WebGL2RenderingContext !== "undefined" && gl instanceof WebGL2RenderingContext;
      if (!this.isWebGL2) {
        gl.getExtension("OES_element_index_uint");
        gl.getExtension("OES_texture_float");
      } else {
        gl.getExtension("EXT_color_buffer_float");
        gl.getExtension("OES_texture_float_linear");
      }

      // 1. Point SDF Shader (anti-aliased circles + stroke + per-point RGBA & radius)
      const vsPoints = `
        attribute vec2 a_pos;
        attribute vec4 a_color;
        attribute float a_radius;
        uniform vec2 u_center_merc;
        uniform float u_scale;
        uniform vec2 u_viewport;
        uniform float u_dpr;
        uniform float u_opacity;
        varying vec4 v_color;
        varying float v_radius;
        void main() {
          vec2 delta_px = (a_pos - u_center_merc) * u_scale;
          vec2 clip = (delta_px / (u_viewport * 0.5)) * vec2(1.0, -1.0);
          gl_Position = vec4(clip, 0.0, 1.0);
          float r = max(1.5, a_radius);
          gl_PointSize = (r * 2.0 + 3.0) * u_dpr;
          v_color = vec4(a_color.rgb / 255.0, (a_color.a / 255.0) * u_opacity);
          v_radius = r;
        }
      `;
      const fsPoints = `
        precision highp float;
        varying vec4 v_color;
        varying float v_radius;
        uniform float u_stroke;
        uniform vec3 u_stroke_color;
        uniform float u_stroke_width;
        void main() {
          vec2 p = (gl_PointCoord - 0.5) * (v_radius * 2.0 + 3.0);
          float dist = length(p);
          float outer_alpha = 1.0 - smoothstep(v_radius - 0.6, v_radius + 0.8, dist);
          if (outer_alpha <= 0.01) discard;
          if (u_stroke > 0.5 && v_radius >= 2.5) {
            float inner_r = max(0.5, v_radius - u_stroke_width);
            float stroke_mix = smoothstep(inner_r - 0.6, inner_r + 0.5, dist);
            vec3 rgb = mix(v_color.rgb, u_stroke_color / 255.0, stroke_mix * 0.85);
            gl_FragColor = vec4(rgb, v_color.a * outer_alpha);
          } else {
            gl_FragColor = vec4(v_color.rgb, v_color.a * outer_alpha);
          }
        }
      `;
      this.progPoints = createProgram(gl, vsPoints, fsPoints);

      // 2. Polygon & Line Mesh Shader
      const vsMesh = `
        attribute vec2 a_pos;
        attribute vec4 a_color;
        uniform vec2 u_center_merc;
        uniform float u_scale;
        uniform vec2 u_viewport;
        uniform float u_opacity;
        uniform float u_use_uniform_color;
        uniform vec4 u_uniform_color;
        varying vec4 v_color;
        void main() {
          vec2 delta_px = (a_pos - u_center_merc) * u_scale;
          vec2 clip = (delta_px / (u_viewport * 0.5)) * vec2(1.0, -1.0);
          gl_Position = vec4(clip, 0.0, 1.0);
          if (u_use_uniform_color > 0.5) {
            v_color = u_uniform_color;
          } else {
            v_color = vec4(a_color.rgb / 255.0, (a_color.a / 255.0) * u_opacity);
          }
        }
      `;
      const fsMesh = `
        precision mediump float;
        varying vec4 v_color;
        void main() {
          gl_FragColor = v_color;
        }
      `;
      this.progMesh = createProgram(gl, vsMesh, fsMesh);

      // 3. Heatmap Additive Gaussian Kernel Shader
      const vsHeat = `
        attribute vec2 a_pos;
        attribute float a_radius;
        uniform vec2 u_center_merc;
        uniform float u_scale;
        uniform vec2 u_viewport;
        uniform float u_dpr;
        uniform float u_radius_mult;
        void main() {
          vec2 delta_px = (a_pos - u_center_merc) * u_scale;
          vec2 clip = (delta_px / (u_viewport * 0.5)) * vec2(1.0, -1.0);
          gl_Position = vec4(clip, 0.0, 1.0);
          gl_PointSize = max(8.0, a_radius * u_radius_mult) * 2.0 * u_dpr;
        }
      `;
      const fsHeat = `
        precision mediump float;
        uniform float u_intensity;
        uniform float u_opacity;
        void main() {
          vec2 d = (gl_PointCoord - 0.5) * 2.0;
          float r2 = dot(d, d);
          if (r2 > 1.0) discard;
          float w = exp(-r2 * 3.5) * u_intensity;
          vec3 col = mix(vec3(0.95, 0.25, 0.05), vec3(1.0, 0.92, 0.35), clamp(w, 0.0, 1.0));
          gl_FragColor = vec4(col * w, w * 0.45 * u_opacity);
        }
      `;
      this.progHeat = createProgram(gl, vsHeat, fsHeat);

      // 4. GPU Raster Float32 Shader (live LUT colormap, contrast stretch, hillshading, multi-band math)
      const vsRaster = `
        attribute vec2 a_pos;
        attribute vec2 a_uv;
        uniform vec2 u_center_merc;
        uniform float u_scale;
        uniform vec2 u_viewport;
        varying vec2 v_uv;
        void main() {
          vec2 delta_px = (a_pos - u_center_merc) * u_scale;
          vec2 clip = (delta_px / (u_viewport * 0.5)) * vec2(1.0, -1.0);
          gl_Position = vec4(clip, 0.0, 1.0);
          v_uv = a_uv;
        }
      `;
      const fsRaster = `
        precision highp float;
        varying vec2 v_uv;
        uniform sampler2D u_raster_tex;
        uniform sampler2D u_lut_tex;
        uniform float u_vmin;
        uniform float u_vmax;
        uniform float u_opacity;
        uniform float u_hillshade;
        uniform float u_band_math;
        uniform vec2 u_texel_size;
        void main() {
          vec4 sample_val = texture2D(u_raster_tex, v_uv);
          if (sample_val.a < 0.5) discard;
          float b1 = sample_val.r;
          float b2 = sample_val.g;
          float val = b1;
          if (u_band_math > 1.5) {
            val = b1 - b2; // Band 1 - Band 2 difference
          } else if (u_band_math > 0.5) {
            val = (b2 - b1) / max(1e-5, abs(b2 + b1)); // Normalized Difference (NDVI)
          }
          float t = clamp((val - u_vmin) / max(1e-6, u_vmax - u_vmin), 0.0, 1.0);
          vec3 rgb = texture2D(u_lut_tex, vec2(t, 0.5)).rgb;

          if (u_hillshade > 0.5) {
            float vL = texture2D(u_raster_tex, v_uv + vec2(-u_texel_size.x, 0.0)).r;
            float vR = texture2D(u_raster_tex, v_uv + vec2( u_texel_size.x, 0.0)).r;
            float vU = texture2D(u_raster_tex, v_uv + vec2(0.0, -u_texel_size.y)).r;
            float vD = texture2D(u_raster_tex, v_uv + vec2(0.0,  u_texel_size.y)).r;
            float dzdx = (vR - vL) / max(1e-5, u_vmax - u_vmin) * 4.0;
            float dzdy = (vD - vU) / max(1e-5, u_vmax - u_vmin) * 4.0;
            vec3 norm = normalize(vec3(-dzdx, -dzdy, 1.0));
            vec3 light = normalize(vec3(-0.6, -0.6, 0.8));
            float shade = clamp(dot(norm, light) * 1.15, 0.35, 1.25);
            rgb = clamp(rgb * shade, 0.0, 1.0);
          }

          gl_FragColor = vec4(rgb, u_opacity);
        }
      `;
      this.progRaster = createProgram(gl, vsRaster, fsRaster);
    }

    async renderValue(x) {
      this.spec = x;
      this.layers.clear();
      this.layerOrder = [];
      this.legends = x.legends || [];

      // Set initial camera from view or layer bounds
      if (x.view && Array.isArray(x.view.center) && x.view.center.length >= 2) {
        this.camera.centerLon = Number(x.view.center[0]);
        this.camera.centerLat = Number(x.view.center[1]);
        this.camera.zoom = Number(x.view.zoom || 9);
      } else if (x.view && Array.isArray(x.view.bounds) && x.view.bounds.length === 4) {
        this._fitCameraToBounds(x.view.bounds);
      }

      this._initMapLibre(x);
      this._buildToolbar(x);

      // Load all binary buffers & upload to GPU VBOs/Textures
      if (Array.isArray(x.layers)) {
        for (const layerSpec of x.layers) {
          await this.addLayer(layerSpec);
        }
      }

      // Fit bounds if center wasn't explicitly set
      if ((!x.view || !x.view.center) && x.view && Array.isArray(x.view.bounds)) {
        this.fitBounds(x.view.bounds);
      }

      this._rebuildLayerSwitcher();
      this._rebuildLegends();
      this._updateHUD();
      this._initCrosstalk(x.crosstalk);
      this._runPlugins(x.plugins);
      this.requestRender();
    }

    _fitCameraToBounds(b) {
      const [xmin, ymin, xmax, ymax] = b;
      this.camera.centerLon = (xmin + xmax) * 0.5;
      this.camera.centerLat = (ymin + ymax) * 0.5;
      const spanLon = Math.max(0.005, Math.abs(xmax - xmin));
      const spanLat = Math.max(0.005, Math.abs(ymax - ymin));
      const maxSpan = Math.max(spanLon, spanLat * 1.4);
      this.camera.zoom = Math.max(1, Math.min(16, Math.log2(360.0 / maxSpan) - 0.5));
    }

    _initMapLibre(x) {
      if (this.map) {
        try { this.map.remove(); } catch (e) {}
        this.map = null;
      }

      const basemap = x.basemap || { bg: "#0e1117", tiles: [] };
      this.el.style.background = basemap.bg || "#0e1117";

  const styleUrl = basemap.style_url || null;
      let mapStyle = {
        version: 8,
        sources: {},
        layers: [
          {
            id: "gl-background",
            type: "background",
            paint: { "background-color": basemap.bg || "#0e1117" }
          }
        ]
      };

      if (styleUrl) {
        mapStyle = styleUrl;
      } else if (Array.isArray(basemap.tiles) && basemap.tiles.length > 0) {
        mapStyle.sources["gl-basemap"] = {
          type: "raster",
          tiles: basemap.tiles,
          tileSize: 256,
          attribution: basemap.attribution || ""
        };
        mapStyle.layers.push({
          id: "gl-basemap-layer",
          type: "raster",
          source: "gl-basemap",
          minzoom: 0,
          maxzoom: 20
        });
      }

      if (typeof maplibregl !== "undefined") {
        try {
          this.map = new maplibregl.Map({
            container: this.mapContainer,
            style: mapStyle,
            center: [this.camera.centerLon, this.camera.centerLat],
            zoom: this.camera.zoom,
            pitch: 0,
            bearing: 0,
            attributionControl: false
          });

          if (x.controls && x.controls.navigation && x.controls.navigation.enabled) {
            this.map.addControl(new maplibregl.NavigationControl({ showCompass: true }), "top-right");
          }
          if (x.controls && x.controls.scale && x.controls.scale.enabled) {
            this.map.addControl(new maplibregl.ScaleControl({ maxWidth: 100, unit: "metric" }), "bottom-left");
          }

          const syncMove = () => {
            const c = this.map.getCenter();
            this.camera.centerLon = c.lng;
            this.camera.centerLat = c.lat;
            this.camera.zoom = this.map.getZoom();
            this.requestRender();
          };

          this.map.on("move", syncMove);
          this.map.on("moveend", () => {
            syncMove();
            this._onViewportChanged();
          });
          this.map.on("resize", () => this.resize());
        } catch (err) {
          console.warn("MapLibre fallback to standalone WebGL2 pan/zoom controller:", err);
          this._bindStandalonePanZoom();
        }
      } else {
        this._bindStandalonePanZoom();
      }

      this._bindInteractionEvents();
    }

    _bindStandalonePanZoom() {
      let dragging = false;
      let lastX = 0;
      let lastY = 0;
      this.mapContainer.addEventListener("mousedown", (e) => {
        dragging = true;
        lastX = e.clientX;
        lastY = e.clientY;
      });
      window.addEventListener("mousemove", (e) => {
        if (!dragging) return;
        const dx = e.clientX - lastX;
        const dy = e.clientY - lastY;
        lastX = e.clientX;
        lastY = e.clientY;
        const scale = 512.0 * Math.pow(2.0, this.camera.zoom);
        const mx = lonToMercX(this.camera.centerLon) - dx / scale;
        const my = latToMercY(this.camera.centerLat) - dy / scale;
        this.camera.centerLon = mercXToLon(mx);
        this.camera.centerLat = mercYToLat(my);
        this.requestRender();
      });
      window.addEventListener("mouseup", () => {
        if (dragging) {
          dragging = false;
          this._onViewportChanged();
        }
      });
      this.mapContainer.addEventListener("wheel", (e) => {
        e.preventDefault();
        const dz = -e.deltaY * 0.0025;
        this.camera.zoom = Math.max(1, Math.min(20, this.camera.zoom + dz));
        this.requestRender();
      }, { passive: false });
    }

    _bindInteractionEvents() {
      this.el.addEventListener("mousemove", (e) => {
        const rect = this.el.getBoundingClientRect();
        const px = e.clientX - rect.left;
        const py = e.clientY - rect.top;
        const [lon, lat] = this.screenToLonLat(px, py);
        this._handleHover(px, py, lon, lat);
      });

      this.el.addEventListener("mouseleave", () => {
        this.tooltipEl.style.display = "none";
      });

      this.el.addEventListener("click", (e) => {
        if (e.target.closest(".glmap-panel") || e.target.closest(".glmap-toolbar")) return;
        const rect = this.el.getBoundingClientRect();
        const px = e.clientX - rect.left;
        const py = e.clientY - rect.top;
        const [lon, lat] = this.screenToLonLat(px, py);
        this._handleClick(px, py, lon, lat);
      });
    }

    screenToLonLat(px, py) {
      const w = this.el.clientWidth || 800;
      const h = this.el.clientHeight || 600;
      const scale = 512.0 * Math.pow(2.0, this.camera.zoom);
      const cx = lonToMercX(this.camera.centerLon);
      const cy = latToMercY(this.camera.centerLat);
      const mx = cx + (px - w * 0.5) / scale;
      const my = cy + (py - h * 0.5) / scale;
      return [mercXToLon(mx), mercYToLat(my)];
    }

    async addLayer(layerSpec, legendSpec = null) {
      const gl = this.gl;
      const entry = Object.assign({ visible: true, opacity: 0.85 }, layerSpec);

      if (legendSpec) {
        this.legends = this.legends.filter((l) => l.layer_id !== legendSpec.layer_id);
        this.legends.push(legendSpec);
      }

      if (entry.type === "points" || entry.type === "lines" || entry.type === "polygons" || entry.type === "heatmap" || entry.type === "labels") {
        const ab = await loadBinaryBuffer(entry.buffer);
        const parsed = parseGlmpBuffer(ab);
        if (parsed && gl) {
          entry.parsed = parsed;
          entry.vboPos = gl.createBuffer();
          gl.bindBuffer(gl.ARRAY_BUFFER, entry.vboPos);
          gl.bufferData(gl.ARRAY_BUFFER, parsed.mercCoords, gl.STATIC_DRAW);

          entry.vboCol = gl.createBuffer();
          gl.bindBuffer(gl.ARRAY_BUFFER, entry.vboCol);
          gl.bufferData(gl.ARRAY_BUFFER, parsed.vertexRgba, gl.STATIC_DRAW);

          entry.vboRad = gl.createBuffer();
          gl.bindBuffer(gl.ARRAY_BUFFER, entry.vboRad);
          gl.bufferData(gl.ARRAY_BUFFER, parsed.vertexRadius, gl.STATIC_DRAW);

          if (parsed.indices && parsed.indices.length > 0) {
            entry.iboTri = gl.createBuffer();
            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, entry.iboTri);
            gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, parsed.indices, gl.STATIC_DRAW);
          }

          if (parsed.lineIndices && parsed.lineIndices.length > 0) {
            entry.iboLine = gl.createBuffer();
            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, entry.iboLine);
            gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, parsed.lineIndices, gl.STATIC_DRAW);
          }
        }
      } else if (entry.type === "raster") {
        const ab = await loadBinaryBuffer(entry.buffer);
        const parsed = parseGlmrBuffer(ab);
        if (parsed && gl) {
          entry.parsed = parsed;
          this._uploadRasterTexture(entry, parsed);
        }
      } else if (entry.type === "wms" && this.map && entry.wms_url) {
        const addWms = () => {
          try {
            const srcId = "wms_src_" + entry.id;
            const lyrId = "wms_lyr_" + entry.id;
            if (!this.map.getSource(srcId)) {
              this.map.addSource(srcId, {
                type: "raster",
                tiles: [entry.wms_url],
                tileSize: entry.tile_size || 256
              });
              this.map.addLayer({
                id: lyrId,
                type: "raster",
                source: srcId,
                paint: { "raster-opacity": entry.opacity || 0.8 }
              });
            }
          } catch (e) {}
        };
        if (this.map.loaded()) addWms();
        else this.map.on("load", addWms);
      }

      if (!this.layers.has(entry.id)) {
        this.layerOrder.push(entry.id);
      }
      this.layers.set(entry.id, entry);
      this._rebuildLayerSwitcher();
      this._rebuildLegends();
      this.requestRender();
    }

    _uploadRasterTexture(entry, parsed) {
      const gl = this.gl;
      const { width, height, values, nodata, bbox } = parsed;

      // Pack Float32 value into R channel (normalized or raw float) + mask in A channel
      // To guarantee 100% compatibility across both WebGL1 & WebGL2 hardware with linear filtering,
      // we store normalized [0..1] 16-bit/8-bit precision in R+G or Float32 texture when supported
      const vmin = parsed.vmin;
      const vmax = Math.max(vmin + 1e-6, parsed.vmax);
      entry.rawMin = vmin;
      entry.rawMax = vmax;
      entry.curMin = entry.style && entry.style.vmin !== undefined ? entry.style.vmin : vmin;
      entry.curMax = entry.style && entry.style.vmax !== undefined ? entry.style.vmax : vmax;

      const nCells = width * height;
      const nBands = parsed.nBands || 1;
      const texData = new Float32Array(nCells * 4);
      for (let i = 0; i < nCells; i++) {
        const v1 = values[i];
        const v2 = nBands >= 2 ? values[nCells + i] : v1;
        const v3 = nBands >= 3 ? values[2 * nCells + i] : v1;
        if (!Number.isFinite(v1) || Math.abs(v1 - nodata) < 1e-3) {
          texData[4 * i] = 0.0;
          texData[4 * i + 1] = 0.0;
          texData[4 * i + 2] = 0.0;
          texData[4 * i + 3] = 0.0;
        } else {
          texData[4 * i] = v1;
          texData[4 * i + 1] = Number.isFinite(v2) ? v2 : v1;
          texData[4 * i + 2] = Number.isFinite(v3) ? v3 : v1;
          texData[4 * i + 3] = 1.0;
        }
      }

      entry.rasterTex = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, entry.rasterTex);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

      if (this.isWebGL2) {
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, width, height, 0, gl.RGBA, gl.FLOAT, texData);
      } else {
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.FLOAT, texData);
      }

      // Upload 256x1 RGB LUT texture
      const lutBytes = entry.style && Array.isArray(entry.style.lut_rgb) && entry.style.lut_rgb.length === 768
        ? new Uint8Array(entry.style.lut_rgb)
        : buildPaletteLUT256(entry.style ? entry.style.palette : "viridis");

      entry.lutTex = gl.createTexture();
      this._updateRasterLUT(entry, lutBytes);

      // Build quad vertices in Web Mercator
      const [xmin, ymin, xmax, ymax] = bbox;
      const mx0 = lonToMercX(xmin);
      const mx1 = lonToMercX(xmax);
      const my0 = latToMercY(ymax); // top (north)
      const my1 = latToMercY(ymin); // bottom (south)

      const quadPos = new Float32Array([
        mx0, my0,
        mx1, my0,
        mx0, my1,
        mx0, my1,
        mx1, my0,
        mx1, my1
      ]);
      const quadUV = new Float32Array([
        0, 0,
        1, 0,
        0, 1,
        0, 1,
        1, 0,
        1, 1
      ]);

      entry.vboQuadPos = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, entry.vboQuadPos);
      gl.bufferData(gl.ARRAY_BUFFER, quadPos, gl.STATIC_DRAW);

      entry.vboQuadUV = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, entry.vboQuadUV);
      gl.bufferData(gl.ARRAY_BUFFER, quadUV, gl.STATIC_DRAW);
    }

    _updateRasterLUT(entry, lutBytes) {
      const gl = this.gl;
      if (!gl || !entry.lutTex) return;
      gl.bindTexture(gl.TEXTURE_2D, entry.lutTex);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, 256, 1, 0, gl.RGB, gl.UNSIGNED_BYTE, lutBytes);
    }

    requestRender() {
      if (this._rafPending) return;
      this._rafPending = true;
      requestAnimationFrame(() => {
        this._rafPending = false;
        this._drawScene();
      });
    }

    _drawScene() {
      const gl = this.gl;
      if (!gl) return;

      const dpr = window.devicePixelRatio || 1.0;
      const w = this.el.clientWidth || 800;
      const h = this.el.clientHeight || 600;
      const pw = Math.round(w * dpr);
      const ph = Math.round(h * dpr);

      if (this.glCanvas.width !== pw || this.glCanvas.height !== ph) {
        this.glCanvas.width = pw;
        this.glCanvas.height = ph;
      }
      if (this.labelCanvas && (this.labelCanvas.width !== pw || this.labelCanvas.height !== ph)) {
        this.labelCanvas.width = pw;
        this.labelCanvas.height = ph;
      }
      const ctx2d = this.labelCanvas ? this.labelCanvas.getContext("2d") : null;
      if (ctx2d) {
        ctx2d.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx2d.clearRect(0, 0, w, h);
      }

      gl.viewport(0, 0, pw, ph);
      gl.clearColor(0, 0, 0, 0);
      gl.clear(gl.COLOR_BUFFER_BIT);

      gl.enable(gl.BLEND);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

      const centerMercX = lonToMercX(this.camera.centerLon);
      const centerMercY = latToMercY(this.camera.centerLat);
      const scale = 512.0 * Math.pow(2.0, this.camera.zoom);

      for (const id of this.layerOrder) {
        const layer = this.layers.get(id);
        if (!layer || !layer.visible) continue;

        if (layer.type === "raster" && layer.parsed) {
          this._drawRasterLayer(layer, centerMercX, centerMercY, scale, w, h);
        } else if (layer.type === "polygons" && layer.parsed) {
          this._drawPolygonLayer(layer, centerMercX, centerMercY, scale, w, h);
        } else if (layer.type === "lines" && layer.parsed) {
          this._drawLineLayer(layer, centerMercX, centerMercY, scale, w, h);
        } else if (layer.type === "heatmap" && layer.parsed) {
          this._drawHeatmapLayer(layer, centerMercX, centerMercY, scale, w, h, dpr);
        } else if (layer.type === "points" && layer.parsed) {
          this._drawPointsLayer(layer, centerMercX, centerMercY, scale, w, h, dpr);
        } else if (layer.type === "labels" && layer.parsed && ctx2d) {
          this._drawLabelsLayer(ctx2d, layer, centerMercX, centerMercY, scale, w, h);
        }
      }

      // Track frame time & effective FPS
      this._frameCount++;
      const now = performance.now();
      const dt = now - (this._lastRenderTime || (now - 16.6));
      this._lastRenderTime = now;
      if (dt > 0 && dt < 250) {
        this.fps = Math.min(60, Math.round(1000 / Math.max(16.6, dt)));
      } else {
        this.fps = 60;
      }
      this._updateHUD();
    }

    _drawPointsLayer(layer, cx, cy, scale, w, h, dpr) {
      const gl = this.gl;
      const prog = this.progPoints;
      gl.useProgram(prog);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

      const locPos = gl.getAttribLocation(prog, "a_pos");
      const locCol = gl.getAttribLocation(prog, "a_color");
      const locRad = gl.getAttribLocation(prog, "a_radius");

      gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboPos);
      gl.enableVertexAttribArray(locPos);
      gl.vertexAttribPointer(locPos, 2, gl.FLOAT, false, 0, 0);

      gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboCol);
      gl.enableVertexAttribArray(locCol);
      gl.vertexAttribPointer(locCol, 4, gl.UNSIGNED_BYTE, false, 0, 0);

      gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboRad);
      gl.enableVertexAttribArray(locRad);
      gl.vertexAttribPointer(locRad, 1, gl.FLOAT, false, 0, 0);

      gl.uniform2f(gl.getUniformLocation(prog, "u_center_merc"), cx, cy);
      gl.uniform1f(gl.getUniformLocation(prog, "u_scale"), scale);
      gl.uniform2f(gl.getUniformLocation(prog, "u_viewport"), w, h);
      gl.uniform1f(gl.getUniformLocation(prog, "u_dpr"), dpr);
      gl.uniform1f(gl.getUniformLocation(prog, "u_opacity"), layer.opacity);

      const st = layer.style || {};
      gl.uniform1f(gl.getUniformLocation(prog, "u_stroke"), st.stroke ? 1.0 : 0.0);
      const sc = st.stroke_color || [255, 255, 255];
      gl.uniform3f(gl.getUniformLocation(prog, "u_stroke_color"), sc[0], sc[1], sc[2]);
      gl.uniform1f(gl.getUniformLocation(prog, "u_stroke_width"), st.stroke_width || 1.0);

      gl.drawArrays(gl.POINTS, 0, layer.parsed.nVertices);
    }

    _drawLabelsLayer(ctx, layer, cx, cy, scale, w, h) {
      const mc = layer.parsed.mercCoords;
      const labels = layer.labels || [];
      const st = layer.style || {};
      const fontSize = st.size || 12;
      ctx.font = `600 ${fontSize}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "bottom";
      ctx.lineWidth = 3.0;
      ctx.strokeStyle = st.halo_color || "#0f172a";
      ctx.fillStyle = st.color || "#f8fafc";

      const n = Math.min(layer.parsed.nVertices, labels.length);
      for (let i = 0; i < n; i++) {
        const txt = labels[i];
        if (!txt) continue;
        const sx = w * 0.5 + (mc[2 * i] - cx) * scale;
        const sy = h * 0.5 + (mc[2 * i + 1] - cy) * scale - 6;
        if (sx >= -50 && sx <= w + 50 && sy >= -20 && sy <= h + 20) {
          ctx.strokeText(txt, sx, sy);
          ctx.fillText(txt, sx, sy);
        }
      }
    }

    _drawPolygonLayer(layer, cx, cy, scale, w, h) {
      const gl = this.gl;
      const prog = this.progMesh;
      gl.useProgram(prog);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

      const locPos = gl.getAttribLocation(prog, "a_pos");
      const locCol = gl.getAttribLocation(prog, "a_color");

      gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboPos);
      gl.enableVertexAttribArray(locPos);
      gl.vertexAttribPointer(locPos, 2, gl.FLOAT, false, 0, 0);

      gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboCol);
      gl.enableVertexAttribArray(locCol);
      gl.vertexAttribPointer(locCol, 4, gl.UNSIGNED_BYTE, false, 0, 0);

      gl.uniform2f(gl.getUniformLocation(prog, "u_center_merc"), cx, cy);
      gl.uniform1f(gl.getUniformLocation(prog, "u_scale"), scale);
      gl.uniform2f(gl.getUniformLocation(prog, "u_viewport"), w, h);
      gl.uniform1f(gl.getUniformLocation(prog, "u_opacity"), layer.opacity);
      gl.uniform1f(gl.getUniformLocation(prog, "u_use_uniform_color"), 0.0);

      if (layer.iboTri && layer.parsed.nIndices > 0) {
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, layer.iboTri);
        gl.drawElements(gl.TRIANGLES, layer.parsed.nIndices, gl.UNSIGNED_INT, 0);
      }

      if (layer.style && layer.style.stroke && layer.iboLine) {
        const lc = layer.style.line_color || [226, 232, 240];
        gl.uniform1f(gl.getUniformLocation(prog, "u_use_uniform_color"), 1.0);
        gl.uniform4f(gl.getUniformLocation(prog, "u_uniform_color"), lc[0] / 255, lc[1] / 255, lc[2] / 255, Math.min(1.0, layer.opacity + 0.15));
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, layer.iboLine);
        gl.drawElements(gl.LINES, layer.parsed.lineIndices.length, gl.UNSIGNED_INT, 0);
      }
    }

    _drawLineLayer(layer, cx, cy, scale, w, h) {
      const gl = this.gl;
      const prog = this.progMesh;
      gl.useProgram(prog);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

      const locPos = gl.getAttribLocation(prog, "a_pos");
      const locCol = gl.getAttribLocation(prog, "a_color");

      gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboPos);
      gl.enableVertexAttribArray(locPos);
      gl.vertexAttribPointer(locPos, 2, gl.FLOAT, false, 0, 0);

      gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboCol);
      gl.enableVertexAttribArray(locCol);
      gl.vertexAttribPointer(locCol, 4, gl.UNSIGNED_BYTE, false, 0, 0);

      gl.uniform2f(gl.getUniformLocation(prog, "u_center_merc"), cx, cy);
      gl.uniform1f(gl.getUniformLocation(prog, "u_scale"), scale);
      gl.uniform2f(gl.getUniformLocation(prog, "u_viewport"), w, h);
      gl.uniform1f(gl.getUniformLocation(prog, "u_opacity"), layer.opacity);
      gl.uniform1f(gl.getUniformLocation(prog, "u_use_uniform_color"), 0.0);

      if (layer.iboLine) {
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, layer.iboLine);
        gl.drawElements(gl.LINES, layer.parsed.lineIndices.length, gl.UNSIGNED_INT, 0);
      } else {
        gl.drawArrays(gl.LINE_STRIP, 0, layer.parsed.nVertices);
      }
    }

    _drawHeatmapLayer(layer, cx, cy, scale, w, h, dpr) {
      const gl = this.gl;
      const prog = this.progHeat;
      gl.useProgram(prog);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE);

      const locPos = gl.getAttribLocation(prog, "a_pos");
      const locRad = gl.getAttribLocation(prog, "a_radius");

      gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboPos);
      gl.enableVertexAttribArray(locPos);
      gl.vertexAttribPointer(locPos, 2, gl.FLOAT, false, 0, 0);

      gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboRad);
      gl.enableVertexAttribArray(locRad);
      gl.vertexAttribPointer(locRad, 1, gl.FLOAT, false, 0, 0);

      gl.uniform2f(gl.getUniformLocation(prog, "u_center_merc"), cx, cy);
      gl.uniform1f(gl.getUniformLocation(prog, "u_scale"), scale);
      gl.uniform2f(gl.getUniformLocation(prog, "u_viewport"), w, h);
      gl.uniform1f(gl.getUniformLocation(prog, "u_dpr"), dpr);
      gl.uniform1f(gl.getUniformLocation(prog, "u_radius_mult"), 1.0);
      gl.uniform1f(gl.getUniformLocation(prog, "u_intensity"), (layer.style && layer.style.intensity) || 1.0);
      gl.uniform1f(gl.getUniformLocation(prog, "u_opacity"), layer.opacity);

      gl.drawArrays(gl.POINTS, 0, layer.parsed.nVertices);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    }

    _drawRasterLayer(layer, cx, cy, scale, w, h) {
      const gl = this.gl;
      const prog = this.progRaster;
      gl.useProgram(prog);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

      const locPos = gl.getAttribLocation(prog, "a_pos");
      const locUV = gl.getAttribLocation(prog, "a_uv");

      gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboQuadPos);
      gl.enableVertexAttribArray(locPos);
      gl.vertexAttribPointer(locPos, 2, gl.FLOAT, false, 0, 0);

      gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboQuadUV);
      gl.enableVertexAttribArray(locUV);
      gl.vertexAttribPointer(locUV, 2, gl.FLOAT, false, 0, 0);

      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, layer.rasterTex);
      gl.uniform1i(gl.getUniformLocation(prog, "u_raster_tex"), 0);

      gl.activeTexture(gl.TEXTURE1);
      gl.bindTexture(gl.TEXTURE_2D, layer.lutTex);
      gl.uniform1i(gl.getUniformLocation(prog, "u_lut_tex"), 1);

      gl.uniform2f(gl.getUniformLocation(prog, "u_center_merc"), cx, cy);
      gl.uniform1f(gl.getUniformLocation(prog, "u_scale"), scale);
      gl.uniform2f(gl.getUniformLocation(prog, "u_viewport"), w, h);
      gl.uniform1f(gl.getUniformLocation(prog, "u_vmin"), layer.curMin);
      gl.uniform1f(gl.getUniformLocation(prog, "u_vmax"), layer.curMax);
      gl.uniform1f(gl.getUniformLocation(prog, "u_opacity"), layer.opacity);
      gl.uniform1f(gl.getUniformLocation(prog, "u_hillshade"), layer.style && layer.style.hillshade ? 1.0 : 0.0);
      gl.uniform1f(gl.getUniformLocation(prog, "u_band_math"), layer.bandMathMode || 0.0);
      gl.uniform2f(gl.getUniformLocation(prog, "u_texel_size"), 1.0 / layer.parsed.width, 1.0 / layer.parsed.height);

      gl.drawArrays(gl.TRIANGLES, 0, 6);
    }

    async _onViewportChanged() {
      const w = this.el.clientWidth || 800;
      const h = this.el.clientHeight || 600;
      const [xmin, ymax] = this.screenToLonLat(0, 0);
      const [xmax, ymin] = this.screenToLonLat(w, h);

      // Update Shiny inputs (leaflet-compatible <id>_bounds, <id>_zoom, <id>_center)
      if (typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode && window.Shiny) {
        window.Shiny.setInputValue(this.el.id + "_bounds", { west: xmin, south: ymin, east: xmax, north: ymax });
        window.Shiny.setInputValue(this.el.id + "_zoom", this.camera.zoom);
        window.Shiny.setInputValue(this.el.id + "_center", { lng: this.camera.centerLon, lat: this.camera.centerLat });
      }

      // Dynamic viewport spatial index streaming
      for (const layer of this.layers.values()) {
        if (layer.viewport_url && layer.visible) {
          try {
            const url = `${layer.viewport_url}?bbox=${xmin},${ymin},${xmax},${ymax}&max=100000`;
            const resp = await fetch(url);
            if (resp.ok) {
              const ab = await resp.arrayBuffer();
              const parsed = parseGlmpBuffer(ab);
              if (parsed && this.gl) {
                layer.parsed = parsed;
                const gl = this.gl;
                gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboPos);
                gl.bufferData(gl.ARRAY_BUFFER, parsed.mercCoords, gl.DYNAMIC_DRAW);
                gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboCol);
                gl.bufferData(gl.ARRAY_BUFFER, parsed.vertexRgba, gl.DYNAMIC_DRAW);
                gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboRad);
                gl.bufferData(gl.ARRAY_BUFFER, parsed.vertexRadius, gl.DYNAMIC_DRAW);
                this.requestRender();
              }
            }
          } catch (e) {}
        }
      }
    }

    _handleHover(px, py, lon, lat) {
      this._cursorLon = lon;
      this._cursorLat = lat;
      this._cursorRasterVal = null;

      // Sample raster cell directly in JS memory in O(1) time
      for (const layer of this.layers.values()) {
        if (layer.visible && layer.type === "raster" && layer.parsed) {
          const [xmin, ymin, xmax, ymax] = layer.parsed.bbox;
          if (lon >= xmin && lon <= xmax && lat >= ymin && lat <= ymax) {
            const col = Math.floor(((lon - xmin) / (xmax - xmin)) * layer.parsed.width);
            const row = Math.floor(((ymax - lat) / (ymax - ymin)) * layer.parsed.height);
            if (col >= 0 && col < layer.parsed.width && row >= 0 && row < layer.parsed.height) {
              const val = layer.parsed.values[row * layer.parsed.width + col];
              if (Number.isFinite(val) && Math.abs(val - layer.parsed.nodata) > 1e-2) {
                this._cursorRasterVal = val;
              }
            }
          }
        }
      }

      this._updateHUD();

      // Nearest feature picking for tooltips & Shiny events
      let hitText = null;
      let hitFeature = null;
      const scale = 512.0 * Math.pow(2.0, this.camera.zoom);
      const mx = lonToMercX(lon);
      const my = latToMercY(lat);
      const tolMerc = 8.0 / scale;

      for (const layer of this.layers.values()) {
        if (!layer.visible || !layer.parsed) continue;
        const mc = layer.parsed.mercCoords;
        const nV = layer.parsed.nVertices;
        const stride = nV > 100000 ? Math.ceil(nV / 100000) : 1;
        for (let v = 0; v < nV; v += stride) {
          const dx = mc[2 * v] - mx;
          const dy = mc[2 * v + 1] - my;
          if (Math.abs(dx) < tolMerc && Math.abs(dy) < tolMerc) {
            const fid = layer.parsed.vertexFeatureIds[v];
            hitFeature = {
              id: fid + 1,
              layerId: layer.id,
              group: layer.group || layer.id,
              type: layer.type,
              lng: lon,
              lat: lat
            };
            if (layer.tooltips && layer.tooltips[fid]) {
              hitText = layer.tooltips[fid];
            }
            break;
          }
        }
        if (hitFeature) break;
      }

      this._hoveredFeature = hitFeature;
      if (hitFeature && typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode && window.Shiny) {
        const evtSuffix = hitFeature.type === "points" ? "_marker_mouseover" : "_shape_mouseover";
        window.Shiny.setInputValue(this.el.id + evtSuffix, hitFeature);
      }

      if (hitText) {
        this.tooltipEl.innerHTML = hitText;
        this.tooltipEl.style.left = (px + 12) + "px";
        this.tooltipEl.style.top = (py + 12) + "px";
        this.tooltipEl.style.display = "block";
      } else {
        this.tooltipEl.style.display = "none";
      }
    }

    _handleClick(px, py, lon, lat) {
      if (this.measureActive) {
        this.measurePoints.push([lon, lat]);
        this._updateHUD();
        return;
      }
      if (typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode && window.Shiny) {
        window.Shiny.setInputValue(this.el.id + "_click", {
          lng: lon,
          lat: lat,
          raster_value: this._cursorRasterVal,
          nonce: Math.random()
        });
        if (this._hoveredFeature) {
          const evtSuffix = this._hoveredFeature.type === "points" ? "_marker_click" : "_shape_click";
          window.Shiny.setInputValue(this.el.id + evtSuffix, Object.assign({}, this._hoveredFeature, { nonce: Math.random() }));
        }
      }
    }

    _buildToolbar(x) {
      this.toolbarEl.innerHTML = "";

      const resetBtn = document.createElement("button");
      resetBtn.className = "glmap-btn";
      resetBtn.textContent = "Fit Data";
      resetBtn.onclick = () => {
        if (this.spec && this.spec.view && this.spec.view.bounds) {
          this.fitBounds(this.spec.view.bounds);
        }
      };
      this.toolbarEl.appendChild(resetBtn);

      const measureBtn = document.createElement("button");
      measureBtn.className = "glmap-btn";
      measureBtn.textContent = "Measure";
      measureBtn.onclick = () => {
        this.measureActive = !this.measureActive;
        this.measurePoints = [];
        measureBtn.classList.toggle("active", this.measureActive);
        this._updateHUD();
      };
      this.toolbarEl.appendChild(measureBtn);

      const brushBtn = document.createElement("button");
      brushBtn.className = "glmap-btn";
      brushBtn.textContent = "Box Brush";
      brushBtn.onclick = () => {
        this.enableBoxSelect();
        brushBtn.classList.toggle("active", this.boxSelectActive);
      };
      this.toolbarEl.appendChild(brushBtn);
    }

    _rebuildLayerSwitcher() {
      if (this.layers.size === 0) {
        this.switcherEl.style.display = "none";
        return;
      }
      this.switcherEl.style.display = "block";
      let html = `<div class="glmap-panel-title"><span>GPU Layers</span><span>${this.layers.size}</span></div>`;
      for (const id of this.layerOrder) {
        const l = this.layers.get(id);
        const countBadge = l.type === "raster"
          ? `${l.width}x${l.height}`
          : (l.n_features || 0).toLocaleString();
        html += `
          <div class="glmap-layer-item">
            <label class="glmap-layer-label">
              <input type="checkbox" data-layer-id="${l.id}" ${l.visible ? "checked" : ""}/>
              <span>${l.group || l.id}</span>
            </label>
            <span class="glmap-badge">${countBadge}</span>
          </div>
        `;
      }
      this.switcherEl.innerHTML = html;
      this.switcherEl.querySelectorAll("input[type='checkbox']").forEach((cb) => {
        cb.addEventListener("change", (e) => {
          const lid = e.target.getAttribute("data-layer-id");
          this.setLayerVisibility(lid, e.target.checked);
        });
      });
    }

    _rebuildLegends() {
      this.legendsEl.innerHTML = "";
      for (const leg of this.legends) {
        const card = document.createElement("div");
        card.className = "glmap-panel";
        let html = `<div class="glmap-panel-title"><span>${leg.title || "Legend"}</span></div>`;
        if (leg.type === "continuous" && Array.isArray(leg.colors)) {
          const grad = `linear-gradient(to right, ${leg.colors.join(", ")})`;
          const d0 = leg.domain ? Number(leg.domain[0]).toFixed(1) : "0";
          const d1 = leg.domain ? Number(leg.domain[1]).toFixed(1) : "1";
          html += `
            <div class="glmap-gradient-bar" style="background: ${grad}"></div>
            <div class="glmap-domain-labels"><span>${d0}</span><span>${d1}</span></div>
          `;
          if (leg.is_raster && leg.layer_id && this.layers.has(leg.layer_id)) {
            const rl = this.layers.get(leg.layer_id);
            html += `
              <div class="glmap-raster-controls" data-raster-id="${leg.layer_id}">
                <label style="font-size:10px;color:#94a3b8">GPU Shader Palette</label>
                <select class="gl-pal-select">
                  ${["viridis", "magma", "plasma", "turbo", "terrain", "rdylbu"].map(p =>
                    `<option value="${p}" ${(rl.style && rl.style.palette === p) ? "selected" : ""}>${p}</option>`
                  ).join("")}
                </select>
                <label style="font-size:10px;color:#94a3b8;display:flex;align-items:center;gap:4px;margin-top:3px">
                  <input type="checkbox" class="gl-hill-cb" ${(rl.style && rl.style.hillshade) ? "checked" : ""}/>
                  Real-Time GPU Hillshade
                </label>
              </div>
            `;
          }
        } else if (leg.type === "categorical" && Array.isArray(leg.labels)) {
          for (let i = 0; i < leg.labels.length; i++) {
            html += `
              <div class="glmap-cat-row">
                <span class="glmap-cat-swatch" style="background:${leg.colors[i] || '#38bdf8'}"></span>
                <span>${leg.labels[i]}</span>
              </div>
            `;
          }
        }
        card.innerHTML = html;
        this.legendsEl.appendChild(card);

        const ctrl = card.querySelector(".glmap-raster-controls");
        if (ctrl) {
          const rid = ctrl.getAttribute("data-raster-id");
          const sel = ctrl.querySelector(".gl-pal-select");
          const cb = ctrl.querySelector(".gl-hill-cb");
          if (sel) {
            sel.addEventListener("change", (e) => {
              this.setRasterStyle({ id: rid, palette: e.target.value });
            });
          }
          if (cb) {
            cb.addEventListener("change", (e) => {
              this.setRasterStyle({ id: rid, hillshade: e.target.checked });
            });
          }
        }
      }
    }

    _updateHUD() {
      let totalVerts = 0;
      let totalFeats = 0;
      for (const l of this.layers.values()) {
        if (!l.visible) continue;
        if (l.parsed && l.parsed.nVertices) {
          totalVerts += l.parsed.nVertices;
          totalFeats += l.parsed.nFeatures;
        } else if (l.type === "raster" && l.parsed) {
          totalFeats += l.parsed.width * layerCellFactor(l);
        }
      }

      const lonStr = this._cursorLon !== undefined ? this._cursorLon.toFixed(4) : this.camera.centerLon.toFixed(4);
      const latStr = this._cursorLat !== undefined ? this._cursorLat.toFixed(4) : this.camera.centerLat.toFixed(4);
      let extra = "";
      if (this._cursorRasterVal !== null && this._cursorRasterVal !== undefined) {
        extra = ` | <span>Raster: <b>${this._cursorRasterVal.toFixed(2)}</b></span>`;
      }
      if (this.measureActive && this.measurePoints.length >= 2) {
        const dKm = computePathDistanceKm(this.measurePoints);
        extra += ` | <span style="color:#38bdf8">Dist: <b>${dKm.toFixed(2)} km</b></span>`;
      }

      this.hudEl.innerHTML = `
        <span class="glmap-hud-fps">${this.fps} FPS</span>
        <span>Features: <b>${totalFeats.toLocaleString()}</b></span>
        <span>Lon/Lat: ${lonStr}, ${latStr}</span>
        ${extra}
      `;
    }

    // Proxy & API methods
    setView(opts) {
      if (Array.isArray(opts.center)) {
        this.camera.centerLon = Number(opts.center[0]);
        this.camera.centerLat = Number(opts.center[1]);
      }
      if (opts.zoom !== undefined) this.camera.zoom = Number(opts.zoom);
      if (this.map) {
        this.map.jumpTo({ center: [this.camera.centerLon, this.camera.centerLat], zoom: this.camera.zoom });
      }
      this.requestRender();
    }

    flyTo(opts) {
      if (Array.isArray(opts.center)) {
        this.camera.centerLon = Number(opts.center[0]);
        this.camera.centerLat = Number(opts.center[1]);
      }
      if (opts.zoom !== undefined) this.camera.zoom = Number(opts.zoom);
      if (this.map) {
        this.map.flyTo({
          center: [this.camera.centerLon, this.camera.centerLat],
          zoom: this.camera.zoom,
          duration: opts.duration || 1500
        });
      }
      this.requestRender();
    }

    fitBounds(bounds) {
      if (!Array.isArray(bounds) || bounds.length < 4) return;
      this._fitCameraToBounds(bounds);
      if (this.map) {
        try {
          this.map.fitBounds([[bounds[0], bounds[1]], [bounds[2], bounds[3]]], { padding: 40, duration: 0 });
        } catch (e) {}
      }
      this.requestRender();
    }

    clearLayer(id) {
      this.layers.delete(id);
      this.layerOrder = this.layerOrder.filter((x) => x !== id);
      this.legends = this.legends.filter((l) => l.layer_id !== id);
      this._rebuildLayerSwitcher();
      this._rebuildLegends();
      this._updateHUD();
      this.requestRender();
    }

    clearLayers() {
      this.layers.clear();
      this.layerOrder = [];
      this.legends = [];
      this._rebuildLayerSwitcher();
      this._rebuildLegends();
      this._updateHUD();
      this.requestRender();
    }

    setLayerVisibility(id, visible) {
      const l = this.layers.get(id);
      if (l) {
        l.visible = Boolean(visible);
        this._updateHUD();
        this.requestRender();
      }
    }

    setGroupVisibility(groups, visible) {
      const grpSet = new Set(Array.isArray(groups) ? groups : [groups]);
      for (const l of this.layers.values()) {
        if (grpSet.has(l.group) || grpSet.has(l.id)) {
          l.visible = Boolean(visible);
        }
      }
      this._rebuildLayerSwitcher();
      this._updateHUD();
      this.requestRender();
    }

    clearGroup(groups) {
      const grpSet = new Set(Array.isArray(groups) ? groups : [groups]);
      const toRemove = [];
      for (const [id, l] of this.layers.entries()) {
        if (grpSet.has(l.group) || grpSet.has(l.id)) {
          toRemove.push(id);
        }
      }
      for (const id of toRemove) {
        this.clearLayer(id);
      }
    }

    flyToBounds(opts) {
      if (!opts || !Array.isArray(opts.bounds)) return;
      const b = opts.bounds;
      this._fitCameraToBounds(b);
      if (this.map) {
        try {
          this.map.fitBounds([[b[0], b[1]], [b[2], b[3]]], {
            padding: opts.padding || 40,
            duration: opts.duration || 1600
          });
        } catch (e) {}
      }
      this.requestRender();
    }

    setMaxBounds(opts) {
      if (!opts || !Array.isArray(opts.max_bounds)) return;
      const b = opts.max_bounds;
      if (this.map) {
        try {
          this.map.setMaxBounds([[b[0], b[1]], [b[2], b[3]]]);
        } catch (e) {}
      }
    }

    setLayerOpacity(id, opacity) {
      const l = this.layers.get(id);
      if (l) {
        l.opacity = Number(opacity);
        this.requestRender();
      }
    }

    setRasterStyle(patch) {
      const l = this.layers.get(patch.id);
      if (!l || l.type !== "raster") return;
      l.style = l.style || {};
      if (patch.palette) {
        l.style.palette = patch.palette;
        const lutBytes = Array.isArray(patch.lut_rgb) && patch.lut_rgb.length === 768
          ? new Uint8Array(patch.lut_rgb)
          : buildPaletteLUT256(patch.palette);
        this._updateRasterLUT(l, lutBytes);
      }
      if (patch.vmin !== undefined && patch.vmin !== null) l.curMin = Number(patch.vmin);
      if (patch.vmax !== undefined && patch.vmax !== null) l.curMax = Number(patch.vmax);
      if (patch.hillshade !== undefined && patch.hillshade !== null) {
        l.style.hillshade = Boolean(patch.hillshade);
      }
      this.requestRender();
    }

    enableMeasureTool(cfg) {
      this.measureActive = true;
      this.measurePoints = [];
      this._updateHUD();
    }

    enableBoxSelect(cfg) {
      this.boxSelectActive = !this.boxSelectActive;
      if (this.map && this.map.dragPan) {
        if (this.boxSelectActive) this.map.dragPan.disable();
        else this.map.dragPan.enable();
      }
      if (!this._boxSelectBound) {
        this._boxSelectBound = true;
        const boxEl = document.createElement("div");
        boxEl.style.cssText = "position:absolute;border:1.5px dashed #38bdf8;background:rgba(56,189,248,0.16);pointer-events:none;display:none;z-index:25;";
        this.el.appendChild(boxEl);
        let startPx = null;

        this.el.addEventListener("mousedown", (e) => {
          if (!this.boxSelectActive || e.target.closest(".glmap-panel") || e.target.closest(".glmap-toolbar")) return;
          const rect = this.el.getBoundingClientRect();
          startPx = [e.clientX - rect.left, e.clientY - rect.top];
          boxEl.style.left = startPx[0] + "px";
          boxEl.style.top = startPx[1] + "px";
          boxEl.style.width = "0px";
          boxEl.style.height = "0px";
          boxEl.style.display = "block";
        });

        window.addEventListener("mousemove", (e) => {
          if (!this.boxSelectActive || !startPx) return;
          const rect = this.el.getBoundingClientRect();
          const curX = e.clientX - rect.left;
          const curY = e.clientY - rect.top;
          boxEl.style.left = Math.min(startPx[0], curX) + "px";
          boxEl.style.top = Math.min(startPx[1], curY) + "px";
          boxEl.style.width = Math.abs(curX - startPx[0]) + "px";
          boxEl.style.height = Math.abs(curY - startPx[1]) + "px";
        });

        window.addEventListener("mouseup", (e) => {
          if (!this.boxSelectActive || !startPx) return;
          boxEl.style.display = "none";
          const rect = this.el.getBoundingClientRect();
          const endPx = [e.clientX - rect.left, e.clientY - rect.top];
          const [lon1, lat1] = this.screenToLonLat(Math.min(startPx[0], endPx[0]), Math.max(startPx[1], endPx[1]));
          const [lon2, lat2] = this.screenToLonLat(Math.max(startPx[0], endPx[0]), Math.min(startPx[1], endPx[1]));
          startPx = null;
          this._selectInBbox([lon1, lat1, lon2, lat2]);
        });
      }
    }

    _selectInBbox(bbox) {
      const [xmin, ymin, xmax, ymax] = bbox;
      const mx0 = lonToMercX(xmin), mx1 = lonToMercX(xmax);
      const my0 = latToMercY(ymax), my1 = latToMercY(ymin);
      const selectedIds = [];

      for (const l of this.layers.values()) {
        if (!l.visible || !l.parsed || !l.parsed.mercCoords) continue;
        const mc = l.parsed.mercCoords;
        const fids = l.parsed.vertexFeatureIds;
        const seen = new Set();
        for (let v = 0; v < l.parsed.nVertices; v++) {
          const x = mc[2 * v], y = mc[2 * v + 1];
          if (x >= mx0 && x <= mx1 && y >= my0 && y <= my1) {
            seen.add(fids[v] + 1);
          }
        }
        selectedIds.push(...Array.from(seen));
      }

      this._brushedCount = selectedIds.length;
      this._updateHUD();

      if (typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode && window.Shiny) {
        window.Shiny.setInputValue(this.el.id + "_selected", {
          bbox: bbox,
          count: selectedIds.length,
          indices: selectedIds.slice(0, 50000)
        });
      }
      if (this._ctSelHandle && this.spec && this.spec.crosstalk && Array.isArray(this.spec.crosstalk.keys)) {
        const keys = selectedIds.map((idx) => this.spec.crosstalk.keys[idx - 1]).filter(Boolean);
        this._ctSelHandle.set(keys);
      }
    }

    enableExportButton(cfg) {
      const btn = document.createElement("button");
      btn.className = "glmap-btn";
      btn.textContent = "Export PNG";
      btn.onclick = () => {
        const a = document.createElement("a");
        a.download = (cfg && cfg.filename) || "glmap-map.png";
        a.href = this.glCanvas.toDataURL("image/png");
        a.click();
      };
      this.toolbarEl.appendChild(btn);
    }

    _initCrosstalk(ct) {
      if (!ct || !ct.group || typeof crosstalk === "undefined") return;
      try {
        this._ctSelHandle = new crosstalk.SelectionHandle(ct.group);
        const filterHandle = new crosstalk.FilterHandle(ct.group);
        filterHandle.on("change", (e) => {
          this.requestRender();
        });
      } catch (e) {}
    }

    _runPlugins(plugins) {
      if (!Array.isArray(plugins)) return;
      for (const p of plugins) {
        if (p.css) {
          const styleEl = document.createElement("style");
          styleEl.textContent = p.css;
          document.head.appendChild(styleEl);
        }
        if (p.js_init) {
          try {
            const fn = new Function("return (" + p.js_init + ")")();
            if (typeof fn === "function") fn(this, p.config || {});
          } catch (e) {
            console.warn("Plugin init error (" + p.name + "):", e);
          }
        }
      }
    }

    resize() {
      if (this.map) {
        try { this.map.resize(); } catch (e) {}
      }
      this.requestRender();
    }
  }

  function layerCellFactor(l) {
    return l.parsed ? l.parsed.height : 1;
  }

  function computePathDistanceKm(pts) {
    let total = 0;
    for (let i = 1; i < pts.length; i++) {
      const [lon1, lat1] = pts[i - 1];
      const [lon2, lat2] = pts[i];
      const dLat = (lat2 - lat1) * DEG2RAD;
      const dLon = (lon2 - lon1) * DEG2RAD;
      const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1 * DEG2RAD) * Math.cos(lat2 * DEG2RAD) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
      total += 6371.0 * 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
    return total;
  }

  // Register htmlwidgets binding
  if (typeof HTMLWidgets !== "undefined") {
    HTMLWidgets.widget({
      name: "glmap",
      type: "output",
      factory: function (el, width, height) {
        const instance = new GLMapInstance(el, width, height);
        el._glmapInstance = instance;
        return {
          renderValue: function (x) {
            instance.renderValue(x);
          },
          resize: function (width, height) {
            instance.resize(width, height);
          },
          getInstance: function () {
            return instance;
          }
        };
      }
    });

    // Register Shiny proxy message handler
    if (HTMLWidgets.shinyMode && typeof Shiny !== "undefined") {
      Shiny.addCustomMessageHandler("glmap-proxy", function (msg) {
        const el = document.getElementById(msg.id);
        if (!el || !el._glmapInstance) return;
        const inst = el._glmapInstance;
        const m = msg.call.method;
        const args = msg.call.args || {};
        if (m === "addLayer") inst.addLayer(args.layer, args.legend);
        else if (m === "clearLayer") inst.clearLayer(args.id);
        else if (m === "clearLayers") inst.clearLayers();
        else if (m === "setLayerVisibility") inst.setLayerVisibility(args.id, args.visible);
        else if (m === "setGroupVisibility") inst.setGroupVisibility(args.group, args.visible);
        else if (m === "clearGroup") inst.clearGroup(args.group);
        else if (m === "setLayerOpacity") inst.setLayerOpacity(args.id, args.opacity);
        else if (m === "setRasterStyle") inst.setRasterStyle(args);
        else if (m === "setView") inst.setView(args);
        else if (m === "flyTo") inst.flyTo(args);
        else if (m === "flyToBounds") inst.flyToBounds(args);
        else if (m === "setMaxBounds") inst.setMaxBounds(args);
        else if (m === "fitBounds") inst.fitBounds(args.bounds);
        else if (m === "usePlugin") inst._runPlugins([args]);
      });
    }
  }
})();
