#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

dry_run=false
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      dry_run=true
      ;;
  esac
done

src="$repo_root/.specify/memory/constitution.md"
specify_backup="$repo_root/.specify/memory/constitution-backup.md"
tmp_dir="$repo_root/tmp"
tmp_backup="$tmp_dir/constitution-backup.md"
env_path="$repo_root/.env"
timestamp="$(date +%Y%m%d-%H%M%S)"
specify_backup_stamped="$repo_root/.specify/memory/constitution-backup-$timestamp.md"
tmp_backup_stamped="$tmp_dir/constitution-backup-$timestamp.md"

if [[ ! -f "$src" ]]; then
  echo "Missing $src. Run this from the base2 repo root after spec-kit has generated memory." >&2
  exit 1
fi

if [[ ! -f "$env_path" ]]; then
  echo "Missing $env_path. Add SPEC_KIT_AI and SPEC_KIT_SCRIPT to .env." >&2
  exit 1
fi

spec_kit_ai="$(grep -E '^SPEC_KIT_AI=' "$env_path" | tail -n 1 | cut -d= -f2-)"
spec_kit_script="$(grep -E '^SPEC_KIT_SCRIPT=' "$env_path" | tail -n 1 | cut -d= -f2-)"

if [[ -z "$spec_kit_ai" || -z "$spec_kit_script" ]]; then
  echo "Missing SPEC_KIT_AI or SPEC_KIT_SCRIPT in .env. Add these keys." >&2
  exit 1
fi

echo "[spec-kit-update] Repo root: $repo_root"
echo "[spec-kit-update] Backup source: $src"

if [[ "$dry_run" == "true" ]]; then
  echo "[spec-kit-update] DRY RUN: would ensure directory $tmp_dir"
  echo "[spec-kit-update] DRY RUN: would copy $src -> $specify_backup"
  echo "[spec-kit-update] DRY RUN: would copy $src -> $tmp_backup"
  echo "[spec-kit-update] DRY RUN: would copy $src -> $specify_backup_stamped"
  echo "[spec-kit-update] DRY RUN: would copy $src -> $tmp_backup_stamped"
  echo "[spec-kit-update] DRY RUN: would run: uv tool install specify-cli --force --from git+https://github.com/github/spec-kit.git"
  echo "[spec-kit-update] DRY RUN: would run: specify init --here --force --ai $spec_kit_ai --script $spec_kit_script"
  exit 0
fi


mkdir -p "$tmp_dir"
cp "$src" "$specify_backup"
cp "$src" "$tmp_backup"
cp "$src" "$specify_backup_stamped"
cp "$src" "$tmp_backup_stamped"

uv tool install specify-cli --force --from git+https://github.com/github/spec-kit.git || {
  echo "spec-kit not install" >&2
  exit 1
}
specify init --here --force --ai "$spec_kit_ai" --script "$spec_kit_script" || {
  echo "spec-kit not install" >&2
  exit 1
}
