#include <cpp11.hpp>
#include "earcut.h"
#include <vector>
#include <cstdint>
#include <cmath>
#include <cstring>
#include <algorithm>
#include <limits>
#include <array>

using namespace cpp11;

namespace {

#pragma pack(push, 1)
struct GexpHeader {
  char magic[4];           // "GEXP" (4)
  uint16_t version;        // 1 (2)
  uint16_t geom_type;      // 1=POINT, 2=LINESTRING, 3=POLYGON, 4=RASTER, 5=HEXBIN (2)
  uint32_t n_features;     // (4)
  uint32_t n_vertices;     // (4)
  uint32_t n_indices;      // (4)
  uint32_t n_ring_starts;  // (4)
  uint32_t has_radius;     // (4)
  uint32_t has_elevation;  // (4)
  float bbox[4];           // xmin, ymin, xmax, ymax (16) -> total = 48 bytes
};

struct GexpRasterHeader {
  char magic[4];           // "GEXR"
  uint16_t version;        // 1
  uint16_t n_bands;
  uint32_t width;
  uint32_t height;
  float bbox[4];           // xmin, ymin, xmax, ymax
  float vmin;
  float vmax;
  float nodata;
  uint32_t reserved;       // padding to 48 bytes
};
#pragma pack(pop)

inline void update_bbox(float x, float y, float bbox[4]) {
  if (std::isfinite(x) && std::isfinite(y)) {
    if (x < bbox[0]) bbox[0] = x;
    if (y < bbox[1]) bbox[1] = y;
    if (x > bbox[2]) bbox[2] = x;
    if (y > bbox[3]) bbox[3] = y;
  }
}

void extract_sfg_coords(
    SEXP sfg,
    uint16_t geom_type,
    uint32_t feat_id,
    std::vector<float>& coords,
    std::vector<uint32_t>& ring_starts,
    std::vector<uint32_t>& tri_indices,
    std::vector<uint32_t>& vertex_feat_ids,
    float bbox[4]
) {
  if (TYPEOF(sfg) == REALSXP) {
    // Either a numeric vector (POINT) or a numeric matrix (LINESTRING / Multipoint)
    SEXP dim = Rf_getAttrib(sfg, R_DimSymbol);
    const double* ptr = REAL(sfg);
    if (dim == R_NilValue) {
      // Single point vector c(x, y, ...)
      R_xlen_t len = Rf_xlength(sfg);
      if (len >= 2) {
        float x = static_cast<float>(ptr[0]);
        float y = static_cast<float>(ptr[1]);
        coords.push_back(x);
        coords.push_back(y);
        vertex_feat_ids.push_back(feat_id);
        update_bbox(x, y, bbox);
      }
    } else {
      // Matrix (nrow x ncol), column-major in R: col 0 is X, col 1 is Y
      int nrow = INTEGER(dim)[0];
      int ncol = INTEGER(dim)[1];
      if (nrow > 0 && ncol >= 2) {
        uint32_t start_v = static_cast<uint32_t>(coords.size() / 2);
        ring_starts.push_back(start_v);
        for (int r = 0; r < nrow; ++r) {
          float x = static_cast<float>(ptr[r]);
          float y = static_cast<float>(ptr[r + nrow]);
          coords.push_back(x);
          coords.push_back(y);
          vertex_feat_ids.push_back(feat_id);
          update_bbox(x, y, bbox);
        }
      }
    }
  } else if (TYPEOF(sfg) == VECSXP) {
    R_xlen_t n_sub = Rf_xlength(sfg);
    if (n_sub == 0) return;

    // Check if this VECSXP is a single POLYGON (list of numeric ring matrices: exterior + holes)
    SEXP first_elt = VECTOR_ELT(sfg, 0);
    if (geom_type == 3 && TYPEOF(first_elt) == REALSXP && Rf_getAttrib(first_elt, R_DimSymbol) != R_NilValue) {
      using Pt = std::array<double, 2>;
      std::vector<std::vector<Pt>> polygon_rings;
      polygon_rings.reserve(n_sub);
      uint32_t poly_base_v = static_cast<uint32_t>(coords.size() / 2);

      for (R_xlen_t r_idx = 0; r_idx < n_sub; ++r_idx) {
        SEXP ring_mat = VECTOR_ELT(sfg, r_idx);
        if (TYPEOF(ring_mat) != REALSXP) continue;
        SEXP dim = Rf_getAttrib(ring_mat, R_DimSymbol);
        if (dim == R_NilValue) continue;
        int nrow = INTEGER(dim)[0];
        int ncol = INTEGER(dim)[1];
        if (nrow <= 0 || ncol < 2) continue;

        const double* ptr = REAL(ring_mat);
        uint32_t ring_start_v = static_cast<uint32_t>(coords.size() / 2);
        ring_starts.push_back(ring_start_v);

        std::vector<Pt> ring_pts;
        ring_pts.reserve(nrow);
        for (int r = 0; r < nrow; ++r) {
          double dx = ptr[r];
          double dy = ptr[r + nrow];
          float fx = static_cast<float>(dx);
          float fy = static_cast<float>(dy);
          coords.push_back(fx);
          coords.push_back(fy);
          vertex_feat_ids.push_back(feat_id);
          update_bbox(fx, fy, bbox);
          ring_pts.push_back({dx, dy});
        }
        polygon_rings.push_back(std::move(ring_pts));
      }

      if (!polygon_rings.empty()) {
        std::vector<uint32_t> local_indices = mapbox::earcut<uint32_t>(polygon_rings);
        for (uint32_t idx : local_indices) {
          tri_indices.push_back(poly_base_v + idx);
        }
      }
      return;
    }

    // Otherwise recurse (e.g., MULTIPOLYGON list of polygons, or MULTILINESTRING list of matrices)
    for (R_xlen_t i = 0; i < n_sub; ++i) {
      SEXP sub = VECTOR_ELT(sfg, i);
      extract_sfg_coords(sub, geom_type, feat_id, coords, ring_starts, tri_indices, vertex_feat_ids, bbox);
    }
  }
}

struct SpatialGridIndex {
  int grid_nx = 64;
  int grid_ny = 64;
  float bbox[4];
  uint32_t n_items = 0;
  std::vector<float> item_bboxes; // 4 * n_items: xmin, ymin, xmax, ymax
  std::vector<std::vector<uint32_t>> cells;
};

} // anonymous namespace

