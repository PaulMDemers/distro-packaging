#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Usage: sudo $0 [debian|ubuntu|all]" >&2
  exit 1
fi

target="${1:-all}"

common_packages=(
  ca-certificates
  coreutils
  curl
  build-essential
  debhelper
  devscripts
  dpkg-dev
  git
  lintian
  p7zip-full
  qemu-system-x86
  qemu-utils
  rsync
  shellcheck
  squashfs-tools
  syslinux-utils
  xorriso
)

debian_packages=(
  live-build
  debootstrap
  mmdebstrap
  simple-cdd
)

ubuntu_packages=(
  cloud-image-utils
)

apt-get update

case "$target" in
  all)
    apt-get install -y "${common_packages[@]}" "${debian_packages[@]}" "${ubuntu_packages[@]}"
    ;;
  debian)
    apt-get install -y "${common_packages[@]}" "${debian_packages[@]}"
    ;;
  ubuntu)
    apt-get install -y "${common_packages[@]}" "${ubuntu_packages[@]}"
    ;;
  *)
    echo "unknown dependency target: $target" >&2
    echo "expected one of: debian, ubuntu, all" >&2
    exit 2
    ;;
esac
