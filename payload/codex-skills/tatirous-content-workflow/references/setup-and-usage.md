# Setup and usage

Read this reference when preparing Tatiana's MacBook, starting a project, or
explaining how she can alternate between chat and HyperFrames Studio.

## Machine readiness

The local workflow needs:

- Apple Silicon (`arm64`) for Parakeet MLX;
- Node.js 22 or newer for HyperFrames;
- `ffmpeg` and `ffprobe` for media handling and QA;
- the installed HyperFrames, `general-video`, `media-use`, animation, audio and
  CLI skills;
- `uv`, an isolated Python 3.12 environment, and `parakeet-mlx`;
- optional HeyGen authentication only for catalog/cloud capabilities such as
  fresh BGM resolution or hosted rendering.

Check the machine without reading credential values:

```bash
uname -m
node --version
ffmpeg -version
ffprobe -version
npx hyperframes doctor --json
test -x "$HOME/.venvs/parakeet/bin/parakeet-mlx"
```

`hyperframes doctor --json` always exits zero; inspect its `.ok` payload rather
than trusting the process exit status.

## Install Parakeet on Apple Silicon

Use an isolated uv-managed Python rather than the macOS system Python:

```bash
uv python install 3.12
uv venv --python 3.12 "$HOME/.venvs/parakeet"
VIRTUAL_ENV="$HOME/.venvs/parakeet" uv pip install parakeet-mlx
```

If `uv` is absent, install it using Homebrew when Homebrew is already managed on
the machine, or follow uv's official installer. Do not install Parakeet into the
system Python.

The production model is:

```text
mlx-community/parakeet-tdt-0.6b-v3
```

Prove the runtime with real local speech, not only `--help`:

```bash
say -o /tmp/tatirou-parakeet-smoke.aiff "This is a local transcription test"
afconvert -f WAVE -d LEI16@16000 \
  /tmp/tatirou-parakeet-smoke.aiff \
  /tmp/tatirou-parakeet-smoke.wav
"$HOME/.venvs/parakeet/bin/parakeet-mlx" \
  /tmp/tatirou-parakeet-smoke.wav \
  --model mlx-community/parakeet-tdt-0.6b-v3 \
  --output-format json \
  --output-dir /tmp/tatirou-parakeet-smoke-out
```

Confirm a non-empty transcript and cached model, then remove only the smoke-test
files. The media-use wrapper will discover the venv directly even when
`parakeet-mlx` is not on the general `PATH`.

Parakeet runs locally. It does not use an OpenAI API key or the current
ChatGPT/Codex session credentials. `watch` may separately use an OpenAI or Groq
key as its own fallback; that configuration is unrelated.

## Start a new video from chat

Upload the clips into the same local project context and say, for example:

```text
Usa $tatirous-content-workflow. Crea un reel vertical con estos clips en este
orden: intro.mov, cocina.mov y cierre.mov. Recorta silencios largos, conserva mi
ritmo natural, añade subtítulos en español y una transición sutil entre cada
escena. Quiero revisar y seguir editando el mismo proyecto en HyperFrames
Studio. No agregues B-roll ni escenas generadas.
```

The workflow should return the project path, assembled order, threshold used,
caption language, current duration and Studio preview state.

## Ask for chat revisions

Examples:

```text
Mueve cocina.mov antes de intro.mov y conserva todos mis cambios manuales.
```

```text
Deja las pausas naturales, pero recorta silencios de más de 1.2 segundos.
```

```text
Haz los subtítulos un poco más pequeños y muévelos cuando cubran mi cara. No
cambies los cortes.
```

```text
Añade música suave debajo de mi voz usando solo una pista con procedencia y
licencia registradas. Si no hay una disponible, deja el video sin música.
```

## Direct a chat edit from Studio

1. Open the saved project with `npx hyperframes preview --background`.
2. Select the clip, caption or text element in Studio.
3. Ask in chat, for example:

```text
En $tatirous-content-workflow, mueve este texto al lado izquierdo y haz su
entrada más sutil. No cambies ningún otro elemento.
```

The agent queries Studio selection context, patches that saved target, reruns
the affected check, and refreshes the same project. If no selection is visible,
the agent asks only for the target to be selected.

Always save manual Studio work before asking chat to write project files. Do not
edit the same file manually while a chat mutation is running.

## Finalize and export

Example:

```text
Verifica el video completo, abre el preview final en Studio y espera mi
aprobación. Cuando lo apruebe, renderiza el master vertical en alta calidad y
revisa decode, sincronización, subtítulos, transiciones y loudness. No lo
publiques.
```

Studio preview approval and render approval are separate from publishing.
HeyGen-hosted cloud rendering, uploads, scheduling and social posting require
their own authentication and explicit authority.