// Pack numeric x, y vectors directly into a GEXP binary point buffer (Ultra-fast path for 1M+ points)
[[cpp11::register]]
cpp11::raws cpp_pack_points_xy(
    cpp11::doubles x,
    cpp11::doubles y,
    cpp11::integers rgba,
    cpp11::doubles radius,
    cpp11::doubles elevation
) {
  uint32_t n = static_cast<uint32_t>(x.size());
  if (static_cast<uint32_t>(y.size()) != n) {
    cpp11::stop("`x` and `y` must have the same length.");
  }

  uint32_t has_radius = (radius.size() > 0) ? 1u : 0u;
  uint32_t has_elevation = (elevation.size() > 0) ? 1u : 0u;

  GexpHeader hdr;
  std::memset(&hdr, 0, sizeof(GexpHeader));
  std::memcpy(hdr.magic, "GEXP", 4);
  hdr.version = 1;
  hdr.geom_type = 1; // POINT
  hdr.n_features = n;
  hdr.n_vertices = n;
  hdr.n_indices = 0;
  hdr.n_ring_starts = 0;
  hdr.has_radius = has_radius;
  hdr.has_elevation = has_elevation;
  hdr.bbox[0] = std::numeric_limits<float>::infinity();
  hdr.bbox[1] = std::numeric_limits<float>::infinity();
  hdr.bbox[2] = -std::numeric_limits<float>::infinity();
  hdr.bbox[3] = -std::numeric_limits<float>::infinity();

  size_t coords_bytes = static_cast<size_t>(n) * 2 * sizeof(float);
  size_t feat_id_bytes = static_cast<size_t>(n) * sizeof(uint32_t);
  size_t rgba_bytes = static_cast<size_t>(n) * 4 * sizeof(uint8_t);
  size_t radius_bytes = has_radius ? (static_cast<size_t>(n) * sizeof(float)) : 0;
  size_t elev_bytes = has_elevation ? (static_cast<size_t>(n) * sizeof(float)) : 0;

  size_t total_bytes = sizeof(GexpHeader) + coords_bytes + feat_id_bytes + rgba_bytes + radius_bytes + elev_bytes;
  cpp11::writable::raws out(total_bytes);
  uint8_t* base = reinterpret_cast<uint8_t*>(RAW(out));

  float* coords_ptr = reinterpret_cast<float*>(base + sizeof(GexpHeader));
  uint32_t* feat_ptr = reinterpret_cast<uint32_t*>(base + sizeof(GexpHeader) + coords_bytes);
  uint8_t* rgba_ptr = base + sizeof(GexpHeader) + coords_bytes + feat_id_bytes;
  float* rad_ptr = reinterpret_cast<float*>(rgba_ptr + rgba_bytes);
  float* elev_ptr = reinterpret_cast<float*>(reinterpret_cast<uint8_t*>(rad_ptr) + radius_bytes);

  const double* xp = REAL(x);
  const double* yp = REAL(y);
  const int* rgbap = INTEGER(rgba);
  bool single_color = (rgba.size() == 4);
  bool single_radius = (radius.size() == 1);
  bool single_elev = (elevation.size() == 1);
  const double* radp = has_radius ? REAL(radius) : nullptr;
  const double* elevp = has_elevation ? REAL(elevation) : nullptr;

  float xmin = hdr.bbox[0], ymin = hdr.bbox[1], xmax = hdr.bbox[2], ymax = hdr.bbox[3];

  for (uint32_t i = 0; i < n; ++i) {
    float xi = static_cast<float>(xp[i]);
    float yi = static_cast<float>(yp[i]);
    coords_ptr[2 * i] = xi;
    coords_ptr[2 * i + 1] = yi;
    feat_ptr[i] = i;

    if (std::isfinite(xi) && std::isfinite(yi)) {
      if (xi < xmin) xmin = xi;
      if (yi < ymin) ymin = yi;
      if (xi > xmax) xmax = xi;
      if (yi > ymax) ymax = yi;
    }

    if (single_color) {
      rgba_ptr[4 * i]     = static_cast<uint8_t>(rgbap[0]);
      rgba_ptr[4 * i + 1] = static_cast<uint8_t>(rgbap[1]);
      rgba_ptr[4 * i + 2] = static_cast<uint8_t>(rgbap[2]);
      rgba_ptr[4 * i + 3] = static_cast<uint8_t>(rgbap[3]);
    } else {
      rgba_ptr[4 * i]     = static_cast<uint8_t>(rgbap[4 * i]);
      rgba_ptr[4 * i + 1] = static_cast<uint8_t>(rgbap[4 * i + 1]);
      rgba_ptr[4 * i + 2] = static_cast<uint8_t>(rgbap[4 * i + 2]);
      rgba_ptr[4 * i + 3] = static_cast<uint8_t>(rgbap[4 * i + 3]);
    }

    if (has_radius) {
      rad_ptr[i] = static_cast<float>(single_radius ? radp[0] : radp[i]);
    }
    if (has_elevation) {
      elev_ptr[i] = static_cast<float>(single_elev ? elevp[0] : elevp[i]);
    }
  }

  if (!std::isfinite(xmin)) {
    xmin = -180.0f; ymin = -90.0f; xmax = 180.0f; ymax = 90.0f;
  }
  hdr.bbox[0] = xmin;
  hdr.bbox[1] = ymin;
  hdr.bbox[2] = xmax;
  hdr.bbox[3] = ymax;

  std::memcpy(base, &hdr, sizeof(GexpHeader));
  return out;
}

