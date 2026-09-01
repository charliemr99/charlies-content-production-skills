#!/usr/bin/env bash

set -u
set -o pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACKAGE_ROOT="$SCRIPT_DIR"
PAYLOAD_ROOT="$PACKAGE_ROOT/payload"
REPORT_DIR="$PACKAGE_ROOT/report"
MANIFEST_PATH="$PACKAGE_ROOT/MANIFEST.sha256"
VALIDATE_ONLY=0
WORK_ROOT=""
REPORT_TMP=""
OVERALL_FAILURE=0
AGENT_FAILURE=0

AGENT_SKILLS=(
  video
  hyperframes
  product-launch-video
  general-video
  motion-graphics
  media-use
  hyperframes-core
  hyperframes-creative
  hyperframes-animation
  hyperframes-keyframes
  hyperframes-audio
  hyperframes-cli
  hyperframes-registry
  social-content
  viral-short-form
  viral-short-form-ideas
  viral-hooks
  viral-captions-and-ctas
  viral-instagram-reels
  viral-tiktok-content
  viral-youtube-shorts
  ad-creative
  review-animations
  website-to-hyperframes
)

CODEX_SKILLS=(
  watch
  playwright
  playwright-interactive
  charlies-content-workflow
)

usage() {
  printf 'Usage: %s [--validate-only]\n' "$(basename "$0")"
}

cleanup() {
  if [[ -n "$REPORT_TMP" && -e "$REPORT_TMP" ]]; then
    rm -f -- "$REPORT_TMP"
  fi
  if [[ -n "$WORK_ROOT" && -d "$WORK_ROOT" ]]; then
    case "$WORK_ROOT" in
      "${TMPDIR:-/tmp}"/skill-transfer.*|/tmp/skill-transfer.*|/private/tmp/skill-transfer.*)
        rm -rf -- "$WORK_ROOT"
        ;;
      *)
        printf 'Refusing to remove unexpected temporary path.\n' >&2
        ;;
    esac
  fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi
