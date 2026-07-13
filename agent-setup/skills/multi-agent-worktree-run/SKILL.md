---
name: multi-agent-worktree-run
description: Coordinate multi-agent coding work with git worktrees, branch-per-agent lanes, run manifests, integration branches, evidence reports, verifier gates, and safe cleanup. Use when a task will involve multiple implementation agents, parallel writable work, isolated experiments, branch/worktree versioning, or agent teams that must not trample the main checkout.
---

# Multi Agent Worktree Run

Use this skill to turn multi-agent coding into git-addressable lanes. The main checkout is the coordinator and integration area. Writable agents work only in their own branches and worktrees. Integration and verification happen after worker output is reported, reviewed, and accepted.

This skill is orchestrator-neutral. "The coordinator" is whichever agent the repo's `AGENTS.md` binds to that role (Codex, Claude Code, or another harness); the same file binds any independent review gate that must approve integrated diffs before commit.

## Fast Path

This skill is not the normal one-worker path. For one sequential OpenCode implementation worker, use `agent-run start` in the active checkout and stop here.

Use this worktree workflow only when there are concurrent writable workers, a risky disposable experiment, or a strict fixed-SHA reproduction requiring filesystem isolation. Then run only the fast preflight:

```bash
git status --short --untracked-files=no
git branch --show-current
git rev-parse HEAD
```

Do not create a worktree merely because the checkout is clean. Worktrees solve concurrent-write and experiment-isolation problems; they are not the default delegation mechanism.

If tracked files are dirty, do not create writable worktree lanes from that base unless the user explicitly wants that tradeoff.

Common local run receipts do not block worker lane creation:

- `docs/smartex-agent/runs/**`
- `.codex/**`

Tracked dirty files still block writable lane creation unless the user explicitly includes them.

## Rules

- Read the repo state before creating lanes.
- Route a single sequential implementation worker back to `agent-run start`; do not continue this workflow.
- Refuse to start from tracked dirty files in the main checkout unless the user explicitly wants those changes included.
- Use read-only exploration agents freely; create writable worktrees only for implementation lanes.
- Do not let two writable agents own the same files unless the coordinator serializes them.
- Default commit policy is coordinator-owned: workers edit, run gates, and report; the coordinator reviews, integrates, and commits from the main/integration checkout.
- If the user asked the coordinator to implement the work directly, the coordinator owns the final local commit after review and verification pass.
- For sequential `agent-run start` tasks, OpenCode must not commit; the coordinator reviews the active-checkout diff, verifies it, and commits locally.
- If the repo's `AGENTS.md` declares an independent review gate, its approval receipt is a blocking precondition for every integration commit; the coordinator never writes or edits the gate's receipts.
- Serialize resource-heavy gates across lanes (docker compose stacks, shared brokers/historians, fixed ports): only one lane runs them at a time unless ports and compose project names are explicitly namespaced per lane.
- Claude worktree workers must not commit by default. Use worker-owned commits only when the prompt explicitly says `commit_policy: worker` and explains why a dirty-worktree patch is insufficient. This avoids per-worktree hook/bootstrap drift, such as local hooks trying to install unrelated toolchains.
- Workers must never push.
- The coordinator integrates accepted worker output; workers do not merge themselves into the integration branch.
- Delete a worktree only when it is clean and its branch is integrated or explicitly abandoned.

## Run Layout

Use a short slug for the run id, preferably date plus purpose:

```text
run-id: 2026-06-17-auth-refactor
branches:
  agent/<run-id>/<lane>
  integrate/<run-id>
worktrees:
  .worktrees/agents/<run-id>/<lane>   # default; a repo may standardize an
                                      # external sibling dir instead, e.g.
                                      # ../<repo>-worktrees/<run-id>/<lane>,
                                      # to keep lanes out of repo watchers.
                                      # Record the choice in the manifest.
artifacts:
  .codex/runs/<run-id>/manifest.json
  .codex/runs/<run-id>/prompts/<lane>.md
  .codex/runs/<run-id>/reports/<lane>.md
  .codex/runs/<run-id>/integration/<lane>.patch
```