// Pack an sfc geometry list column (POINT, LINESTRING, POLYGON, MULTIPOLYGON, etc.)
// directly into a contiguous GEXP binary buffer with C++ earcut triangulation
[[cpp11::register]]
cpp11::raws cpp_pack_sfc_binary(
    cpp11::list sfc,
    int geom_type_int,
    cpp11::integers rgba,
    cpp11::doubles radius,
    cpp11::doubles elevation
) {
  uint32_t n_features = static_cast<uint32_t>(sfc.size());
  uint16_t geom_type = static_cast<uint16_t>(geom_type_int);

  std::vector<float> coords;
  std::vector<uint32_t> ring_starts;
  std::vector<uint32_t> tri_indices;
  std::vector<uint32_t> vertex_feat_ids;

  coords.reserve(n_features * (geom_type == 1 ? 2 : 10));
  vertex_feat_ids.reserve(n_features * (geom_type == 1 ? 1 : 5));
  if (geom_type >= 2) ring_starts.reserve(n_features + 1);
  if (geom_type == 3) tri_indices.reserve(n_features * 9);

  float bbox[4] = {
    std::numeric_limits<float>::infinity(),
    std::numeric_limits<float>::infinity(),
    -std::numeric_limits<float>::infinity(),
    -std::numeric_limits<float>::infinity()
  };

  SEXP sfc_sexp = sfc;
  for (uint32_t i = 0; i < n_features; ++i) {
    SEXP sfg = VECTOR_ELT(sfc_sexp, i);
    extract_sfg_coords(sfg, geom_type, i, coords, ring_starts, tri_indices, vertex_feat_ids, bbox);
  }

  uint32_t n_vertices = static_cast<uint32_t>(coords.size() / 2);
  if (geom_type >= 2 && !ring_starts.empty()) {
    ring_starts.push_back(n_vertices); // Sentinel end offset
  }

  if (!std::isfinite(bbox[0])) {
    bbox[0] = -180.0f; bbox[1] = -90.0f; bbox[2] = 180.0f; bbox[3] = 90.0f;
  }

  uint32_t has_radius = (radius.size() > 0) ? 1u : 0u;
  uint32_t has_elevation = (elevation.size() > 0) ? 1u : 0u;

  GexpHeader hdr;
  std::memset(&hdr, 0, sizeof(GexpHeader));
  std::memcpy(hdr.magic, "GEXP", 4);
  hdr.version = 1;
  hdr.geom_type = geom_type;
  hdr.n_features = n_features;
  hdr.n_vertices = n_vertices;
  hdr.n_indices = static_cast<uint32_t>(tri_indices.size());
  hdr.n_ring_starts = static_cast<uint32_t>(ring_starts.size());
  hdr.has_radius = has_radius;
  hdr.has_elevation = has_elevation;
  std::memcpy(hdr.bbox, bbox, 4 * sizeof(float));

  size_t coords_bytes = coords.size() * sizeof(float);
  size_t feat_id_bytes = vertex_feat_ids.size() * sizeof(uint32_t);
  size_t ring_bytes = ring_starts.size() * sizeof(uint32_t);
  size_t idx_bytes = tri_indices.size() * sizeof(uint32_t);
  size_t rgba_bytes = static_cast<size_t>(n_features) * 4 * sizeof(uint8_t);
  size_t rad_bytes = has_radius ? (static_cast<size_t>(n_features) * sizeof(float)) : 0;
  size_t elev_bytes = has_elevation ? (static_cast<size_t>(n_features) * sizeof(float)) : 0;

  size_t total_bytes = sizeof(GexpHeader) + coords_bytes + feat_id_bytes +
                       ring_bytes + idx_bytes + rgba_bytes + rad_bytes + elev_bytes;

  cpp11::writable::raws out(total_bytes);
  uint8_t* ptr = reinterpret_cast<uint8_t*>(RAW(out));

  std::memcpy(ptr, &hdr, sizeof(GexpHeader));
  ptr += sizeof(GexpHeader);

  if (coords_bytes > 0) {
    std::memcpy(ptr, coords.data(), coords_bytes);
    ptr += coords_bytes;
  }
  if (feat_id_bytes > 0) {
    std::memcpy(ptr, vertex_feat_ids.data(), feat_id_bytes);
    ptr += feat_id_bytes;
  }
  if (ring_bytes > 0) {
    std::memcpy(ptr, ring_starts.data(), ring_bytes);
    ptr += ring_bytes;
  }
  if (idx_bytes > 0) {
    std::memcpy(ptr, tri_indices.data(), idx_bytes);
    ptr += idx_bytes;
  }

  // Copy per-feature RGBA colors
  const int* rgbap = INTEGER(rgba);
  bool single_color = (rgba.size() == 4);
  for (uint32_t i = 0; i < n_features; ++i) {
    if (single_color) {
      ptr[4 * i]     = static_cast<uint8_t>(rgbap[0]);
      ptr[4 * i + 1] = static_cast<uint8_t>(rgbap[1]);
      ptr[4 * i + 2] = static_cast<uint8_t>(rgbap[2]);
      ptr[4 * i + 3] = static_cast<uint8_t>(rgbap[3]);
    } else {
      ptr[4 * i]     = static_cast<uint8_t>(rgbap[4 * i]);
      ptr[4 * i + 1] = static_cast<uint8_t>(rgbap[4 * i + 1]);
      ptr[4 * i + 2] = static_cast<uint8_t>(rgbap[4 * i + 2]);
      ptr[4 * i + 3] = static_cast<uint8_t>(rgbap[4 * i + 3]);
    }
  }
  ptr += rgba_bytes;

  if (has_radius) {
    float* rptr = reinterpret_cast<float*>(ptr);
    const double* rp = REAL(radius);
    bool single_r = (radius.size() == 1);
    for (uint32_t i = 0; i < n_features; ++i) {
      rptr[i] = static_cast<float>(single_r ? rp[0] : rp[i]);
    }
    ptr += rad_bytes;
  }

  if (has_elevation) {
    float* eptr = reinterpret_cast<float*>(ptr);
    const double* ep = REAL(elevation);
    bool single_e = (elevation.size() == 1);
    for (uint32_t i = 0; i < n_features; ++i) {
      eptr[i] = static_cast<float>(single_e ? ep[0] : ep[i]);
    }
    ptr += elev_bytes;
  }

  return out;
}

