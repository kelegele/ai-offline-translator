#!/usr/bin/env bash
set -euo pipefail

MODEL_SCOPE_MODEL="${MODEL_SCOPE_MODEL:-AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF}"
LLAMA_REPO="${LLAMA_REPO:-https://github.com/ggml-org/llama.cpp.git}"
LLAMA_REF="${LLAMA_REF:-refs/pull/22836/head}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELS_DIR="$REPO_ROOT/models"
MODEL_DIR="$MODELS_DIR/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF"
THIRD_PARTY_DIR="$REPO_ROOT/third_party"
LLAMA_DIR="$THIRD_PARTY_DIR/llama.cpp"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command '$1'. $2" >&2
    exit 1
  }
}

mkdir -p "$MODEL_DIR" "$THIRD_PARTY_DIR"

need_cmd git "Install Git and rerun."
need_cmd uv "Install uv first: https://docs.astral.sh/uv/"

if ! command -v modelscope >/dev/null 2>&1; then
  echo "Installing modelscope CLI with uv tool install..."
  uv tool install modelscope
fi

if [[ ! -d "$LLAMA_DIR/.git" ]]; then
  echo "Initializing llama.cpp repo in third_party/llama.cpp..."
  mkdir -p "$LLAMA_DIR"
  git -C "$LLAMA_DIR" init
  git -C "$LLAMA_DIR" remote add origin "$LLAMA_REPO"
fi

echo "Fetching llama.cpp PR #22836..."
git -C "$LLAMA_DIR" fetch --depth 1 origin "$LLAMA_REF"
git -C "$LLAMA_DIR" checkout -B pr-22836 FETCH_HEAD

echo "Downloading model into model-specific directory..."
modelscope download --model "$MODEL_SCOPE_MODEL" --local_dir "$MODEL_DIR"

echo "Setup complete."
echo "Model root: $MODEL_DIR"
echo "llama.cpp: $LLAMA_DIR"