Lane names should be short and scoped: `api`, `ui`, `tests`, `docs`, `migration`, `verifier`.

## Sequential Task Mode

Sequential delegation is intentionally outside the lane workflow:

```bash
agent-run start <task> --objective "<bounded objective>" --own <path> --gate "<command>"
```

It packages the prompt, records versions and base state, launches one background OpenCode worker, preserves the exact session for continuation, and leaves review, verification, and commit ownership with the coordinator.

## Workflow

### 1. Establish Base

Run:

```bash
git status --short --untracked-files=no
git branch --show-current
git rev-parse HEAD
```

If tracked files are dirty, stop and choose direct coordinator implementation, a sequential `agent-run start` task with clean owned paths, commit/stash first, or explicitly opt into the dirty-base tradeoff. Record the base branch and base SHA.

### 2. Define Lanes

Create one lane per independent writable slice. Prefer fewer, sharper lanes over many vague workers.

Good lanes:
- `api`: route/service/model changes
- `ui`: component and interaction changes
- `tests`: regression or harness changes after implementation shape is known
- `docs`: docs only

Bad lanes:
- `fix everything`
- `look around and improve`
- two writers on the same module without serialization

### 3. Create Branches And Worktrees

For each writable lane:

```bash
git branch agent/<run-id>/<lane> <base-sha>
git worktree add .worktrees/agents/<run-id>/<lane> agent/<run-id>/<lane>
```

If a branch or worktree already exists, inspect it before reusing it. Do not overwrite it blindly.

### 4. Write The Manifest

Create `.codex/runs/<run-id>/manifest.json` with this shape:

```json
{
  "run_id": "2026-06-17-auth-refactor",
  "repo": "/abs/path/to/repo",
  "base_branch": "main",
  "base_sha": "abc123",
  "integration_branch": "integrate/2026-06-17-auth-refactor",
  "lanes": [
    {
      "name": "api",
      "agent": "build",
      "branch": "agent/2026-06-17-auth-refactor/api",
      "worktree": ".worktrees/agents/2026-06-17-auth-refactor/api",
      "prompt": ".codex/runs/2026-06-17-auth-refactor/prompts/api.md",
      "report": ".codex/runs/2026-06-17-auth-refactor/reports/api.md",
      "commit_policy": "coordinator",
      "status": "planned"
    }
  ]
}
```

Allowed statuses: `planned`, `running`, `done`, `failed`, `integrated`, `abandoned`.

### 5. Write Self-Contained Worker Prompts

Every worker prompt must stand alone. Include:

- Objective
- Base branch and base SHA
- Worktree path and branch
- Exact ownership boundaries
- Files or directories to prefer
- Files or directories to avoid
- Non-goals
- Verification command or acceptance gate
- Required final report path
- Commit policy: `coordinator` by default, `worker` only when explicitly useful
- Truth discipline and claims audit requirements

Prompt template:

```markdown
# Worker Lane: <lane>

Objective: <specific result>

Repo facts:
- Base branch: <base-branch>
- Base SHA: <base-sha>
- Your branch: agent/<run-id>/<lane>
- Your worktree: <absolute-worktree-path>
- Commit policy: coordinator

Scope:
- Own: <files/dirs/behavior>
- Avoid: <files/dirs/behavior>
- Non-goals: <explicit exclusions>

Implementation rules:
- Read before writing.
- Make the smallest correct change.
- Do not push.
- Do not edit outside this worktree.
- Commit policy is coordinator-owned: do not run `git commit`, `git push`, `git merge`, `git rebase`, `git stash`, or switch branches. Leave the worktree dirty for the coordinator to review/integrate. If you think a commit is necessary, stop and write that as a blocker in the report.
- Do not change Git hook configuration. Do not run hook bootstrap commands. Run the explicit verification gates below instead.
- Do not infer product readiness from artifact presence.
- A receipt proves only what its schema explicitly says.
- If evidence is ambiguous, classify it as partial, not ready.
- Prefer false negatives over false positives.

Verification:
- Run: <command>
- If blocked, record the exact command and error.

Final report:
- Write <report-path>.
- Include branch, commit status or commit SHA, files changed, checks run, risks, merge recommendation, claims made, claims intentionally not made, evidence for each claim, ambiguous evidence, and recommended reviewer checks.
```

