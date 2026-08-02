---
name: "typst"
description: "Typst is a first-class choice for modern engineering/technical reports; also for ENSA reports, papers, and math-heavy PDFs when Typst is requested or a committed .typ template exists."
---

## What I Do

I produce polished Typst documents. Typst is fully capable of premium,
engineering-grade output (see the Argyris report system: IBM Plex + booktabs +
doc-control masthead); the "webpage feel" people complain about comes from font
and styling choices, not the tool. Use `latex-report` only for traditional
academic/journal formatting where a LaTeX class is mandated; otherwise Typst is
the default for modern technical reports (faster, byte-reproducible, native
`json()` data loading, no escaping).

**Capabilities:**
- Generate complete `.typ` documents from rough notes when Typst is requested
- Reuse existing Typst templates
- Convert existing Typst documents when the source format must remain Typst
- Embed Mermaid diagrams as SVG
- Orchestrate subagents for complex documents:
  - `multimodal-looker` for analyzing images, PDFs, diagrams
  - `document-writer` for structuring long content
  - `general` for finding existing templates in your vault or repo

## When to Use Me

Invoke this skill when:
- The user explicitly asks for Typst
- The repo already has a committed `.typ` template that must be reused
- Maintaining or compiling an existing `.typ` file
- Converting an existing document to Typst by explicit request

Prefer this skill for modern engineering/technical reports, evidence packs, and data-forward PDFs. Reach for `latex-report` only when a LaTeX class/journal template is explicitly required. For premium engineering output, bundle a real typeface (IBM Plex Sans + Mono via `--font-path`) and use booktabs tables + tabular numerals + a doc-control masthead — see the distilled reference at the end of this file.

---

## Document Types

### 1. ENSA Report (Your Standard)

Structure from your actual reports:

```typst
// ============================
// PAGE DE GARDE (FRONTPAGE)
// ============================

#set page(margin: 2cm)

// Frontpage with 3-column header (logo - center text - logo)
#page()[
  #grid(
    columns: (1fr, 2fr, 1fr),
    gutter: 1cm,
    [
      #align(center)[
        #v(0.1cm)
        #image("media/logo_ensab.png", width: 3.5cm)
      ]
    ],
    [
      #align(center)[
        #text(13pt)[*UNIVERSITE HASSAN 1er – SETTAT*]
        #linebreak()
        #text(10pt)[École Nationale Des Sciences Appliquées Berrechid]
        #linebreak()
        #text(9pt)[Département de mathématique et informatique]
      ]
    ],
    [
      #align(center)[
        #v(0.1cm)
        #image("media/uh1.png", height: 1.25cm)
      ]
    ]
  )
  #v(1.2cm)

  // Type box (Stage, TP, Projet, etc.)
  #align(center)[
    #rect(
      radius: 6pt,
      inset: 1.2em,
      stroke: 1.5pt + gray,
      width: 100%
    )[
      #text(22pt, weight: "bold")[*Stage d'Observation*]
      #linebreak()
      #text(16pt)[Filière : Ingénierie des Systèmes d'Information et Big Data]
    ]

    #v(1cm)

    // Main title box
    #rect(
      stroke: 3pt + black,
      radius: 6pt,
      inset: 0.8cm,
      fill: white,
      width: 100%
    )[
      #align(center)[
        #text(18pt, weight: "bold")[*Main Title Here*]
        #linebreak()
        #text(13pt, style: "italic", fill: gray.darken(30%))[_Subtitle or description_]
        #linebreak()
        #text(14pt)[Additional info line]
      ]
    ]
  ]

  #v(1.5cm)

  // Company/Organization logo (if applicable)
  #align(center)[
    #text(14pt, weight: "bold")[Réalisé à :]
    #linebreak()
    #image("media/company_logo.svg", width: 7cm)
  ]

  #v(1.6cm)

  // Author and Supervisor grid
  #align(center)[
    #rect(
      width: 85%,
      inset: 1cm,
      radius: 10pt,
      stroke: 0.7pt + gray.lighten(80%),
      fill: white
    )[
      #grid(
        columns: (1fr, 1fr),
        gutter: 2cm,
        [
          #align(center)[
            #text(14pt, weight: "bold")[Mr. AUTHOR NAME]
            #v(0.25cm)
            #text(11pt, style: "italic", fill: gray.darken(25%))[Auteur]
          ]
        ],
        [
          #align(center)[
            #text(13pt, weight: "bold")[Encadrement]
            #v(0.3cm)
            #text(12pt)[Pr. NAME · Encadrant académique]
            #linebreak()
            #text(12pt)[Mr. NAME · Encadrant professionnel]
          ]
        ]
      )

      #line(length: 60%, stroke: 1pt + gray.lighten(60%))

      #align(center)[
        #text(11pt)[Membres du jury : Pr. NAME, Pr. NAME]
      ]
    ]
  ]

  #line(length: 100%, stroke: 2.5pt + black)

  // Footer
  #align(center)[
    #text(12pt)[Période : du XX/XX/XXXX au XX/XX/XXXX]
    #linebreak()
    #text(12pt)[Année Universitaire : 2024/2025]
  ]
]

// ============================
// DOCUMENT BODY
// ============================

#set par(justify: true)
#set text(13pt)

// Chapter title pattern
#pagebreak()
#align(center)[
  #text(24pt, weight: "bold")[*Chapitre 1 : Title*]
]
#v(1.5cm)

== 1. Introduction
Content here...

== 2. Section Title
Content here...
```

