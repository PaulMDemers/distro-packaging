#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
catalog="$script_dir/configs/catalog.tsv"

usage() {
  cat >&2 <<'EOF'
Usage: select.sh

Prints a comma-separated package-set selection. Uses whiptail/dialog when
available and falls back to a terminal prompt.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ -n "${DEMUNTU_PACKAGE_SETS_PRESELECT:-}" ]; then
  printf '%s\n' "$DEMUNTU_PACKAGE_SETS_PRESELECT"
  exit 0
fi

ids=()
names=()
summaries=()

if [ -f "$catalog" ]; then
  while IFS=$'\t' read -r set_id name summary; do
    case "$set_id" in
      ""|\#*) continue ;;
    esac
    ids+=("$set_id")
    names+=("${name:-$set_id}")
    summaries+=("${summary:-Optional Demuntu package set}")
  done < "$catalog"
else
  while IFS= read -r -d '' installer; do
    set_id="$(basename "$installer" .sh)"
    ids+=("$set_id")
    names+=("$set_id")
    summaries+=("Optional Demuntu package set")
  done < <(find "$script_dir/sets" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
fi

if [ "${#ids[@]}" -eq 0 ]; then
  printf 'none\n'
  exit 0
fi

choose_tty() {
  local tty
  for tty in /dev/tty1 /dev/ttyS0 /dev/console; do
    if [ -r "$tty" ] && [ -w "$tty" ]; then
      printf '%s\n' "$tty"
      return 0
    fi
  done
  return 1
}

tty="$(choose_tty || true)"
if [ -z "$tty" ]; then
  printf 'none\n'
  exit 0
fi

if command -v whiptail >/dev/null 2>&1; then
  args=()
  for index in "${!ids[@]}"; do
    args+=("${ids[$index]}" "${names[$index]} - ${summaries[$index]}" off)
  done
  if selection="$(
    whiptail \
      --separate-output \
      --output-fd 3 \
      --title "Demuntu Package Sets" \
      --checklist "Choose optional package sets for this system." \
      20 78 10 \
      "${args[@]}" \
      3>&1 1>"$tty" 2>"$tty"
  )"; then
    printf '%s\n' "$selection" | awk 'NF { if (out) out=out "," $0; else out=$0 } END { print out ? out : "none" }'
    exit 0
  fi
  printf 'none\n'
  exit 0
fi

{
  printf '\nDemuntu Package Sets\n\n'
  printf 'Choose optional package sets for this system.\n'
  printf 'Enter numbers separated by commas, or press Enter for none.\n\n'
  for index in "${!ids[@]}"; do
    printf '  %d. %s - %s\n' "$((index + 1))" "${names[$index]}" "${summaries[$index]}"
  done
  printf '\nSelection: '
} > "$tty"

IFS= read -r reply < "$tty" || reply=""
reply="${reply//,/ }"

selected=()
for item in $reply; do
  case "$item" in
    ''|*[!0-9]*)
      continue
      ;;
  esac
  if [ "$item" -ge 1 ] && [ "$item" -le "${#ids[@]}" ]; then
    selected+=("${ids[$((item - 1))]}")
  fi
done

if [ "${#selected[@]}" -eq 0 ]; then
  printf 'none\n'
else
  (IFS=,; printf '%s\n' "${selected[*]}")
fi
