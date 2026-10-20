/* Persistent ELI5 vs Technical Mode Switcher for glmap pkgdown & Quarto Docs */
(function () {
  "use strict";

  const STORAGE_KEY = "glmap_doc_mode";

  // Automatic plain-English ELI5 summaries for key reference functions
  const REF_ELI5_SUMMARIES = {
    "glmap": "Starts a new interactive map on your graphics card (GPU). Just pass your data (`glmap(my_data)`) and it automatically picks the right layer—no setup required!",
    "add_points": "Draws up to 1,000,000+ dots on the map at 60 FPS. Pass `color = ~my_column` to color them automatically with a legend.",
    "add_polygons": "Draws shapes (like postal codes, lakes, or buildings) on the map. Behind the scenes, C++ pre-cuts the shapes into triangles so your browser never freezes.",
    "add_raster": "Draws a grid/heatmap image (like elevation or temperature from `terra`). Because your graphics card colors the raw numbers live, you can change color palettes or turn on 3D shadows in 0 milliseconds!",
    "add_hexbin": "Groups millions of overlapping dots into neat honeycomb hexagons in a fraction of a second so you can spot hotspots immediately.",
    "add_heatmap": "Turns dense points into a glowing heat surface where overlapping points add up to brighter colors.",
    "add_duckdb": "Connects your map directly to a giant `.parquet` file or DuckDB database. As you pan and zoom, it only fetches the points currently visible on your screen!",
    "glmap_proxy": "Updates a live map inside a Shiny app (changing colors, hiding layers, or flying to a city) without reloading the whole map.",
    "gl_providers": "A catalog of ready-to-use background maps (dark mode, light mode, satellite imagery, street maps, and topo maps)—just like `leaflet::providers`.",
    "gl_set_api_key": "Saves your optional API key (for CARTO, MapTiler, Stadia, or Mapbox) once per R session so every map uses it automatically."
  };

  function getSavedMode() {
    try {
      return localStorage.getItem(STORAGE_KEY) || "eli5";
    } catch (e) {
      return "eli5";
    }
  }

  function applyMode(mode) {
    const cleanMode = mode === "tech" ? "tech" : "eli5";
    document.documentElement.setAttribute("data-glmap-mode", cleanMode);
    try {
      localStorage.setItem(STORAGE_KEY, cleanMode);
    } catch (e) {}

    document.querySelectorAll(".glmap-mode-btn").forEach((btn) => {
      btn.classList.toggle("active", btn.getAttribute("data-mode") === cleanMode);
    });
  }

  function injectNavbarToggle() {
    if (document.querySelector(".glmap-mode-switcher")) return;

    const switcher = document.createElement("div");
    switcher.className = "glmap-mode-switcher";
    switcher.setAttribute("role", "group");
    switcher.setAttribute("aria-label", "Documentation Language Mode");

    const btnEli5 = document.createElement("button");
    btnEli5.type = "button";
    btnEli5.className = "glmap-mode-btn";
    btnEli5.setAttribute("data-mode", "eli5");
    btnEli5.innerHTML = "🌱 ELI5 (Simple)";
    btnEli5.title = "Explain Like I'm 5: Plain-English intuition and quick mental models";
    btnEli5.onclick = () => applyMode("eli5");

    const btnTech = document.createElement("button");
    btnTech.type = "button";
    btnTech.className = "glmap-mode-btn";
    btnTech.setAttribute("data-mode", "tech");
    btnTech.innerHTML = "⚙️ Technical (Deep Dive)";
    btnTech.title = "Technical Mode: C++17 binary layouts, WebGL2 shaders, and GPU architecture";
    btnTech.onclick = () => applyMode("tech");

    switcher.appendChild(btnEli5);
    switcher.appendChild(btnTech);

    // Target pkgdown navbar, Quarto navbar, or top of main container
    const navRight =
      document.querySelector(".navbar .navbar-nav:last-of-type") ||
      document.querySelector(".navbar .container, .navbar .container-fluid") ||
      document.querySelector("#quarto-header nav") ||
      document.querySelector("header");

    if (navRight) {
      navRight.appendChild(switcher);
    } else {
      const main = document.querySelector("main") || document.body;
      main.insertBefore(switcher, main.firstChild);
    }
  }

  function injectReferencePageEli5Banner() {
    // On pkgdown /reference/<fn>.html pages, inject a helpful ELI5 translation card at the top
    const path = window.location.pathname || "";
    const match = path.match(/\/reference\/([a-zA-Z0-9_]+)\.html$/);
    if (!match) return;
    const fnName = match[1];
    const summary = REF_ELI5_SUMMARIES[fnName];
    if (!summary) return;

    const header = document.querySelector(".page-header") || document.querySelector("main h1");
    if (!header || document.querySelector(".glmap-ref-auto-eli5")) return;

    const box = document.createElement("div");
    box.className = "glmap-eli5-box glmap-ref-auto-eli5";
    box.innerHTML = `
      <div class="glmap-box-badge">🌱 ELI5 Plain-English Summary</div>
      <div>${summary} <span style="opacity:0.75;font-size:12px;">(Switch to <b>⚙️ Technical</b> in the top bar for low-level GPU/C++ details.)</span></div>
    `;
    header.parentNode.insertBefore(box, header.nextSibling);
  }

  // Apply saved mode immediately to avoid flash
  applyMode(getSavedMode());

  document.addEventListener("DOMContentLoaded", function () {
    injectNavbarToggle();
    injectReferencePageEli5Banner();
    applyMode(getSavedMode());
  });
})();