// Pack a terra raster numeric vector into a GEXR raw Float32 binary packet for GPU fragment shaders
[[cpp11::register]]
cpp11::raws cpp_pack_raster_float32(
    cpp11::doubles values,
    int width,
    int height,
    int n_bands,
    cpp11::doubles bbox,
    double nodata
) {
  size_t n_vals = static_cast<size_t>(values.size());
  GexpRasterHeader hdr;
  std::memset(&hdr, 0, sizeof(GexpRasterHeader));
  std::memcpy(hdr.magic, "GEXR", 4);
  hdr.version = 1;
  hdr.n_bands = static_cast<uint16_t>(n_bands);
  hdr.width = static_cast<uint32_t>(width);
  hdr.height = static_cast<uint32_t>(height);
  for (int i = 0; i < 4; ++i) {
    hdr.bbox[i] = static_cast<float>(bbox[i]);
  }
  hdr.nodata = static_cast<float>(nodata);

  float vmin = std::numeric_limits<float>::infinity();
  float vmax = -std::numeric_limits<float>::infinity();

  size_t total_bytes = sizeof(GexpRasterHeader) + n_vals * sizeof(float);
  cpp11::writable::raws out(total_bytes);
  uint8_t* base = reinterpret_cast<uint8_t*>(RAW(out));
  float* fptr = reinterpret_cast<float*>(base + sizeof(GexpRasterHeader));

  const double* vp = REAL(values);
  for (size_t i = 0; i < n_vals; ++i) {
    double val = vp[i];
    if (ISNAN(val) || !std::isfinite(val)) {
      fptr[i] = hdr.nodata;
    } else {
      float fv = static_cast<float>(val);
      fptr[i] = fv;
      if (fv < vmin) vmin = fv;
      if (fv > vmax) vmax = fv;
    }
  }

  if (!std::isfinite(vmin)) {
    vmin = 0.0f;
    vmax = 1.0f;
  }
  hdr.vmin = vmin;
  hdr.vmax = vmax;
  std::memcpy(base, &hdr, sizeof(GexpRasterHeader));
  return out;
}

