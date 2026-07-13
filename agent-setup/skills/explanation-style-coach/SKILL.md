---
name: explanation-style-coach
description: Analyze a speaker, lecturer, founder, teacher, interviewer, or public figure's explanation style from video, audio, transcript, clips, or user-provided observations. Use when the user asks what makes someone's way of talking, teaching, body language, cadence, presence, Q&A behavior, or charisma interesting; wants to imitate a style for pitching, teaching, sales, relationships, or personal communication; provides a YouTube/video URL and asks for non-transcript analysis; or wants a readable blog-style note plus concrete practice drills.
---

# Explanation Style Coach

## Overview

Turn an observed speaker style into a usable model. Separate what is visible in
the artifact from what is inferred, extract the speaker's repeatable moves, and
translate them into practice for the user's context.

Prefer a high-signal explanation over a generic communication review. The goal
is not "be more charismatic"; it is to name the exact loop that makes the
speaker compelling.

## Evidence First

Begin by clarifying the evidence surface:

- transcript/captions only
- audio only
- screenshots/frame samples
- playable video clips
- user observations
- comparison across multiple talks

State the boundary in the final answer or file. Never turn a public performance
into unsupported claims about private personality, attachment style, morality,
or relationship behavior.

If the source is YouTube and the user wants body language or cadence, try to get
captions plus playable media. If available, use the local
`youtube-channel-research` skill for yt-dlp/browser fallback rules. If media
cannot be obtained, say so and downgrade visual/audio claims.

## Analysis Loop

Use this loop:

1. **Sample high-signal moments.** Pick opening, first explanation, hard visual
   section, conceptual pivot, and Q&A/live interaction. Avoid analyzing the full
   video frame by frame unless requested.
2. **Watch the object of attention.** Identify whether the speaker makes
   themselves, the slide, the audience, the question, or a concrete artifact the
   center.
3. **Extract the explanation move.** Look for the repeated chain: object ->
   attention -> interpretation -> abstraction -> decision/action.
4. **Read body language semantically.** Describe gestures by what relation they
   mark: holding a concept, separating alternatives, opening possibility,
   narrowing to a decision, receiving the room, re-centering after thought.
5. **Read cadence locally.** Do not summarize as simply fast/slow. Identify
   where the speaker pauses: before abstractions, during visual inspection,
   before hard answers, after jokes, or at emotional transitions.
6. **Analyze Q&A separately.** Q&A often reveals the real style: reactive vs
   reflective, defensive vs reframing, answer-first vs diagnosis-first.
7. **Separate copyable method from personal aura.** Name what the user can
   practice without trying to become the speaker.

## Speaker Pattern Vocabulary

Use precise phrases when they fit:

- **precision warmth**: cognitively sharp while emotionally unthreatening
- **secure shared attention**: inviting people to look at reality together
- **object-first explanation**: beginning from a visible artifact before naming
  the abstraction
- **inspection time**: pausing so the audience can actually look
- **productive pivot**: "this works, but it is not the whole story"
- **semantic gesture**: movement that maps to structure rather than decoration
- **live reframing**: reshaping a question before answering it
- **low-noise presence**: holding attention without performative excess

Use these as hypotheses, not labels to force onto every speaker.

## Output Shapes

Choose the shape that matches the user's request:

**Short answer:** name the core pattern, give 3-5 evidence moments, and provide
one practice drill.

**Blog note:** write a readable essay with short sections, minimal bullets, and
a strong through-line. Use this when the user says the note is too long, wants
something readable, or asks for a personal reflection.

**Practice protocol:** produce timed clips, exact behaviors to imitate, and a
record/watch-back drill.

**Personal taste read:** when the user is drawn to the speaker as a human
quality, discuss the visible qualities carefully. Include an explicit boundary:
public behavior can reveal taste signals but not prove private character.

## Blog Note Template

For a readable note, use this structure:

```markdown
---
type: explanation_style_note
date: YYYY-MM-DD
source: "..."
confidence: ...
evidence_boundary: "..."
---

# The [Speaker] Thing

Opening thesis in plain language.

## What Makes It Work

Describe the central pattern, not a list of tips.

## How The Body Supports The Thought

Describe posture, gesture, gaze, and movement only at the confidence level the
artifact supports.

## How The Voice/Cadence Works

Explain local pacing and pauses.

## What Happens In Q&A Or Live Interaction

Name how the speaker receives pressure, confusion, praise, or disagreement.

## What To Copy

Translate into the user's domain.

## What Not To Copy

Prevent cargo-cult imitation.

## Practice

Give a small drill the user can actually perform.
```

## Translation Rules

When translating into the user's context:

- For pitching: turn the style into artifact-led explanation, objection
  reframing, and slide/visual inspection behavior.
- For teaching: turn it into attention cues, concept staging, and pause
  placement.
- For sales: turn it into shared problem framing, evidence inspection, and
  decision language.
- For personal/relationship taste: translate only visible behavior into desired
  interaction qualities, with clear uncertainty boundaries.

End with the smallest practice that would make the style real in the user's
body, not only in their notes.
