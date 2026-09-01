# Skill transfer for MacBook-Air-4.local

Paquete autocontenido para instalar 29 skills: 24 en `~/.agents/skills` y 5 en `~/.codex/skills`. No descarga ni instala software, no toca otras skills y no contiene configuración global completa ni credenciales.

Este repositorio es un vehículo público temporal de transferencia. Se eliminará después de completar y verificar la instalación remota. Las atribuciones y licencias de las skills de terceros están documentadas en `THIRD_PARTY_NOTICES.md` y `licenses/`.

## Uso

Desde la raíz del paquete:

```bash
./install-skills.sh --validate-only
./install-skills.sh
```

El primer comando valida `MANIFEST.sha256`, inventario, `SKILL.md`, symlinks y el runtime mínimo del instalador sin escribir en `HOME`. También reporta la disponibilidad de `node`, `npx`, `ffmpeg`, `ffprobe`, `python3`, `yt-dlp` y `git`; las ausencias que solo afectan el uso posterior de una skill se muestran como advertencias y no bloquean la copia. La instalación compara manifiestos deterministas de rutas, tipos, modos y SHA-256; deja intactas las copias idénticas y escribe `report/install-report.tsv` con las 29 filas.

Las versiones reemplazadas y el lock previo quedan bajo `~/.codex/skill-transfer-backups/<timestamp>/`. Para recuperar una skill, mueve primero la versión instalada a un nombre temporal y copia con `cp -a` la copia correspondiente desde `agents-skills/` o `codex-skills/`. Para recuperar el lock, copia `agents/.skill-lock.json` desde el mismo timestamp a `~/.agents/.skill-lock.json` mediante un archivo temporal y un `mv` final.

## Alcance

El instalador usa el `HOME` real del proceso, fusiona únicamente las 23 entradas disponibles en `payload/skill-lock-selected.json` y falla si falta su runtime mínimo o una validación de integridad real. Las herramientas de producción que falten se conservan como caveats explícitos para una instalación posterior separada. `watch` incluye un `.git` interno; como Git no puede versionar un `.git` anidado como archivos normales, su contenido completo se transporta en `transfer-metadata/watch-dotgit.tar` y se reconstruye en staging antes de toda comparación o instalación. Transporta este estado con clone/worktree/handoff del commit; no uses `git archive`, porque las reglas `export-ignore` propias de `watch` omiten tres dotfiles de esa skill.
