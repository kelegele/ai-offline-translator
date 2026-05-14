# Repository Bootstrap Design

**Goal:** Make this repo self-explanatory and one-command bootstrappable for local development.

**Scope:**
- Standardize model location as `models/`
- Standardize external source location as `third_party/llama.cpp/`
- Add setup scripts for model download and `llama.cpp` PR checkout
- Update docs to separate project-relative paths from author-local paths

**Decisions:**
- Model files are not committed to Git
- Models are fetched with `modelscope download --model AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF --local_dir models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF`
- `llama.cpp` is cloned into `third_party/llama.cpp/` and checked out from `https://github.com/ggml-org/llama.cpp/pull/22836`
- Python-adjacent tooling uses `uv`

**Why:**
- Keeps repo small
- Keeps model provenance explicit
- Makes setup reproducible
- Removes misleading hard-coded machine-specific paths from primary instructions