if [[ $# -eq 1 ]]; then
  if [[ "$1" == "--validate-only" ]]; then
    VALIDATE_ONLY=1
  else
    usage >&2
    exit 2
  fi
fi

init_report() {
  mkdir -p "$REPORT_DIR" || return 1
  REPORT_TMP="$(mktemp "$REPORT_DIR/.install-report.XXXXXX")" || return 1
  printf 'target\tskill\tstatus\tdetail\n' > "$REPORT_TMP" || return 1
}

record_report() {
  local target="$1"
  local skill="$2"
  local status="$3"
  local detail="$4"
  detail="${detail//$'\t'/ }"
  detail="${detail//$'\r'/ }"
  detail="${detail//$'\n'/ }"
  printf '%s\t%s\t%s\t%s\n' "$target" "$skill" "$status" "$detail" >> "$REPORT_TMP"
  printf '%s\t%s\t%s\n' "$target" "$skill" "$status"
}

finish_report() {
  local final_path="$REPORT_DIR/install-report.tsv"
  chmod 600 "$REPORT_TMP" || return 1
  mv -f -- "$REPORT_TMP" "$final_path" || return 1
  REPORT_TMP=""
}

mark_all_failed() {
  local detail="$1"
  local skill
  for skill in "${AGENT_SKILLS[@]}"; do
    record_report agents "$skill" failed "$detail"
  done
  for skill in "${CODEX_SKILLS[@]}"; do
    record_report codex "$skill" failed "$detail"
  done
}

report_skill_tools() {
  local tool
  for tool in node npx ffmpeg ffprobe python3 yt-dlp git; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf 'tool\t%s\tavailable\n' "$tool"
    else
      printf 'tool\t%s\tmissing\n' "$tool" >&2
    fi
  done
}

check_runtime_tools() {
  local missing=0
  local tool
  for tool in python3 cp mv find mktemp tar; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'runtime\t%s\tmissing\n' "$tool" >&2
      missing=1
    fi
  done
  return "$missing"
}

verify_package_manifest() {
  [[ -f "$MANIFEST_PATH" ]] || return 1
  python3 - "$PACKAGE_ROOT" "$MANIFEST_PATH" <<'PY'
import hashlib
import os
import re
import sys

root = os.path.realpath(sys.argv[1])
manifest_path = os.path.realpath(sys.argv[2])
line_re = re.compile(r"^([0-9a-f]{64})  (.+)$")
listed = {}

with open(manifest_path, "r", encoding="utf-8") as handle:
    for number, raw in enumerate(handle, 1):
        line = raw.rstrip("\n")
        match = line_re.fullmatch(line)
        if not match:
            raise SystemExit(f"invalid manifest line {number}")
        digest, relative = match.groups()
        if relative.startswith("/") or ".." in relative.split("/"):
            raise SystemExit(f"unsafe manifest path on line {number}")
        if relative in listed:
            raise SystemExit(f"duplicate manifest path on line {number}")
        listed[relative] = digest

expected = set()
for relative_root in ("payload", "transfer-metadata"):
    absolute_root = os.path.join(root, relative_root)
    for current, dirs, files in os.walk(absolute_root, followlinks=False):
        dirs.sort()
        files.sort()
        rel_current = os.path.relpath(current, root)
        if rel_current == "payload/codex-skills/watch":
            dirs[:] = [name for name in dirs if name != ".git"]
        for name in files:
            path = os.path.join(current, name)
            relative = os.path.relpath(path, root).replace(os.sep, "/")
            if os.path.islink(path):
                raise SystemExit(f"package symlink is not supported: {relative}")
            expected.add(relative)

for relative in (
    "README.md", "TRANSFER-INVENTORY.tsv", "install-skills.sh", ".gitignore"
):
    path = os.path.join(root, relative)
    if not os.path.isfile(path):
        raise SystemExit(f"required package file missing: {relative}")
    expected.add(relative)

if set(listed) != expected:
    missing = sorted(expected - set(listed))
    extra = sorted(set(listed) - expected)
    if missing:
        print("manifest missing package paths", file=sys.stderr)
    if extra:
        print("manifest contains unexpected paths", file=sys.stderr)
    raise SystemExit(1)

for relative in sorted(expected):
    path = os.path.join(root, *relative.split("/"))
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != listed[relative]:
        print(f"checksum mismatch: {relative}", file=sys.stderr)
        raise SystemExit(1)
PY
}

materialize_sources() {
  local archive="$PACKAGE_ROOT/transfer-metadata/watch-dotgit.tar"
  mkdir -p "$WORK_ROOT/agents-skills" "$WORK_ROOT/codex-skills" || return 1
  cp -a "$PAYLOAD_ROOT/agents-skills/." "$WORK_ROOT/agents-skills/" || return 1
  cp -a "$PAYLOAD_ROOT/codex-skills/." "$WORK_ROOT/codex-skills/" || return 1
  python3 - "$archive" "$WORK_ROOT/codex-skills/watch" <<'PY'
import os
import shutil
import stat
import sys
import tarfile
from pathlib import PurePosixPath

archive, watch_root = sys.argv[1:]
dotgit = os.path.join(watch_root, ".git")
if os.path.lexists(dotgit):
    if os.path.isdir(dotgit) and not os.path.islink(dotgit):
        shutil.rmtree(dotgit)
    else:
        os.unlink(dotgit)

with tarfile.open(archive, "r:") as bundle:
    members = bundle.getmembers()
    for member in members:
        path = PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit("unsafe watch metadata archive path")
        if not path.parts or path.parts[0] != ".git":
            raise SystemExit("unexpected watch metadata archive member")
        if member.isdev() or member.isfifo():
            raise SystemExit("unsupported watch metadata archive member")
        if member.issym() or member.islnk():
            link = PurePosixPath(member.linkname)
            if link.is_absolute() or ".." in link.parts:
                raise SystemExit("unsafe watch metadata archive link")
    bundle.extractall(watch_root, members=members)
PY
}

validate_source_inventory() {
  python3 - "$WORK_ROOT" <<'PY'
import os
import sys

root = sys.argv[1]
expected = {
    "agents-skills": {
        "video", "hyperframes", "product-launch-video", "general-video",
        "motion-graphics", "media-use", "hyperframes-core",
        "hyperframes-creative", "hyperframes-animation",
        "hyperframes-keyframes", "hyperframes-audio", "hyperframes-cli",
        "hyperframes-registry", "social-content", "viral-short-form",
        "viral-short-form-ideas", "viral-hooks", "viral-captions-and-ctas",
        "viral-instagram-reels", "viral-tiktok-content",
        "viral-youtube-shorts", "ad-creative", "review-animations",
        "website-to-hyperframes",
    },
    "codex-skills": {
        "watch", "playwright", "playwright-interactive",
        "charlies-content-workflow",
    },
}

for scope, wanted in expected.items():
    scope_root = os.path.join(root, scope)
    actual = {
        name for name in os.listdir(scope_root)
        if os.path.isdir(os.path.join(scope_root, name))
        and not os.path.islink(os.path.join(scope_root, name))
    }
    if actual != wanted:
        raise SystemExit(f"unexpected {scope} inventory")
PY
}

validate_skill_tree() {
  local path="$1"
  local broken
  [[ -d "$path" && ! -L "$path" && -f "$path/SKILL.md" ]] || return 1
  broken="$(find "$path" -type l ! -exec test -e {} \; -print -quit)" || return 1
  [[ -z "$broken" ]] || return 1
  python3 - "$path" /dev/null <<'PY'
import hashlib
import json
import os
import stat
import sys

root, output = sys.argv[1:]
records = []
for current, dirs, files in os.walk(root, topdown=True, followlinks=False):
    dirs.sort()
    files.sort()
    for name in dirs + files:
        path = os.path.join(current, name)
        relative = os.path.relpath(path, root).replace(os.sep, "/")
        info = os.lstat(path)
        mode = format(stat.S_IMODE(info.st_mode), "04o")
        if stat.S_ISDIR(info.st_mode):
            record = {"mode": mode, "path": relative, "type": "dir"}
        elif stat.S_ISREG(info.st_mode):
            digest = hashlib.sha256()
            with open(path, "rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
            record = {
                "mode": mode,
                "path": relative,
                "sha256": digest.hexdigest(),
                "type": "file",
            }
        elif stat.S_ISLNK(info.st_mode):
            record = {
                "mode": mode,
                "path": relative,
                "target": os.readlink(path),
                "type": "symlink",
            }
        else:
            raise SystemExit(f"unsupported filesystem object: {relative}")
        records.append(record)

records.sort(key=lambda item: item["path"].encode("utf-8", "surrogateescape"))
if output != "/dev/null":
    with open(output, "w", encoding="utf-8", newline="\n") as handle:
        for record in records:
            handle.write(json.dumps(record, sort_keys=True, separators=(",", ":")))
            handle.write("\n")
PY
}

write_tree_manifest() {
  local path="$1"
  local output="$2"
  python3 - "$path" "$output" <<'PY'
import hashlib
import json
import os
import stat
import sys

root, output = sys.argv[1:]
records = []
for current, dirs, files in os.walk(root, topdown=True, followlinks=False):
    dirs.sort()
    files.sort()
    for name in dirs + files:
        path = os.path.join(current, name)
        relative = os.path.relpath(path, root).replace(os.sep, "/")
        info = os.lstat(path)
        mode = format(stat.S_IMODE(info.st_mode), "04o")
        if stat.S_ISDIR(info.st_mode):
            record = {"mode": mode, "path": relative, "type": "dir"}
        elif stat.S_ISREG(info.st_mode):
            digest = hashlib.sha256()
            with open(path, "rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
            record = {
                "mode": mode,
                "path": relative,
                "sha256": digest.hexdigest(),
                "type": "file",
            }
        elif stat.S_ISLNK(info.st_mode):
            record = {
                "mode": mode,
                "path": relative,
                "target": os.readlink(path),
                "type": "symlink",
            }
        else:
            raise SystemExit(f"unsupported filesystem object: {relative}")
        records.append(record)

records.sort(key=lambda item: item["path"].encode("utf-8", "surrogateescape"))
with open(output, "w", encoding="utf-8", newline="\n") as handle:
    for record in records:
        handle.write(json.dumps(record, sort_keys=True, separators=(",", ":")))
        handle.write("\n")
PY
}

validate_all_sources() {
  local skill
  validate_source_inventory || return 1
  for skill in "${AGENT_SKILLS[@]}"; do
    validate_skill_tree "$WORK_ROOT/agents-skills/$skill" || return 1
  done
  for skill in "${CODEX_SKILLS[@]}"; do
    validate_skill_tree "$WORK_ROOT/codex-skills/$skill" || return 1
  done
}

safe_remove_transfer_path() {
  local path="$1"
  local parent="$2"
  case "$path" in
    "$parent"/.skill-transfer-*) rm -rf -- "$path" ;;
    *) return 1 ;;
  esac
}

compare_trees() {
  local source="$1"
  local destination="$2"
  local key="$3"
  local source_manifest="$WORK_ROOT/${key}.source.manifest"
  local destination_manifest="$WORK_ROOT/${key}.destination.manifest"
  [[ -d "$destination" && ! -L "$destination" ]] || return 1
  write_tree_manifest "$source" "$source_manifest" || return 1
  write_tree_manifest "$destination" "$destination_manifest" || return 1
  cmp -s "$source_manifest" "$destination_manifest"
}

install_absent_skill() {
  local source="$1"
  local destination="$2"
  local target_root="$3"
  local key="$4"
  local incoming
  incoming="$(mktemp -d "$target_root/.skill-transfer-${key}.incoming.XXXXXX")" || return 1
  rmdir "$incoming" || return 1
  if ! cp -a "$source" "$incoming"; then
    safe_remove_transfer_path "$incoming" "$target_root" || true
    return 1
  fi
  if ! mv -- "$incoming" "$destination"; then
    safe_remove_transfer_path "$incoming" "$target_root" || true
    return 1
  fi
  if ! compare_trees "$source" "$destination" "${key}.installed"; then
    local failed_copy
    failed_copy="$(mktemp -d "$target_root/.skill-transfer-${key}.failed.XXXXXX")" || return 1
    rmdir "$failed_copy" || return 1
    if mv -- "$destination" "$failed_copy"; then
      safe_remove_transfer_path "$failed_copy" "$target_root" || true
    fi
    return 1
  fi
  return 0
}

update_skill() {
  local source="$1"
  local destination="$2"
  local target_root="$3"
  local backup_parent="$4"
  local key="$5"
  local incoming previous

  mkdir -p "$backup_parent" || return 1
  [[ ! -e "$backup_parent/$key" && ! -L "$backup_parent/$key" ]] || return 1
  cp -a "$destination" "$backup_parent/$key" || return 1

  incoming="$(mktemp -d "$target_root/.skill-transfer-${key}.incoming.XXXXXX")" || return 1
  rmdir "$incoming" || return 1
  if ! cp -a "$source" "$incoming"; then
    safe_remove_transfer_path "$incoming" "$target_root" || true
    return 1
  fi

  previous="$(mktemp -d "$target_root/.skill-transfer-${key}.previous.XXXXXX")" || {
    safe_remove_transfer_path "$incoming" "$target_root" || true
    return 1
  }
  rmdir "$previous" || return 1

  if ! mv -- "$destination" "$previous"; then
    safe_remove_transfer_path "$incoming" "$target_root" || true
    return 1
  fi
  if ! mv -- "$incoming" "$destination"; then
    mv -- "$previous" "$destination" || true
    safe_remove_transfer_path "$incoming" "$target_root" || true
    return 1
  fi

  if ! compare_trees "$source" "$destination" "${key}.updated"; then
    local failed_copy
    failed_copy="$(mktemp -d "$target_root/.skill-transfer-${key}.failed.XXXXXX")" || return 1
    rmdir "$failed_copy" || return 1
    mv -- "$destination" "$failed_copy" || return 1
    if ! mv -- "$previous" "$destination"; then
      return 1
    fi
    safe_remove_transfer_path "$failed_copy" "$target_root" || true
    return 1
  fi

  safe_remove_transfer_path "$previous" "$target_root" || return 1
  return 0
}

process_skill() {
  local target_label="$1"
  local skill="$2"
  local source="$3"
  local target_root="$4"
  local backup_scope="$5"
  local destination="$target_root/$skill"
  local key="${target_label}-${skill}"

  if [[ ! "$skill" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    record_report "$target_label" "$skill" failed invalid-skill-name
    return 1
  fi
  case "$destination" in
    "$target_root"/*) ;;
    *)
      record_report "$target_label" "$skill" failed unsafe-destination
      return 1
      ;;
  esac

  if [[ -d "$destination" && ! -L "$destination" ]] && compare_trees "$source" "$destination" "$key"; then
    record_report "$target_label" "$skill" identical content-and-mode-match
    return 0
  fi

  if [[ ! -e "$destination" && ! -L "$destination" ]]; then
    if install_absent_skill "$source" "$destination" "$target_root" "$key"; then
      record_report "$target_label" "$skill" installed exact-copy-verified
      return 0
    fi
    record_report "$target_label" "$skill" failed install-or-verification-failed
    return 1
  fi

  if update_skill "$source" "$destination" "$target_root" "$backup_scope" "$skill"; then
    record_report "$target_label" "$skill" updated backup-and-exact-copy-verified
    return 0
  fi
  record_report "$target_label" "$skill" failed update-or-verification-failed
  return 1
}

merge_selected_lock() {
  local target_lock="$1"
  local selected_lock="$PAYLOAD_ROOT/skill-lock-selected.json"
  local candidate rc lock_backup_parent
  candidate="$(mktemp "$TARGET_AGENTS_ROOT/.skill-lock.candidate.XXXXXX")" || return 1
  python3 - "$target_lock" "$selected_lock" "$candidate" <<'PY'
import copy
import json
import os
import sys

target_path, selected_path, candidate_path = sys.argv[1:]
with open(selected_path, "r", encoding="utf-8") as handle:
    selected = json.load(handle)
selected_skills = selected.get("skills")
if not isinstance(selected_skills, dict):
    raise SystemExit(2)

exists = os.path.exists(target_path)
if exists:
    try:
        with open(target_path, "r", encoding="utf-8") as handle:
            target = json.load(handle)
    except (OSError, json.JSONDecodeError):
        raise SystemExit(2)
    if not isinstance(target, dict):
        raise SystemExit(2)
else:
    target = {"version": selected.get("version", 1), "skills": {}, "dismissed": {}}

target_skills = target.get("skills")
if target_skills is None:
    target_skills = {}
    target["skills"] = target_skills
if not isinstance(target_skills, dict):
    raise SystemExit(2)

changed = not exists
for name, value in selected_skills.items():
    if target_skills.get(name) != value:
        target_skills[name] = copy.deepcopy(value)
        changed = True

if not changed:
    raise SystemExit(3)

with open(candidate_path, "w", encoding="utf-8", newline="\n") as handle:
    json.dump(target, handle, indent=2, sort_keys=True, ensure_ascii=False)
    handle.write("\n")
PY
  rc=$?
  if [[ $rc -eq 3 ]]; then
    rm -f -- "$candidate"
    printf 'lock\tidentical\n'
    return 0
  fi
  if [[ $rc -ne 0 ]]; then
    rm -f -- "$candidate"
    printf 'lock\tfailed\n' >&2
    return 1
  fi

  if [[ -e "$target_lock" || -L "$target_lock" ]]; then
    lock_backup_parent="$BACKUP_RUN_ROOT/agents"
    mkdir -p "$lock_backup_parent" || {
      rm -f -- "$candidate"
      return 1
    }
    cp -a "$target_lock" "$lock_backup_parent/.skill-lock.json" || {
      rm -f -- "$candidate"
      return 1
    }
  fi
  if ! mv -f -- "$candidate" "$target_lock"; then
    rm -f -- "$candidate"
    return 1
  fi
  printf 'lock\tupdated\n'
  return 0
}

if [[ $VALIDATE_ONLY -eq 0 ]]; then
  if ! init_report; then
    printf 'Unable to initialize install report.\n' >&2
    exit 1
  fi
fi

report_skill_tools

if ! check_runtime_tools; then
  if [[ $VALIDATE_ONLY -eq 0 ]]; then
    mark_all_failed missing-installer-runtime
    finish_report || true
  fi
  exit 1
fi

if ! verify_package_manifest; then
  printf 'Package integrity validation failed.\n' >&2
  if [[ $VALIDATE_ONLY -eq 0 ]]; then
    mark_all_failed package-integrity-failed
    finish_report || true
  fi
  exit 1
fi

WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skill-transfer.XXXXXX")" || {
  if [[ $VALIDATE_ONLY -eq 0 ]]; then
    mark_all_failed temporary-workspace-failed
    finish_report || true
  fi
  exit 1
}

if ! materialize_sources || ! validate_all_sources; then
  printf 'Payload validation failed.\n' >&2
  if [[ $VALIDATE_ONLY -eq 0 ]]; then
    mark_all_failed payload-validation-failed
    finish_report || true
  fi
  exit 1
fi

if [[ $VALIDATE_ONLY -eq 1 ]]; then
  printf 'validation\tok\t28 skills; HOME not modified\n'
  exit 0
fi

if [[ -z "${HOME:-}" || "$HOME" != /* || ! -d "$HOME" ]]; then
  mark_all_failed invalid-process-home
  finish_report || true
  exit 1
fi

TARGET_HOME="$(cd "$HOME" && pwd -P)" || {
  mark_all_failed invalid-process-home
  finish_report || true
  exit 1
}
TARGET_AGENTS_ROOT="$TARGET_HOME/.agents"
TARGET_AGENTS_SKILLS="$TARGET_AGENTS_ROOT/skills"
TARGET_CODEX_ROOT="$TARGET_HOME/.codex"
TARGET_CODEX_SKILLS="$TARGET_CODEX_ROOT/skills"

case "$TARGET_AGENTS_SKILLS:$TARGET_CODEX_SKILLS" in
  "$TARGET_HOME"/*:"$TARGET_HOME"/*) ;;
  *)
    mark_all_failed unsafe-process-home
    finish_report || true
    exit 1
    ;;
esac

if ! mkdir -p "$TARGET_AGENTS_SKILLS" "$TARGET_CODEX_SKILLS"; then
  mark_all_failed target-directory-failed
  finish_report || true
  exit 1
fi

BACKUP_TIMESTAMP="$(python3 - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ"))
PY
)" || {
  mark_all_failed timestamp-failed
  finish_report || true
  exit 1
}
BACKUP_RUN_ROOT="$TARGET_CODEX_ROOT/skill-transfer-backups/$BACKUP_TIMESTAMP"

for skill in "${AGENT_SKILLS[@]}"; do
  if ! process_skill agents "$skill" "$WORK_ROOT/agents-skills/$skill" \
    "$TARGET_AGENTS_SKILLS" "$BACKUP_RUN_ROOT/agents-skills"; then
    OVERALL_FAILURE=1
    AGENT_FAILURE=1
  fi
done

for skill in "${CODEX_SKILLS[@]}"; do
  if ! process_skill codex "$skill" "$WORK_ROOT/codex-skills/$skill" \
    "$TARGET_CODEX_SKILLS" "$BACKUP_RUN_ROOT/codex-skills"; then
    OVERALL_FAILURE=1
  fi
done

if [[ $AGENT_FAILURE -eq 0 ]]; then
  if ! merge_selected_lock "$TARGET_AGENTS_ROOT/.skill-lock.json"; then
    OVERALL_FAILURE=1
  fi
else
  printf 'lock\tskipped-after-agent-failure\n' >&2
fi

if ! finish_report; then
  printf 'Unable to finalize install report.\n' >&2
  exit 1
fi

exit "$OVERALL_FAILURE"