// Fast C++ spatial grid / R-tree style index for 1M-50M features with viewport querying & LOD sampling
[[cpp11::register]]
SEXP cpp_build_spatial_index(
    cpp11::doubles xmin,
    cpp11::doubles ymin,
    cpp11::doubles xmax,
    cpp11::doubles ymax,
    int grid_res
) {
  uint32_t n = static_cast<uint32_t>(xmin.size());
  auto* idx = new SpatialGridIndex();
  idx->grid_nx = std::max(8, std::min(512, grid_res));
  idx->grid_ny = std::max(8, std::min(512, grid_res));
  idx->n_items = n;
  idx->item_bboxes.resize(static_cast<size_t>(n) * 4);
  idx->cells.resize(static_cast<size_t>(idx->grid_nx * idx->grid_ny));

  float gxmin = std::numeric_limits<float>::infinity();
  float gymin = std::numeric_limits<float>::infinity();
  float gxmax = -std::numeric_limits<float>::infinity();
  float gymax = -std::numeric_limits<float>::infinity();

  const double* x0p = REAL(xmin);
  const double* y0p = REAL(ymin);
  const double* x1p = REAL(xmax);
  const double* y1p = REAL(ymax);

  for (uint32_t i = 0; i < n; ++i) {
    float bx0 = static_cast<float>(x0p[i]);
    float by0 = static_cast<float>(y0p[i]);
    float bx1 = static_cast<float>(x1p[i]);
    float by1 = static_cast<float>(y1p[i]);
    idx->item_bboxes[4 * i]     = bx0;
    idx->item_bboxes[4 * i + 1] = by0;
    idx->item_bboxes[4 * i + 2] = bx1;
    idx->item_bboxes[4 * i + 3] = by1;
    if (std::isfinite(bx0) && bx0 < gxmin) gxmin = bx0;
    if (std::isfinite(by0) && by0 < gymin) gymin = by0;
    if (std::isfinite(bx1) && bx1 > gxmax) gxmax = bx1;
    if (std::isfinite(by1) && by1 > gymax) gymax = by1;
  }

  if (!std::isfinite(gxmin)) {
    gxmin = -180.0f; gymin = -90.0f; gxmax = 180.0f; gymax = 90.0f;
  }
  float dx = std::max(1e-6f, gxmax - gxmin);
  float dy = std::max(1e-6f, gymax - gymin);
  idx->bbox[0] = gxmin;
  idx->bbox[1] = gymin;
  idx->bbox[2] = gxmax;
  idx->bbox[3] = gymax;

  for (uint32_t i = 0; i < n; ++i) {
    float bx0 = idx->item_bboxes[4 * i];
    float by0 = idx->item_bboxes[4 * i + 1];
    float bx1 = idx->item_bboxes[4 * i + 2];
    float by1 = idx->item_bboxes[4 * i + 3];
    if (!std::isfinite(bx0) || !std::isfinite(by0)) continue;

    int cx0 = std::clamp(static_cast<int>(((bx0 - gxmin) / dx) * idx->grid_nx), 0, idx->grid_nx - 1);
    int cy0 = std::clamp(static_cast<int>(((by0 - gymin) / dy) * idx->grid_ny), 0, idx->grid_ny - 1);
    int cx1 = std::clamp(static_cast<int>(((bx1 - gxmin) / dx) * idx->grid_nx), 0, idx->grid_nx - 1);
    int cy1 = std::clamp(static_cast<int>(((by1 - gymin) / dy) * idx->grid_ny), 0, idx->grid_ny - 1);

    for (int cy = cy0; cy <= cy1; ++cy) {
      for (int cx = cx0; cx <= cx1; ++cx) {
        idx->cells[cy * idx->grid_nx + cx].push_back(i);
      }
    }
  }

  cpp11::external_pointer<SpatialGridIndex> ptr(idx);
  return ptr;
}

