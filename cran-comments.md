## Test environments
* local Windows 11 x64, R 4.6.1 (GCC 14.3.0 C++17)
* GitHub Actions: ubuntu-latest (r-devel, r-release, r-oldrel-1), macos-latest (r-release), windows-latest (r-release)

## R CMD check results
0 errors | 0 warnings | 0 notes

## Notes for CRAN maintainers
* `SystemRequirements: C++17` is declared for structured bindings and `std::clamp` in `src/glmap_cpp.cpp` and `src/earcut.h`.
* `src/earcut.h` is the ISC-licensed `mapbox/earcut.hpp` library and `inst/htmlwidgets/lib/maplibre-gl/` is the BSD-3-Clause-licensed `MapLibre GL JS` library; both copyright holders are credited in `Authors@R` with `role = "cph"` and full license texts are included in `inst/COPYRIGHTS`.
