# Editable organic production workflow

Read this reference for a fresh Tatirou project or any edit that changes clip
order, silence cuts, captions, transitions, music, or final timing.

## 1. Intake without flattening

Preserve every original. Probe each supplied clip and record at least its path,
duration, dimensions, frame rate, audio presence and supplied order. Keep the
user's explicit order authoritative. When no order is stated, retain the order
in which the files were supplied and say so.

For a fresh project, route through `/hyperframes` into `general-video`. Use
companion flow because Tatiana wants a live Studio editing surface; default to
`storyboard: no` because the assembled timeline is the review surface. Scaffold
and keep the project pinned according to `/general-video` and
`/hyperframes-cli`; do not invent a second project format.

Adopt source media through `/media-use` so originals and derived assets retain
provenance. Do not overwrite or destructively trim a source file.

## 2. Transcribe locally with Parakeet

Use the installed media skill so it can find the documented venv even when the
binary is not on the general shell `PATH`:

```bash
node <MEDIA_SKILL_DIR>/scripts/transcribe.mjs \
  --input <source-clip> \
  --out <source-clip>.transcribe.json \
  --engine auto
```

On Tatiana's Apple Silicon Mac, `auto` must resolve to Parakeet from
`~/.venvs/parakeet/bin/parakeet-mlx`. The expected model is
`mlx-community/parakeet-tdt-0.6b-v3`. This path is local and does not require an
OpenAI API key. If Parakeet fails, report the failure; use HyperFrames'
whisper.cpp fallback only when it is installed and suitable for the language.

Keep the detected/spoken language. Never use an English-only transcription
model for Spanish speech. Empty or unusable speech output produces no captions
and no silence-cut claim.

## 3. Compile an editable silence plan

Use the existing compiler in plan mode:

```bash
node <MEDIA_SKILL_DIR>/scripts/transcript-cut.mjs \
  --transcript <source-clip>.transcribe.json \
  --cut-silence 0.8 \
  --plan
```

The default removes only the center of inter-word gaps longer than `0.8`
seconds. The compiler preserves `0.15` seconds beside speech on both sides.
Tatiana may ask for a different threshold. Do not remove filler words unless
she explicitly requests that semantic edit.

Do not encode the plan into one flattened replacement video by default. For
every kept source segment, create one stable HyperFrames clip segment:

```text
sourceStart     = kept.start
sourceDuration  = kept.end - kept.start
timelineStart   = authored start after prior kept segments and transitions

data-media-start = sourceStart
data-duration    = sourceDuration
data-start       = timelineStart
```

Use deterministic IDs such as `<source-slug>-segment-001`. Preserve those IDs
through later revisions so Studio changes and chat instructions continue to
target the same elements. Embedded source audio follows the same media window.
If picture and audio are authored separately, give their corresponding clips
identical source and timeline ranges.

## 4. Remap captions to the edited timeline

Reuse the source transcript instead of transcribing the edit again. For each
word contained by a kept segment:

```text
timelineWordStart = clip.data-start + (word.start - kept.start)
timelineWordEnd   = clip.data-start + (word.end   - kept.start)
```

When a transition changes authored placement, calculate caption time from the
clip's final `data-start`, not a stale cumulative estimate. Exclude words in
removed ranges. Preserve the spoken wording; punctuation and capitalization may
be cleaned without rewriting what Tatiana said.

Group captions on sentence boundaries, meaningful pauses, and readable word
counts. Use at most two lines. Inspect representative real frames and move the
caption block when it covers her eyes, mouth, hands, or the active side callout.

## 5. Assemble the organic edit

Use the user's scene order first, then build the smallest treatment that makes
it feel intentional:

- Within one continuous idea, prefer a clean hard cut. A subtle punch-in is
  optional only when it helps hide a jump cut and must use
  `/hyperframes-keyframes`.
- Between different scenes, use one restrained transition family. Load
  `/hyperframes-animation`, search the registry/catalog before hand-authoring,
  and keep the transition shorter than the idea it separates.
- Side text is brief, secondary to captions, and shown one item at a time. It
  may emphasize a name, place, step or key phrase; it must not become a generated
  support scene unless requested.
- Do not add stock footage, synthetic B-roll, avatars, evidence cards, or HTML
  explainer sequences just to fill the frame.

Treat the first approved project as the visual baseline for later Tatirou
pieces. Preserve its typography, caption placement, color accents, transition
family and music level unless Tatiana explicitly changes them.

## 6. Music and dialogue

Resolve music through `/media-use`. Prefer the authenticated HeyGen catalog when
available, or use a user-supplied track whose license is known. Record provider,
asset ID/path and license/provenance in the project ledger. “Found online” or a
filename containing “no copyright” is not evidence.

Keep dialogue dominant. Use `/hyperframes-audio` for placement, fades and
ducking. A useful starting point for spoken social delivery is approximately
`-14 LUFS` integrated and true peak `<= -1.5 dBTP`, measured after the final
encode; project requirements may override it.

When no vetted track is available, deliberate silence is preferable to an
unlicensed download.

## 7. Alternate between chat and Studio safely

The saved HyperFrames project is the only source of truth. Use this loop:

1. Save the current Studio edit.
2. Chat rereads the affected composition and project artifacts.
3. For a selection-directed request, query Studio context and use its `hfId` or
   returned selector/source file.
4. Chat applies a narrow patch without replacing unrelated timing, IDs, styles,
   captions, or manual changes.
5. Run fast lint after structural authoring and the required check at the final
   gate.
6. Refresh or reopen the same Studio project for the next manual pass.

Do not keep a hidden chat-owned timeline or regenerate from an earlier plan.
Do not edit concurrently while Studio has unsaved work.

## 8. Preview, render and verify

After structural work:

```bash
npx hyperframes lint
npx hyperframes check
npx hyperframes preview --background
```

Do not run redundant lint immediately before the final `check`; `check` already
includes lint. Open final Studio preview only after checks pass. Render only
after Tatiana approves that preview.

For a requested final master, verify:

- complete decode without errors;
- structured `ffprobe` stream, dimensions, frame rate, duration and codecs;
- A/V sync near the beginning, middle and end;
- every spoken phrase has correctly timed, readable captions;
- no caption or side text obscures Tatiana;
- transitions show no blank/frozen/duplicated frames;
- dialogue intelligibility, integrated loudness and true peak;
- no unintended private information;
- the reported clip order and final duration match the encoded master.

Rendering completion is not permission to publish, upload, schedule or share.
