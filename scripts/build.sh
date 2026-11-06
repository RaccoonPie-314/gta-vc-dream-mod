#!/bin/bash
# Configure and build. Plain CMake: the Conan 2 / premake 5.0.0 route both fail here.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE/reVC"

cmake -S . -B build -DCMAKE_BUILD_TYPE=Release > /dev/null
cmake --build build -j"$(sysctl -n hw.ncpu)" | grep -Ev "^ld: warning: building for macOS"
echo "built: $HERE/reVC/build/src/reVC.app"
