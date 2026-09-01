---
name: tatirous-content-workflow
description: Assemble and revise Tatiana's organic A-roll videos as one editable HyperFrames project, including ordered clips, local Parakeet transcription, non-destructive silence cuts, captions, subtle text, transitions, music, and alternating chat/Studio edits. Use for Tatirou creator-content production or revisions; use a simpler media skill for an isolated trim or caption rewrite.
---

# Tatirou's Content Workflow

## Purpose

Turn Tatiana's own footage into an organic, editable social video. Her clips,
voice, ordering instructions, and saved Studio edits are the editorial truth.
Keep generated HTML scenes, avatars, synthetic B-roll, filler removal, and heavy
motion graphics off unless she explicitly asks for them.

The deliverable is one saved HyperFrames project that supports two alternating
control surfaces:

- chat edits the project files and timeline;
- HyperFrames Studio lets Tatiana inspect and edit the same saved project.

This is sequential collaboration, not simultaneous multi-writer editing. Chat
must reread the current saved files before every mutation and preserve manual
changes it does not own.

## Load the owning domains

Load `/hyperframes` first, then use `/general-video` for the existing-footage
edit. Load these domains only when their need is active:

- `/hyperframes-core`: source windows, clip placement, track timing and media.
- `/media-use`: Parakeet transcription, silence planning, captions and BGM.
- `/hyperframes-animation`: transitions between scenes.
- `/hyperframes-audio`: BGM placement, ducking, fades and loudness work.
- `/hyperframes-cli`: checks, Studio context, preview and render.
- `/hyperframes-keyframes`: only when Tatiana asks for a punch-in, reframe or
  other camera motion.

Use `charlies-content-workflow` only when a piece contains material factual
claims that need source/evidence governance. Ordinary personal storytelling
does not need a claim ledger.

## Route from saved project state

Apply the first matching route:

1. **Studio selection request** — for “this clip/text/element,” query Studio
   selection context before editing. Never infer the target from conversation.
2. **Specific edit to an existing project** — reread the saved composition,
   brief, assets and current timing; patch only the requested surface and rerun
   invalidated checks. Do not restart intake.
3. **Existing project without a specific edit** — summarize the current order,
   duration, unresolved media and last verified state, then continue from it.
4. **Fresh project** — enter `/hyperframes`, route to `general-video`, and use
   companion flow with the user's current instructions. Default to no storyboard
   because Tatiana reviews the assembled timeline directly in Studio.

For a fresh or structural edit, read
[editing-workflow.md](references/editing-workflow.md). For machine readiness or
paste-ready prompts, read [setup-and-usage.md](references/setup-and-usage.md).

## Organic default profile

- Preserve original recordings and use source windows for cuts.
- Respect the exact clip order Tatiana gives. If she gives none, preserve the
  supplied order and state that assumption.
- Use natural speech as the edit clock. Tighten dead air, not human cadence.
- Caption all speech in its spoken language with no more than two readable
  lines; keep captions clear of her face.
- Use at most one subtle side callout at a time when it adds real meaning.
- Prefer hard cuts within one thought and restrained transitions between
  genuinely different scenes.
- Keep dialogue dominant. Add BGM only from an asset with recorded provider and
  license/provenance; duck it under speech.
- Do not download arbitrary “copyright-free” music from the web.

Defaults are starting points, not a redesign mandate. Preserve an established
Tatirou project style and record only preferences Tatiana explicitly approves.

## Dual-control contract

Before a chat edit:

1. Read the current on-disk project and preserve stable IDs and unknown changes.
2. If the instruction refers to a selected Studio element, run:

   ```bash
   npx hyperframes preview --context --json --context-fields selection
   ```

3. Use `selection.target.hfId` when available; otherwise use the returned
   selector and source file. If there is no selection, ask only for the element
   to be selected.
4. Patch narrowly. Never regenerate the composition from an older storyboard,
   transcript, or chat summary.
5. Rerun the checks affected by the edit and refresh the same Studio project.

Chat can preserve only saved Studio state. If Tatiana has an unsaved manual
change, have her save it before writing files.

## Gates

- No speech detected means no invented transcript or captions.
- Automatic filler-word removal is off; enable it only per explicit request.
- A missing or unreadable clip blocks only that exact placement and must be
  named; never silently omit it.
- Run `npx hyperframes check` before the final Studio preview.
- Render only after final preview approval.
- Verify the rendered master, not only the preview.
- Editing and rendering never authorize upload, scheduling or publishing.

## Completion

Report the saved project path, actual timeline duration, clip order, silence
threshold used, caption language, music provenance or deliberate silence,
Studio preview state, verification results, rendered master when requested, and
any remaining dependency or publication boundary.
