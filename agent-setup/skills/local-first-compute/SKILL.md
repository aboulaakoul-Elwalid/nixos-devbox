---
name: "local-first-compute"
description: "Decide whether ML, GPU, training, inference, rendering, or long-running compute should run locally before using cloud resources."
---

# Local-First Compute Skill

## Purpose

Choose the right compute lane before starting heavy work.

WALID defaults to this machine first.
Cloud GPUs are the fallback, not the default.

## Hardware Snapshot

- CPU: Intel i9-7900X (10 cores / 20 threads)
- RAM: about 62.6 GiB
- GPU: NVIDIA RTX 3060 with 12 GiB VRAM
- Current driver lane observed on this machine: NVIDIA driver 595.x reporting CUDA 13.2
- Current working PyTorch wheel lane for local x86_64 Linux: CUDA 13.0 wheels, e.g. `torch` / `torchvision` `+cu130`

Always verify current driver and wheel state before large runs:

- `nvidia-smi`
- `python -c 'import torch; print(torch.__version__, torch.version.cuda, torch.cuda.is_available())'`

This is enough for:
- local coding, builds, tests, indexing, and documentation
- local research, data wrangling, and moderate batch jobs
- local GPU inference, render tests, and small-to-medium experiments that fit in 12 GiB VRAM

## Routing Rules

### Choose local CPU first when

- the task is mostly coding, testing, building, searching, indexing, or document work
- the task is compute-heavy but does not need a GPU
- the data fits comfortably in local RAM

### Choose local GPU first when

- the task benefits from CUDA but fits inside 12 GiB VRAM
- the workload is a prototype, debug run, render test, or moderate inference/training job
- quick feedback matters more than remote scale
- the workload can use the existing CUDA 13 local wheel lane without custom cluster setup

### Escalate to online compute when

- VRAM needs exceed local fit
- the task needs longer unattended runtime than you want to spend locally
- the workload benefits from remote isolation, free quota, or higher-end hardware
- you need to preserve the main machine for other interactive work

### Remote lane choice

If remote execution is justified, load `online-compute` to choose Modal or Kaggle and route to the specialist agent.

## Decision Pattern

Before running anything substantial, answer these:

1. Does it fit local CPU/RAM/GPU?
2. Is local feedback faster and simpler?
3. Does remote scale add real value, or only habit?

If the task fits locally, run it locally.

## Operational Rules

- Say the fit decision explicitly: `local CPU`, `local GPU`, or `online compute`.
- Verify locally before scaling remotely whenever practical.
- Do not default to cloud because it feels safer; use cloud because the workload needs it.
- Keep the main machine responsive for interactive work when choosing long local runs.

## Python ML Environment Rules

For Python ML projects on this NixOS workstation, keep the host and project layers separate.

- Use NixOS for drivers, system libraries, shells, editors, and durable CLI tools.
- Use `uv` project metadata for Python dependencies: `pyproject.toml`, `uv.lock`, and `.python-version`.
- Prefer PyPI/vendor CUDA wheels through `uv` for PyTorch/JAX-style stacks instead of global Nix ML packages, unless the project explicitly needs Nix-built Python packages.
- Pin CUDA wheel indexes in `pyproject.toml` when using GPU wheels; for PyTorch CUDA 13, source `torch` and `torchvision` from `https://download.pytorch.org/whl/cu130` on Linux x86_64.
- Before touching an existing hand-built `.venv`, run `uv sync --locked --dry-run` or `uv sync --locked --check`.
- Use `uv sync --locked --inexact` when preserving extra packages in an existing venv matters.
- Use plain `uv sync --locked` only when pruning packages not declared by the project is acceptable.
- Prefer `uv run --locked --no-sync ...` for verification against the current environment without mutating it.

Mental model: Nix owns the machine; `uv` owns the repo; CUDA wheel compatibility is verified, not assumed.

## Example Requests

- "Can this run on my machine?" -> estimate local fit first
- "Train this small model" -> prefer local GPU if it fits 12 GiB VRAM
- "Run this overnight fine-tune" -> decide between local GPU and online compute based on fit, runtime, and interaction cost
- "Should I use Kaggle or Modal?" -> load `online-compute` only after ruling out local execution
