#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: clean.sh MODE

Modes:
  work       Remove temporary build trees and test disks.
  cache      Remove downloaded upstream base ISOs.
  artifacts  Remove generated ISOs, checksums, screenshots, logs, and manifest.
             Requires CONFIRM_DELETE_ARTIFACTS=yes.
  all        Run work and cache cleanup. Artifacts are preserved.
EOF
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

mode="$1"
workspace="$(pwd)"

remove_path() {
  local target="$1"
  local resolved

  resolved="$(realpath -m "$target")"
  case "$resolved" in
    "$workspace"/*)
      ;;
    *)
      echo "refusing to remove outside workspace: $resolved" >&2
      exit 1
      ;;
  esac

  if [ -e "$resolved" ]; then
    rm -rf --one-file-system "$resolved"
    echo "removed: ${resolved#$workspace/}"
  fi
}

ensure_dir() {
  mkdir -p "$1"
}

clean_work() {
  remove_path build
}

clean_cache() {
  remove_path dist/downloads
  ensure_dir dist/downloads
}

clean_artifacts() {
  if [ "${CONFIRM_DELETE_ARTIFACTS:-}" != "yes" ]; then
    echo "refusing artifact cleanup without CONFIRM_DELETE_ARTIFACTS=yes" >&2
    exit 1
  fi

  remove_path dist/images
  remove_path dist/test
  remove_path dist/packages
  rm -f dist/manifest.json
  ensure_dir dist/images
  ensure_dir dist/test
  ensure_dir dist/packages
}

case "$mode" in
  work)
    clean_work
    ;;
  cache)
    clean_cache
    ;;
  artifacts)
    clean_artifacts
    ;;
  all)
    clean_work
    clean_cache
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "unknown cleanup mode: $mode" >&2
    usage
    exit 2
    ;;
esac
