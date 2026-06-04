#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: export-demian.sh [TARGET_REPO]

Export Demian-owned files from the packaging workspace into a Demian product
repo checkout. TARGET_REPO defaults to ../Demian.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -gt 1 ]; then
  usage
  exit 2
fi

workspace="$(git rev-parse --show-toplevel)"
target="${1:-"$workspace/../Demian"}"
target="$(realpath -m "$target")"

if [ ! -d "$target/.git" ]; then
  echo "target is not a Git repo checkout: $target" >&2
  exit 1
fi

if [ "$target" = "$workspace" ]; then
  echo "refusing to export into the packaging workspace itself" >&2
  exit 1
fi

copy_path() {
  local src="$1"
  local dst="$target/$src"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -a "$workspace/$src" "$dst"
  echo "exported $src"
}

copy_glob() {
  local pattern="$1"
  local dst_dir="$2"
  mkdir -p "$target/$dst_dir"
  find "$target/$dst_dir" -maxdepth 1 -type f -name "$(basename "$pattern")" -delete
  shopt -s nullglob
  for src in "$workspace"/$pattern; do
    cp -a "$src" "$target/$dst_dir/"
    echo "exported ${src#$workspace/}"
  done
  shopt -u nullglob
}

copy_glob "assets/boot/demian-*" "assets/boot"
copy_path "configs/debian"
copy_glob "configs/spins/demian-*.toml" "configs/spins"
copy_path "packages/meta/demian-meta"

for doc in docs/BRANDING.md docs/PACKAGE-SETS.md docs/DEVELOPER-GUIS.md docs/SPIN-MATRIX.md; do
  copy_path "$doc"
done
