---
name: "obsidian"
description: "Search, read, create, update, organize, or summarize notes in Elwalid's local Obsidian vault using obsidian-cli or direct Markdown edits."
---

# Obsidian

Use the local Obsidian vault as Walid's durable knowledge base.

Default vault:

- Name: `vault_elwalid`
- Path: `/home/elwalid/Documents/vault_elwalid`
- CLI: `/home/elwalid/go/bin/obsidian-cli`

## Workflow

1. Discover before editing.
   - Use `obsidian-cli search-content --vault vault_elwalid "<query>"` to find relevant notes by content.
   - Use `obsidian-cli list --vault vault_elwalid [path]` to inspect folders.
   - Use `rg` directly in `/home/elwalid/Documents/vault_elwalid` for precise or multi-term searches.

2. Read notes before modifying them.
   - Use `obsidian-cli print --vault vault_elwalid "<note>"`.
   - If the CLI cannot resolve the note name, read the Markdown file directly from the vault path.

3. Prefer Markdown-compatible edits.
   - Keep YAML frontmatter valid.
   - Preserve existing headings, links, tags, callouts, and embedded assets.
   - Use wiki links like `[[Note Name]]` only when that convention already appears nearby.
   - Do not rewrite large notes just to add a small section.

4. Protect private knowledge.
   - Do not quote or summarize unrelated personal notes unless the user asked for them.
   - Do not inspect secrets, credentials, private keys, or sensitive exports unless explicitly requested.
   - When using vault content in reports or code comments, include only task-relevant excerpts.

## Common Commands

List the vault or a folder:

```bash
obsidian-cli list --vault vault_elwalid
obsidian-cli list --vault vault_elwalid "Projects"
```

Search note content:

```bash
obsidian-cli search-content --vault vault_elwalid "search terms"
rg -n "search terms" /home/elwalid/Documents/vault_elwalid
```

Print a note:

```bash
obsidian-cli print --vault vault_elwalid "note name"
```

Create or append a note:

```bash
obsidian-cli create --vault vault_elwalid --content "text" "Folder/Note name"
obsidian-cli create --vault vault_elwalid --append --content "text" "Folder/Note name"
```

Inspect or update frontmatter:

```bash
obsidian-cli frontmatter --vault vault_elwalid "note name" --print
obsidian-cli frontmatter --vault vault_elwalid "note name" --edit --key status --value done
```

Move or rename a note while updating links:

```bash
obsidian-cli move --vault vault_elwalid "Old note" "Folder/New note"
```

## Direct File Access

Use direct filesystem access when it is clearer than the CLI:

- Find files: `rg --files /home/elwalid/Documents/vault_elwalid | rg '<term>'`
- Read files: `sed -n '1,220p' "/home/elwalid/Documents/vault_elwalid/path/note.md"`
- Edit files: use `apply_patch`, not shell redirection, for manual changes.

Use direct edits for structured refactors, multi-section updates, or when preserving exact formatting matters.

## Note Placement

Choose conservative locations:

- Project/session notes: `Projects/`
- Technical references: `Tech/`
- Research/literature notes: `Research/`
- Course/report material: `Academic/`
- Daily capture: `daily/`
- Unsure: search for an existing related note first; otherwise ask if placement materially changes the result.

## Verification

After edits:

- Re-read the changed note.
- Run `rg -n "<new heading or unique phrase>" /home/elwalid/Documents/vault_elwalid` for direct edits.
- If frontmatter was changed, run `obsidian-cli frontmatter --vault vault_elwalid "<note>" --print`.
