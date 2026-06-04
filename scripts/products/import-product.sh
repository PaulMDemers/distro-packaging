#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: import-product.sh PRODUCT [SOURCE_REPO]

Import a product-layer repo into the packaging workspace.

Products:
  demuntu   Import from SOURCE_REPO or ../Demuntu
  demian    Import from SOURCE_REPO or ../Demian
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
  exit 2
fi

product="$1"
workspace="$(git rev-parse --show-toplevel)"

case "$product" in
  demuntu)
    source_repo="${2:-"$workspace/../Demuntu"}"
    owned_paths=(
      "configs/ubuntu"
      "packages/meta/demuntu-meta"
    )
    owned_globs=(
      "assets/boot/demuntu-*|assets/boot"
      "configs/spins/demuntu-*.toml|configs/spins"
    )
    ;;
  demian)
    source_repo="${2:-"$workspace/../Demian"}"
    owned_paths=(
      "configs/debian"
      "packages/meta/demian-meta"
    )
    owned_globs=(
      "assets/boot/demian-*|assets/boot"
      "configs/spins/demian-*.toml|configs/spins"
    )
    ;;
  *)
    echo "unknown product: $product" >&2
    usage
    exit 2
    ;;
esac

source_repo="$(realpath -m "$source_repo")"

if [ ! -d "$source_repo/.git" ]; then
  echo "source is not a Git repo checkout: $source_repo" >&2
  exit 1
fi

if [ "$source_repo" = "$workspace" ]; then
  echo "refusing to import from the packaging workspace itself" >&2
  exit 1
fi

copy_path() {
  local src="$1"
  local src_path="$source_repo/$src"
  local dst_path="$workspace/$src"

  if [ ! -e "$src_path" ]; then
    echo "missing source path: $src" >&2
    exit 1
  fi

  rm -rf "$dst_path"
  mkdir -p "$(dirname "$dst_path")"
  cp -a "$src_path" "$dst_path"
  echo "imported $src"
}

copy_glob() {
  local spec="$1"
  local pattern="${spec%%|*}"
  local dst_dir="${spec##*|}"
  mkdir -p "$workspace/$dst_dir"
  find "$workspace/$dst_dir" -maxdepth 1 -type f -name "$(basename "$pattern")" -delete
  shopt -s nullglob
  for src in "$source_repo"/$pattern; do
    cp -a "$src" "$workspace/$dst_dir/"
    echo "imported ${src#$source_repo/}"
  done
  shopt -u nullglob
}

for path in "${owned_paths[@]}"; do
  copy_path "$path"
done

for spec in "${owned_globs[@]}"; do
  copy_glob "$spec"
done
