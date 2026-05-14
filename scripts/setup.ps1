param(
    [string]$ModelScopeModel = "AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF",
    [string]$LlamaRepo = "https://github.com/ggml-org/llama.cpp.git",
    [string]$LlamaRef = "refs/pull/22836/head"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ModelsDir = Join-Path $RepoRoot "models"
$ModelDir = Join-Path $ModelsDir "AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF"
$ThirdPartyDir = Join-Path $RepoRoot "third_party"
$LlamaDir = Join-Path $ThirdPartyDir "llama.cpp"

function Ensure-Command($Name, $InstallHint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing command '$Name'. $InstallHint"
    }
}

function Invoke-Native($Description, $FilePath, [string[]]$Arguments) {
    Write-Host $Description
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $FilePath $($Arguments -join ' ')"
    }
}

New-Item -ItemType Directory -Force $ModelDir, $ThirdPartyDir | Out-Null

Ensure-Command "git" "Install Git and rerun this script."
Ensure-Command "uv" "Install uv first: https://docs.astral.sh/uv/"

if (-not (Get-Command "modelscope" -ErrorAction SilentlyContinue)) {
    Invoke-Native "Installing modelscope CLI with uv tool install..." "uv" @("tool", "install", "modelscope")
}

if (-not (Test-Path $LlamaDir)) {
    New-Item -ItemType Directory -Force $LlamaDir | Out-Null
    Invoke-Native "Initializing llama.cpp repo in third_party/llama.cpp..." "git" @("-C", $LlamaDir, "init")
    Invoke-Native "Adding llama.cpp origin remote..." "git" @("-C", $LlamaDir, "remote", "add", "origin", $LlamaRepo)
}

Invoke-Native "Fetching llama.cpp PR #22836..." "git" @("-C", $LlamaDir, "fetch", "--depth", "1", "origin", $LlamaRef)
Invoke-Native "Checking out llama.cpp PR #22836..." "git" @("-C", $LlamaDir, "checkout", "-B", "pr-22836", "FETCH_HEAD")

Invoke-Native "Downloading model into model-specific directory..." "modelscope" @("download", "--model", $ModelScopeModel, "--local_dir", $ModelDir)

Write-Host "Setup complete."
Write-Host "Model root: $ModelDir"
Write-Host "llama.cpp: $LlamaDir"
