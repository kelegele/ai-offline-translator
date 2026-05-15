#!/usr/bin/env bash
set -euo pipefail

MODEL_SCOPE_MODEL="${MODEL_SCOPE_MODEL:-AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELS_DIR="$REPO_ROOT/models"
MODEL_DIR="$MODELS_DIR/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF"
LLAMA_DIR="$REPO_ROOT/third_party/llama.cpp"
LLAMA_PR_22836_COMMIT="7ef6976b218cfce6158165f4c63a094acb70e707"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command '$1'. $2" >&2
    exit 1
  }
}

mkdir -p "$MODEL_DIR"

need_cmd git "Install Git and rerun."
need_cmd uv "Install uv first: https://docs.astral.sh/uv/"

if ! command -v modelscope >/dev/null 2>&1; then
  echo "Installing modelscope CLI with uv tool install..."
  uv tool install modelscope
fi

if [[ ! -f "$REPO_ROOT/.gitmodules" ]]; then
  echo "Missing .gitmodules. Run setup from the repository root checkout." >&2
  exit 1
fi

echo "Initializing llama.cpp submodule..."
git -C "$REPO_ROOT" submodule update --init third_party/llama.cpp

current_llama_commit="$(git -C "$LLAMA_DIR" rev-parse HEAD)"
if [[ "$current_llama_commit" != "$LLAMA_PR_22836_COMMIT" ]]; then
  echo "Unexpected llama.cpp commit: $current_llama_commit" >&2
  echo "Expected PR #22836 commit: $LLAMA_PR_22836_COMMIT" >&2
  exit 1
fi

echo "Downloading model into model-specific directory..."
modelscope download --model "$MODEL_SCOPE_MODEL" --local_dir "$MODEL_DIR"

echo "Setup complete."
echo "Model root: $MODEL_DIR"
echo "llama.cpp: $LLAMA_DIR"