**Key patterns from your style:**
- 3-column grid for institutional header (logo - text - logo)
- Rounded rect boxes (`radius: 6pt`) for title sections
- Gray color palette: `gray.lighten(80%)`, `gray.darken(30%)`
- Justified paragraphs, 13pt text
- Figures with centered captions
- RTL support for Arabic abstracts: `#set text(dir: rtl)`

### 2. ArXiv Paper Style

```typst
#let arxiv-paper(
  title: none,
  authors: (),
  abstract: none,
  doc
) = {
  set page(
    paper: "us-letter",
    margin: auto,
    header: align(right + horizon, title),
    numbering: "1",
    columns: 2,
  )
  set text(font: "Libertinus Serif", size: 11pt)
  set par(justify: true)
  
  // Style headings
  show heading.where(level: 1): it => [
    #set align(center)
    #set text(13pt, weight: "regular")
    #block(smallcaps(it.body))
  ]
  
  show heading.where(level: 2): it => text(
    size: 11pt,
    weight: "regular",
    style: "italic",
    it.body + [.],
  )
  
  // Title spans both columns
  place(
    top + center,
    float: true,
    scope: "parent",
    clearance: 2em,
  )[
    #text(17pt, weight: "bold", title)
    
    #grid(
      columns: authors.len(),
      ..authors.map(author => align(center, author))
    )
    
    #if abstract != none [
      #set par(justify: false)
      *Abstract* \
      #abstract
    ]
  ]
  
  doc
}

// Usage
#show: doc => arxiv-paper(
  title: "Paper Title",
  authors: (
    [Author 1 \ Institution \ email],
    [Author 2 \ Institution \ email],
  ),
  abstract: [Abstract text here...],
  doc
)

= Introduction
Content...

= Related Work
Content...
```

### 3. Quick TP/Assignment

```typst
#set page(margin: 2cm)
#set text(font: "Times New Roman", size: 11pt)
#set par(justify: true)
#set heading(numbering: "1.1")

#align(center)[
  #text(16pt, weight: "bold")[TP N°X: Title]
  #v(0.5em)
  Module: Name | Date: YYYY-MM-DD
  #v(0.5em)
  *Your Name*
]

#line(length: 100%)

= Objective
...

= Implementation
...

= Results
...

= Conclusion
...
```

---

## Core Typst Syntax

### CRITICAL: Content Blocks vs Strings

```typst
// Content block [..] - can contain *markup*
#text(size: 12pt)[This *will* be bold]

// String ".." - literal text only  
#image("path/to/file.jpg")

// WRONG - common mistakes
#text(size: 12pt, "This *won't* be bold")  // ❌
#image([photo.jpg])                         // ❌
```

