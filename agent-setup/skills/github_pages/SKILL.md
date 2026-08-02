---
name: "github-pages"
description: "Publish plain static HTML/CSS/JS sites to GitHub Pages, especially github.io pages or simple profile and landing sites."
---

# GitHub Pages Static Deploy Skill

## Purpose

Deploy plain static sites to GitHub Pages with the least moving parts.

Default to branch publishing from `main` and the repo root `/`.
This is GitHub's recommended path when there is no custom build process.

## Choose The Site Type

- User or org site: repo name must be exactly `<owner>.github.io`
- User or org site URL: `https://<owner>.github.io/`
- Project site: repo name can be anything
- Project site URL: `https://<owner>.github.io/<repo>/`

## Default Lane

- Prefer `Deploy from a branch` for plain static files.
- Prefer source branch `main` and source path `/`.
- Use `/docs` only when the repo already keeps the publishable site there.
- Use a GitHub Actions Pages workflow only if there is a real build step, symlinks are involved, or branch publishing cannot fit the repo layout.

## Preflight

- Check the active account with `gh auth status`.
- If the target owner is different, switch with `gh auth switch -u <username>` when that account already exists locally.
- If the needed account is not authenticated yet, stop and ask the user to authenticate that account.
- Verify `index.html` exists at the publish root.
- If the site contains paths starting with `_`, add `.nojekyll` before publishing so Pages does not treat the site as Jekyll input.

## Important Gotcha

- For project sites, avoid root-relative asset links like `/style.css` or `/app.js` unless the site is intentionally built for the repo subpath.
- Prefer relative paths like `./style.css`, `assets/app.js`, and `images/logo.png` so the site works under `https://<owner>.github.io/<repo>/`.

## Repo Setup

- If the directory is not already a git repo, initialize git.
- Ensure the default branch is `main`.
- If the GitHub repo does not exist, create it with `gh repo create <owner>/<repo> --public --source=. --remote=origin`.
- If a remote already exists, do not replace it unless the user explicitly asks.

## Preferred Deploy Procedure

1. Confirm whether this is a user/org site or a project site.
2. Confirm the target GitHub owner, especially if multiple accounts are available.
3. Push the site files to `main` when the user explicitly asked to deploy or publish.
4. Configure GitHub Pages to publish from `main` and `/`.
5. Verify the Pages URL and latest build status.

## Pages API Commands

Create a Pages site:

```bash
gh api -X POST repos/<owner>/<repo>/pages \
  -F build_type=legacy \
  -F "source[branch]=main" \
  -F "source[path]=/"
```

Update an existing Pages site:

```bash
gh api -X PUT repos/<owner>/<repo>/pages \
  -F build_type=legacy \
  -F "source[branch]=main" \
  -F "source[path]=/"
```

Read the deployed URL and current Pages config:

```bash
gh api repos/<owner>/<repo>/pages
```

Read the latest build status:

```bash
gh api repos/<owner>/<repo>/pages/builds/latest
```

Trigger a rebuild without changing files:

```bash
gh api -X POST repos/<owner>/<repo>/pages/builds
```

## Decision Rules

- If there is no build step, do not invent a workflow file.
- If the site is already static HTML, CSS, JS, prefer branch deploy over GitHub Actions.
- If Pages already exists, update it instead of recreating the repo.
- If the repo is `<owner>.github.io`, treat it as a user or org site unless the user says otherwise.
- If the repo is a project site, keep links and asset paths repo-safe.

## When To Fall Back To Actions

- The repo needs a build step to generate the publishable output.
- The site uses symbolic links.
- The publishable output must come from somewhere other than `/` or `/docs`.
- The user explicitly asks for a Pages workflow.

## Output Rules

- Prefer the smallest working deploy path.
- Use `gh` for repo creation, Pages configuration, and verification.
- Report the final public URL.
- If deployment fails, surface the exact Pages build error before proposing changes.
