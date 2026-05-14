param(
    [string]$Exe = ".\third_party\llama.cpp\build\bin\llama-cli.exe",
    [string]$Model = ".\models\AngelSlim\Hy-MT1.5-1.8B-1.25bit-GGUF\Hy-MT1.5-1.8B-STQ1_0.gguf",
    [string]$Prompt = "translate to chinese: hello",
    [int]$Timeout = 60,
    [int]$NCtx = 256,
    [int]$NPredict = 16,
    [int]$Threads = 2,
    [int]$GpuLayers = -1,
    [switch]$AllowCpu,
    [switch]$PrintCommand
)

$ErrorActionPreference = "Stop"

$args = @(
    "run",
    ".\scripts\safe_llama_smoketest.py",
    "--exe", $Exe,
    "--model", $Model,
    "--prompt", $Prompt,
    "--timeout", $Timeout,
    "--n-ctx", $NCtx,
    "--n-predict", $NPredict,
    "--threads", $Threads,
    "--gpu-layers", $GpuLayers
)

if ($AllowCpu) {
    $args += "--allow-cpu"
}

if ($PrintCommand) {
    $args += "--print-command"
}

& uv @args
if ($LASTEXITCODE -ne 0) {
    throw "safe_llama_smoketest failed with exit code $LASTEXITCODE"
}
