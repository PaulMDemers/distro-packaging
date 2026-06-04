#!/usr/bin/env bash
set -euo pipefail

target="${1:-/target}"
cmdline_path="${CMDLINE_PATH:-/proc/cmdline}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
serial_device="${DEMUNTU_SERIAL_DEVICE:-/dev/ttyS0}"
log_file="$target/var/log/demuntu-package-sets.log"

if [ ! -d "$target" ]; then
  echo "missing target root: $target" >&2
  exit 1
fi

mkdir -p "$(dirname "$log_file")"

log() {
  local message="DEMUNTU_PACKAGE_SETS: $*"
  printf '%s\n' "$message" | tee -a "$log_file" >&2
  if [ -e "$serial_device" ]; then
    printf '%s\n' "$message" > "$serial_device" 2>/dev/null || true
  fi
}

cmdline="$(cat "$cmdline_path" 2>/dev/null || true)"
sets="$(
  printf '%s\n' "$cmdline" \
    | sed -n 's/.*demuntu\.package_sets=\([^ ]*\).*/\1/p' \
    | tail -n 1
)"

if [ -z "$sets" ] || [ "$sets" = "none" ]; then
  log "none requested"
  exit 0
fi

if ! command -v curtin >/dev/null 2>&1; then
  log "curtin is required to install package sets into $target"
  exit 1
fi

log "requested $sets"

target_payload="/tmp/demuntu-package-sets"
rm -rf "$target/$target_payload"
mkdir -p "$target/$target_payload"
cp -a "$script_dir/." "$target/$target_payload/"
find "$target/$target_payload" -type f -name '*.sh' -exec chmod 0755 {} +

case "$sets" in
  ask|prompt|select)
    if [ -x "$script_dir/select.sh" ]; then
      sets="$("$script_dir/select.sh")"
    else
      sets="none"
    fi
    ;;
esac

if [ -z "$sets" ] || [ "$sets" = "none" ]; then
  log "none selected"
  rm -rf "$target/$target_payload"
  exit 0
fi

log "installing $sets"
if curtin in-target --target="$target" -- "$target_payload/install.sh" "$sets" >>"$log_file" 2>&1; then
  log "completed $sets"
else
  rc="$?"
  log "failed $sets rc=$rc"
  exit "$rc"
fi
rm -rf "$target/$target_payload"