### Essential Set Rules

```typst
#set page(paper: "a4", margin: 2cm, numbering: "1")
#set text(font: "Times New Roman", size: 11pt)
#set par(justify: true, first-line-indent: 1.5em)
#set heading(numbering: "1.1")
#set document(title: "Title", author: "Author")
```

### Show Rules for Custom Styling

```typst
// Center all level-1 headings
#show heading.where(level: 1): it => [
  #set align(center)
  #set text(size: 16pt, weight: "bold")
  #it.body
]

// Make "TODO" red
#show "TODO": text(fill: red)[TODO]

// Style all headings
#show heading: it => block(
  above: 1.5em,
  below: 1em,
  it
)
```

### Figures and Tables

```typst
// Figure with caption and label
#figure(
  image("diagram.png", width: 80%),
  caption: [Description here]
) <fig-diagram>

See @fig-diagram for details.

// Table with alternating row colors
#table(
  columns: (2fr, 4fr),
  inset: 9pt,
  stroke: 1pt + black,
  fill: (x, y) => if y == 0 { gray.lighten(80%) } 
                  else if calc.rem(y, 2) == 1 { gray.lighten(95%) }
                  else { white },
  [*Header 1*], [*Header 2*],
  [Row 1], [Data 1],
  [Row 2], [Data 2],
)
```

### Grid Layouts

```typst
// Two-column layout
#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [Left column content],
  [Right column content]
)

// Figure with icon on the side
#grid(
  columns: (9fr, 1fr),
  gutter: 0.5cm,
  [
    #figure(
      image("screenshot.png", width: 100%),
      caption: [Description]
    )
  ],
  [
    #align(center + horizon)[
      #image("icon.svg", width: 80%)
    ]
  ]
)
```

### Spacing and Breaks

```typst
#v(1cm)           // Vertical space
#h(1em)           // Horizontal space
#pagebreak()      // Page break
#linebreak()      // Line break (or just \)
```

---

## Mermaid Diagram Integration

When the document needs diagrams, use this decision matrix:

| Intent | Best Diagram Type |
|--------|-------------------|
| Cloud/system architecture | `architecture-beta` |
| Project tasks/workflow | `kanban` |
| Data comparison (multi-metric) | `radar-beta` |
| Trends over time | `xychart` |
| Database schema | `erDiagram` |
| Process/logic flow | `flowchart` |
| Sequence of interactions | `sequenceDiagram` |
| Hierarchy/brainstorm | `mindmap` |
| Timeline/milestones | `timeline` |
| Class structure | `classDiagram` |

**Embedding in Typst:**
1. Generate Mermaid diagram
2. Export as SVG: `mmdc -i diagram.mmd -o diagram.svg`
3. Include: `#image("diagram.svg", width: 80%)`

**Example architecture diagram:**
```mermaid
architecture-beta
    title "MLOps Pipeline on GCP"
    
    group gcp(cloud)[GCP Project]
        service gcs(s3)[Cloud Storage] in gcp
        service run(server)[Cloud Run Jobs] in gcp
        service bq(database)[BigQuery] in gcp
    end
    
    gcs:R --> L:run
    run:R --> L:bq
```

---

## Subagent Orchestration

For complex documents, I orchestrate specialized agents:

| Situation | Subagent | Purpose |
|-----------|----------|---------|
| Document has images/PDFs to analyze | `multimodal-looker` | Extract info, describe visuals |
| Long unstructured content | `document-writer` | Structure into sections |
| Need existing template | `general` | Find in vault/repo |

**Orchestration flow:**
1. Analyze content type
2. Determine template (ENSA report, ArXiv, TP)
3. Spawn subagents if needed
4. Generate .typ file
5. Verify with `typst compile`

---

## Common Mistakes & Fixes

### Error: Content block for file path
```typst
// WRONG
#image([photo.jpg])

// RIGHT
#image("photo.jpg")
```

