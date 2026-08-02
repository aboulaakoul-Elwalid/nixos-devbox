---
name: "online-compute"
description: "Escalate ML, GPU, TPU, training, or long-running compute to Modal or Kaggle after local-first-compute rules out local execution."
---

# Online Compute Skill

## Purpose

Escalate from this machine to online compute with the least operational weight.

This skill is not the first stop. Use `local-first-compute` before this skill unless the user explicitly asks for Modal or Kaggle.

## Decision Rule

- Prefer Modal for paid, reliable, scriptable cloud GPU work.
- Prefer Kaggle for free GPU/TPU experiments when quota, runtime, and environment constraints fit.
- Prefer local again if the remote setup would be more complex than the workload.

## Modal Lane

Use `modal-gpu` when the task needs:

- reliable long-running cloud jobs
- deployment or scheduled execution
- stronger automation than notebooks
- profile failover between `aboulaakoul-elwalid` and `walid-aboolaakool`

Operational defaults:

- Use `MODAL_PROFILE=aboulaakoul-elwalid` first.
- Run preflight before run/deploy operations when available.
- Use failover wrappers if the primary profile fails.
- Report the app/function name, profile, command, logs URL or log command, and output path.

Direct fallback procedure when `modal-gpu` is unavailable or unnecessary:

1. Identify the Modal app file or ask for the target path if ambiguous.
2. Prefer the primary profile: `MODAL_PROFILE=aboulaakoul-elwalid`.
3. If a repo provides a preflight command or wrapper, run it before `run` or `deploy`.
4. Use explicit profile-prefixed commands, for example:
   - `MODAL_PROFILE=aboulaakoul-elwalid modal run path/to/app.py`
   - `MODAL_PROFILE=aboulaakoul-elwalid modal deploy path/to/app.py`
   - `MODAL_PROFILE=aboulaakoul-elwalid modal app logs <app-name>`
   - `MODAL_PROFILE=aboulaakoul-elwalid modal container list`
5. If auth, quota, or profile errors block the run, retry with `MODAL_PROFILE=walid-aboolaakool` only when safe.
6. Capture the exact command, app/function name, profile, output path, and log command.

## Kaggle Lane

Use `kaggle-gpu` when the task needs:

- free GPU quota and the workload fits Kaggle constraints
- TPU experiments
- notebook-style reproducibility
- manual GUI selection for hardware the CLI cannot request

Operational defaults:

- GPU runner: `~/dotfiles/kaggle/gpu-runner/`
- TPU runner: `~/dotfiles/kaggle/tpu-runner/`
- Run archives: `~/dotfiles/kaggle/runs/`
- GPU dashboard: `https://www.kaggle.com/code/elwalidaboulaakoul/gpu-runner`
- TPU dashboard: `https://www.kaggle.com/code/elwalidaboulaakoul/tpu-runner`

Direct fallback procedure when `kaggle-gpu` is unavailable or unnecessary:

1. Choose the runner directory:
   - GPU: `~/dotfiles/kaggle/gpu-runner/`
   - TPU: `~/dotfiles/kaggle/tpu-runner/`
2. Check whether the requested hardware can be selected by CLI.
3. Use CLI automation for standard GPU/TPU runner flows when available.
4. If the requested hardware requires GUI selection, prepare the notebook/files and tell the user the exact manual step.
5. Download or locate outputs under `~/dotfiles/kaggle/runs/` when the run completes.
6. Capture the notebook path, runner directory, dashboard URL, output/archive path, and shortest status/rerun command.

## Routing Pattern

When remote compute is justified:

1. State why local CPU/GPU is not enough.
2. Choose `Modal` or `Kaggle` with one sentence.
3. Prefer launching the specialist agent directly when available:
   - `modal-gpu` for Modal
   - `kaggle-gpu` for Kaggle
4. If the specialist agent is unavailable, unnecessary, or would add overhead, follow the direct fallback procedure in this skill.
5. Ask only if credentials, target hardware, or destructive deployment state is ambiguous.

## Reporting

Always finish with:

- selected lane: `Modal` or `Kaggle`
- reason local was skipped
- exact command or notebook path used
- output/log location
- shortest rerun command
