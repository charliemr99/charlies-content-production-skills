# Skill transfer for MacBook-Air-4.local

Paquete autocontenido para instalar 28 skills: 24 en `~/.agents/skills` y 4 en `~/.codex/skills`. No descarga ni instala software, no toca otras skills y no contiene configuración global completa ni credenciales.

## Uso

Desde la raíz del paquete:

```bash
./install-skills.sh --validate-only
./install-skills.sh
```

El primer comando valida `MANIFEST.sha256`, inventario, `SKILL.md`, symlinks y herramientas sin escribir en `HOME`. La instalación compara manifiestos deterministas de rutas, tipos, modos y SHA-256; deja intactas las copias idénticas y escribe `report/install-report.tsv` con las 28 filas.

Las versiones reemplazadas y el lock previo quedan bajo `~/.codex/skill-transfer-backups/<timestamp>/`. Para recuperar una skill, mueve primero la versión instalada a un nombre temporal y copia con `cp -a` la copia correspondiente desde `agents-skills/` o `codex-skills/`. Para recuperar el lock, copia `agents/.skill-lock.json` desde el mismo timestamp a `~/.agents/.skill-lock.json` mediante un archivo temporal y un `mv` final.

## Alcance

El instalador usa el `HOME` real del proceso, fusiona únicamente las 23 entradas disponibles en `payload/skill-lock-selected.json` y falla si falta una herramienta requerida o una validación real. `watch` incluye un `.git` interno; como Git no puede versionar un `.git` anidado como archivos normales, su contenido completo se transporta en `transfer-metadata/watch-dotgit.tar` y se reconstruye en staging antes de toda comparación o instalación. Transporta este estado con clone/worktree/handoff del commit; no uses `git archive`, porque las reglas `export-ignore` propias de `watch` omiten tres dotfiles de esa skill.