### Error: String for markup content
```typst
// WRONG
#text(size: 12pt, "This *won't* be bold")

// RIGHT
#text(size: 12pt)[This *will* be bold]
```

### Error: Show rule syntax
```typst
// WRONG
#show heading: [*heading*]

// RIGHT
#show heading: it => [*#it.body*]
```

### Error: Missing # in code context
```typst
// WRONG
let my-func() = [
  text(size: 12pt)[Hello]
]

// RIGHT
let my-func() = [
  #text(size: 12pt)[Hello]
]
```

### Error: Wrong line function parameter
```typst
// WRONG
#line(width: 100%)

// RIGHT
#line(length: 100%)
```

---

## File Organization

Standard project structure:
```
project/
├── main.typ           # Main document
├── frontpage.typ      # Frontpage (if separate)
├── media/             # Images, logos, diagrams
│   ├── logo_ensab.png
│   ├── uh1.png
│   └── diagrams/
└── chapters/          # For long documents
    ├── chapter1.typ
    └── chapter2.typ
```

Include chapters: `#include "chapters/chapter1.typ"`

---

## Compilation

```bash
# Compile to PDF
typst compile document.typ

# Watch mode (auto-recompile on save)
typst watch document.typ

# Specify output path
typst compile document.typ output.pdf

# With custom fonts directory
typst compile --font-path ./fonts document.typ
```

---

## Distilled reference (2026, from typst.app/docs — Typst 0.14)

The highest-value patterns and the corrections that catch most agent errors.

### Premium engineering-report setup

```typst
#set page(paper: "a4", margin: (top: 2.6cm, bottom: 2cm, x: 2.2cm),
  numbering: "1 / 1",
  header: context {
    if here().page() == 1 { return }              // masthead only on page 1
    set text(9pt, fill: gray)
    grid(columns: (1fr, auto), [Report title], align(right)[REV 3])
    line(length: 100%, stroke: 0.4pt + gray)
  })
#set text(font: ("IBM Plex Sans", "Noto Sans"), size: 10pt, number-width: "tabular")
#set par(justify: true, leading: 0.62em)
#set heading(numbering: "1.")
```

Data values in a mono face align in columns: `#show table.cell: set text(font:
"IBM Plex Mono", number-width: "tabular")`. Small caps is the element
`#smallcaps[...]`, never a `text()` parameter.

### Booktabs table (no grids, no fills — the academic/engineering look)

```typst
#table(columns: (auto, 1fr, auto), stroke: none, inset: (x: 8pt, y: 5pt),
  align: (left, left, right),
  table.header([*ID*], [*Description*], [*Value*]),
  table.hline(stroke: 0.7pt),
  [S-01], [Feedwater flow], [12.4],
  table.hline(stroke: 0.4pt + gray),
  [S-02], [Drum pressure], [8.1],
  table.hline(stroke: 0.7pt))
```

### Data loading + fail-closed (evidence into the document)

```typst
#let ev = json("evidence.json")
#ev.readings.at(0).at("unit", default: "-")   // safe access — never panics
#let f = ev.at("emission_factor", default: none)
#if f == none { panic("missing emission_factor — refuse to render") }
```

`context` is required to read page numbers / counters / style state at layout
time: `#context counter(heading).get()`.

### Corrections that catch most mistakes

| Mistake | Fix |
|---|---|
| `image([f.png])` | `image("f.png")` — path is a string |
| `numbering: [1.]` | `numbering: "1."` — a `str` pattern |
| `#show heading: [*x*]` | `#show heading: it => [*#it.body*]` or a set rule |
| `line(width: 2pt)` | `line(length: 4cm, stroke: 2pt)` — no `width:` |
| `#1 + 2` in markup | `#(1 + 2)` |
| `#set text(smallcaps: true)` | `#smallcaps[...]` |
| `dict.key` (maybe absent) | `dict.at("key", default: none)` |
| custom font silently wrong | pass `--font-path <dir>` |
| numeric columns misaligned | `#set text(number-width: "tabular")` |
| counter/page read in plain code | wrap in `#context ...` |
