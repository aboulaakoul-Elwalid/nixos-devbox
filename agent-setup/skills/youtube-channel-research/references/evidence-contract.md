# Evidence Contract

## Artifact Layers

1. `sources/<channel>/<video>/`: source metadata, captions, transcript, and per-video analysis.
2. `context.md`: user-supplied knowledge and research questions.
3. `reports/<channel>.md`: channel synthesis derived from per-video analyses.
4. `reports/cross-analysis.md`: comparison of channel findings with `context.md`.
5. `state/`: archives, receipts, logs, and analysis status.

## Per-Video Analysis

Require these sections:

- Scope and source
- Executive summary
- Claims and evidence
- Entities, dates, and relationships
- Reasoning and rhetoric
- Agreement or conflict with supplied context
- Uncertainties and transcription risks
- Follow-up questions

Each material claim must include a timestamp URL in this form:

```text
https://www.youtube.com/watch?v=VIDEO_ID&t=SECONDSs
```

Use the following labels:

- `Transcript evidence`: directly supported by the caption text.
- `Context evidence`: directly supported by `context.md`.
- `Inference`: reasoned interpretation, not directly stated.
- `Unknown`: insufficient evidence.

## Synthesis

Promote a claim into channel synthesis only when its source analysis retains a video ID and timestamp. Note repetition across videos without treating repetition as independent confirmation.

Separate:

- recurring positions
- changes over time
- internal contradictions
- factual claims requiring external verification
- rhetorical framing
- gaps caused by absent or unreliable transcripts

## Coverage Receipt

Record at least:

- discovered metadata records
- videos with normalized transcripts
- videos without transcripts
- completed and failed analyses
- model identifier
- run timestamp

