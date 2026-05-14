# Models

This directory is the local model cache for development.

Use one subdirectory per upstream model repo.

Recommended layout:

```text
models/
└─ AngelSlim/
   └─ Hy-MT1.5-1.8B-1.25bit-GGUF/
      ├─ Hy-MT1.5-1.8B-STQ1_0.gguf
      ├─ Hy-MT1.5-1.8B-1.25bit.gguf
      └─ ...
```

Download the MVP model with:

```powershell
.\scripts\setup.ps1
```

or directly:

```powershell
modelscope download --model AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF --local_dir models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF
```

Expected MVP file:

- `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-STQ1_0.gguf`

Large model files are ignored by Git. Do not commit `.gguf`, `.bin`, `.safetensors`, or `.apk` files.