### 6. Launch Workers

Launch each worker with its `cwd` set to its worktree when the agent system supports cwd. If it does not, include the absolute worktree path in the prompt and instruct the worker to `cd` there before doing any work.

Use OpenCode `build` for implementation lanes unless the user asks for a different worker or model. Do not use product-runtime/read-only agents as coding workers. Use `explore` only for read-only discovery. Use `verifier` only after integration.

When a lane's worker is deliberately Claude instead of OpenCode (per-lane choice, not the default), use the `al-jazari` custom subagent (`~/.claude/agents/al-jazari.md`, also invocable via `agent-run start --backend claude --agent al-jazari`) rather than an unnamed generic Claude worker, so Claude-backed lanes carry a consistent implementer persona and verification discipline.

### 7. Collect Reports

Do not integrate a lane until the report includes:

- Branch name
- Explicit `not committed; coordinator-owned commit policy`
- Changed files
- Verification command and output summary
- Risks or blocked checks
- Merge recommendation
- Claims audit

If a coordinator-owned lane changed files but did not commit, collect the dirty worktree plus report and let the coordinator review/integrate. Do not ask Claude worktree workers to commit merely to ease cherry-picking; build a reviewed patch from the dirty worktree instead.

Optionally run a read-only triage verifier in the finished lane worktree before integration: fresh gate re-run, owned/forbidden path audit, and a claims-vs-evidence check, written as `<report>-triage.md` beside the lane report. Triage pipelines the review; it does not replace integration verification or a declared review gate.

### 8. Integrate

Create the integration branch from the base SHA:

```bash
git switch -c integrate/<run-id> <base-sha>
```

Apply accepted worker work by building a reviewed patch from the dirty worktree and applying it to the integration checkout. Use cherry-pick or merge only for an explicitly worker-owned commit lane.

For coordinator-owned lanes, build a reviewed patch from the worker worktree, apply it to the integration worktree, run the lane gates, and let the coordinator create the integration commit.

If commit hooks hang during a coordinator-owned integration commit, the coordinator may commit with hooks disabled only after equivalent gates pass and the bypass is recorded in the run artifacts.

After each integration step, run the smallest relevant gate to catch conflicts early. Update the manifest lane status to `integrated` only after its commits are present on the integration branch.

### 9. Verify

Run a fresh verifier against `integrate/<run-id>`. The verifier must test the integrated behavior, not individual worker branches.

The verifier input must include:
- Original user goal
- Base SHA
- Integration branch
- Accepted worker commits or coordinator-owned integration patches
- Claimed behavior
- Commands already run

Completion requires `VERDICT: PASS`. Treat `FAIL` as requiring fixes. Treat `PARTIAL` as unresolved unless the user accepts the remaining risk.

### 10. Cleanup

For each lane, inspect before deletion:

```bash
git -C <worktree> status --porcelain
git -C <worktree> rev-list --count <base-sha>..HEAD
```

Remove the worktree only if it is clean and either integrated or abandoned:

```bash
git worktree remove <worktree>
git branch -D agent/<run-id>/<lane>
```

Keep dirty, failed, unmerged, or uncertain lanes. Report preserved paths to the user.

## Final Response Shape

When the run is complete, report:

- Run id
- Integration branch
- Worker lanes and final statuses
- Accepted commits
- Verification verdict
- Worktrees removed
- Worktrees preserved
- Remaining risks
