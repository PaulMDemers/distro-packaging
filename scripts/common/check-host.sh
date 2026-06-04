#!/usr/bin/env bash
set -euo pipefail

required=(
  awk
  curl
  sha256sum
  xorriso
  unsquashfs
  mksquashfs
)

optional=(
  lb
  qemu-system-x86_64
  7z
)

missing=0

for cmd in "${required[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    missing=1
  fi
done

for cmd in "${optional[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing optional command: $cmd" >&2
  fi
done

if [ "$(id -u)" -eq 0 ]; then
  echo "running as root: yes"
else
  echo "running as root: no"
fi

echo "kernel: $(uname -srm)"
echo "workspace: $(pwd)"

if grep -qi microsoft /proc/version 2>/dev/null && [ "${PWD#/mnt/}" != "$PWD" ]; then
  echo "warning: workspace is on a Windows-mounted path; prefer copying to ~/src/distro before ISO builds" >&2
fi

exit "$missing"
