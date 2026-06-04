#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  profile-info.sh list
  profile-info.sh PROFILE_ID FIELD

Fields:
  id, family, kind, profile_dir, description, image_name, iso, sha256,
  serial_log, boot_marker, boot_timeout, memory, metapackages, base_alias, base_iso,
  screenshot, disk, install_serial_log, boot_serial_log, install_cpus, install_timeout,
  install_complete_marker, install_boot_timeout
EOF
}

registry="${PROFILE_REGISTRY:-configs/profiles.tsv}"

if [ "$#" -lt 1 ]; then
  usage
  exit 2
fi

if [ ! -f "$registry" ]; then
  echo "missing profile registry: $registry" >&2
  exit 1
fi

if [ "$1" = "list" ]; then
  awk -F '\t' 'NR > 1 { printf "%-28s %-8s %-12s %s\n", $1, $2, $3, $5 }' "$registry"
  exit 0
fi

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

profile_id="$1"
field="$2"
family=""
kind=""
profile_dir=""
description=""

while IFS=$'\t' read -r id row_family row_kind row_profile_dir row_description; do
  if [ "$id" = "id" ]; then
    continue
  fi
  if [ "$id" = "$profile_id" ]; then
    family="$row_family"
    kind="$row_kind"
    profile_dir="$row_profile_dir"
    description="$row_description"
    break
  fi
done < "$registry"

if [ -z "$profile_dir" ]; then
  echo "unknown profile: $profile_id" >&2
  exit 1
fi

profile_env="$profile_dir/profile.env"
if [ ! -f "$profile_env" ]; then
  echo "missing profile env: $profile_env" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$profile_env"

: "${IMAGE_NAME:=$profile_id}"
: "${ARCHITECTURE:=amd64}"
: "${DEBIAN_RELEASE:=}"
: "${BOOT_MARKER:=}"
: "${BOOT_TEST_TIMEOUT:=300}"
: "${BOOT_TEST_MEMORY:=2048}"
: "${UBUNTU_BASE_ALIAS:=}"
: "${UBUNTU_BASE_ISO:=}"
: "${INSTALL_TEST_TIMEOUT:=3600}"
: "${INSTALL_COMPLETE_MARKER:=}"
: "${INSTALL_BOOT_TEST_TIMEOUT:=300}"
: "${CUSTOM_METAPACKAGES:=}"

case "$family:$kind" in
  debian:live)
    default_iso="dist/images/${IMAGE_NAME}-${DEBIAN_RELEASE}-${ARCHITECTURE}.iso"
    default_serial_log="dist/images/${IMAGE_NAME}-${DEBIAN_RELEASE}-${ARCHITECTURE}-serial.log"
    ;;
  ubuntu:autoinstall)
    default_iso="dist/images/${IMAGE_NAME}.iso"
    default_serial_log="build/test/${IMAGE_NAME}-serial.log"
    ;;
  *)
    default_iso="dist/images/${IMAGE_NAME}.iso"
    default_serial_log="build/test/${IMAGE_NAME}-serial.log"
    ;;
esac

: "${ISO_PATH:=$default_iso}"
: "${SERIAL_LOG:=$default_serial_log}"
: "${SCREENSHOT:=${ISO_PATH%.iso}-qemu.ppm}"
: "${INSTALL_DISK:=build/test/${IMAGE_NAME}.qcow2}"
: "${INSTALL_CPUS:=2}"
: "${INSTALL_BOOT_SERIAL_LOG:=build/test/${DISTRO_NAME:-$IMAGE_NAME}-installed-boot-serial.log}"

case "$field" in
  id) printf '%s\n' "$profile_id" ;;
  family) printf '%s\n' "$family" ;;
  kind) printf '%s\n' "$kind" ;;
  profile_dir) printf '%s\n' "$profile_dir" ;;
  description) printf '%s\n' "$description" ;;
  image_name) printf '%s\n' "$IMAGE_NAME" ;;
  iso) printf '%s\n' "$ISO_PATH" ;;
  sha256) printf '%s\n' "$ISO_PATH.sha256" ;;
  serial_log) printf '%s\n' "$SERIAL_LOG" ;;
  boot_marker) printf '%s\n' "$BOOT_MARKER" ;;
  boot_timeout) printf '%s\n' "$BOOT_TEST_TIMEOUT" ;;
  memory) printf '%s\n' "$BOOT_TEST_MEMORY" ;;
  metapackages) printf '%s\n' "$CUSTOM_METAPACKAGES" ;;
  base_alias) printf '%s\n' "$UBUNTU_BASE_ALIAS" ;;
  base_iso) printf '%s\n' "$UBUNTU_BASE_ISO" ;;
  screenshot) printf '%s\n' "$SCREENSHOT" ;;
  disk) printf '%s\n' "$INSTALL_DISK" ;;
  install_cpus) printf '%s\n' "$INSTALL_CPUS" ;;
  install_serial_log) printf '%s\n' "$SERIAL_LOG" ;;
  boot_serial_log) printf '%s\n' "$INSTALL_BOOT_SERIAL_LOG" ;;
  install_timeout) printf '%s\n' "$INSTALL_TEST_TIMEOUT" ;;
  install_complete_marker) printf '%s\n' "$INSTALL_COMPLETE_MARKER" ;;
  install_boot_timeout) printf '%s\n' "$INSTALL_BOOT_TEST_TIMEOUT" ;;
  *)
    echo "unknown field: $field" >&2
    usage
    exit 2
    ;;
esac
