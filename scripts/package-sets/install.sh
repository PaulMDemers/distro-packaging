#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
sets_dir="$script_dir/sets"

usage() {
  cat >&2 <<'EOF'
Usage: install.sh [PACKAGE_SET[,PACKAGE_SET...]] [...]

Installs one or more Demuntu package sets inside the current target system.
Use "none" or no arguments to install no optional package sets.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -eq 0 ]; then
  echo "No optional package sets selected."
  exit 0
fi

selected="$*"
selected="${selected//,/ }"

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

for set_id in $selected; do
  case "$set_id" in
    ""|none)
      continue
      ;;
    *[!A-Za-z0-9_-]*)
      echo "invalid package set id: $set_id" >&2
      exit 2
      ;;
  esac

  installer="$sets_dir/$set_id.sh"
  if [ ! -x "$installer" ]; then
    echo "unknown package set: $set_id" >&2
    exit 2
  fi

  echo "Installing package set: $set_id"
  "$installer"
done
