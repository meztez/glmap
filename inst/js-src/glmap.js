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
    const out = new Uint8Array(256 * 4);
    const m = stops.length - 1;
    for (let i = 0; i < 256; i++) {
      const t = (i / 255) * m;
      const idx = Math.min(m - 1, Math.floor(t));
      const frac = t - idx;
      const c0 = stops[idx];
      const c1 = stops[idx + 1];
      out[4 * i] = Math.round(c0[0] + (c1[0] - c0[0]) * frac);
      out[4 * i + 1] = Math.round(c0[1] + (c1[1] - c0[1]) * frac);
      out[4 * i + 2] = Math.round(c0[2] + (c1[2] - c0[2]) * frac);
      out[4 * i + 3] = 255;
    }
    return out;
  }

  function ensureLUT256RGBA(lutRgba, lutRgb, fallbackName) {
    if (Array.isArray(lutRgba) && lutRgba.length === 1024) {
      return new Uint8Array(lutRgba);
    }
    if (Array.isArray(lutRgb) && lutRgb.length === 768) {
      const out = new Uint8Array(1024);
      for (let i = 0; i < 256; i++) {
        out[4 * i] = lutRgb[3 * i];
        out[4 * i + 1] = lutRgb[3 * i + 1];
        out[4 * i + 2] = lutRgb[3 * i + 2];
        out[4 * i + 3] = 255;
      }
      return out;
    }
    return buildPaletteLUT256(fallbackName);
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
      this.drawMode = null; // "polygon", "rectangle", "circle", "polyline", "marker"
      this.drawnFeatures = [];
      this._drawSeq = 0;
      this._activeDrawVertices = [];
      this._dragStartLonLat = null;
      this._dragCurLonLat = null;
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
      this.labels = this._defaultLabels();

      this._initDOM();
      this._initWebGL2Overlay();
    }

    _defaultLabels() {
      return {
        zoom_in: "Zoom in",
        zoom_out: "Zoom out",
        reset_north: "Reset bearing to north",
        layers_title: "Layers",
        basemap_header: "Basemap",
        overlays_header: "Overlays",
        marker_engine_header: "Marker / Icon Engine",
        marker_mode_auto: "Auto (Dynamic)",
        marker_mode_cluster: "Cluster + GPU Atlas",
        marker_mode_lod: "LOD Hybrid (Dots -> Icons)",
        marker_mode_atlas: "GPU Sprite Atlas (All Icons)",
        marker_mode_points: "GPU Fast Dots (SDF)",
        basemap_groups: {},
        layer_groups: {},
        legend_default_title: "Legend",
        layer_opacity: "Layer Opacity",
        shader_palette: "GPU Shader Palette",
        gpu_hillshade: "Real-Time GPU Hillshade",
        custom_palette: "custom (R)",
        draw_poly_label: "Poly",
        draw_rect_label: "Rect",
        draw_circle_label: "Circle",
        draw_line_label: "Line",
        draw_pin_label: "Pin",
        draw_clear_label: "Clear",
        draw_poly_title: "Draw a polygon",
        draw_rect_title: "Draw a rectangle",
        draw_circle_title: "Draw a circle",
        draw_line_title: "Draw a polyline",
        draw_pin_title: "Draw a marker",
        draw_clear_title: "Clear all drawn shapes",
        drawn_area_prefix: "Drawn Area #",
        remove_drawn_button: "Remove",
        measure_start: "Measure Distance / Area",
        measure_finish: "Finish Measure",
        measure_clear: "Clear",
        measure_length: "Length",
        measure_area: "Area",
        measure_hint: "Click points on map (3+ for area, double-click to finish)",
        search_placeholder: "Search address or place...",
        search_button_title: "Search OpenStreetMap",
        search_clear_title: "Clear search",
        search_searching: "Searching OpenStreetMap...",
        search_no_results: "No results found.",
        search_unavailable: "Search unavailable.",
        minimap_title: "Overview",
        export_png: "Export PNG",
        hud_features: "Features",
        hud_lon_lat: "Lon/Lat",
        hud_raster: "Raster",
        hud_dist: "Dist"
      };
    }

    _t(key, fallback) {
      if (this.labels && this.labels[key] !== undefined && this.labels[key] !== null && String(this.labels[key]).length > 0) {
        return String(this.labels[key]);
      }
      const def = this._defaultLabels();
      return def[key] !== undefined ? def[key] : (fallback || key);
    }

    _applyNavLabels() {
      if (!this.navControlEl) return;
      const btnIn = this.navControlEl.querySelector(".glmap-nav-in");
      const btnOut = this.navControlEl.querySelector(".glmap-nav-out");
      const btnComp = this.navControlEl.querySelector(".glmap-nav-compass");
      if (btnIn) {
        btnIn.title = this._t("zoom_in");
        btnIn.setAttribute("aria-label", this._t("zoom_in"));
      }
      if (btnOut) {
        btnOut.title = this._t("zoom_out");
        btnOut.setAttribute("aria-label", this._t("zoom_out"));
      }
      if (btnComp) {
        btnComp.title = this._t("reset_north");
        btnComp.setAttribute("aria-label", this._t("reset_north"));
      }
    }

    setLabels(patch) {
      if (!patch || typeof patch !== "object") return;
      const baseBg = Object.assign({}, (this.labels && this.labels.basemap_groups) || {}, patch.basemap_groups || {});
      const lyrGrp = Object.assign({}, (this.labels && this.labels.layer_groups) || {}, patch.layer_groups || {});
      this.labels = Object.assign(this._defaultLabels(), this.labels || {}, patch);
      this.labels.basemap_groups = baseBg;
      this.labels.layer_groups = lyrGrp;
      if (this.spec) this.spec.labels = this.labels;
      this._applyNavLabels();
      this._rebuildLayerSwitcher();
      this._rebuildLegends();
      if (this.drawSpec && this.drawSpec.enabled) {
        this.addDrawToolbar(this.drawSpec);
      }
      if (this.measureSpec && this.measureSpec.enabled !== false) {
        this._updateMeasureControlUI();
      }
      if (this.searchSpec && this.searchSpec.enabled !== false && this.searchEl) {
        const inp = this.searchEl.querySelector(".gl-osm-input");
        const btn = this.searchEl.querySelector(".gl-osm-btn");
        const clr = this.searchEl.querySelector(".gl-osm-clr");
        if (inp) inp.placeholder = this._t("search_placeholder");
        if (btn) btn.title = this._t("search_button_title");
        if (clr) clr.title = this._t("search_clear_title");
      }
      if (this.miniMapSpec && this.miniMapSpec.enabled !== false && this.miniMapEl) {
        const titleSpan = this.miniMapEl.querySelector(".gl-minimap-title");
        if (titleSpan) titleSpan.textContent = this._t("minimap_title");
      }
      this._updateHUD();
    }

    _initDOM() {
      this.el.innerHTML = "";
      this._iconCache = new Map();

      this.mapContainer = document.createElement("div");
      this.mapContainer.className = "glmap-map-canvas";
      this.el.appendChild(this.mapContainer);

      this.glCanvas = document.createElement("canvas");
      this.glCanvas.className = "glmap-gl-overlay";
      this.el.appendChild(this.glCanvas);

      this.labelCanvas = document.createElement("canvas");
      this.labelCanvas.className = "glmap-gl-overlay";
      this.el.appendChild(this.labelCanvas);

      // 9-Zone Directional & Ordered Layout Dock Grid (x = left|center|right, y = top|center|bottom)
      this.dockGridEl = document.createElement("div");
      this.dockGridEl.className = "glmap-dock-grid";
      this.el.appendChild(this.dockGridEl);

      this.slots = new Map();
      const positions = [
        "top-left", "top-center", "top-right",
        "center-left", "center-center", "center-right",
        "bottom-left", "bottom-center", "bottom-right"
      ];
      for (const pos of positions) {
        const slot = document.createElement("div");
        slot.className = `glmap-slot glmap-slot-${pos}`;
        slot.setAttribute("data-pos", pos);
        slot.setAttribute("data-dir", (pos === "top-center" || pos === "bottom-center") ? "horizontal" : "vertical");
        this.dockGridEl.appendChild(slot);
        this.slots.set(pos, slot);
      }

      // Navigation / Zoom + Compass Control (`add_control(type = "navigation", position = ...)`)
      this.navControlEl = document.createElement("div");
      this.navControlEl.className = "glmap-nav-control";
      this.navControlEl.innerHTML = `
        <button type="button" class="glmap-nav-btn glmap-nav-in" title="Zoom in" aria-label="Zoom in">+</button>
        <button type="button" class="glmap-nav-btn glmap-nav-out" title="Zoom out" aria-label="Zoom out">&minus;</button>
        <button type="button" class="glmap-nav-btn glmap-nav-compass" title="Reset bearing to north" aria-label="Reset bearing to north">
          <span class="glmap-compass-arrow">▲</span>
        </button>
      `;
      this.navControlEl.querySelector(".glmap-nav-in").onclick = (e) => {
        e.stopPropagation();
        if (this.map && typeof this.map.zoomIn === "function") this.map.zoomIn();
        else {
          this.camera.zoom = Math.min(20, this.camera.zoom + 1);
          this.requestRender();
          this._onViewportChanged();
        }
      };
      this.navControlEl.querySelector(".glmap-nav-out").onclick = (e) => {
        e.stopPropagation();
        if (this.map && typeof this.map.zoomOut === "function") this.map.zoomOut();
        else {
          this.camera.zoom = Math.max(1, this.camera.zoom - 1);
          this.requestRender();
          this._onViewportChanged();
        }
      };
      const btnComp = this.navControlEl.querySelector(".glmap-nav-compass");
      let compassDragStartX = null;
      let compassStartBearing = 0;
      let compassDragged = false;
      btnComp.addEventListener("mousedown", (e) => {
        if (e.button !== 0) return;
        e.stopPropagation();
        compassDragStartX = e.clientX;
        compassStartBearing = (this.map && typeof this.map.getBearing === "function") ? this.map.getBearing() : (this.camera.bearing || 0);
        compassDragged = false;
      });
      window.addEventListener("mousemove", (e) => {
        if (compassDragStartX === null) return;
        const dx = e.clientX - compassDragStartX;
        if (Math.abs(dx) > 2) compassDragged = true;
        if (compassDragged) {
          const nextBearing = ((compassStartBearing + dx * 0.8 + 540) % 360) - 180;
          this.camera.bearing = nextBearing;
          if (this.map && typeof this.map.setBearing === "function") {
            this.map.setBearing(nextBearing);
          } else {
            const arrow = this.navControlEl.querySelector(".glmap-compass-arrow");
            if (arrow) arrow.style.transform = `rotate(${-nextBearing}deg)`;
            this.requestRender();
          }
        }
      });
      window.addEventListener("mouseup", () => {
        if (compassDragStartX !== null) {
          compassDragStartX = null;
          if (compassDragged) this._onViewportChanged();
        }
      });
      btnComp.onclick = (e) => {
        e.stopPropagation();
        if (compassDragged) {
          compassDragged = false;
          return;
        }
        const curBearing = (this.map && typeof this.map.getBearing === "function") ? this.map.getBearing() : (this.camera.bearing || 0);
        const curPitch = (this.map && typeof this.map.getPitch === "function") ? this.map.getPitch() : (this.camera.pitch || 0);
        if (Math.abs(curBearing) > 0.5 || Math.abs(curPitch) > 0.5) {
          if (this.map && typeof this.map.resetNorthPitch === "function") this.map.resetNorthPitch();
          else {
            this.camera.bearing = 0;
            this.camera.pitch = 0;
            const arrow = this.navControlEl.querySelector(".glmap-compass-arrow");
            if (arrow) arrow.style.transform = "rotate(0deg)";
            this.requestRender();
          }
        } else if (this.initialCamera) {
          this.flyTo({
            center: [this.initialCamera.centerLon, this.initialCamera.centerLat],
            zoom: this.initialCamera.zoom,
            duration: 700
          });
        }
      };

      // Layer switcher panel
      this.switcherEl = document.createElement("div");
      this.switcherEl.className = "glmap-panel glmap-layer-switcher collapsed";
      this.switcherEl.style.display = "none";

      // Draw Toolbar (leaflet.extras::addDrawToolbar equivalent)
      this.drawToolbarEl = document.createElement("div");
      this.drawToolbarEl.className = "glmap-draw-toolbar";
      this.drawToolbarEl.style.display = "none";

      // Address / OSM Search Control (leaflet.extras::addSearchOSM equivalent)
      this.searchEl = document.createElement("div");
      this.searchEl.className = "glmap-panel glmap-search-control";
      this.searchEl.style.display = "none";

      // Distance & Area Measure Control (leaflet::addMeasure equivalent)
      this.measureControlEl = document.createElement("div");
      this.measureControlEl.className = "glmap-panel glmap-measure-control";
      this.measureControlEl.style.display = "none";

      // Overview MiniMap Control (leaflet::addMiniMap equivalent)
      this.miniMapEl = document.createElement("div");
      this.miniMapEl.className = "glmap-panel glmap-minimap-control";
      this.miniMapEl.style.display = "none";

      // Bottom-center HUD (FPS, feature count, cursor lon/lat/raster value)
      this.hudEl = document.createElement("div");
      this.hudEl.className = "glmap-panel glmap-hud";

      // Scale bar indicator (bottom-left)
      this.scaleEl = document.createElement("div");
      this.scaleEl.className = "glmap-scale-box";
      this.scaleEl.textContent = "50 km";

      // Legends & GPU Raster Shader controls (bottom-right, above attribution)
      this.legendsEl = document.createElement("div");
      this.legendsEl.className = "glmap-legends-wrap";

      // Attribution & Copyright label (fixed bottom-right, order 100)
      this.attributionEl = document.createElement("div");
      this.attributionEl.className = "glmap-attribution-box";

      // Hover tooltip
      this.tooltipEl = document.createElement("div");
      this.tooltipEl.className = "glmap-tooltip";
      this.el.appendChild(this.tooltipEl);

      // Interactive click popup (with close button & Remove button for drawn shapes)
      this.popupEl = document.createElement("div");
      this.popupEl.className = "glmap-popup";
      this.el.appendChild(this.popupEl);
    }

    _mountInSlot(el, position, order = 10, slotDirection = null) {
      const pos = this.slots.has(position) ? position : "top-right";
      const slot = this.slots.get(pos);
      if (slotDirection) {
        slot.setAttribute("data-dir", slotDirection);
      }
      el.setAttribute("data-order", String(order));
      el.style.order = String(order);
      if (el.parentNode !== slot) {
        slot.appendChild(el);
      }
    }

    _applyControlLayout(x) {
      const ctrls = (x && x.controls) || {};
      const nvCfg = ctrls.navigation || { enabled: true, position: "top-right", order: 10 };
      const lsCfg = ctrls.layer_switcher || { enabled: true, position: "top-left", order: 10, collapsed: true };
      const scCfg = ctrls.scale || { enabled: true, position: "bottom-left", order: 90 };
      const hdCfg = ctrls.hud || { enabled: true, position: "bottom-center", order: 20 };
      const lgCfg = ctrls.legends || { enabled: true, position: "bottom-right", order: 20 };
      const atCfg = ctrls.attribution || { enabled: true, position: "bottom-right", order: 100 };

      this.switcherEl.classList.toggle("collapsed", lsCfg.collapsed !== false);
      this._mountInSlot(this.navControlEl, nvCfg.position || "top-right", nvCfg.order || 10, nvCfg.direction || null);
      this.navControlEl.style.display = (nvCfg && nvCfg.enabled === false) ? "none" : "flex";
      this._mountInSlot(this.switcherEl, lsCfg.position || "top-left", lsCfg.order || 10);
      this._mountInSlot(this.scaleEl, scCfg.position || "bottom-left", scCfg.order || 90);
      this._mountInSlot(this.hudEl, hdCfg.position || "bottom-center", hdCfg.order || 20);
      this._mountInSlot(this.legendsEl, lgCfg.position || "bottom-right", lgCfg.order || 20);
      this._mountInSlot(this.attributionEl, atCfg.position || "bottom-right", atCfg.order || 100);
      if (ctrls.search && ctrls.search.enabled) {
        this.addSearchControl(ctrls.search);
      }
      if (ctrls.measure && ctrls.measure.enabled) {
        this.addMeasureControl(ctrls.measure);
      }
      if (ctrls.minimap && ctrls.minimap.enabled) {
        this.addMiniMapControl(ctrls.minimap);
      }
      this.scaleEl.style.display = (scCfg && scCfg.enabled === false) ? "none" : "block";
      this.hudEl.style.display = (hdCfg && hdCfg.enabled === false) ? "none" : "flex";

      const bm = (x && x.basemap) || {};
      this.attributionEl.innerHTML = bm.attribution || "&copy; <a href='https://www.openstreetmap.org/copyright' target='_blank'>OpenStreetMap</a> contributors &copy; <a href='https://carto.com/attributions' target='_blank'>CARTO</a>";
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
        uniform vec2 u_rot;
        varying vec4 v_color;
        varying float v_radius;
        void main() {
          vec2 d = (a_pos - u_center_merc) * u_scale;
          vec2 delta_px = vec2(d.x * u_rot.x + d.y * u_rot.y, -d.x * u_rot.y + d.y * u_rot.x);
          vec2 clip = (delta_px / (u_viewport * 0.5)) * vec2(1.0, -1.0);
          gl_Position = vec4(clip, 0.0, 1.0);
          float r = max(1.5, a_radius);
          gl_PointSize = (r * 2.0 + 3.0) * u_dpr;
          v_color = vec4(a_color.rgb / 255.0, u_opacity);
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
        uniform vec2 u_rot;
        varying vec4 v_color;
        void main() {
          vec2 d = (a_pos - u_center_merc) * u_scale;
          vec2 delta_px = vec2(d.x * u_rot.x + d.y * u_rot.y, -d.x * u_rot.y + d.y * u_rot.x);
          vec2 clip = (delta_px / (u_viewport * 0.5)) * vec2(1.0, -1.0);
          gl_Position = vec4(clip, 0.0, 1.0);
          if (u_use_uniform_color > 0.5) {
            v_color = u_uniform_color;
          } else {
            v_color = vec4(a_color.rgb / 255.0, u_opacity);
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
        uniform vec2 u_rot;
        void main() {
          vec2 d = (a_pos - u_center_merc) * u_scale;
          vec2 delta_px = vec2(d.x * u_rot.x + d.y * u_rot.y, -d.x * u_rot.y + d.y * u_rot.x);
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

      // 4. GPU Raster Float32 Shader (live RGBA LUT colormap, Web Mercator -> EPSG:4326 latitude unprojection, contrast stretch, hillshading, multi-band math)
      const vsRaster = `
        attribute vec2 a_pos;
        attribute vec2 a_uv;
        uniform vec2 u_center_merc;
        uniform float u_scale;
        uniform vec2 u_viewport;
        uniform vec2 u_rot;
        varying vec2 v_uv;
        void main() {
          vec2 d = (a_pos - u_center_merc) * u_scale;
          vec2 delta_px = vec2(d.x * u_rot.x + d.y * u_rot.y, -d.x * u_rot.y + d.y * u_rot.x);
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
        uniform vec2 u_lat_bounds;
        uniform vec2 u_merc_y_bounds;
        void main() {
          // Convert interpolated Web Mercator Y back to exact EPSG:4326 latitude so large-extent rasters hug coastlines tightly
          float my = mix(u_merc_y_bounds.x, u_merc_y_bounds.y, v_uv.y);
          float n = 3.141592653589793 - 6.283185307179586 * my;
          float lat = 57.29577951308232 * atan(0.5 * (exp(n) - exp(-n)));
          float v_lat = clamp((u_lat_bounds.y - lat) / max(1e-6, u_lat_bounds.y - u_lat_bounds.x), 0.0, 1.0);
          vec2 uv = vec2(v_uv.x, v_lat);

          vec4 sample_val = texture2D(u_raster_tex, uv);
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
          vec4 lut_col = texture2D(u_lut_tex, vec2(t, 0.5));
          if (lut_col.a <= 0.004) discard;
          vec3 rgb = lut_col.rgb;

          if (u_hillshade > 0.5) {
            float vL = texture2D(u_raster_tex, uv + vec2(-u_texel_size.x, 0.0)).r;
            float vR = texture2D(u_raster_tex, uv + vec2( u_texel_size.x, 0.0)).r;
            float vU = texture2D(u_raster_tex, uv + vec2(0.0, -u_texel_size.y)).r;
            float vD = texture2D(u_raster_tex, uv + vec2(0.0,  u_texel_size.y)).r;
            float dzdx = (vR - vL) / max(1e-5, u_vmax - u_vmin) * 4.0;
            float dzdy = (vD - vU) / max(1e-5, u_vmax - u_vmin) * 4.0;
            vec3 norm = normalize(vec3(-dzdx, -dzdy, 1.0));
            vec3 light = normalize(vec3(-0.6, -0.6, 0.8));
            float shade = clamp(dot(norm, light) * 1.15, 0.35, 1.25);
            rgb = clamp(rgb * shade, 0.0, 1.0);
          }

          gl_FragColor = vec4(rgb, lut_col.a * u_opacity);
        }
      `;
      this.progRaster = createProgram(gl, vsRaster, fsRaster);

      // 5. GPU Sprite Atlas Shader for Custom SVG/PNG Icons (1 draw call for 100k+ custom markers)
      const vsIcons = `
        attribute vec2 a_pos;
        attribute float a_icon_idx;
        uniform vec2 u_center_merc;
        uniform float u_scale;
        uniform vec2 u_viewport;
        uniform float u_dpr;
        uniform float u_icon_size;
        uniform vec2 u_rot;
        varying float v_icon_idx;
        void main() {
          vec2 d = (a_pos - u_center_merc) * u_scale;
          vec2 delta_px = vec2(d.x * u_rot.x + d.y * u_rot.y, -d.x * u_rot.y + d.y * u_rot.x);
          vec2 clip = (delta_px / (u_viewport * 0.5)) * vec2(1.0, -1.0);
          gl_Position = vec4(clip, 0.0, 1.0);
          gl_PointSize = u_icon_size * u_dpr;
          v_icon_idx = a_icon_idx;
        }
      `;
      const fsIcons = `
        precision highp float;
        varying float v_icon_idx;
        uniform sampler2D u_atlas_tex;
        uniform float u_atlas_count;
        uniform float u_opacity;
        void main() {
          vec2 p = gl_PointCoord;
          // Pad 4% inside cell to prevent texture bleeding across adjacent atlas sprites
          vec2 cell_uv = clamp(p, 0.02, 0.98);
          float u = (floor(v_icon_idx + 0.5) + cell_uv.x) / max(1.0, u_atlas_count);
          vec4 tex_col = texture2D(u_atlas_tex, vec2(u, cell_uv.y));
          if (tex_col.a <= 0.02) discard;
          gl_FragColor = vec4(tex_col.rgb, tex_col.a * u_opacity);
        }
      `;
      this.progIcons = createProgram(gl, vsIcons, fsIcons);
    }

    async renderValue(x) {
      this.spec = x;
      this.labels = Object.assign(this._defaultLabels(), (x && x.labels) || {});
      this._applyNavLabels();
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
      this.initialCamera = {
        centerLon: this.camera.centerLon,
        centerLat: this.camera.centerLat,
        zoom: this.camera.zoom
      };

      this._initMapLibre(x);
      this._applyControlLayout(x);

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
      this._emitActiveGroups();
      this._onViewportChanged();
      this._initCrosstalk(x.crosstalk);
      if (x.draw_toolbar && x.draw_toolbar.enabled) {
        this.addDrawToolbar(x.draw_toolbar);
      }
      if (x.initial_popup) {
        setTimeout(() => this.showPopup(x.initial_popup), 120);
      }
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

    _updateUIThemeFromBasemap(basemap, nameHint) {
      const explicitTheme = (this.spec && this.spec.ui_theme) || "auto";
      if (explicitTheme === "light" || explicitTheme === "dark") {
        this.el.setAttribute("data-ui-theme", explicitTheme);
        return;
      }
      const bgHex = String((basemap && basemap.bg) || "").trim();
      let isLight = false;
      if (/^#[0-9a-fA-F]{6}$/.test(bgHex)) {
        const r = parseInt(bgHex.slice(1, 3), 16);
        const g = parseInt(bgHex.slice(3, 5), 16);
        const b = parseInt(bgHex.slice(5, 7), 16);
        const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
        isLight = lum >= 0.5;
      } else {
        const nm = String(nameHint || (basemap && basemap.style_url) || "").toLowerCase();
        isLight = /positron|light|voyager|liberty|bright|osm|mapnik|topo|street|graycanvas|backdrop|outdoor|landscape|smooth(?!dark)/.test(nm);
      }
      this.el.setAttribute("data-ui-theme", isLight ? "light" : "dark");
    }

    _initMapLibre(x) {
      if (this.map) {
        try { this.map.remove(); } catch (e) {}
        this.map = null;
      }

      const basemap = x.basemap || { bg: "#0e1117", tiles: [] };
      this.el.style.background = basemap.bg || "#0e1117";
      this._updateUIThemeFromBasemap(basemap, x.basemap_name);
      if (!this._activeBaseGroup) {
        const isLightInit = this.el.getAttribute("data-ui-theme") === "light";
        const bName = String(x.basemap_name || "").toLowerCase();
        this._activeBaseGroup = bName.includes("satellite") || bName.includes("imagery")
          ? "Satellite"
          : (isLightInit ? "Light" : "Dark");
      }

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
            attributionControl: false,
            preserveDrawingBuffer: true
          });

          // Navigation control is mounted inside glmap's 9-zone dock grid (`this.navControlEl`)
          // so `add_control(type = "navigation", position = ...)` works dynamically and via proxy!

          const syncMove = () => {
            const c = this.map.getCenter();
            this.camera.centerLon = c.lng;
            this.camera.centerLat = c.lat;
            // MapLibre GL uses 512px world size at zoom 0; match its exact transform scale
            if (this.map.transform && this.map.transform.worldSize) {
              this.camera.worldSize = this.map.transform.worldSize;
            }
            this.camera.zoom = this.map.getZoom();
            if (typeof this.map.getBearing === "function") {
              this.camera.bearing = this.map.getBearing() || 0;
              if (this.navControlEl) {
                const arrow = this.navControlEl.querySelector(".glmap-compass-arrow");
                if (arrow) arrow.style.transform = `rotate(${-this.camera.bearing}deg)`;
              }
            }
            if (typeof this.map.getPitch === "function") {
              this.camera.pitch = this.map.getPitch() || 0;
            }
            this.requestRender();
          };

          this.map.on("load", () => {
            syncMove();
          });
          this.map.on("move", syncMove);
          this.map.on("moveend", () => {
            syncMove();
            this._onViewportChanged();
          });
          this.map.on("resize", () => this.requestRender());
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
      if (this.map && typeof this.map.unproject === "function") {
        try {
          const ll = this.map.unproject([px, py]);
          return [ll.lng, ll.lat];
        } catch (e) {}
      }
      const w = this.el.clientWidth || 800;
      const h = this.el.clientHeight || 600;
      const scale = this.camera.worldSize || (512.0 * Math.pow(2.0, this.camera.zoom));
      const cx = lonToMercX(this.camera.centerLon);
      const cy = latToMercY(this.camera.centerLat);
      const bRad = (this.camera.bearing || 0) * DEG2RAD;
      const c = Math.cos(bRad), s = Math.sin(bRad);
      const dxPx = px - w * 0.5;
      const dyPx = py - h * 0.5;
      const mx = cx + (dxPx * c - dyPx * s) / scale;
      const my = cy + (dxPx * s + dyPx * c) / scale;
      return [mercXToLon(mx), mercYToLat(my)];
    }

    async addLayer(layerSpec, legendSpec = null) {
      const gl = this.gl;
      const entry = Object.assign({ visible: true, opacity: 0.85 }, layerSpec);

      let addedUserGroup = false;
      if (entry.visible && entry.group && entry.group !== "sg_shape" && entry.group !== "js_single_call" && entry.group !== "cat_claims_overlay") {
        if (!this._selectedOverlayGroups) this._selectedOverlayGroups = new Set();
        if (!this._selectedOverlayGroups.has(entry.group)) {
          this._selectedOverlayGroups.add(entry.group);
          addedUserGroup = true;
        }
      }

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

          if (entry.style && entry.style.icons) {
            this._prepareLayerIconAtlas(entry, parsed);
          }

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
      if (addedUserGroup) this._emitActiveGroups();
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

      // Upload 256x1 RGBA LUT texture (preserving per-stop alpha such as transparent 0mm precipitation)
      const st = entry.style || {};
      const lutBytes = ensureLUT256RGBA(st.lut_rgba, st.lut_rgb, st.palette || "viridis");

      entry.lutTex = gl.createTexture();
      this._updateRasterLUT(entry, lutBytes);

      // Build quad vertices in Web Mercator
      const [xmin, ymin, xmax, ymax] = bbox;
      const mx0 = lonToMercX(xmin);
      const mx1 = lonToMercX(xmax);
      const my0 = latToMercY(ymax); // top (north)
      const my1 = latToMercY(ymin); // bottom (south)
      entry.latBounds = [ymin, ymax];
      entry.mercYBounds = [my0, my1];

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
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 256, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, lutBytes);
    }

    _prepareLayerIconAtlas(entry, parsed) {
      const gl = this.gl;
      if (!gl) return;
      const iconSpec = entry.style && entry.style.icons;
      if (!iconSpec) return;

      const n = parsed.nVertices;
      const iconIdxArr = new Float32Array(n);
      if (Array.isArray(iconSpec.indices)) {
        for (let i = 0; i < n; i++) {
          iconIdxArr[i] = Number(iconSpec.indices[i] || 0);
        }
      } else {
        const cIdx = Number(iconSpec.indices || 0);
        iconIdxArr.fill(cIdx);
      }

      entry.vboIcon = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, entry.vboIcon);
      gl.bufferData(gl.ARRAY_BUFFER, iconIdxArr, gl.STATIC_DRAW);
      entry.iconIdxArr = iconIdxArr;

      const cellPx = 64;
      if (iconSpec.type === "url" && Array.isArray(iconSpec.atlas) && iconSpec.atlas.length > 0) {
        const urls = iconSpec.atlas;
        const count = urls.length;
        entry.atlasCount = count;
        const atlasCanvas = document.createElement("canvas");
        atlasCanvas.width = count * cellPx;
        atlasCanvas.height = cellPx;
        const actx = atlasCanvas.getContext("2d");

        entry.atlasTex = gl.createTexture();
        const uploadAtlas = () => {
          if (!this.gl || !entry.atlasTex) return;
          gl.bindTexture(gl.TEXTURE_2D, entry.atlasTex);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
          gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, atlasCanvas);
          this.requestRender();
        };

        // Draw initial fallback circle badges so markers are immediately visible before SVGs finish loading
        for (let i = 0; i < count; i++) {
          actx.fillStyle = "#0284c7";
          actx.strokeStyle = "#ffffff";
          actx.lineWidth = 3;
          actx.beginPath();
          actx.arc(i * cellPx + cellPx * 0.5, cellPx * 0.5, cellPx * 0.34, 0, Math.PI * 2);
          actx.fill();
          actx.stroke();
        }
        uploadAtlas();

        urls.forEach((url, idx) => {
          let img = this._iconCache.get(url);
          const paintSlot = (loadedImg) => {
            if (!loadedImg || !loadedImg.complete || loadedImg.naturalWidth === 0) return;
            actx.clearRect(idx * cellPx, 0, cellPx, cellPx);
            const pad = 4;
            actx.drawImage(loadedImg, idx * cellPx + pad, pad, cellPx - pad * 2, cellPx - pad * 2);
            uploadAtlas();
          };
          if (img && img.complete && img.naturalWidth > 0) {
            paintSlot(img);
          } else {
            img = new Image();
            img.crossOrigin = "anonymous";
            img.onload = () => paintSlot(img);
            img.src = url;
            this._iconCache.set(url, img);
          }
        });
      } else if (iconSpec.type === "awesome") {
        const items = Array.isArray(iconSpec.atlas) && iconSpec.atlas.length > 0
          ? iconSpec.atlas
          : [{ markerColor: iconSpec.markerColor || "#0284c7", iconColor: iconSpec.iconColor || "#ffffff", text: iconSpec.text || "●" }];
        const count = items.length;
        entry.atlasCount = count;
        const atlasCanvas = document.createElement("canvas");
        atlasCanvas.width = count * cellPx;
        atlasCanvas.height = cellPx;
        const actx = atlasCanvas.getContext("2d");
        for (let i = 0; i < count; i++) {
          const it = items[i];
          const cxSlot = i * cellPx + cellPx * 0.5;
          actx.fillStyle = it.markerColor || "#0284c7";
          actx.strokeStyle = "#ffffff";
          actx.lineWidth = 3;
          actx.beginPath();
          actx.arc(cxSlot, cellPx * 0.5, cellPx * 0.38, 0, Math.PI * 2);
          actx.fill();
          actx.stroke();
          actx.fillStyle = it.iconColor || "#ffffff";
          actx.font = "bold 20px sans-serif";
          actx.textAlign = "center";
          actx.textBaseline = "middle";
          actx.fillText(it.text || "●", cxSlot, cellPx * 0.5);
        }

        entry.atlasTex = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, entry.atlasTex);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, atlasCanvas);
      }
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

      // Always sync exact camera center & worldSize from MapLibre right before drawing
      if (this.map && typeof this.map.getCenter === "function") {
        try {
          const c = this.map.getCenter();
          this.camera.centerLon = c.lng;
          this.camera.centerLat = c.lat;
          const newZoom = this.map.getZoom();
          if (this._activeSpiderfy && Math.abs(newZoom - this._activeSpiderfy.zoom) > 0.25) {
            this._activeSpiderfy = null;
          }
          this.camera.zoom = newZoom;
          if (typeof this.map.getBearing === "function") {
            this.camera.bearing = this.map.getBearing() || 0;
          }
          if (this.map.transform && this.map.transform.worldSize) {
            this.camera.worldSize = this.map.transform.worldSize;
          }
        } catch (e) {}
      }
      const bRad = (this.camera.bearing || 0) * DEG2RAD;
      this._curRotCos = Math.cos(bRad);
      this._curRotSin = Math.sin(bRad);

      const centerMercX = lonToMercX(this.camera.centerLon);
      const centerMercY = latToMercY(this.camera.centerLat);
      const scale = this.camera.worldSize || (512.0 * Math.pow(2.0, this.camera.zoom));

      this._activeClusterBadges = [];
      this._activeSpiderfiedLegs = [];

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
          this._dispatchPointAndIconRender(ctx2d, layer, centerMercX, centerMercY, scale, w, h, dpr);
        } else if (layer.type === "labels" && layer.parsed && ctx2d) {
          this._drawLabelsLayer(ctx2d, layer, centerMercX, centerMercY, scale, w, h);
        }
      }

      if (ctx2d) {
        this._renderDrawnFeatures2D(ctx2d, centerMercX, centerMercY, scale, w, h);
      }
      this._updateMiniMap(centerMercX, centerMercY, scale, w, h);

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

    _dispatchPointAndIconRender(ctx2d, layer, cx, cy, scale, w, h, dpr) {
      const st = layer.style || {};
      const hasIcons = Boolean(st.icons && layer.atlasTex && layer.vboIcon);
      const clCfg = st.cluster || {};
      const renCfg = st.render || {};
      const n = layer.parsed.nVertices || 0;
      const zoom = this.camera.zoom;

      // Determine active rendering mode (user override > layer render.mode > dynamic auto)
      let mode = this._userMarkerModeOverride || renCfg.mode || "auto";
      if (mode === "auto") {
        if (clCfg.enabled) {
          mode = "cluster";
        } else if (hasIcons) {
          mode = n > 2500 ? "lod" : "atlas";
        } else {
          mode = "points";
        }
      }

      // Option 2: Screen-Space Grid Clustering + GPU Singleton Sprites (with Spiderfy web expansion for overlapping coordinates)
      if (mode === "cluster" && ctx2d && n > 1) {
        const disableZoom = clCfg.disableClusteringAtZoom !== undefined ? Number(clCfg.disableClusteringAtZoom) : 21;
        if (zoom < disableZoom) {
          this._drawClusteredLayer(ctx2d, layer, cx, cy, scale, w, h, dpr);
          return;
        }
        // Once zoomed in past disableClusteringAtZoom, fall through to GPU Atlas / Points
      }

      // Option 3: Zoom-Level LOD (Level-of-Detail) Hybrid Cross-Fade (GPU SDF Points <-> WebGL2 Icon Atlas)
      if (mode === "lod") {
        if (!hasIcons) {
          this._drawPointsLayer(layer, cx, cy, scale, w, h, dpr, 1.0);
          return;
        }
        let z0 = renCfg.lod_min_zoom !== undefined ? Number(renCfg.lod_min_zoom) : (n <= 2500 ? 0 : (n <= 15000 ? 8.5 : 10.0));
        let z1 = renCfg.lod_max_zoom !== undefined ? Number(renCfg.lod_max_zoom) : (n <= 2500 ? 0 : (n <= 15000 ? 10.5 : 12.0));
        // If user explicitly switched to "lod" in UI on a small dataset where z1===0, use a sensible [8.5, 10.5] fade
        if (this._userMarkerModeOverride === "lod" && z1 <= 0) {
          z0 = 8.5;
          z1 = 10.5;
        }
        if (z1 <= 0 || zoom >= z1) {
          this._drawIconAtlasLayerGPU(layer, cx, cy, scale, w, h, dpr, null, null, 0, 1.0);
        } else if (zoom <= z0) {
          this._drawPointsLayer(layer, cx, cy, scale, w, h, dpr, 1.0);
        } else {
          // Smooth cross-fade transition band
          const t = (zoom - z0) / Math.max(0.1, z1 - z0);
          const smoothT = t * t * (3.0 - 2.0 * t);
          this._drawPointsLayer(layer, cx, cy, scale, w, h, dpr, 1.0 - smoothT * 0.85);
          this._drawIconAtlasLayerGPU(layer, cx, cy, scale, w, h, dpr, null, null, 0, smoothT);
        }
        return;
      }

      // Option 1: Full WebGL2 Texture Atlas Sprite Sheet (1 GPU draw call for all custom icons)
      if ((mode === "atlas" || mode === "cluster") && hasIcons) {
        this._drawIconAtlasLayerGPU(layer, cx, cy, scale, w, h, dpr, null, null, 0, 1.0);
        return;
      }

      // Pure GPU SDF Points
      this._drawPointsLayer(layer, cx, cy, scale, w, h, dpr, 1.0);
    }

    _drawPointsLayer(layer, cx, cy, scale, w, h, dpr, opacityMult = 1.0) {
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
      gl.uniform2f(gl.getUniformLocation(prog, "u_rot"), this._curRotCos || 1.0, this._curRotSin || 0.0);
      gl.uniform1f(gl.getUniformLocation(prog, "u_dpr"), dpr);
      gl.uniform1f(gl.getUniformLocation(prog, "u_opacity"), (layer.opacity !== undefined ? layer.opacity : 0.85) * opacityMult);

      const st = layer.style || {};
      gl.uniform1f(gl.getUniformLocation(prog, "u_stroke"), st.stroke ? 1.0 : 0.0);
      const sc = st.stroke_color || [255, 255, 255];
      gl.uniform3f(gl.getUniformLocation(prog, "u_stroke_color"), sc[0], sc[1], sc[2]);
      gl.uniform1f(gl.getUniformLocation(prog, "u_stroke_width"), st.stroke_width || 1.0);

      gl.drawArrays(gl.POINTS, 0, layer.parsed.nVertices);
    }

    _drawIconAtlasLayerGPU(layer, cx, cy, scale, w, h, dpr, customPosBuf, customIconBuf, customCount, opacityMult = 1.0) {
      const gl = this.gl;
      const prog = this.progIcons;
      if (!gl || !prog || !layer.atlasTex) return;

      const count = customPosBuf ? customCount : layer.parsed.nVertices;
      if (count <= 0) return;

      gl.useProgram(prog);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

      const locPos = gl.getAttribLocation(prog, "a_pos");
      const locIdx = gl.getAttribLocation(prog, "a_icon_idx");

      gl.bindBuffer(gl.ARRAY_BUFFER, customPosBuf || layer.vboPos);
      gl.enableVertexAttribArray(locPos);
      gl.vertexAttribPointer(locPos, 2, gl.FLOAT, false, 0, 0);

      gl.bindBuffer(gl.ARRAY_BUFFER, customIconBuf || layer.vboIcon);
      gl.enableVertexAttribArray(locIdx);
      gl.vertexAttribPointer(locIdx, 1, gl.FLOAT, false, 0, 0);

      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, layer.atlasTex);
      gl.uniform1i(gl.getUniformLocation(prog, "u_atlas_tex"), 0);

      const iconSpec = (layer.style && layer.style.icons) || {};
      const iconSize = Math.max(iconSpec.width || 28, iconSpec.height || 28);

      gl.uniform2f(gl.getUniformLocation(prog, "u_center_merc"), cx, cy);
      gl.uniform1f(gl.getUniformLocation(prog, "u_scale"), scale);
      gl.uniform2f(gl.getUniformLocation(prog, "u_viewport"), w, h);
      gl.uniform2f(gl.getUniformLocation(prog, "u_rot"), this._curRotCos || 1.0, this._curRotSin || 0.0);
      gl.uniform1f(gl.getUniformLocation(prog, "u_dpr"), dpr);
      gl.uniform1f(gl.getUniformLocation(prog, "u_icon_size"), iconSize);
      gl.uniform1f(gl.getUniformLocation(prog, "u_atlas_count"), layer.atlasCount || 1);
      gl.uniform1f(gl.getUniformLocation(prog, "u_opacity"), (layer.opacity !== undefined ? layer.opacity : 1.0) * opacityMult);

      gl.drawArrays(gl.POINTS, 0, count);
    }

    _drawClusteredLayer(ctx, layer, cx, cy, scale, w, h, dpr) {
      const gl = this.gl;
      const mc = layer.parsed.mercCoords;
      const coords = layer.parsed.coords;
      const n = layer.parsed.nVertices;
      const clCfg = (layer.style && layer.style.cluster) || {};
      const cellPx = Math.max(36, Number(clCfg.maxClusterRadius || 65));
      const cols = Math.max(1, Math.ceil(w / cellPx));
      const rows = Math.max(1, Math.ceil(h / cellPx));
      const halfW = w * 0.5;
      const halfH = h * 0.5;
      const pad = cellPx;

      // Fast O(N) screen-space spatial hash using pure arithmetic on precomputed mercCoords
      const buckets = new Map();
      const sp = (this._activeSpiderfy && this._activeSpiderfy.layerId === layer.id) ? this._activeSpiderfy : null;
      const spSet = sp ? sp.memberSet : null;

      const rotCos = this._curRotCos !== undefined ? this._curRotCos : 1.0;
      const rotSin = this._curRotSin !== undefined ? this._curRotSin : 0.0;

      for (let i = 0; i < n; i++) {
        if (spSet && spSet.has(i)) continue; // Spiderfied points are rendered on their expanded web legs!
        const mx = mc[2 * i];
        const my = mc[2 * i + 1];
        const dx = (mx - cx) * scale;
        const dy = (my - cy) * scale;
        const sx = halfW + (dx * rotCos + dy * rotSin);
        const sy = halfH + (-dx * rotSin + dy * rotCos);
        if (sx < -pad || sx > w + pad || sy < -pad || sy > h + pad) continue;
        const gx = Math.floor(sx / cellPx);
        const gy = Math.floor(sy / cellPx);
        const key = (gy + 16) * (cols + 32) + (gx + 16);
        let b = buckets.get(key);
        if (!b) {
          const lon = coords[2 * i];
          const lat = coords[2 * i + 1];
          b = {
            count: 1,
            sumSx: sx,
            sumSy: sy,
            firstIdx: i,
            indices: [i],
            minLon: lon,
            minLat: lat,
            maxLon: lon,
            maxLat: lat
          };
          buckets.set(key, b);
        } else {
          b.count++;
          b.sumSx += sx;
          b.sumSy += sy;
          if (b.indices.length < 64) b.indices.push(i);
          const lon = coords[2 * i];
          const lat = coords[2 * i + 1];
          if (lon < b.minLon) b.minLon = lon;
          if (lon > b.maxLon) b.maxLon = lon;
          if (lat < b.minLat) b.minLat = lat;
          if (lat > b.maxLat) b.maxLat = lat;
        }
      }

      // Separate singleton markers (rendered via GPU shader) from multi-point clusters
      const singles = [];
      const clusters = [];
      for (const b of buckets.values()) {
        if (b.count === 1) {
          singles.push(b.firstIdx);
        } else {
          clusters.push(b);
        }
      }

      // Compute spiderfied leg positions (circle or spiral web) in exact WebGL Mercator space
      let spScreenLegs = null;
      const spStartOffset = singles.length;
      if (sp && sp.indices && sp.indices.length > 0 && gl) {
        const hubMx = lonToMercX(sp.centerLon);
        const hubMy = latToMercY(sp.centerLat);
        const hDx = (hubMx - cx) * scale;
        const hDy = (hubMy - cy) * scale;
        const hubSx = halfW + (hDx * rotCos + hDy * rotSin);
        const hubSy = halfH + (-hDx * rotSin + hDy * rotCos);
        const mCount = sp.indices.length;
        spScreenLegs = [];
        const legVertsMerc = new Float32Array(mCount * 4);
        const legCols = new Uint8Array(mCount * 8);

        for (let k = 0; k < mCount; k++) {
          let legR, ang;
          if (mCount <= 8) {
            // Circular spiderfy fan (exact Leaflet.markercluster circle layout)
            legR = Math.max(30, 24 + mCount * 2.5);
            ang = (k / mCount) * Math.PI * 2.0 - Math.PI * 0.5;
          } else {
            // Spiral spiderfy web for 9+ overlapping markers
            legR = 28 + k * 4.5;
            ang = k * 0.65;
          }
          const lx = hubSx + legR * Math.cos(ang);
          const ly = hubSy + legR * Math.sin(ang);
          const lDx = lx - halfW;
          const lDy = ly - halfH;
          const lmx = cx + (lDx * rotCos - lDy * rotSin) / scale;
          const lmy = cy + (lDx * rotSin + lDy * rotCos) / scale;
          spScreenLegs.push({
            idx: sp.indices[k],
            sx: lx,
            sy: ly,
            hubSx: hubSx,
            hubSy: hubSy,
            mx: lmx,
            my: lmy
          });

          // Vertex 0: hub; Vertex 1: exact icon center in Web Mercator
          legVertsMerc[4 * k] = hubMx;
          legVertsMerc[4 * k + 1] = hubMy;
          legVertsMerc[4 * k + 2] = lmx;
          legVertsMerc[4 * k + 3] = lmy;
          for (let v = 0; v < 2; v++) {
            const off = (2 * k + v) * 4;
            legCols[off] = 30;
            legCols[off + 1] = 41;
            legCols[off + 2] = 59;
            legCols[off + 3] = 210;
          }
        }

        // Draw spiderfy legs + center hub pin on the WebGL canvas (`gl`) BEFORE drawing the GPU icons
        // so the legs sit strictly underneath the icons and terminate at the exact center of each icon!
        if (!layer.vboSpiderLegs) layer.vboSpiderLegs = gl.createBuffer();
        if (!layer.vboSpiderLegCols) layer.vboSpiderLegCols = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSpiderLegs);
        gl.bufferData(gl.ARRAY_BUFFER, legVertsMerc, gl.DYNAMIC_DRAW);
        gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSpiderLegCols);
        gl.bufferData(gl.ARRAY_BUFFER, legCols, gl.DYNAMIC_DRAW);

        const progM = this.progMesh;
        gl.useProgram(progM);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        const locMPos = gl.getAttribLocation(progM, "a_pos");
        const locMCol = gl.getAttribLocation(progM, "a_color");
        gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSpiderLegs);
        gl.enableVertexAttribArray(locMPos);
        gl.vertexAttribPointer(locMPos, 2, gl.FLOAT, false, 0, 0);
        gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSpiderLegCols);
        gl.enableVertexAttribArray(locMCol);
        gl.vertexAttribPointer(locMCol, 4, gl.UNSIGNED_BYTE, false, 0, 0);
        gl.uniform2f(gl.getUniformLocation(progM, "u_center_merc"), cx, cy);
        gl.uniform1f(gl.getUniformLocation(progM, "u_scale"), scale);
        gl.uniform2f(gl.getUniformLocation(progM, "u_viewport"), w, h);
        gl.uniform2f(gl.getUniformLocation(progM, "u_rot"), rotCos, rotSin);
        gl.uniform1f(gl.getUniformLocation(progM, "u_opacity"), 0.85);
        gl.uniform1f(gl.getUniformLocation(progM, "u_use_uniform_color"), 0.0);
        gl.drawArrays(gl.LINES, 0, mCount * 2);

        // Draw center hub pin via progPoints underneath the spiderfied icons
        if (!layer.vboSpiderHubPos) layer.vboSpiderHubPos = gl.createBuffer();
        if (!layer.vboSpiderHubCol) layer.vboSpiderHubCol = gl.createBuffer();
        if (!layer.vboSpiderHubRad) layer.vboSpiderHubRad = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSpiderHubPos);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([hubMx, hubMy]), gl.DYNAMIC_DRAW);
        gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSpiderHubCol);
        gl.bufferData(gl.ARRAY_BUFFER, new Uint8Array([30, 41, 59, 230]), gl.DYNAMIC_DRAW);
        gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSpiderHubRad);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([3.5]), gl.DYNAMIC_DRAW);

        const progP = this.progPoints;
        gl.useProgram(progP);
        const locPPos = gl.getAttribLocation(progP, "a_pos");
        const locPCol = gl.getAttribLocation(progP, "a_color");
        const locPRad = gl.getAttribLocation(progP, "a_radius");
        gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSpiderHubPos);
        gl.enableVertexAttribArray(locPPos);
        gl.vertexAttribPointer(locPPos, 2, gl.FLOAT, false, 0, 0);
        gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSpiderHubCol);
        gl.enableVertexAttribArray(locPCol);
        gl.vertexAttribPointer(locPCol, 4, gl.UNSIGNED_BYTE, false, 0, 0);
        gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSpiderHubRad);
        gl.enableVertexAttribArray(locPRad);
        gl.vertexAttribPointer(locPRad, 1, gl.FLOAT, false, 0, 0);
        gl.uniform2f(gl.getUniformLocation(progP, "u_center_merc"), cx, cy);
        gl.uniform1f(gl.getUniformLocation(progP, "u_scale"), scale);
        gl.uniform2f(gl.getUniformLocation(progP, "u_viewport"), w, h);
        gl.uniform2f(gl.getUniformLocation(progP, "u_rot"), rotCos, rotSin);
        gl.uniform1f(gl.getUniformLocation(progP, "u_dpr"), dpr);
        gl.uniform1f(gl.getUniformLocation(progP, "u_opacity"), 0.9);
        gl.uniform1f(gl.getUniformLocation(progP, "u_stroke"), 1.0);
        gl.uniform3f(gl.getUniformLocation(progP, "u_stroke_color"), 255, 255, 255);
        gl.uniform1f(gl.getUniformLocation(progP, "u_stroke_width"), 1.0);
        gl.drawArrays(gl.POINTS, 0, 1);
      }

      // 1. Render all unclustered singletons + spiderfied markers in 1 GPU draw call
      const extraCount = spScreenLegs ? spScreenLegs.length : 0;
      const totalGpuSingletons = singles.length + extraCount;
      if (totalGpuSingletons > 0 && gl) {
        const sCount = totalGpuSingletons;
        const posArr = new Float32Array(sCount * 2);
        for (let k = 0; k < singles.length; k++) {
          const idx = singles[k];
          posArr[2 * k] = mc[2 * idx];
          posArr[2 * k + 1] = mc[2 * idx + 1];
        }
        if (spScreenLegs) {
          for (let k = 0; k < spScreenLegs.length; k++) {
            const off = spStartOffset + k;
            posArr[2 * off] = spScreenLegs[k].mx;
            posArr[2 * off + 1] = spScreenLegs[k].my;
          }
        }
        if (!layer.vboSinglePos) layer.vboSinglePos = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSinglePos);
        gl.bufferData(gl.ARRAY_BUFFER, posArr, gl.DYNAMIC_DRAW);

        if (layer.style && layer.style.icons && layer.atlasTex && layer.iconIdxArr) {
          const idxArr = new Float32Array(sCount);
          for (let k = 0; k < singles.length; k++) {
            idxArr[k] = layer.iconIdxArr[singles[k]];
          }
          if (spScreenLegs) {
            for (let k = 0; k < spScreenLegs.length; k++) {
              idxArr[spStartOffset + k] = layer.iconIdxArr[spScreenLegs[k].idx];
            }
          }
          if (!layer.vboSingleIcon) layer.vboSingleIcon = gl.createBuffer();
          gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSingleIcon);
          gl.bufferData(gl.ARRAY_BUFFER, idxArr, gl.DYNAMIC_DRAW);
          this._drawIconAtlasLayerGPU(layer, cx, cy, scale, w, h, dpr, layer.vboSinglePos, layer.vboSingleIcon, sCount, 1.0);
        } else {
          const colArr = new Uint8Array(sCount * 4);
          const radArr = new Float32Array(sCount);
          const vRgba = layer.parsed.vertexRgba;
          const vRad = layer.parsed.vertexRadius;
          for (let k = 0; k < sCount; k++) {
            const idx = k < singles.length ? singles[k] : spScreenLegs[k - spStartOffset].idx;
            colArr[4 * k] = vRgba[4 * idx];
            colArr[4 * k + 1] = vRgba[4 * idx + 1];
            colArr[4 * k + 2] = vRgba[4 * idx + 2];
            colArr[4 * k + 3] = vRgba[4 * idx + 3];
            radArr[k] = vRad[idx];
          }
          if (!layer.vboSingleCol) layer.vboSingleCol = gl.createBuffer();
          if (!layer.vboSingleRad) layer.vboSingleRad = gl.createBuffer();
          gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSingleCol);
          gl.bufferData(gl.ARRAY_BUFFER, colArr, gl.DYNAMIC_DRAW);
          gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSingleRad);
          gl.bufferData(gl.ARRAY_BUFFER, radArr, gl.DYNAMIC_DRAW);

          const prog = this.progPoints;
          gl.useProgram(prog);
          gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
          const locPos = gl.getAttribLocation(prog, "a_pos");
          const locCol = gl.getAttribLocation(prog, "a_color");
          const locRad = gl.getAttribLocation(prog, "a_radius");
          gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSinglePos);
          gl.enableVertexAttribArray(locPos);
          gl.vertexAttribPointer(locPos, 2, gl.FLOAT, false, 0, 0);
          gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSingleCol);
          gl.enableVertexAttribArray(locCol);
          gl.vertexAttribPointer(locCol, 4, gl.UNSIGNED_BYTE, false, 0, 0);
          gl.bindBuffer(gl.ARRAY_BUFFER, layer.vboSingleRad);
          gl.enableVertexAttribArray(locRad);
          gl.vertexAttribPointer(locRad, 1, gl.FLOAT, false, 0, 0);
          gl.uniform2f(gl.getUniformLocation(prog, "u_center_merc"), cx, cy);
          gl.uniform1f(gl.getUniformLocation(prog, "u_scale"), scale);
          gl.uniform2f(gl.getUniformLocation(prog, "u_viewport"), w, h);
          gl.uniform2f(gl.getUniformLocation(prog, "u_rot"), rotCos, rotSin);
          gl.uniform1f(gl.getUniformLocation(prog, "u_dpr"), dpr);
          gl.uniform1f(gl.getUniformLocation(prog, "u_opacity"), layer.opacity);
          const st = layer.style || {};
          gl.uniform1f(gl.getUniformLocation(prog, "u_stroke"), st.stroke ? 1.0 : 0.0);
          const sc = st.stroke_color || [255, 255, 255];
          gl.uniform3f(gl.getUniformLocation(prog, "u_stroke_color"), sc[0], sc[1], sc[2]);
          gl.uniform1f(gl.getUniformLocation(prog, "u_stroke_width"), st.stroke_width || 1.0);
          gl.drawArrays(gl.POINTS, 0, sCount);
        }
      }

      // 2. Render Leaflet.markercluster-style dual-ring badges for clusters (at most ~150 on screen)
      ctx.font = "600 12px -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      for (let i = 0; i < clusters.length; i++) {
        const cl = clusters[i];
        const sx = cl.sumSx / cl.count;
        const sy = cl.sumSy / cl.count;
        const cnt = cl.count;
        let outerCol = "rgba(181, 226, 140, 0.6)";
        let innerCol = "rgba(110, 204, 57, 0.85)";
        let rIn = 15;
        if (cnt >= 100) {
          outerCol = "rgba(253, 156, 115, 0.6)";
          innerCol = "rgba(241, 128, 23, 0.88)";
          rIn = 19;
        } else if (cnt >= 10) {
          outerCol = "rgba(241, 211, 87, 0.6)";
          innerCol = "rgba(240, 194, 12, 0.88)";
          rIn = 17;
        }
        const rOut = rIn + 5;

        ctx.fillStyle = outerCol;
        ctx.beginPath();
        ctx.arc(sx, sy, rOut, 0, Math.PI * 2);
        ctx.fill();

        ctx.fillStyle = innerCol;
        ctx.beginPath();
        ctx.arc(sx, sy, rIn, 0, Math.PI * 2);
        ctx.fill();

        ctx.fillStyle = "#1e293b";
        ctx.fillText(String(cnt), sx, sy + 0.5);

        this._activeClusterBadges.push({
          layerId: layer.id,
          sx,
          sy,
          r: rOut,
          count: cnt,
          indices: cl.indices,
          bbox: [cl.minLon, cl.minLat, cl.maxLon, cl.maxLat]
        });
      }

      if (spScreenLegs) {
        this._activeSpiderfiedLegs = spScreenLegs.map((leg) => ({
          layerId: layer.id,
          group: layer.group || layer.id,
          idx: leg.idx,
          sx: leg.sx,
          sy: leg.sy,
          lon: coords[2 * leg.idx],
          lat: coords[2 * leg.idx + 1]
        }));
      }
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

      const rotCos = this._curRotCos !== undefined ? this._curRotCos : 1.0;
      const rotSin = this._curRotSin !== undefined ? this._curRotSin : 0.0;
      const n = Math.min(layer.parsed.nVertices, labels.length);
      for (let i = 0; i < n; i++) {
        const txt = labels[i];
        if (!txt) continue;
        const dx = (mc[2 * i] - cx) * scale;
        const dy = (mc[2 * i + 1] - cy) * scale;
        const sx = w * 0.5 + (dx * rotCos + dy * rotSin);
        const sy = h * 0.5 + (-dx * rotSin + dy * rotCos) - 6;
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
      gl.uniform2f(gl.getUniformLocation(prog, "u_rot"), this._curRotCos || 1.0, this._curRotSin || 0.0);
      gl.uniform1f(gl.getUniformLocation(prog, "u_opacity"), layer.opacity);
      gl.uniform1f(gl.getUniformLocation(prog, "u_use_uniform_color"), 0.0);

      if (layer.iboTri && layer.parsed.nIndices > 0 && (!layer.style || layer.style.fill !== false) && layer.opacity > 0.001) {
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, layer.iboTri);
        gl.drawElements(gl.TRIANGLES, layer.parsed.nIndices, gl.UNSIGNED_INT, 0);
      }

      if (layer.style && layer.style.stroke && layer.iboLine) {
        const lc = layer.style.line_color || [226, 232, 240];
        gl.uniform1f(gl.getUniformLocation(prog, "u_use_uniform_color"), 1.0);
        const lineAlpha = (layer.style && layer.style.fill === false) ? 0.92 : Math.min(1.0, Math.max(0.75, layer.opacity + 0.35));
        gl.uniform4f(gl.getUniformLocation(prog, "u_uniform_color"), lc[0] / 255, lc[1] / 255, lc[2] / 255, lineAlpha);
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
      gl.uniform2f(gl.getUniformLocation(prog, "u_rot"), this._curRotCos || 1.0, this._curRotSin || 0.0);
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
      gl.uniform2f(gl.getUniformLocation(prog, "u_rot"), this._curRotCos || 1.0, this._curRotSin || 0.0);
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
      gl.uniform2f(gl.getUniformLocation(prog, "u_rot"), this._curRotCos || 1.0, this._curRotSin || 0.0);
      gl.uniform1f(gl.getUniformLocation(prog, "u_vmin"), layer.curMin);
      gl.uniform1f(gl.getUniformLocation(prog, "u_vmax"), layer.curMax);
      gl.uniform1f(gl.getUniformLocation(prog, "u_opacity"), layer.opacity);
      gl.uniform1f(gl.getUniformLocation(prog, "u_hillshade"), layer.style && layer.style.hillshade ? 1.0 : 0.0);
      gl.uniform1f(gl.getUniformLocation(prog, "u_band_math"), layer.bandMathMode || 0.0);
      gl.uniform2f(gl.getUniformLocation(prog, "u_texel_size"), 1.0 / layer.parsed.width, 1.0 / layer.parsed.height);
      const lb = layer.latBounds || [layer.parsed.bbox[1], layer.parsed.bbox[3]];
      const mb = layer.mercYBounds || [latToMercY(lb[1]), latToMercY(lb[0])];
      gl.uniform2f(gl.getUniformLocation(prog, "u_lat_bounds"), lb[0], lb[1]);
      gl.uniform2f(gl.getUniformLocation(prog, "u_merc_y_bounds"), mb[0], mb[1]);

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
      if (this.measureActive) {
        this._updateMeasureControlUI();
        this.requestRender();
      }

      // Nearest feature picking for tooltips & Shiny events (check spiderfied legs first!)
      let hitText = null;
      let hitFeature = null;

      if (Array.isArray(this._activeSpiderfiedLegs) && this._activeSpiderfiedLegs.length > 0) {
        for (let k = this._activeSpiderfiedLegs.length - 1; k >= 0; k--) {
          const leg = this._activeSpiderfiedLegs[k];
          if (Math.hypot(px - leg.sx, py - leg.sy) <= 15) {
            const layer = this.layers.get(leg.layerId);
            const fid = layer && layer.parsed ? layer.parsed.vertexFeatureIds[leg.idx] : leg.idx;
            const customId = (layer && Array.isArray(layer.feature_ids) && layer.feature_ids[fid] !== undefined)
              ? layer.feature_ids[fid]
              : (fid + 1);
            hitFeature = {
              id: customId,
              featureIndex: fid + 1,
              layerId: leg.layerId,
              group: leg.group,
              type: "points",
              lng: leg.lon,
              lat: leg.lat
            };
            if (layer && layer.tooltips) {
              hitText = Array.isArray(layer.tooltips) ? layer.tooltips[fid] : layer.tooltips;
            }
            break;
          }
        }
      }

      const scale = 512.0 * Math.pow(2.0, this.camera.zoom);
      const mx = lonToMercX(lon);
      const my = latToMercY(lat);
      const tolMerc = 8.0 / scale;

      if (!hitFeature) {
        const picked = this._pickFeatureAt(lon, lat, mx, my, tolMerc);
        if (picked) {
          hitFeature = picked.feature;
          hitText = picked.tooltip;
        }
      }

      const prevHovered = this._hoveredFeature;
      this._hoveredFeature = hitFeature;
      const changedHover = (prevHovered ? prevHovered.id + ":" + prevHovered.layerId : "") !==
                           (hitFeature ? hitFeature.id + ":" + hitFeature.layerId : "");
      if (changedHover) {
        const hitLayer = hitFeature ? this.layers.get(hitFeature.layerId) : null;
        const prevLayer = prevHovered ? this.layers.get(prevHovered.layerId) : null;
        if ((hitLayer && hitLayer.style && hitLayer.style.highlight) || (prevLayer && prevLayer.style && prevLayer.style.highlight)) {
          this.requestRender();
        }
      }
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

    _pickFeatureAt(lon, lat, mx, my, tolMerc) {
      const ids = this.layerOrder.slice().reverse();
      // Pass 1: check points and labels first so point markers on top of polygons win
      for (const id of ids) {
        const layer = this.layers.get(id);
        if (!layer || !layer.visible || !layer.parsed) continue;
        if (layer.type !== "points" && layer.type !== "labels") continue;
        const mc = layer.parsed.mercCoords;
        const nV = layer.parsed.nVertices;
        const stride = nV > 150000 ? Math.ceil(nV / 150000) : 1;
        for (let v = 0; v < nV; v += stride) {
          const dx = mc[2 * v] - mx;
          const dy = mc[2 * v + 1] - my;
          if (Math.abs(dx) < tolMerc && Math.abs(dy) < tolMerc) {
            const fid = layer.parsed.vertexFeatureIds[v];
            const customId = (Array.isArray(layer.feature_ids) && layer.feature_ids[fid] !== undefined)
              ? layer.feature_ids[fid]
              : (fid + 1);
            return {
              feature: {
                id: customId,
                featureIndex: fid + 1,
                layerId: layer.id,
                group: layer.group || layer.id,
                type: layer.type,
                lng: lon,
                lat: lat
              },
              tooltip: (layer.tooltips && layer.tooltips[fid]) ? (Array.isArray(layer.tooltips) ? layer.tooltips[fid] : layer.tooltips) : null,
              popup: (layer.popups && layer.popups[fid]) ? (Array.isArray(layer.popups) ? layer.popups[fid] : layer.popups) : ((layer.tooltips && layer.tooltips[fid]) ? (Array.isArray(layer.tooltips) ? layer.tooltips[fid] : layer.tooltips) : null)
            };
          }
        }
      }

      // Pass 2: check polygon interiors (using earstrip/earcut triangles) & line/polygon vertices
      for (const id of ids) {
        const layer = this.layers.get(id);
        if (!layer || !layer.visible || !layer.parsed) continue;
        if (layer.type === "points" || layer.type === "labels") continue;
        const bb = layer.bbox || layer.parsed.bbox;
        if (Array.isArray(bb) && bb.length >= 4) {
          if (lon < bb[0] - 0.05 || lat < bb[1] - 0.05 || lon > bb[2] + 0.05 || lat > bb[3] + 0.05) continue;
        }
        const mc = layer.parsed.mercCoords;
        const indices = layer.parsed.indices;
        const vfids = layer.parsed.vertexFeatureIds;
        if (layer.type === "polygons" && mc && indices && indices.length >= 3 && vfids) {
          for (let t = 0; t + 2 < indices.length; t += 3) {
            const i0 = indices[t], i1 = indices[t + 1], i2 = indices[t + 2];
            const ax = mc[2 * i0], ay = mc[2 * i0 + 1];
            const bx = mc[2 * i1], by = mc[2 * i1 + 1];
            const cx = mc[2 * i2], cy = mc[2 * i2 + 1];
            if (mx < Math.min(ax, bx, cx) || mx > Math.max(ax, bx, cx) ||
                my < Math.min(ay, by, cy) || my > Math.max(ay, by, cy)) continue;
            const d1 = (mx - bx) * (ay - by) - (ax - bx) * (my - by);
            const d2 = (mx - cx) * (by - cy) - (bx - cx) * (my - cy);
            const d3 = (mx - ax) * (cy - ay) - (cx - ax) * (my - ay);
            const hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
            const hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
            if (!(hasNeg && hasPos)) {
              const fid = vfids[i0];
              const customId = (Array.isArray(layer.feature_ids) && layer.feature_ids[fid] !== undefined)
                ? layer.feature_ids[fid]
                : (fid + 1);
              return {
                feature: {
                  id: customId,
                  featureIndex: fid + 1,
                  layerId: layer.id,
                  group: layer.group || layer.id,
                  type: layer.type,
                  lng: lon,
                  lat: lat
                },
                tooltip: (layer.tooltips && layer.tooltips[fid]) ? (Array.isArray(layer.tooltips) ? layer.tooltips[fid] : layer.tooltips) : null,
                popup: (layer.popups && layer.popups[fid]) ? (Array.isArray(layer.popups) ? layer.popups[fid] : layer.popups) : ((layer.tooltips && layer.tooltips[fid]) ? (Array.isArray(layer.tooltips) ? layer.tooltips[fid] : layer.tooltips) : null)
              };
            }
          }
        }
        // Fallback vertex proximity for lines or unfilled polygons
        const nV = layer.parsed.nVertices;
        const stride = nV > 100000 ? Math.ceil(nV / 100000) : 1;
        for (let v = 0; v < nV; v += stride) {
          const dx = mc[2 * v] - mx;
          const dy = mc[2 * v + 1] - my;
          if (Math.abs(dx) < tolMerc && Math.abs(dy) < tolMerc) {
            const fid = vfids[v];
            const customId = (Array.isArray(layer.feature_ids) && layer.feature_ids[fid] !== undefined)
              ? layer.feature_ids[fid]
              : (fid + 1);
            return {
              feature: {
                id: customId,
                featureIndex: fid + 1,
                layerId: layer.id,
                group: layer.group || layer.id,
                type: layer.type,
                lng: lon,
                lat: lat
              },
              tooltip: (layer.tooltips && layer.tooltips[fid]) ? (Array.isArray(layer.tooltips) ? layer.tooltips[fid] : layer.tooltips) : null,
              popup: (layer.popups && layer.popups[fid]) ? (Array.isArray(layer.popups) ? layer.popups[fid] : layer.popups) : ((layer.tooltips && layer.tooltips[fid]) ? (Array.isArray(layer.tooltips) ? layer.tooltips[fid] : layer.tooltips) : null)
            };
          }
        }
      }
      return null;
    }

    _handleClick(px, py, lon, lat) {
      if (this.measureActive) {
        this.measurePoints.push([lon, lat]);
        this._updateMeasureControlUI();
        this._updateHUD();
        this.requestRender();
        return;
      }
      if (this.drawMode) return;

      // 0. Check if user clicked a marker cluster badge -> zoom into cluster bounds OR spiderfy into a web!
      if (Array.isArray(this._activeClusterBadges) && this._activeClusterBadges.length > 0) {
        for (let i = this._activeClusterBadges.length - 1; i >= 0; i--) {
          const cl = this._activeClusterBadges[i];
          const dx = px - cl.sx;
          const dy = py - cl.sy;
          if (dx * dx + dy * dy <= cl.r * cl.r) {
            const [b0, b1, b2, b3] = cl.bbox;
            const tightSpan = Math.abs(b2 - b0) < 2e-4 && Math.abs(b3 - b1) < 2e-4;
            const atHighZoom = this.camera.zoom >= 15.5;
            if ((tightSpan || atHighZoom) && Array.isArray(cl.indices) && cl.indices.length > 1) {
              // Spiderfy into a radial/spiral web so every overlapping marker can be inspected & clicked!
              this._activeSpiderfy = {
                layerId: cl.layerId,
                centerLon: (b0 + b2) * 0.5,
                centerLat: (b1 + b3) * 0.5,
                zoom: this.camera.zoom,
                indices: cl.indices,
                memberSet: new Set(cl.indices)
              };
              this.requestRender();
              return;
            }
            this._activeSpiderfy = null;
            if (tightSpan) {
              this.flyTo({ center: [(b0 + b2) * 0.5, (b1 + b3) * 0.5], zoom: Math.min(18, this.camera.zoom + 3), duration: 600 });
            } else {
              this.flyToBounds({ bounds: [b0, b1, b2, b3], padding: 60, duration: 600 });
            }
            return;
          }
        }
      }

      // If user clicked outside any spiderfied leg or cluster, collapse active spiderfy web
      if (this._activeSpiderfy && (!this._hoveredFeature || !this._activeSpiderfy.memberSet.has(this._hoveredFeature.id - 1))) {
        this._activeSpiderfy = null;
        this.requestRender();
      }

      // 1. Check if user clicked inside an existing drawn shape -> show Remove popup
      // Skip if R server already manages drawn shapes via `sg_shape` layer
      const hasServerSgLayer = Array.from(this.layers.values()).some((l) => l.group === "sg_shape" || l.id === "sg_shape");
      if (!hasServerSgLayer) {
        for (let i = this.drawnFeatures.length - 1; i >= 0; i--) {
          const f = this.drawnFeatures[i];
          if (f.bbox && lon >= f.bbox[0] && lon <= f.bbox[2] && lat >= f.bbox[1] && lat <= f.bbox[3]) {
            const fid = f.properties && f.properties._leaflet_id;
            this._showPopupAt(px, py, `
              <div style="padding-right:16px">
                <div style="font-weight:600;margin-bottom:6px;color:#38bdf8;">${this._t("drawn_area_prefix")}${fid}</div>
                <button type="button" class="btn btn-sm btn-danger glmap-remove-drawn-btn" data-drawn-id="${fid}" style="background:#dc2626;color:#fff;border:none;padding:4px 10px;border-radius:4px;cursor:pointer;font-size:11px;">
                  ${this._t("remove_drawn_button")}
                </button>
              </div>
            `);
            const rmBtn = this.popupEl.querySelector(".glmap-remove-drawn-btn");
            if (rmBtn) {
              rmBtn.onclick = (ev) => {
                ev.stopPropagation();
                this._removeDrawnFeatureById(fid);
                this.popupEl.style.display = "none";
              };
            }
            return;
          }
        }
      }

      // 2. Direct pick at click coordinates if not already hovered, then open popup/tooltip
      let clickedFeature = this._hoveredFeature;
      let clickedPopupHtml = (this.tooltipEl && this.tooltipEl.style.display === "block") ? this.tooltipEl.innerHTML : null;
      const scale = 512.0 * Math.pow(2.0, this.camera.zoom);
      const picked = this._pickFeatureAt(lon, lat, lonToMercX(lon), latToMercY(lat), 8.0 / scale);
      if (picked) {
        clickedFeature = picked.feature;
        if (picked.popup) clickedPopupHtml = picked.popup;
      }
      if (clickedFeature && clickedPopupHtml) {
        this._showPopupAt(px, py, clickedPopupHtml);
      } else {
        this.popupEl.style.display = "none";
      }

      if (typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode && window.Shiny) {
        window.Shiny.setInputValue(this.el.id + "_click", {
          lng: lon,
          lat: lat,
          raster_value: this._cursorRasterVal,
          nonce: Math.random()
        });
        if (clickedFeature) {
          const evtSuffix = clickedFeature.type === "points" ? "_marker_click" : "_shape_click";
          window.Shiny.setInputValue(this.el.id + evtSuffix, Object.assign({}, clickedFeature, { nonce: Math.random() }));
        }
      }
    }

    _showPopupAt(px, py, htmlContent) {
      this.popupEl.innerHTML = `<button type="button" class="glmap-popup-close">&times;</button><div class="glmap-popup-content leaflet-popup-content">${htmlContent}</div>`;
      const mapW = this.el.clientWidth || 800;
      const mapH = this.el.clientHeight || 600;
      const rightReserve = mapW > 640 ? 540 : 280;
      this.popupEl.style.left = Math.min(mapW - rightReserve, Math.max(12, px)) + "px";
      this.popupEl.style.top = Math.min(mapH - 220, Math.max(12, py)) + "px";
      this.popupEl.style.display = "block";
      const closeBtn = this.popupEl.querySelector(".glmap-popup-close");
      if (closeBtn) {
        closeBtn.onclick = (e) => {
          e.stopPropagation();
          this.popupEl.style.display = "none";
        };
      }
    }

    showPopup(opts) {
      if (!opts) return;
      const lon = Number(opts.lng !== undefined ? opts.lng : opts.lon);
      const lat = Number(opts.lat);
      const cx = lonToMercX(this.camera.centerLon);
      const cy = latToMercY(this.camera.centerLat);
      const scale = this.camera.worldSize || (512.0 * Math.pow(2.0, this.camera.zoom));
      const w = this.el.clientWidth || 800;
      const h = this.el.clientHeight || 600;
      const [px, py] = this.lonLatToScreen(lon, lat, cx, cy, scale, w, h);
      this._showPopupAt(px, py, opts.html || "");
    }

    clearPopups() {
      if (this.popupEl) {
        this.popupEl.style.display = "none";
        this.popupEl.innerHTML = "";
      }
    }

    _removeDrawnFeatureById(fid) {
      const removed = this.drawnFeatures.filter((f) => f.properties && f.properties._leaflet_id === fid);
      this.drawnFeatures = this.drawnFeatures.filter((f) => !(f.properties && f.properties._leaflet_id === fid));
      if (typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode && window.Shiny) {
        window.Shiny.setInputValue("sg_remove", fid, { priority: "event" });
        window.Shiny.setInputValue(this.el.id + "_draw_deleted_features", {
          type: "FeatureCollection",
          features: removed,
          nonce: Math.random()
        });
        window.Shiny.setInputValue(this.el.id + "_draw_all_features", {
          type: "FeatureCollection",
          features: this.drawnFeatures,
          nonce: Math.random()
        });
        if (this.drawnFeatures.length === 0) {
          window.Shiny.setInputValue(this.el.id + "_selected", null);
        }
      }
      this.requestRender();
    }

    _rebuildLayerSwitcher() {
      const lsCfg = (this.spec && this.spec.controls && this.spec.controls.layer_switcher) || {};
      const baseGroups = Array.isArray(lsCfg.baseGroups) && lsCfg.baseGroups.length > 0
        ? lsCfg.baseGroups
        : ["Light", "Dark", "Satellite"];
      const configuredOverlays = Array.isArray(lsCfg.overlayGroups) ? lsCfg.overlayGroups : [];

      // Collect unique overlay groups from both configured overlayGroups and loaded layers
      const groupMap = new Map();
      const selGroups = this._selectedOverlayGroups || new Set();
      let hasSwitchablePointLayer = configuredOverlays.length > 0;
      for (const g of configuredOverlays) {
        if (g && g !== "sg_shape" && g !== "js_single_call" && g !== "cat_claims_overlay") {
          groupMap.set(g, { name: g, visible: selGroups.has(g), count: 0 });
        }
      }
      for (const id of this.layerOrder) {
        const l = this.layers.get(id);
        const gName = l.group || l.id;
        if (gName === "sg_shape" || gName === "js_single_call" || gName === "cat_claims_overlay") continue;
        if (l.type === "points") {
          const allowUi = !(l.style && l.style.render && l.style.render.allow_ui_switcher === false);
          if (allowUi) hasSwitchablePointLayer = true;
        }
        const cnt = l.type === "raster" ? `${l.width}x${l.height}` : (l.n_features || 0).toLocaleString();
        groupMap.set(gName, { name: gName, visible: selGroups.has(gName) || Boolean(l.visible), count: cnt });
      }

      this.switcherEl.style.display = "block";
      const curBase = this._activeBaseGroup || (baseGroups.includes("Dark") ? "Dark" : baseGroups[0]);
      const bgMap = (this.labels && this.labels.basemap_groups) || {};
      const lgMap = (this.labels && this.labels.layer_groups) || {};

      let html = `
        <div class="glmap-panel-title">
          <span>☰ ${this._t("layers_title")}</span>
          <span class="glmap-badge">${groupMap.size}</span>
        </div>
        <div class="glmap-switcher-body">
          <div class="glmap-layer-section-hdr">${this._t("basemap_header")}</div>
      `;

      for (const bg of baseGroups) {
        const bgDisp = bgMap[bg] || bg;
        html += `
          <div class="glmap-layer-item">
            <label class="glmap-layer-label">
              <input type="radio" name="glmap_base_${this.el.id}" value="${bg}" ${curBase === bg ? "checked" : ""}/>
              <span>${bgDisp}</span>
            </label>
          </div>
        `;
      }

      if (groupMap.size > 0) {
        html += `<div class="glmap-layer-section-hdr">${this._t("overlays_header")}</div>`;
        for (const [gName, info] of groupMap.entries()) {
          const gDisp = lgMap[gName] || gName;
          html += `
            <div class="glmap-layer-item">
              <label class="glmap-layer-label">
                <input type="checkbox" data-group-name="${gName}" ${info.visible ? "checked" : ""}/>
                <span>${gDisp}</span>
              </label>
              ${info.count ? `<span class="glmap-badge">${info.count}</span>` : ""}
            </div>
          `;
        }
      }

      if (hasSwitchablePointLayer) {
        const curMode = this._userMarkerModeOverride || "auto";
        const modeOpts = [
          { val: "auto", label: this._t("marker_mode_auto") },
          { val: "cluster", label: this._t("marker_mode_cluster") },
          { val: "lod", label: this._t("marker_mode_lod") },
          { val: "atlas", label: this._t("marker_mode_atlas") },
          { val: "points", label: this._t("marker_mode_points") }
        ];
        html += `
          <div class="glmap-layer-section-hdr" style="margin-top:6px">${this._t("marker_engine_header")}</div>
          <div style="padding:2px 4px 4px 4px">
            <select class="gl-marker-mode-select" style="width:100%;font-size:11px;padding:3px 5px;border-radius:4px;background:var(--gl-input-bg);color:var(--gl-text-primary);border:1px solid var(--gl-input-border);cursor:pointer">
              ${modeOpts.map((o) => `<option value="${o.val}" ${curMode === o.val ? "selected" : ""}>${o.label}</option>`).join("")}
            </select>
          </div>
        `;
      }

      html += `</div>`;
      this.switcherEl.innerHTML = html;

      // Toggle collapsed/expanded on title click
      const titleEl = this.switcherEl.querySelector(".glmap-panel-title");
      if (titleEl) {
        titleEl.onclick = (e) => {
          e.stopPropagation();
          this.switcherEl.classList.toggle("expanded");
        };
      }

      const modeSel = this.switcherEl.querySelector(".gl-marker-mode-select");
      if (modeSel) {
        modeSel.addEventListener("change", (e) => {
          e.stopPropagation();
          const val = e.target.value;
          this._userMarkerModeOverride = val === "auto" ? null : val;
          this.requestRender();
        });
      }

      // Basemap radio change
      this.switcherEl.querySelectorAll("input[type='radio']").forEach((rb) => {
        rb.addEventListener("change", (e) => {
          const val = e.target.value;
          this._activeBaseGroup = val;
          this._switchNamedBasemap(val);
          this._emitActiveGroups();
        });
      });

      // Overlay group checkbox change
      this.switcherEl.querySelectorAll("input[type='checkbox']").forEach((cb) => {
        cb.addEventListener("change", (e) => {
          const grp = e.target.getAttribute("data-group-name");
          if (!this._selectedOverlayGroups) this._selectedOverlayGroups = new Set();
          if (e.target.checked) this._selectedOverlayGroups.add(grp);
          else this._selectedOverlayGroups.delete(grp);
          this.setGroupVisibility([grp], e.target.checked);
          this._emitActiveGroups();
        });
      });
    }

    _switchNamedBasemap(name) {
      const b = String(name).toLowerCase();
      if (b === "light" || b === "positron") {
        this.setBasemap({
          basemap: {
            style_url: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json",
            bg: "#f4f6f8",
            attribution: "&copy; OpenStreetMap contributors &copy; CARTO"
          }
        });
      } else if (b === "satellite") {
        this.setBasemap({
          basemap: {
            tiles: ["https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"],
            bg: "#070b12",
            attribution: "Tiles &copy; Esri"
          }
        });
      } else {
        this.setBasemap({
          basemap: {
            style_url: "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json",
            bg: "#0e1117",
            attribution: "&copy; OpenStreetMap contributors &copy; CARTO"
          }
        });
      }
    }

    _emitActiveGroups() {
      if (typeof HTMLWidgets === "undefined" || !HTMLWidgets.shinyMode || !window.Shiny) return;
      if (!this._selectedOverlayGroups) {
        this._selectedOverlayGroups = new Set();
        for (const l of this.layers.values()) {
          if (l.visible && l.group) this._selectedOverlayGroups.add(l.group);
        }
      }
      if (this._emitGroupsTimer) clearTimeout(this._emitGroupsTimer);
      this._emitGroupsTimer = setTimeout(() => {
        this._emitGroupsTimer = null;
        const active = [this._activeBaseGroup || "Dark", ...Array.from(this._selectedOverlayGroups || [])];
        window.Shiny.setInputValue(this.el.id + "_groups", active);
      }, 15);
    }

    _rebuildLegends() {
      this.legendsEl.innerHTML = "";
      for (const leg of this.legends) {
        let targetLayer = null;
        if (leg.layer_id && this.layers.has(leg.layer_id)) {
          const lyr = this.layers.get(leg.layer_id);
          if (!lyr.visible) continue;
          targetLayer = lyr;
        } else if (leg.group) {
          let anyVis = false;
          for (const l of this.layers.values()) {
            if (l.group === leg.group && l.visible) {
              anyVis = true;
              if (!targetLayer) targetLayer = l;
            }
          }
          if (!anyVis) continue;
        }
        const card = document.createElement("div");
        card.className = "glmap-panel";
        const lgMap = (this.labels && this.labels.layer_groups) || {};
        const rawTitle = leg.title || this._t("legend_default_title");
        const dispTitle = lgMap[rawTitle] || rawTitle;
        let html = `<div class="glmap-panel-title"><span>${dispTitle}</span></div>`;
        let hasRasterOpacity = false;
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
            const sc = (rl.style && rl.style.shader_controls) || leg.shader_controls || { enabled: true, palette: true, hillshade: true, opacity: true };
            if (sc.enabled !== false && (sc.palette || sc.hillshade || sc.opacity)) {
              const curPal = (rl.style && rl.style.palette) || "viridis";
              const palOpts = ["custom", "viridis", "magma", "plasma", "turbo", "terrain", "rdylbu"]
                .filter((p) => p !== "custom" || curPal === "custom")
                .map((p) => `<option value="${p}" ${curPal === p ? "selected" : ""}>${p === "custom" ? this._t("custom_palette") : p}</option>`)
                .join("");
              const curOp = rl.opacity !== undefined ? Number(rl.opacity) : 0.85;
              html += `<div class="glmap-raster-controls" data-raster-id="${leg.layer_id}">`;
              if (sc.palette !== false) {
                html += `
                  <label style="font-size:10px;color:var(--gl-text-muted)">${this._t("shader_palette")}</label>
                  <select class="gl-pal-select">${palOpts}</select>
                `;
              }
              if (sc.hillshade !== false) {
                html += `
                  <label style="font-size:10px;color:var(--gl-text-muted);display:flex;align-items:center;gap:4px;margin-top:3px">
                    <input type="checkbox" class="gl-hill-cb" ${(rl.style && rl.style.hillshade) ? "checked" : ""}/>
                    ${this._t("gpu_hillshade")}
                  </label>
                `;
              }
              if (sc.opacity !== false) {
                hasRasterOpacity = true;
                html += `
                  <label style="font-size:10px;color:var(--gl-text-muted);display:flex;justify-content:space-between;margin-top:4px">
                    <span>${this._t("layer_opacity")}</span>
                    <span class="gl-op-val">${Math.round(curOp * 100)}%</span>
                  </label>
                  <input type="range" class="gl-op-slider" min="0" max="1" step="0.05" value="${curOp}" style="width:100%;accent-color:var(--gl-accent);cursor:pointer;margin-top:2px"/>
                `;
              }
              html += `</div>`;
            }
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
        if (!hasRasterOpacity && leg.opacity_slider !== false && targetLayer) {
          const opTarget = leg.group || targetLayer.id;
          const curOp = targetLayer.opacity !== undefined ? Number(targetLayer.opacity) : 0.65;
          html += `
            <div class="glmap-layer-opacity-ctrl" data-target-id="${opTarget}" style="margin-top:6px;padding-top:4px;border-top:1px solid var(--gl-divider)">
              <label style="font-size:10px;color:var(--gl-text-muted);display:flex;justify-content:space-between">
                <span>${this._t("layer_opacity")}</span>
                <span class="gl-op-val">${Math.round(curOp * 100)}%</span>
              </label>
              <input type="range" class="gl-op-slider" min="0" max="1" step="0.05" value="${curOp}" style="width:100%;accent-color:var(--gl-accent);cursor:pointer;margin-top:2px"/>
            </div>
          `;
        }
        card.innerHTML = html;
        this.legendsEl.appendChild(card);

        const ctrl = card.querySelector(".glmap-raster-controls");
        if (ctrl) {
          const rid = ctrl.getAttribute("data-raster-id");
          const sel = ctrl.querySelector(".gl-pal-select");
          const cb = ctrl.querySelector(".gl-hill-cb");
          const opSlider = ctrl.querySelector(".gl-op-slider");
          const opVal = ctrl.querySelector(".gl-op-val");
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
          if (opSlider) {
            opSlider.addEventListener("input", (e) => {
              const v = Number(e.target.value);
              if (opVal) opVal.textContent = `${Math.round(v * 100)}%`;
              this.setLayerOpacity(rid, v);
            });
          }
        }

        const lyrOpCtrl = card.querySelector(".glmap-layer-opacity-ctrl");
        if (lyrOpCtrl) {
          const tid = lyrOpCtrl.getAttribute("data-target-id");
          const opSlider = lyrOpCtrl.querySelector(".gl-op-slider");
          const opVal = lyrOpCtrl.querySelector(".gl-op-val");
          if (opSlider && tid) {
            opSlider.addEventListener("input", (e) => {
              const v = Number(e.target.value);
              if (opVal) opVal.textContent = `${Math.round(v * 100)}%`;
              this.setLayerOpacity(tid, v);
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
        extra = ` | <span>${this._t("hud_raster")}: <b>${this._cursorRasterVal.toFixed(2)}</b></span>`;
      }
      if (this.measureActive && this.measurePoints.length >= 2) {
        const dKm = computePathDistanceKm(this.measurePoints);
        extra += ` | <span style="color:#38bdf8">${this._t("hud_dist")}: <b>${dKm.toFixed(2)} km</b></span>`;
      }

      this.hudEl.innerHTML = `
        <span class="glmap-hud-fps">${this.fps} FPS</span>
        <span>${this._t("hud_features")}: <b>${totalFeats.toLocaleString()}</b></span>
        <span>${this._t("hud_lon_lat")}: ${lonStr}, ${latStr}</span>
        ${extra}
      `;

      // Update metric scale bar based on zoom & latitude
      const metersPerPx = (156543.03392 * Math.cos(this.camera.centerLat * DEG2RAD)) / Math.pow(2.0, this.camera.zoom);
      const barMeters = metersPerPx * 90;
      const labelKm = barMeters >= 1000 ? `${Math.round(barMeters / 1000)} km` : `${Math.round(barMeters)} m`;
      if (this.scaleEl) {
        this.scaleEl.textContent = labelKm;
      }
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
          const c = this.map.getCenter();
          this.camera.centerLon = c.lng;
          this.camera.centerLat = c.lat;
          this.camera.zoom = this.map.getZoom();
          if (this.map.transform && this.map.transform.worldSize) {
            this.camera.worldSize = this.map.transform.worldSize;
          }
        } catch (e) {}
      }
      this.requestRender();
    }

    setBasemap(opts) {
      if (!opts || !opts.basemap) return;
      const basemap = opts.basemap;
      this.el.style.background = basemap.bg || "#0e1117";
      this._updateUIThemeFromBasemap(basemap, opts.name);
      if (!this.map) return;

      const styleUrl = basemap.style_url || null;
      if (styleUrl) {
        this.map.setStyle(styleUrl);
      } else if (Array.isArray(basemap.tiles) && basemap.tiles.length > 0) {
        this.map.setStyle({
          version: 8,
          sources: {
            "gl-basemap": {
              type: "raster",
              tiles: basemap.tiles,
              tileSize: 256,
              attribution: basemap.attribution || ""
            }
          },
          layers: [
            { id: "gl-background", type: "background", paint: { "background-color": basemap.bg || "#0e1117" } },
            { id: "gl-basemap-layer", type: "raster", source: "gl-basemap", minzoom: 0, maxzoom: 20 }
          ]
        });
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

    clearShapes() {
      const toRemove = [];
      for (const [id, l] of this.layers.entries()) {
        if (l.type === "polygons" || l.type === "lines" || l.type === "hexbin") {
          toRemove.push(id);
        }
      }
      for (const id of toRemove) {
        this.clearLayer(id);
      }
    }

    clearMarkers() {
      const toRemove = [];
      for (const [id, l] of this.layers.entries()) {
        if (l.type === "points" || l.type === "labels") {
          toRemove.push(id);
        }
      }
      for (const id of toRemove) {
        this.clearLayer(id);
      }
    }

    clearControls() {
      this.legends = [];
      this._rebuildLegends();
      this.requestRender();
    }

    setLayerVisibility(id, visible) {
      const l = this.layers.get(id);
      if (l) {
        l.visible = Boolean(visible);
        this._rebuildLegends();
        this._updateHUD();
        this.requestRender();
      }
    }

    setGroupVisibility(groups, visible) {
      const INTERNAL_GROUPS = new Set(["sg_shape", "js_single_call", "cat_claims_overlay"]);
      const grpSet = new Set(Array.isArray(groups) ? groups : [groups]);
      if (!this._selectedOverlayGroups) this._selectedOverlayGroups = new Set();
      let changedUserGroup = false;
      for (const g of grpSet) {
        if (INTERNAL_GROUPS.has(g)) continue;
        const had = this._selectedOverlayGroups.has(g);
        if (visible && !had) {
          this._selectedOverlayGroups.add(g);
          changedUserGroup = true;
        } else if (!visible && had) {
          this._selectedOverlayGroups.delete(g);
          changedUserGroup = true;
        }
      }
      for (const l of this.layers.values()) {
        if (grpSet.has(l.group) || grpSet.has(l.id)) {
          l.visible = Boolean(visible);
        }
      }
      this._rebuildLayerSwitcher();
      this._rebuildLegends();
      this._updateHUD();
      if (changedUserGroup) this._emitActiveGroups();
      this.requestRender();
    }

    clearGroup(groups) {
      const grpSet = new Set(Array.isArray(groups) ? groups : [groups]);
      this.legends = this.legends.filter((l) => !grpSet.has(l.group) && !grpSet.has(l.layer_id));
      const toRemove = [];
      for (const [id, l] of this.layers.entries()) {
        if (grpSet.has(l.group) || grpSet.has(l.id)) {
          toRemove.push(id);
        }
      }
      for (const id of toRemove) {
        this.clearLayer(id);
      }
      this._rebuildLayerSwitcher();
      this._rebuildLegends();
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
      const v = Number(opacity);
      const l = this.layers.get(id);
      if (l) {
        l.opacity = v;
      }
      for (const lyr of this.layers.values()) {
        if (lyr.group === id) {
          lyr.opacity = v;
        }
      }
      this.requestRender();
    }

    setRasterStyle(patch) {
      const l = this.layers.get(patch.id);
      if (!l || l.type !== "raster") return;
      l.style = l.style || {};
      if (patch.palette) {
        if (patch.palette === "custom" && Array.isArray(l.style.lut_rgba)) {
          l.style.palette = "custom";
          this._updateRasterLUT(l, new Uint8Array(l.style.lut_rgba));
        } else {
          l.style.palette = patch.palette;
          const lutBytes = ensureLUT256RGBA(patch.lut_rgba, patch.lut_rgb, patch.palette);
          this._updateRasterLUT(l, lutBytes);
        }
      }
      if (patch.vmin !== undefined && patch.vmin !== null) l.curMin = Number(patch.vmin);
      if (patch.vmax !== undefined && patch.vmax !== null) l.curMax = Number(patch.vmax);
      if (patch.hillshade !== undefined && patch.hillshade !== null) {
        l.style.hillshade = Boolean(patch.hillshade);
      }
      if (patch.opacity !== undefined && patch.opacity !== null) {
        l.opacity = Number(patch.opacity);
      }
      if (patch.shader_controls !== undefined && patch.shader_controls !== null) {
        l.style.shader_controls = patch.shader_controls;
        this._rebuildLegends();
      }
      this.requestRender();
    }

    setMarkerMode(patch) {
      if (!patch) return;
      const target = patch.id;
      const mode = patch.mode || "auto";
      for (const l of this.layers.values()) {
        if (!target || l.id === target || l.group === target) {
          l.style = l.style || {};
          l.style.render = l.style.render || {};
          l.style.render.mode = mode;
          if (Array.isArray(patch.lod_zoom) && patch.lod_zoom.length >= 2) {
            l.style.render.lod_min_zoom = Number(patch.lod_zoom[0]);
            l.style.render.lod_max_zoom = Number(patch.lod_zoom[1]);
          } else if (typeof patch.lod_zoom === "number") {
            l.style.render.lod_min_zoom = Math.max(0, patch.lod_zoom - 1.0);
            l.style.render.lod_max_zoom = patch.lod_zoom + 0.5;
          }
          if (patch.disableClusteringAtZoom !== undefined && patch.disableClusteringAtZoom !== null) {
            l.style.cluster = l.style.cluster || { enabled: true };
            l.style.cluster.disableClusteringAtZoom = Number(patch.disableClusteringAtZoom);
          }
          if (mode === "cluster") {
            l.style.cluster = l.style.cluster || { enabled: true, maxClusterRadius: 65, disableClusteringAtZoom: 15 };
            l.style.cluster.enabled = true;
          }
        }
      }
      this._userMarkerModeOverride = null;
      this._rebuildLayerSwitcher();
      this.requestRender();
    }

    enableMeasureTool(cfg) {
      this.measureActive = true;
      this.measurePoints = [];
      this._updateHUD();
    }

    lonLatToScreen(lon, lat, cx, cy, scale, w, h) {
      if (this.map && typeof this.map.project === "function") {
        try {
          const p = this.map.project([lon, lat]);
          return [p.x, p.y];
        } catch (e) {}
      }
      const mx = lonToMercX(lon);
      const my = latToMercY(lat);
      const dx = (mx - cx) * scale;
      const dy = (my - cy) * scale;
      const c = this._curRotCos !== undefined ? this._curRotCos : 1.0;
      const s = this._curRotSin !== undefined ? this._curRotSin : 0.0;
      return [w * 0.5 + (dx * c + dy * s), h * 0.5 + (-dx * s + dy * c)];
    }

    addDrawToolbar(spec) {
      if (!spec || !spec.enabled) return;
      this.drawSpec = spec;
      this.drawToolbarEl.style.display = "flex";
      const pos = spec.position || "bottom-left";
      const dir = spec.direction || "vertical";
      const ord = spec.order || 15;
      this.drawToolbarEl.setAttribute("data-pos", pos);
      this.drawToolbarEl.setAttribute("data-dir", dir);
      this._mountInSlot(this.drawToolbarEl, pos, ord);

      const tools = spec.tools || { polygon: true, rectangle: true, circle: true, polyline: true, marker: true, edit: true };
      const btns = (spec.toolbar && spec.toolbar.buttons) || {};
      const defBtns = {
        polygon: "Draw a polygon",
        rectangle: "Draw a rectangle",
        circle: "Draw a circle",
        polyline: "Draw a polyline",
        marker: "Draw a marker"
      };
      const resolveTitle = (btnKey, labelKey) => {
        const bVal = btns[btnKey];
        if (bVal && bVal !== defBtns[btnKey]) return bVal;
        return this._t(labelKey, bVal || defBtns[btnKey]);
      };

      const items = [];
      if (tools.polygon) items.push({ mode: "polygon", icon: "⬠", label: this._t("draw_poly_label"), title: resolveTitle("polygon", "draw_poly_title") });
      if (tools.rectangle) items.push({ mode: "rectangle", icon: "▭", label: this._t("draw_rect_label"), title: resolveTitle("rectangle", "draw_rect_title") });
      if (tools.circle) items.push({ mode: "circle", icon: "◯", label: this._t("draw_circle_label"), title: resolveTitle("circle", "draw_circle_title") });
      if (tools.polyline) items.push({ mode: "polyline", icon: "╱", label: this._t("draw_line_label"), title: resolveTitle("polyline", "draw_line_title") });
      if (tools.marker) items.push({ mode: "marker", icon: "📍", label: this._t("draw_pin_label"), title: resolveTitle("marker", "draw_pin_title") });

      let html = items.map((it) => `
        <button type="button" class="glmap-draw-btn" data-draw-mode="${it.mode}" title="${it.title}">
          <span class="glmap-draw-icon">${it.icon}</span>
          <span>${it.label}</span>
        </button>
      `).join("");

      if (tools.edit) {
        html += `
          <button type="button" class="glmap-draw-btn glmap-draw-clear" data-draw-action="clear" title="${this._t("draw_clear_title")}">
            <span class="glmap-draw-icon">🗑</span>
            <span>${this._t("draw_clear_label")}</span>
          </button>
        `;
      }

      this.drawToolbarEl.innerHTML = html;

      this.drawToolbarEl.querySelectorAll(".glmap-draw-btn[data-draw-mode]").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          e.stopPropagation();
          const m = btn.getAttribute("data-draw-mode");
          if (this.drawMode === m) {
            this._stopDrawMode();
          } else {
            this._startDrawMode(m);
          }
        });
      });

      const clrBtn = this.drawToolbarEl.querySelector(".glmap-draw-clear");
      if (clrBtn) {
        clrBtn.addEventListener("click", (e) => {
          e.stopPropagation();
          this._clearDrawnFeatures();
        });
      }

      this._bindDrawHandlersOnce();
    }

    removeDrawToolbar(opts) {
      this._stopDrawMode();
      this.drawToolbarEl.style.display = "none";
      if (opts && opts.clearFeatures) {
        this._clearDrawnFeatures(false);
      }
    }

    _startDrawMode(mode) {
      this.drawMode = mode;
      this._activeDrawVertices = [];
      this._dragStartLonLat = null;
      this._dragCurLonLat = null;

      this.drawToolbarEl.querySelectorAll(".glmap-draw-btn[data-draw-mode]").forEach((b) => {
        b.classList.toggle("active", b.getAttribute("data-draw-mode") === mode);
      });

      if (this.map) {
        if ((mode === "rectangle" || mode === "circle") && this.map.dragPan) {
          this.map.dragPan.disable();
        } else if (this.map.dragPan) {
          this.map.dragPan.enable();
        }
        if ((mode === "polygon" || mode === "polyline") && this.map.doubleClickZoom) {
          this.map.doubleClickZoom.disable();
        }
      }

      if (typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode && window.Shiny) {
        window.Shiny.setInputValue(this.el.id + "_draw_start", {
          feature_type: mode,
          nonce: Math.random()
        });
      }
      this.requestRender();
    }

    _stopDrawMode() {
      const prevMode = this.drawMode;
      this.drawMode = null;
      this._activeDrawVertices = [];
      this._dragStartLonLat = null;
      this._dragCurLonLat = null;

      this.drawToolbarEl.querySelectorAll(".glmap-draw-btn[data-draw-mode]").forEach((b) => {
        b.classList.remove("active");
      });

      if (this.map) {
        if (this.map.dragPan) this.map.dragPan.enable();
        if (this.map.doubleClickZoom) this.map.doubleClickZoom.enable();
      }

      if (prevMode && typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode && window.Shiny) {
        window.Shiny.setInputValue(this.el.id + "_draw_stop", {
          feature_type: prevMode,
          nonce: Math.random()
        });
      }
      this.requestRender();
    }

    _clearDrawnFeatures(emitServerEvents = true) {
      const deleted = this.drawnFeatures.slice();
      this.drawnFeatures = [];
      this._stopDrawMode();
      if (this.popupEl) this.popupEl.style.display = "none";
      if (this.tooltipEl) this.tooltipEl.style.display = "none";

      // Also clear any server-pushed `sg_shape` AOI layer and notify `sg_remove` when triggered by user clicking Clear
      const sgIdsToRemove = [];
      if (emitServerEvents) {
        for (const [id, l] of this.layers.entries()) {
          if (l.group === "sg_shape" || id === "sg_shape") {
            sgIdsToRemove.push(id);
          }
        }
        for (const id of sgIdsToRemove) {
          this.layers.delete(id);
          this.layerOrder = this.layerOrder.filter((x) => x !== id);
        }
      }

      if (emitServerEvents && typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode && window.Shiny) {
        if (sgIdsToRemove.length > 0 || deleted.length > 0) {
          // Emit sg_remove with 1..25 so server-side reactive AOI handlers clear all stored polygons
          const allIds = Array.from({ length: Math.max(25, this._drawSeq + 5) }, (_, i) => i + 1);
          window.Shiny.setInputValue("sg_remove", allIds, { priority: "event" });
        }
        window.Shiny.setInputValue(this.el.id + "_draw_deleted_features", {
          type: "FeatureCollection",
          features: deleted,
          nonce: Math.random()
        });
        window.Shiny.setInputValue(this.el.id + "_draw_all_features", {
          type: "FeatureCollection",
          features: [],
          nonce: Math.random()
        });
        window.Shiny.setInputValue(this.el.id + "_selected", null);
      }
      this.requestRender();
    }

    _bindDrawHandlersOnce() {
      if (this._drawHandlersBound) return;
      this._drawHandlersBound = true;

      this.el.addEventListener("mousedown", (e) => {
        if (!this.drawMode || e.target.closest(".glmap-panel") || e.target.closest(".glmap-toolbar") || e.target.closest(".glmap-draw-toolbar")) return;
        const rect = this.el.getBoundingClientRect();
        const [lon, lat] = this.screenToLonLat(e.clientX - rect.left, e.clientY - rect.top);

        if (this.drawMode === "rectangle" || this.drawMode === "circle") {
          this._dragStartLonLat = [lon, lat];
          this._dragCurLonLat = [lon, lat];
        }
      });

      window.addEventListener("mousemove", (e) => {
        if (!this.drawMode) return;
        const rect = this.el.getBoundingClientRect();
        const [lon, lat] = this.screenToLonLat(e.clientX - rect.left, e.clientY - rect.top);
        this._dragCurLonLat = [lon, lat];
        if (this._dragStartLonLat || this._activeDrawVertices.length > 0) {
          this.requestRender();
        }
      });

      window.addEventListener("mouseup", (e) => {
        if (!this.drawMode || !this._dragStartLonLat) return;
        const rect = this.el.getBoundingClientRect();
        const [lon2, lat2] = this.screenToLonLat(e.clientX - rect.left, e.clientY - rect.top);
        const [lon1, lat1] = this._dragStartLonLat;
        this._dragStartLonLat = null;

        if (Math.abs(lon2 - lon1) < 1e-5 && Math.abs(lat2 - lat1) < 1e-5) return;

        if (this.drawMode === "rectangle") {
          const xmin = Math.min(lon1, lon2), xmax = Math.max(lon1, lon2);
          const ymin = Math.min(lat1, lat2), ymax = Math.max(lat1, lat2);
          const ring = [[xmin, ymin], [xmax, ymin], [xmax, ymax], [xmin, ymax], [xmin, ymin]];
          this._commitDrawnFeature("rectangle", {
            type: "Polygon",
            coordinates: [ring]
          }, { feature_type: "rectangle" }, [xmin, ymin, xmax, ymax]);
          this._stopDrawMode();
        } else if (this.drawMode === "circle") {
          const radKm = computePathDistanceKm([[lon1, lat1], [lon2, lat2]]);
          const radM = Math.max(10, radKm * 1000.0);
          // Build 32-segment polygon approximation for bbox/WKT while emitting exact leaflet.extras Point + radius GeoJSON!
          const ring = [];
          for (let i = 0; i <= 32; i++) {
            const ang = (i / 32) * Math.PI * 2.0;
            const dy = (radM / 111320.0) * Math.sin(ang);
            const dx = (radM / (111320.0 * Math.max(0.1, Math.cos(lat1 * DEG2RAD)))) * Math.cos(ang);
            ring.push([lon1 + dx, lat1 + dy]);
          }
          const xs = ring.map(p => p[0]), ys = ring.map(p => p[1]);
          const bbox = [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)];
          this._commitDrawnFeature("circle", {
            type: "Point",
            coordinates: [lon1, lat1]
          }, { feature_type: "circle", radius: radM, _poly_ring: ring }, bbox);
          this._stopDrawMode();
        }
      });

      this.el.addEventListener("click", (e) => {
        if (!this.drawMode || e.target.closest(".glmap-panel") || e.target.closest(".glmap-toolbar") || e.target.closest(".glmap-draw-toolbar")) return;
        const rect = this.el.getBoundingClientRect();
        const px = e.clientX - rect.left;
        const py = e.clientY - rect.top;
        const [lon, lat] = this.screenToLonLat(px, py);

        if (this.drawMode === "marker") {
          this._commitDrawnFeature("marker", {
            type: "Point",
            coordinates: [lon, lat]
          }, { feature_type: "marker" }, [lon - 0.001, lat - 0.001, lon + 0.001, lat + 0.001]);
          this._stopDrawMode();
        } else if (this.drawMode === "polygon" || this.drawMode === "polyline") {
          // If clicking near the first vertex of a polygon with >= 3 vertices, close and finish!
          if (this.drawMode === "polygon" && this._activeDrawVertices.length >= 3) {
            const [fx, fy] = this.lonLatToScreen(
              this._activeDrawVertices[0][0], this._activeDrawVertices[0][1],
              lonToMercX(this.camera.centerLon), latToMercY(this.camera.centerLat),
              this.camera.worldSize || (512.0 * Math.pow(2.0, this.camera.zoom)),
              this.el.clientWidth || 800, this.el.clientHeight || 600
            );
            if (Math.hypot(px - fx, py - fy) < 14) {
              this._finishActiveVertexShape();
              return;
            }
          }
          this._activeDrawVertices.push([lon, lat]);
          this.requestRender();
        }
      });

      this.el.addEventListener("dblclick", (e) => {
        if (this.measureActive && this.measurePoints.length >= 2) {
          e.preventDefault();
          e.stopPropagation();
          this.measureActive = false;
          if (this.map && this.map.doubleClickZoom) this.map.doubleClickZoom.enable();
          this._updateMeasureControlUI();
          this._updateHUD();
          this.requestRender();
          return;
        }
        if (this.drawMode === "polygon" || this.drawMode === "polyline") {
          e.preventDefault();
          e.stopPropagation();
          this._finishActiveVertexShape();
        }
      });
    }

    addMeasureControl(spec) {
      if (!spec || spec.enabled === false) {
        this.measureControlEl.style.display = "none";
        return;
      }
      this.measureSpec = spec;
      this.measureControlEl.style.display = "block";
      const pos = spec.position || "bottom-right";
      const ord = spec.order || 15;
      this._mountInSlot(this.measureControlEl, pos, ord);
      this._updateMeasureControlUI();
      this._bindDrawHandlersOnce();
    }

    _updateMeasureControlUI() {
      if (!this.measureControlEl || this.measureControlEl.style.display === "none") return;
      const pts = this.measurePoints || [];
      const allPts = (this.measureActive && this._cursorLon !== undefined && this._cursorLat !== undefined)
        ? pts.concat([[this._cursorLon, this._cursorLat]])
        : pts;
      const distKm = allPts.length >= 2 ? computePathDistanceKm(allPts) : 0;
      const distM = distKm * 1000.0;
      const areaSqM = allPts.length >= 3 ? computePolygonAreaSqM(allPts) : 0;

      const lenStr = distM >= 1000
        ? `${distKm.toFixed(2)} km (${Math.round(distM).toLocaleString()} m)`
        : `${Math.round(distM).toLocaleString()} m`;
      const areaStr = areaSqM >= 1e6
        ? `${(areaSqM / 1e6).toFixed(2)} sq. km (${Math.round(areaSqM).toLocaleString()} sq. m)`
        : `${Math.round(areaSqM).toLocaleString()} sq. m`;

      let html = `
        <div style="display:flex;align-items:center;justify-content:space-between;gap:8px">
          <button type="button" class="glmap-btn gl-meas-toggle ${this.measureActive ? "active" : ""}" style="font-size:11px;padding:4px 8px;cursor:pointer">
            📐 ${this.measureActive ? this._t("measure_finish") : this._t("measure_start")}
          </button>
          ${pts.length > 0 ? `<button type="button" class="glmap-btn gl-meas-clear" style="font-size:11px;padding:4px 7px;background:#dc2626;color:#fff;border:none;border-radius:5px;cursor:pointer">${this._t("measure_clear")}</button>` : ""}
        </div>
      `;
      if (pts.length > 0 || this.measureActive) {
        html += `
          <div style="margin-top:6px;font-size:11px;color:var(--gl-text-primary);line-height:1.45;border-top:1px solid var(--gl-divider);padding-top:5px">
            <div>${this._t("measure_length")}: <b style="color:var(--gl-accent)">${lenStr}</b></div>
            ${allPts.length >= 3 ? `<div>${this._t("measure_area")}: <b style="color:#9333ea">${areaStr}</b></div>` : `<div style="color:var(--gl-text-muted);font-size:10px">${this._t("measure_hint")}</div>`}
          </div>
        `;
      }
      this.measureControlEl.innerHTML = html;

      const toggleBtn = this.measureControlEl.querySelector(".gl-meas-toggle");
      if (toggleBtn) {
        toggleBtn.onclick = (e) => {
          e.stopPropagation();
          if (!this.measureActive) {
            this._stopDrawMode();
            this.measureActive = true;
            this.measurePoints = [];
            if (this.map && this.map.doubleClickZoom) this.map.doubleClickZoom.disable();
          } else {
            this.measureActive = false;
            if (this.map && this.map.doubleClickZoom) this.map.doubleClickZoom.enable();
          }
          this._updateMeasureControlUI();
          this._updateHUD();
          this.requestRender();
        };
      }
      const clrBtn = this.measureControlEl.querySelector(".gl-meas-clear");
      if (clrBtn) {
        clrBtn.onclick = (e) => {
          e.stopPropagation();
          this.measureActive = false;
          this.measurePoints = [];
          if (this.map && this.map.doubleClickZoom) this.map.doubleClickZoom.enable();
          this._updateMeasureControlUI();
          this._updateHUD();
          this.requestRender();
        };
      }
    }

    addSearchControl(spec) {
      if (!spec || spec.enabled === false) {
        this.searchEl.style.display = "none";
        return;
      }
      this.searchSpec = spec;
      this.searchEl.style.display = "block";
      const pos = spec.position || "top-left";
      const ord = spec.order !== undefined ? spec.order : 5;
      this._mountInSlot(this.searchEl, pos, ord);

      const placeholder = (spec.textPlaceholder && spec.textPlaceholder !== "Search address or place...")
        ? spec.textPlaceholder
        : this._t("search_placeholder");
      this.searchEl.innerHTML = `
        <div style="display:flex;align-items:center;gap:4px">
          <input type="text" class="gl-osm-input" placeholder="${placeholder}" style="width:195px;padding:4px 8px;font-size:11px;border-radius:6px;border:1px solid var(--gl-input-border);background:var(--gl-input-bg);color:var(--gl-text-primary);outline:none"/>
          <button type="button" class="glmap-btn gl-osm-btn" title="${this._t("search_button_title")}" style="padding:4px 7px;font-size:11px;cursor:pointer">🔍</button>
          <button type="button" class="glmap-btn gl-osm-clr" title="${this._t("search_clear_title")}" style="padding:4px 6px;font-size:11px;display:none;cursor:pointer">&times;</button>
        </div>
        <div class="gl-osm-results" style="display:none;margin-top:4px;max-height:180px;overflow-y:auto;border-top:1px solid var(--gl-divider);padding-top:4px"></div>
      `;

      const inp = this.searchEl.querySelector(".gl-osm-input");
      const btn = this.searchEl.querySelector(".gl-osm-btn");
      const clr = this.searchEl.querySelector(".gl-osm-clr");
      const resBox = this.searchEl.querySelector(".gl-osm-results");

      const runSearch = async () => {
        const q = (inp.value || "").trim();
        if (!q) return;
        resBox.style.display = "block";
        resBox.innerHTML = `<div style="font-size:10px;color:var(--gl-text-muted);padding:3px">${this._t("search_searching")}</div>`;
        try {
          const urlTmpl = spec.url || "https://nominatim.openstreetmap.org/search?format=json&q={s}";
          const url = urlTmpl.replace("{s}", encodeURIComponent(q));
          const resp = await fetch(url, { headers: { "Accept": "application/json" } });
          const data = await resp.json();
          if (!Array.isArray(data) || data.length === 0) {
            resBox.innerHTML = `<div style="font-size:10px;color:#ef4444;padding:3px">${this._t("search_no_results")}</div>`;
            return;
          }
          resBox.innerHTML = data.slice(0, 6).map((item, idx) => `
            <div class="gl-osm-item" data-idx="${idx}" style="padding:4px 6px;font-size:11px;cursor:pointer;border-radius:4px;color:var(--gl-text-primary);border-bottom:1px solid var(--gl-divider)">
              ${item.display_name}
            </div>
          `).join("");
          resBox.querySelectorAll(".gl-osm-item").forEach((elItem) => {
            elItem.onclick = (ev) => {
              ev.stopPropagation();
              const pick = data[Number(elItem.getAttribute("data-idx"))];
              if (!pick) return;
              const lon = Number(pick.lon);
              const lat = Number(pick.lat);
              this._searchMarkerLonLat = [lon, lat];
              clr.style.display = "inline-block";
              resBox.style.display = "none";
              inp.value = pick.display_name.split(",")[0];
              this.flyTo({ center: [lon, lat], zoom: Number(spec.zoom || 15), duration: 900 });
              this.requestRender();
            };
          });
        } catch (err) {
          resBox.innerHTML = `<div style="font-size:10px;color:#f87171;padding:3px">${this._t("search_unavailable")}</div>`;
        }
      };

      btn.onclick = (e) => { e.stopPropagation(); runSearch(); };
      inp.addEventListener("keydown", (e) => {
        e.stopPropagation();
        if (e.key === "Enter") {
          e.preventDefault();
          runSearch();
        }
      });
      clr.onclick = (e) => {
        e.stopPropagation();
        inp.value = "";
        resBox.style.display = "none";
        clr.style.display = "none";
        this._searchMarkerLonLat = null;
        this.requestRender();
      };
    }

    addMiniMapControl(spec) {
      if (!spec || spec.enabled === false) {
        this.miniMapEl.style.display = "none";
        return;
      }
      this.miniMapSpec = spec;
      const w = Number(spec.width || 150);
      const h = Number(spec.height || 150);
      const pos = spec.position || "bottom-right";
      const ord = spec.order !== undefined ? spec.order : 80;
      this.miniMapEl.style.display = "block";
      this.miniMapEl.style.padding = "4px";
      this._mountInSlot(this.miniMapEl, pos, ord);

      this.miniMapEl.innerHTML = `
        <div style="display:flex;align-items:center;justify-content:space-between;font-size:10px;color:#94a3b8;margin-bottom:3px;padding:0 2px">
          <span class="gl-minimap-title">${this._t("minimap_title")}</span>
          ${spec.toggleDisplay !== false ? `<button type="button" class="gl-mini-toggle" style="background:none;border:none;color:#cbd5e1;cursor:pointer;font-size:10px;padding:0">▾</button>` : ""}
        </div>
        <canvas class="gl-minimap-canvas" width="${w}" height="${h}" style="width:${w}px;height:${h}px;display:block;border-radius:6px;cursor:crosshair;background:#0f172a;border:1px solid rgba(148,163,184,0.28)"></canvas>
      `;
      const cvs = this.miniMapEl.querySelector(".gl-minimap-canvas");
      const tgl = this.miniMapEl.querySelector(".gl-mini-toggle");
      if (tgl && cvs) {
        tgl.onclick = (e) => {
          e.stopPropagation();
          const hidden = cvs.style.display === "none";
          cvs.style.display = hidden ? "block" : "none";
          tgl.textContent = hidden ? "▾" : "▸";
        };
      }
      if (cvs) {
        cvs.onclick = (e) => {
          e.stopPropagation();
          const r = cvs.getBoundingClientRect();
          const px = e.clientX - r.left;
          const py = e.clientY - r.top;
          const zOff = Number(spec.zoomLevelOffset !== undefined ? spec.zoomLevelOffset : -5);
          const miniZoom = Math.max(0.5, this.camera.zoom + zOff);
          const miniScale = 128.0 * Math.pow(2.0, miniZoom);
          const cx = lonToMercX(this.camera.centerLon);
          const cy = latToMercY(this.camera.centerLat);
          const targetMx = cx + (px - w * 0.5) / miniScale;
          const targetMy = cy + (py - h * 0.5) / miniScale;
          this.flyTo({ center: [mercXToLon(targetMx), mercYToLat(targetMy)], zoom: this.camera.zoom, duration: 500 });
        };
      }
      this.requestRender();
    }

    _updateMiniMap(cx, cy, mainScale, mainW, mainH) {
      if (!this.miniMapEl || this.miniMapEl.style.display === "none") return;
      const cvs = this.miniMapEl.querySelector(".gl-minimap-canvas");
      if (!cvs || cvs.style.display === "none") return;
      const ctx = cvs.getContext("2d");
      const spec = this.miniMapSpec || {};
      const w = cvs.width;
      const h = cvs.height;
      const zOff = Number(spec.zoomLevelOffset !== undefined ? spec.zoomLevelOffset : -5);
      const miniZoom = Math.max(0.5, this.camera.zoom + zOff);
      const miniScale = 128.0 * Math.pow(2.0, miniZoom);

      ctx.clearRect(0, 0, w, h);
      ctx.fillStyle = "#0f172a";
      ctx.fillRect(0, 0, w, h);

      // Subtle graticule lines inside minimap
      ctx.strokeStyle = "rgba(148, 163, 184, 0.16)";
      ctx.lineWidth = 1;
      for (let lon = -180; lon <= 180; lon += 30) {
        const sx = w * 0.5 + (lonToMercX(lon) - cx) * miniScale;
        if (sx >= 0 && sx <= w) {
          ctx.beginPath(); ctx.moveTo(sx, 0); ctx.lineTo(sx, h); ctx.stroke();
        }
      }
      for (let lat = -60; lat <= 60; lat += 20) {
        const sy = h * 0.5 + (latToMercY(lat) - cy) * miniScale;
        if (sy >= 0 && sy <= h) {
          ctx.beginPath(); ctx.moveTo(0, sy); ctx.lineTo(w, sy); ctx.stroke();
        }
      }

      // Render overview of active vector layers inside MiniMap
      for (const l of this.layers.values()) {
        if (!l.visible || !l.parsed || !l.parsed.mercCoords) continue;
        const mc = l.parsed.mercCoords;
        const nV = l.parsed.nVertices;
        const stride = Math.max(1, Math.ceil(nV / 800));
        ctx.fillStyle = "rgba(56, 189, 248, 0.7)";
        for (let v = 0; v < nV; v += stride) {
          const sx = w * 0.5 + (mc[2 * v] - cx) * miniScale;
          const sy = h * 0.5 + (mc[2 * v + 1] - cy) * miniScale;
          if (sx >= 0 && sx <= w && sy >= 0 && sy <= h) {
            ctx.fillRect(sx - 1, sy - 1, 2, 2);
          }
        }
      }

      // Draw aiming rectangle representing current main viewport bounds
      const aimW = Math.max(10, Math.min(w - 4, (mainW / mainScale) * miniScale));
      const aimH = Math.max(8, Math.min(h - 4, (mainH / mainScale) * miniScale));
      const aimCol = spec.aimingColor || "#ff7800";
      ctx.strokeStyle = aimCol;
      ctx.fillStyle = "rgba(255, 120, 0, 0.16)";
      ctx.lineWidth = 1.8;
      ctx.fillRect((w - aimW) * 0.5, (h - aimH) * 0.5, aimW, aimH);
      ctx.strokeRect((w - aimW) * 0.5, (h - aimH) * 0.5, aimW, aimH);
    }

    _finishActiveVertexShape() {
      const pts = this._activeDrawVertices.slice();
      if (this.drawMode === "polygon" && pts.length >= 3) {
        const ring = pts.concat([[pts[0][0], pts[0][1]]]);
        const xs = ring.map(p => p[0]), ys = ring.map(p => p[1]);
        this._commitDrawnFeature("polygon", {
          type: "Polygon",
          coordinates: [ring]
        }, { feature_type: "polygon" }, [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)]);
      } else if (this.drawMode === "polyline" && pts.length >= 2) {
        const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
        this._commitDrawnFeature("polyline", {
          type: "LineString",
          coordinates: pts
        }, { feature_type: "polyline" }, [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)]);
      }
      this._stopDrawMode();
    }

    _commitDrawnFeature(mode, geometry, props, bbox) {
      const id = ++this._drawSeq;
      if (this.drawSpec && this.drawSpec.singleFeature) {
        this.drawnFeatures = [];
      }

      // Compute WKT string for sf / terra / DuckDB Spatial
      let wkt = "";
      const ringForWkt = (geometry.type === "Polygon") ? geometry.coordinates[0] : (props._poly_ring || null);
      if (ringForWkt) {
        wkt = "POLYGON ((" + ringForWkt.map(p => `${p[0].toFixed(6)} ${p[1].toFixed(6)}`).join(", ") + "))";
      } else if (geometry.type === "Point") {
        wkt = `POINT (${geometry.coordinates[0].toFixed(6)} ${geometry.coordinates[1].toFixed(6)})`;
      }

      const feature = {
        type: "Feature",
        properties: Object.assign({ _leaflet_id: id, feature_type: mode }, props),
        geometry: geometry,
        bbox: bbox,
        wkt: wkt
      };
      this.drawnFeatures.push(feature);

      // Also update _selected input so apps listening to either _draw_new_feature or _selected work seamlessly!
      this._selectInBbox(bbox, wkt);

      if (typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode && window.Shiny) {
        window.Shiny.setInputValue(this.el.id + "_draw_new_feature", feature);
        window.Shiny.setInputValue(this.el.id + "_draw_all_features", {
          type: "FeatureCollection",
          features: this.drawnFeatures,
          nonce: Math.random()
        });
      }
      this.requestRender();
    }

    _renderDrawnFeatures2D(ctx, cx, cy, scale, w, h) {
      ctx.save();
      ctx.lineWidth = 2.2;
      ctx.strokeStyle = "#38bdf8";
      ctx.fillStyle = "rgba(56, 189, 248, 0.20)";

      // 1. Render committed drawn features (skip if R server already manages drawn shapes via `sg_shape` layer)
      const hasServerSgLayer = Array.from(this.layers.values()).some((l) => l.group === "sg_shape" || l.id === "sg_shape");
      if (!hasServerSgLayer) {
        for (const f of this.drawnFeatures) {
          const g = f.geometry;
          const ring = (g.type === "Polygon") ? g.coordinates[0] : (f.properties && f.properties._poly_ring);
          if (ring && ring.length >= 2) {
            ctx.beginPath();
            for (let i = 0; i < ring.length; i++) {
              const [sx, sy] = this.lonLatToScreen(ring[i][0], ring[i][1], cx, cy, scale, w, h);
              if (i === 0) ctx.moveTo(sx, sy);
              else ctx.lineTo(sx, sy);
            }
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
          } else if (g.type === "LineString" && g.coordinates.length >= 2) {
            ctx.beginPath();
            for (let i = 0; i < g.coordinates.length; i++) {
              const [sx, sy] = this.lonLatToScreen(g.coordinates[i][0], g.coordinates[i][1], cx, cy, scale, w, h);
              if (i === 0) ctx.moveTo(sx, sy);
              else ctx.lineTo(sx, sy);
            }
            ctx.stroke();
          } else if (g.type === "Point") {
            const [sx, sy] = this.lonLatToScreen(g.coordinates[0], g.coordinates[1], cx, cy, scale, w, h);
            ctx.beginPath();
            ctx.arc(sx, sy, 6, 0, Math.PI * 2);
            ctx.fill();
            ctx.stroke();
          }
        }
      }

      // 1a. Render hovered polygon/line highlight outline if highlightOptions is configured on the hovered layer
      if (this._hoveredFeature && (this._hoveredFeature.type === "polygons" || this._hoveredFeature.type === "lines")) {
        const hLayer = this.layers.get(this._hoveredFeature.layerId);
        if (hLayer && hLayer.visible && hLayer.parsed && hLayer.style && hLayer.style.highlight && hLayer.style.highlight.enabled) {
          const hl = hLayer.style.highlight;
          const targetFid = (this._hoveredFeature.featureIndex !== undefined ? this._hoveredFeature.featureIndex : this._hoveredFeature.id) - 1;
          const mc = hLayer.parsed.mercCoords;
          const fids = hLayer.parsed.vertexFeatureIds;
          const rs = hLayer.parsed.ringStarts;
          const col = Array.isArray(hl.color) ? `rgb(${hl.color[0]},${hl.color[1]},${hl.color[2]})` : "#ffffff";
          ctx.strokeStyle = col;
          ctx.lineWidth = Number(hl.weight || 3.0);
          ctx.setLineDash([]);
          if (rs && rs.length >= 2) {
            for (let r = 0; r < rs.length - 1; r++) {
              const s = rs[r], e = rs[r + 1];
              if (s < e && fids[s] === targetFid) {
                ctx.beginPath();
                for (let v = s; v < e; v++) {
                    const [sx, sy] = this.lonLatToScreen(
                      mercXToLon(mc[2 * v]),
                      mercYToLat(mc[2 * v + 1]),
                      cx, cy, scale, w, h
                    );
                    if (v === s) ctx.moveTo(sx, sy);
                    else ctx.lineTo(sx, sy);
                  }
                ctx.stroke();
              }
            }
          }
        }
      }

      // 1b. RenderOSM Search Marker Pin if present
      if (this._searchMarkerLonLat) {
        const [sx, sy] = this.lonLatToScreen(this._searchMarkerLonLat[0], this._searchMarkerLonLat[1], cx, cy, scale, w, h);
        ctx.fillStyle = "#ef4444";
        ctx.strokeStyle = "#ffffff";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(sx, sy, 7, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
      }

      // 1c. Render Distance & Area Measure Tool Polygon / Path
      if (this.measurePoints && this.measurePoints.length > 0) {
        const mCfg = this.measureSpec || {};
        const col = this.measureActive ? (mCfg.activeColor || "#38bdf8") : (mCfg.completedColor || "#a855f7");
        ctx.strokeStyle = col;
        ctx.fillStyle = this.measureActive ? "rgba(56, 189, 248, 0.16)" : "rgba(168, 85, 247, 0.22)";
        ctx.lineWidth = 2.4;
        ctx.setLineDash(this.measureActive ? [5, 4] : []);
        ctx.beginPath();
        for (let i = 0; i < this.measurePoints.length; i++) {
          const [sx, sy] = this.lonLatToScreen(this.measurePoints[i][0], this.measurePoints[i][1], cx, cy, scale, w, h);
          if (i === 0) ctx.moveTo(sx, sy);
          else ctx.lineTo(sx, sy);
        }
        if (this.measureActive && this._cursorLon !== undefined && this._cursorLat !== undefined) {
          const [cxPx, cyPx] = this.lonLatToScreen(this._cursorLon, this._cursorLat, cx, cy, scale, w, h);
          ctx.lineTo(cxPx, cyPx);
        }
        if (this.measurePoints.length >= 3) {
          ctx.closePath();
          ctx.fill();
        }
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.fillStyle = col;
        for (let i = 0; i < this.measurePoints.length; i++) {
          const [sx, sy] = this.lonLatToScreen(this.measurePoints[i][0], this.measurePoints[i][1], cx, cy, scale, w, h);
          ctx.beginPath();
          ctx.arc(sx, sy, 4.5, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      // 2. Render in-progress shape while user is actively drawing
      ctx.setLineDash([6, 4]);
      ctx.strokeStyle = "#facc15";
      ctx.fillStyle = "rgba(250, 204, 21, 0.18)";

      if (this._dragStartLonLat && this._dragCurLonLat) {
        const [lon1, lat1] = this._dragStartLonLat;
        const [lon2, lat2] = this._dragCurLonLat;
        if (this.drawMode === "rectangle") {
          const [x1, y1] = this.lonLatToScreen(lon1, lat1, cx, cy, scale, w, h);
          const [x2, y2] = this.lonLatToScreen(lon2, lat2, cx, cy, scale, w, h);
          ctx.fillRect(Math.min(x1, x2), Math.min(y1, y2), Math.abs(x2 - x1), Math.abs(y2 - y1));
          ctx.strokeRect(Math.min(x1, x2), Math.min(y1, y2), Math.abs(x2 - x1), Math.abs(y2 - y1));
        } else if (this.drawMode === "circle") {
          const [x1, y1] = this.lonLatToScreen(lon1, lat1, cx, cy, scale, w, h);
          const [x2, y2] = this.lonLatToScreen(lon2, lat2, cx, cy, scale, w, h);
          const rPx = Math.hypot(x2 - x1, y2 - y1);
          ctx.beginPath();
          ctx.arc(x1, y1, rPx, 0, Math.PI * 2);
          ctx.fill();
          ctx.stroke();
        }
      } else if (this._activeDrawVertices.length > 0) {
        ctx.beginPath();
        for (let i = 0; i < this._activeDrawVertices.length; i++) {
          const [sx, sy] = this.lonLatToScreen(this._activeDrawVertices[i][0], this._activeDrawVertices[i][1], cx, cy, scale, w, h);
          if (i === 0) ctx.moveTo(sx, sy);
          else ctx.lineTo(sx, sy);
        }
        if (this._dragCurLonLat) {
          const [cxPx, cyPx] = this.lonLatToScreen(this._dragCurLonLat[0], this._dragCurLonLat[1], cx, cy, scale, w, h);
          ctx.lineTo(cxPx, cyPx);
        }
        if (this.drawMode === "polygon" && this._activeDrawVertices.length >= 2) {
          ctx.fill();
        }
        ctx.stroke();

        // Draw vertex handles
        ctx.setLineDash([]);
        ctx.fillStyle = "#facc15";
        for (let i = 0; i < this._activeDrawVertices.length; i++) {
          const [sx, sy] = this.lonLatToScreen(this._activeDrawVertices[i][0], this._activeDrawVertices[i][1], cx, cy, scale, w, h);
          ctx.beginPath();
          ctx.arc(sx, sy, i === 0 ? 5.5 : 4.0, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      ctx.restore();
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

    _selectInBbox(bbox, customWkt = null) {
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

      const wkt = customWkt || `POLYGON ((${xmin.toFixed(6)} ${ymin.toFixed(6)}, ${xmax.toFixed(6)} ${ymin.toFixed(6)}, ${xmax.toFixed(6)} ${ymax.toFixed(6)}, ${xmin.toFixed(6)} ${ymax.toFixed(6)}, ${xmin.toFixed(6)} ${ymin.toFixed(6)}))`;
      if (typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode && window.Shiny) {
        window.Shiny.setInputValue(this.el.id + "_selected", {
          bbox: bbox,
          wkt: wkt,
          count: selectedIds.length,
          indices: selectedIds.slice(0, 50000),
          nonce: Math.random()
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
      btn.textContent = this._t("export_png");
      btn.onclick = () => {
        const a = document.createElement("a");
        a.download = (cfg && cfg.filename) || "glmap-map.png";
        a.href = this.glCanvas.toDataURL("image/png");
        a.click();
      };
      this._mountInSlot(btn, (cfg && cfg.position) || "top-right", (cfg && cfg.order) || 30);
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
      if (this._isResizing) return;
      this._isResizing = true;
      if (this.map) {
        try { this.map.resize(); } catch (e) {}
      }
      this._isResizing = false;
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

  function computePolygonAreaSqM(pts) {
    if (!Array.isArray(pts) || pts.length < 3) return 0;
    const R = 6378137.0;
    let area = 0;
    for (let i = 0; i < pts.length; i++) {
      const [lon1, lat1] = pts[i];
      const [lon2, lat2] = pts[(i + 1) % pts.length];
      area += (lon2 - lon1) * DEG2RAD * (2.0 + Math.sin(lat1 * DEG2RAD) + Math.sin(lat2 * DEG2RAD));
    }
    return Math.abs((area * R * R) / 2.0);
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
        else if (m === "clearShapes") inst.clearShapes();
        else if (m === "clearMarkers") inst.clearMarkers();
        else if (m === "clearControls") inst.clearControls();
        else if (m === "setLayerVisibility") inst.setLayerVisibility(args.id, args.visible);
        else if (m === "setGroupVisibility") inst.setGroupVisibility(args.group, args.visible);
        else if (m === "clearGroup") inst.clearGroup(args.group);
        else if (m === "setLayerOpacity") inst.setLayerOpacity(args.id, args.opacity);
        else if (m === "setRasterStyle") inst.setRasterStyle(args);
        else if (m === "setMarkerMode") inst.setMarkerMode(args);
        else if (m === "addMeasureControl") inst.addMeasureControl(args);
        else if (m === "addSearchControl") inst.addSearchControl(args);
        else if (m === "addMiniMap") inst.addMiniMapControl(args);
        else if (m === "showPopup") inst.showPopup(args);
        else if (m === "clearPopups") inst.clearPopups();
        else if (m === "setBasemap") inst.setBasemap(args);
        else if (m === "setView") inst.setView(args);
        else if (m === "flyTo") inst.flyTo(args);
        else if (m === "flyToBounds") inst.flyToBounds(args);
        else if (m === "setMaxBounds") inst.setMaxBounds(args);
        else if (m === "fitBounds") inst.fitBounds(args.bounds);
        else if (m === "addLegend") {
          inst.legends = inst.legends.filter((l) => l.layer_id !== args.layer_id);
          inst.legends.push(args);
          inst._rebuildLegends();
        }
        else if (m === "setLayersControl") {
          inst.spec = inst.spec || {};
          inst.spec.controls = inst.spec.controls || {};
          inst.spec.controls.layer_switcher = args;
          inst._applyControlLayout(inst.spec);
          inst._rebuildLayerSwitcher();
        }
        else if (m === "configureControl") {
          inst.spec = inst.spec || {};
          inst.spec.controls = inst.spec.controls || {};
          inst.spec.controls[args.type] = args.config;
          inst._applyControlLayout(inst.spec);
        }
        else if (m === "setLabels") inst.setLabels(args);
        else if (m === "addDrawToolbar") inst.addDrawToolbar(args);
        else if (m === "removeDrawToolbar") inst.removeDrawToolbar(args);
        else if (m === "usePlugin") inst._runPlugins([args]);
      });
    }
  }
})();
