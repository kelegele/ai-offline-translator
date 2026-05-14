from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EXE = REPO_ROOT / "third_party" / "llama.cpp" / "build" / "bin" / "llama-cli.exe"
DEFAULT_MODEL = (
    REPO_ROOT
    / "models"
    / "AngelSlim"
    / "Hy-MT1.5-1.8B-1.25bit-GGUF"
    / "Hy-MT1.5-1.8B-STQ1_0.gguf"
)
DEFAULT_PROMPT = "translate to chinese: hello"

MAX_N_CTX = 512
MAX_N_PREDICT = 64
MAX_THREADS = 4
MAX_TIMEOUT_SECONDS = 120
MAX_OUTPUT_BYTES = 64 * 1024


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Safely run a bounded llama.cpp smoke test. Must be launched with uv run."
    )
    parser.add_argument("--exe", type=Path, default=DEFAULT_EXE)
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--prompt", default=DEFAULT_PROMPT)
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--n-ctx", type=int, default=256)
    parser.add_argument("--n-predict", type=int, default=16)
    parser.add_argument("--threads", type=int, default=2)
    parser.add_argument("--gpu-layers", type=int, default=-1)
    parser.add_argument(
        "--allow-cpu",
        action="store_true",
        help="Allow a bounded CPU fallback. Without this, Windows requires GPU offload.",
    )
    parser.add_argument(
        "--print-command",
        action="store_true",
        help="Print the sanitized command before running it.",
    )
    return parser.parse_args()


def require_uv() -> None:
    if "UV_RUN_RECURSION_DEPTH" not in os.environ:
        raise SystemExit("Refusing to run: launch with `uv run scripts/safe_llama_smoketest.py`.")


def validate_args(args: argparse.Namespace) -> None:
    if not args.exe.is_file():
        raise SystemExit(f"llama-cli not found: {args.exe}")
    if not args.model.is_file():
        raise SystemExit(f"model not found: {args.model}")
    if args.timeout < 1 or args.timeout > MAX_TIMEOUT_SECONDS:
        raise SystemExit(f"timeout must be 1..{MAX_TIMEOUT_SECONDS} seconds")
    if args.n_ctx < 64 or args.n_ctx > MAX_N_CTX:
        raise SystemExit(f"n-ctx must be 64..{MAX_N_CTX}")
    if args.n_predict < 1 or args.n_predict > MAX_N_PREDICT:
        raise SystemExit(f"n-predict must be 1..{MAX_N_PREDICT}")
    if args.threads < 1 or args.threads > MAX_THREADS:
        raise SystemExit(f"threads must be 1..{MAX_THREADS}")
    if args.gpu_layers < -1 or args.gpu_layers > 999:
        raise SystemExit("gpu-layers must be -1..999")
    if platform.system() == "Windows" and args.gpu_layers == 0 and not args.allow_cpu:
        raise SystemExit("Refusing Windows CPU-only run. Use GPU offload or pass --allow-cpu for bounded fallback.")


def has_nvidia_gpu() -> bool:
    nvidia_smi = shutil.which("nvidia-smi")
    if not nvidia_smi:
        return False
    result = subprocess.run(
        [nvidia_smi, "--query-gpu=name", "--format=csv,noheader"],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    return result.returncode == 0 and bool(result.stdout.strip())


def build_command(args: argparse.Namespace) -> list[str]:
    return [
        str(args.exe),
        "-m",
        str(args.model),
        "-p",
        args.prompt,
        "-n",
        str(args.n_predict),
        "-c",
        str(args.n_ctx),
        "-t",
        str(args.threads),
        "-ngl",
        str(args.gpu_layers),
        "--temp",
        "0",
        "--single-turn",
        "--no-conversation",
        "--no-display-prompt",
        "--no-warmup",
    ]


def run_bounded(command: list[str], timeout: int) -> int:
    process = subprocess.Popen(
        command,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=False,
        cwd=REPO_ROOT,
    )
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        raise SystemExit(f"Timed out after {timeout}s; process was killed.")
    finally:
        if process.poll() is None:
            process.kill()

    if len(output) > MAX_OUTPUT_BYTES:
        raise SystemExit(f"Output exceeded {MAX_OUTPUT_BYTES} bytes; process was killed.")

    output = output.decode("utf-8", errors="replace")
    print(output.strip())
    return process.returncode or 0


def main() -> int:
    require_uv()
    args = parse_args()
    validate_args(args)

    if platform.system() == "Windows" and args.gpu_layers != 0 and not has_nvidia_gpu():
        print("Warning: no NVIDIA GPU detected by nvidia-smi; llama.cpp may fall back depending on build backend.")
        if not args.allow_cpu:
            raise SystemExit("Refusing to continue without detected GPU. Pass --allow-cpu for bounded fallback.")

    command = build_command(args)
    if args.print_command:
        print("Command:", " ".join(command))
    return run_bounded(command, args.timeout)


if __name__ == "__main__":
    raise SystemExit(main())
