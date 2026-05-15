#!/usr/bin/env bash
# Build llama.cpp static libraries for Android arm64-v8a
# Only builds the required libs: llama, llama-common, ggml, ggml-cpu, ggml-base
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LLAMA_DIR="$ROOT_DIR/third_party/llama.cpp"
BUILD_DIR="$LLAMA_DIR/build-android"

if [ -z "${ANDROID_NDK_HOME:-}" ]; then
  echo "Error: ANDROID_NDK_HOME not set"
  echo "Install NDK via Android Studio or: sdkmanager 'ndk;27.0.12077973'"
  exit 1
fi

CMAKE_TOOLCHAIN="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"
if [ ! -f "$CMAKE_TOOLCHAIN" ]; then
  echo "Error: NDK toolchain not found at $CMAKE_TOOLCHAIN"
  exit 1
fi

echo "Building llama.cpp for Android arm64-v8a..."
echo "LLAMA_DIR: $LLAMA_DIR"
echo "BUILD_DIR: $BUILD_DIR"

cmake -S "$LLAMA_DIR" -B "$BUILD_DIR" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-24 \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_OPENMP=OFF \
  -DGGML_METAL=OFF \
  -DGGML_VULKAN=OFF \
  -DGGML_CUDA=OFF \
  -DGGML_BLAS=OFF \
  -DLLAMA_CURL=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLAMA_BUILD_TOOLS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_SERVER=OFF

cmake --build "$BUILD_DIR" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)" \
  --target llama \
  --target llama-common \
  --target ggml \
  --target ggml-cpu \
  --target ggml-base

echo ""
echo "Build complete. Static libs:"
find "$BUILD_DIR" -name "*.a" -type f | sort
