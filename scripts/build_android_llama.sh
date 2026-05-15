#!/usr/bin/env bash
# Build llama.cpp static libraries for Android arm64-v8a
# Requires ANDROID_NDK_HOME to be set
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
  -DBUILD_SHARED_LIBS=OFF

cmake --build "$BUILD_DIR" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"

echo ""
echo "Build complete. Static libs at:"
ls -la "$BUILD_DIR/src/libllama.a" 2>/dev/null || true
ls -la "$BUILD_DIR/common/libllama-common.a" 2>/dev/null || true
ls -la "$BUILD_DIR/common/libllama-common-base.a" 2>/dev/null || true
ls -la "$BUILD_DIR/ggml/src/libggml.a" 2>/dev/null || true
ls -la "$BUILD_DIR/ggml/src/libggml-cpu.a" 2>/dev/null || true
ls -la "$BUILD_DIR/ggml/src/libggml-base.a" 2>/dev/null || true