// Query spatial index for a bounding box [xmin, ymin, xmax, ymax] with optional max_features cap (LOD sampling)
[[cpp11::register]]
cpp11::integers cpp_query_spatial_index(
    SEXP index_ptr,
    double qxmin,
    double qymin,
    double qxmax,
    double qymax,
    int max_features
) {
  cpp11::external_pointer<SpatialGridIndex> ptr(index_ptr);
  SpatialGridIndex* idx = ptr.get();
  if (!idx || idx->n_items == 0) {
    return cpp11::writable::integers();
  }

  float gxmin = idx->bbox[0];
  float gymin = idx->bbox[1];
  float gxmax = idx->bbox[2];
  float gymax = idx->bbox[3];
  float dx = std::max(1e-6f, gxmax - gxmin);
  float dy = std::max(1e-6f, gymax - gymin);

  int cx0 = std::clamp(static_cast<int>(((static_cast<float>(qxmin) - gxmin) / dx) * idx->grid_nx), 0, idx->grid_nx - 1);
  int cy0 = std::clamp(static_cast<int>(((static_cast<float>(qymin) - gymin) / dy) * idx->grid_ny), 0, idx->grid_ny - 1);
  int cx1 = std::clamp(static_cast<int>(((static_cast<float>(qxmax) - gxmin) / dx) * idx->grid_nx), 0, idx->grid_nx - 1);
  int cy1 = std::clamp(static_cast<int>(((static_cast<float>(qymax) - gymin) / dy) * idx->grid_ny), 0, idx->grid_ny - 1);

  std::vector<uint8_t> seen(idx->n_items, 0);
  std::vector<int> hits;
  hits.reserve(std::min<size_t>(idx->n_items, 65536));

  float fqxmin = static_cast<float>(qxmin);
  float fqymin = static_cast<float>(qymin);
  float fqxmax = static_cast<float>(qxmax);
  float fqymax = static_cast<float>(qymax);

  for (int cy = cy0; cy <= cy1; ++cy) {
    for (int cx = cx0; cx <= cx1; ++cx) {
      const auto& bucket = idx->cells[cy * idx->grid_nx + cx];
      for (uint32_t item : bucket) {
        if (seen[item]) continue;
        seen[item] = 1;
        float bx0 = idx->item_bboxes[4 * item];
        float by0 = idx->item_bboxes[4 * item + 1];
        float bx1 = idx->item_bboxes[4 * item + 2];
        float by1 = idx->item_bboxes[4 * item + 3];
        if (bx1 >= fqxmin && bx0 <= fqxmax && by1 >= fqymin && by0 <= fqymax) {
          hits.push_back(static_cast<int>(item + 1)); // 1-based R index
        }
      }
    }
  }

  if (max_features > 0 && static_cast<int>(hits.size()) > max_features) {
    // Deterministic stride sampling for smooth LOD at low zoom levels
    cpp11::writable::integers sampled(max_features);
    double step = static_cast<double>(hits.size()) / static_cast<double>(max_features);
    for (int i = 0; i < max_features; ++i) {
      sampled[i] = hits[static_cast<size_t>(i * step)];
    }
    return sampled;
  }

  cpp11::writable::integers out(hits.size());
  for (size_t i = 0; i < hits.size(); ++i) {
    out[i] = hits[i];
  }
  return out;
}

