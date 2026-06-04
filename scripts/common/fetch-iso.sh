#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  fetch-iso.sh ubuntu-26.04-lts-live-server-amd64
  fetch-iso.sh ubuntu-26.04-lts-desktop-amd64
  fetch-iso.sh ubuntu-24.04-lts-live-server-amd64
  fetch-iso.sh ubuntu-24.04-lts-desktop-amd64
  fetch-iso.sh URL [sha256]
EOF
}

if [ "$#" -lt 1 ]; then
  usage
  exit 2
fi

mkdir -p dist/downloads

case "$1" in
  ubuntu-26.04-lts-live-server-amd64|ubuntu-26.04-live-server-amd64)
    url="https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso"
    sha_url="https://releases.ubuntu.com/26.04/SHA256SUMS"
    ;;
  ubuntu-26.04-lts-desktop-amd64|ubuntu-26.04-desktop-amd64)
    url="https://releases.ubuntu.com/26.04/ubuntu-26.04-desktop-amd64.iso"
    sha_url="https://releases.ubuntu.com/26.04/SHA256SUMS"
    ;;
  ubuntu-24.04-lts-live-server-amd64|ubuntu-24.04.4-live-server-amd64)
    url="https://releases.ubuntu.com/24.04.4/ubuntu-24.04.4-live-server-amd64.iso"
    sha_url="https://releases.ubuntu.com/24.04.4/SHA256SUMS"
    ;;
  ubuntu-24.04-lts-desktop-amd64|ubuntu-24.04.4-desktop-amd64)
    url="https://releases.ubuntu.com/24.04.4/ubuntu-24.04.4-desktop-amd64.iso"
    sha_url="https://releases.ubuntu.com/24.04.4/SHA256SUMS"
    ;;
  http://*|https://*)
    url="$1"
    sha_url=""
    ;;
  *)
    echo "unknown ISO alias or URL: $1" >&2
    usage
    exit 2
    ;;
esac

iso_name="$(basename "$url")"
iso_path="dist/downloads/$iso_name"

if [ ! -f "$iso_path" ]; then
  curl -L --fail --output "$iso_path" "$url"
else
  echo "already downloaded: $iso_path"
fi

if [ "$#" -ge 2 ]; then
  printf '%s  %s\n' "$2" "$iso_path" | sha256sum -c -
elif [ -n "$sha_url" ]; then
  tmp="$(mktemp)"
  curl -L --fail --output "$tmp" "$sha_url"
  expected="$(awk -v f="$iso_name" '$2 == "*" f || $2 == f { print $1 }' "$tmp")"
  rm -f "$tmp"
  if [ -z "$expected" ]; then
    echo "could not find checksum for $iso_name" >&2
    exit 1
  fi
  printf '%s  %s\n' "$expected" "$iso_path" | sha256sum -c -
else
  sha256sum "$iso_path" | tee "$iso_path.sha256"
fi

echo "$iso_path"
