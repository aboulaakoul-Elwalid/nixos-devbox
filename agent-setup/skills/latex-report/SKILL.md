---
name: latex-report
description: Default workflow for academic reports, ENSA reports, papers, PDFs, bibliographies, and math-heavy documents using LaTeX.
---

# LaTeX Report Skill

Use this skill before writing polished PDF documents unless the user explicitly asks for Typst or the repo already has a committed Typst template that must be reused.

## When To Use

Use this skill for:

- academic reports
- ENSA reports and TP reports
- ArXiv-style papers
- PDFs with equations, figures, tables, screenshots, or bibliography
- migration from rough Markdown notes to a polished report
- any request that says `report`, `paper`, `PDF`, `LaTeX`, `bibliography`, or `main.tex`

Do not use this skill for rough research logs, gates, or replay receipts. Keep those in Markdown unless the user asks for a polished PDF.

## Default Decision

- Prefer LaTeX over Typst for serious reports and papers.
- Prefer `lualatex` for Unicode, French, Arabic, and modern font handling.
- Prefer `latexmk` as the build driver.
- Prefer `biblatex` plus `biber` when bibliography is needed.
- Use Typst only when explicitly requested or required by an existing committed template.

## Output Shape

For a small report, produce:

- `main.tex`
- `references.bib` only if citations are needed
- `build/main.pdf` after compilation

For a larger report, use:

- `main.tex`
- `preamble.tex`
- `frontpage.tex` when a formal cover page is needed
- `sections/*.tex` only when the document is large enough to justify splitting
- `figures/` or an existing screenshot directory for images
- `references.bib` only if citations are needed

Do not create template sprawl. Keep one-file `main.tex` reports when that is enough.

## Build Command

Use this as the default verification command:

```bash
latexmk -lualatex -interaction=nonstopmode -file-line-error -outdir=build main.tex
```

For documents using `minted`, add shell escape only when the document actually needs it:

```bash
latexmk -lualatex -shell-escape -interaction=nonstopmode -file-line-error -outdir=build main.tex
```

Clean generated intermediates only when the user asks. Do not delete source files, images, or PDFs.

## Minimal Preamble

Start simple and add packages only when needed:

```tex
\documentclass[12pt,a4paper]{article}

\usepackage[a4paper,margin=2.5cm]{geometry}
\usepackage{fontspec}
\usepackage{polyglossia}
\setmainlanguage{french}
\setotherlanguage{english}
\usepackage{microtype}
\usepackage{graphicx}
\usepackage{booktabs}
\usepackage{amsmath,amssymb}
\usepackage{xcolor}
\usepackage[hidelinks]{hyperref}

\setmainfont{Noto Serif}
\setsansfont{Noto Sans}
\setmonofont{Noto Sans Mono}
```

Add `minted`, `biblatex`, `float`, `caption`, `subcaption`, `longtable`, or Arabic language support only when the report needs them.

## Report Structure

Use a classical report structure unless the user gives another one:

- front page or title block
- abstract or objective
- environment and data sources
- method or execution steps
- results and observations
- limitations or failure modes
- conclusion
- bibliography or appendices when needed

For TP/session reports, each execution block should include:

- objective
- command or procedure
- observed result
- screenshot or log excerpt when available
- short interpretation

## Figure Rules

- Prefer relative paths.
- Do not invent figures, screenshots, commands, or results.
- If a screenshot is missing, state that it is missing and use the closest real evidence only if it is clearly related.
- Keep figures near the text that discusses them.

## Agent Rules

- Search the repo for existing `.tex`, `.cls`, `.sty`, `.bib`, `Makefile`, `.latexmkrc`, and template assets before writing a new template.
- Reuse project templates when present.
- Keep LaTeX code conventional; avoid clever macro systems unless the repo already uses them.
- Compile before reporting success.
- If compilation fails, fix the LaTeX error directly and rerun the build.
- Report the exact build command and PDF path at the end.