// Fast C++ hexagonal binning for 1M+ points (returns hex centers, counts, and aggregated values)
[[cpp11::register]]
cpp11::writable::list cpp_hexbin_aggregate(
    cpp11::doubles x,
    cpp11::doubles y,
    cpp11::doubles weight,
    double radius_deg
) {
  size_t n = x.size();
  double r = std::max(1e-5, radius_deg);
  double dx = r * std::sqrt(3.0);
  double dy = r * 1.5;

  struct HexCell {
    double cx;
    double cy;
    int count;
    double sum_w;
  };

  // Use sorted 64-bit grid key for ultra-fast aggregation without hash collisions
  struct KeyEntry {
    int64_t key;
    int32_t q;
    int32_t row;
    double w;
  };

  const double* xp = REAL(x);
  const double* yp = REAL(y);
  bool has_w = (weight.size() == x.size());
  const double* wp = has_w ? REAL(weight) : nullptr;

  std::vector<KeyEntry> entries;
  entries.reserve(n);

  for (size_t i = 0; i < n; ++i) {
    double xi = xp[i];
    double yi = yp[i];
    if (!std::isfinite(xi) || !std::isfinite(yi)) continue;
    int32_t row = static_cast<int32_t>(std::floor(yi / dy));
    double x_shift = (row & 1) ? (dx * 0.5) : 0.0;
    int32_t col = static_cast<int32_t>(std::floor((xi - x_shift) / dx));
    int64_t key = (static_cast<int64_t>(row) << 32) | static_cast<uint32_t>(col);
    entries.push_back({key, col, row, has_w ? wp[i] : 1.0});
  }

  std::sort(entries.begin(), entries.end(), [](const KeyEntry& a, const KeyEntry& b) {
    return a.key < b.key;
  });

  std::vector<double> out_x;
  std::vector<double> out_y;
  std::vector<int> out_count;
  std::vector<double> out_val;

  size_t i = 0;
  while (i < entries.size()) {
    int64_t k = entries[i].key;
    int32_t col = entries[i].q;
    int32_t row = entries[i].row;
    int cnt = 0;
    double sum_w = 0.0;
    while (i < entries.size() && entries[i].key == k) {
      cnt++;
      sum_w += entries[i].w;
      i++;
    }
    double x_shift = (row & 1) ? (dx * 0.5) : 0.0;
    out_x.push_back((col + 0.5) * dx + x_shift);
    out_y.push_back((row + 0.5) * dy);
    out_count.push_back(cnt);
    out_val.push_back(sum_w / std::max(1, cnt));
  }

  cpp11::writable::list res;
  res.push_back(cpp11::named_arg("x") = cpp11::writable::doubles(out_x.begin(), out_x.end()));
  res.push_back(cpp11::named_arg("y") = cpp11::writable::doubles(out_y.begin(), out_y.end()));
  res.push_back(cpp11::named_arg("count") = cpp11::writable::integers(out_count.begin(), out_count.end()));
  res.push_back(cpp11::named_arg("mean_weight") = cpp11::writable::doubles(out_val.begin(), out_val.end()));
  return res;
}
