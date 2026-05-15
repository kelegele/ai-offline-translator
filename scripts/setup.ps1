param(
    [string]$ModelScopeModel = "AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ModelsDir = Join-Path $RepoRoot "models"
$ModelDir = Join-Path $ModelsDir "AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF"
$LlamaDir = Join-Path $RepoRoot "third_party\llama.cpp"
$LlamaPr22836Commit = "7ef6976b218cfce6158165f4c63a094acb70e707"

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

New-Item -ItemType Directory -Force $ModelDir | Out-Null

Ensure-Command "git" "Install Git and rerun this script."
Ensure-Command "uv" "Install uv first: https://docs.astral.sh/uv/"

if (-not (Get-Command "modelscope" -ErrorAction SilentlyContinue)) {
    Invoke-Native "Installing modelscope CLI with uv tool install..." "uv" @("tool", "install", "modelscope")
}

if (-not (Test-Path (Join-Path $RepoRoot ".gitmodules"))) {
    throw "Missing .gitmodules. Run setup from the repository root checkout."
}

Invoke-Native "Initializing llama.cpp submodule..." "git" @("-C", $RepoRoot, "submodule", "update", "--init", "third_party/llama.cpp")

$CurrentLlamaCommit = (& git -C $LlamaDir rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Failed to read llama.cpp submodule commit."
}
if ($CurrentLlamaCommit -ne $LlamaPr22836Commit) {
    throw "Unexpected llama.cpp commit: $CurrentLlamaCommit. Expected PR #22836 commit: $LlamaPr22836Commit"
}

Invoke-Native "Downloading model into model-specific directory..." "modelscope" @("download", "--model", $ModelScopeModel, "--local_dir", $ModelDir)

Write-Host "Setup complete."
Write-Host "Model root: $ModelDir"
Write-Host "llama.cpp: $LlamaDir"
