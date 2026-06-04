#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:-packages/meta/demian-meta}"
output_dir="${OUTPUT_DIR:-dist/packages}"

if [ ! -d "$source_dir/debian" ]; then
  echo "missing Debian package source: $source_dir" >&2
  exit 1
fi

if ! command -v dpkg-buildpackage >/dev/null 2>&1; then
  echo "missing dpkg-buildpackage; run: sudo ./scripts/common/install-deps.sh all" >&2
  exit 1
fi

if ! command -v dpkg-checkbuilddeps >/dev/null 2>&1; then
  echo "missing dpkg-checkbuilddeps; run: sudo ./scripts/common/install-deps.sh all" >&2
  exit 1
fi

if ! (
  cd "$source_dir"
  dpkg-checkbuilddeps
); then
  echo "package build dependencies are missing; run: sudo ./scripts/common/install-deps.sh all" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "missing rsync; run: sudo ./scripts/common/install-deps.sh all" >&2
  exit 1
fi

build_root="$(mktemp -d "${TMPDIR:-/tmp}/distro-pkg.XXXXXX")"
trap 'rm -rf "$build_root"' EXIT

build_source="$build_root/$(basename "$source_dir")"
rsync -a \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='debian/.debhelper/' \
  --exclude='debian/debhelper-build-stamp' \
  --exclude='debian/files' \
  --exclude='debian/*.substvars' \
  --exclude='debian/*-*/' \
  "$source_dir/" "$build_source/"

package_family=""
case "$(basename "$source_dir")" in
  demian-meta)
    package_family="demian"
    ;;
  demuntu-meta)
    package_family="demuntu"
    ;;
esac

if [ -n "$package_family" ] && [ -d "scripts/package-sets" ]; then
  package_sets_target="$build_source/branding/usr/lib/$package_family/package-sets"
  rm -rf "$package_sets_target"
  mkdir -p "$package_sets_target"
  rsync -a "scripts/package-sets/." "$package_sets_target/"

  if [ -d "configs/package-sets" ]; then
    mkdir -p "$package_sets_target/configs"
    rsync -a "configs/package-sets/." "$package_sets_target/configs/"
  fi
fi

find "$build_source" -type d -exec chmod 0755 {} +
find "$build_source" -type f -exec chmod 0644 {} +
chmod 0755 "$build_source/debian/rules"
find "$build_source/debian" -maxdepth 1 -type f -name '*.postinst' -exec chmod 0755 {} +

if [ -n "$package_family" ]; then
  find "$build_source/branding/usr/bin" -type f -exec chmod 0755 {} + 2>/dev/null || true
  find "$build_source/branding/etc/skel/Desktop" -type f -name '*.desktop' \
    -exec chmod 0755 {} + 2>/dev/null || true
  find "$build_source/branding/usr/lib/$package_family" -maxdepth 1 -type f \
    \( -name 'apply-*' -o -name "$package_family-welcome" \) \
    -exec chmod 0755 {} + 2>/dev/null || true
  find "$build_source/branding/usr/lib/$package_family/package-sets" -type f -name '*.sh' \
    -exec chmod 0755 {} + 2>/dev/null || true
fi

if ! (
  cd "$build_source"
  dpkg-checkbuilddeps
); then
  echo "package build dependencies are missing; run: sudo ./scripts/common/install-deps.sh all" >&2
  exit 1
fi

mkdir -p "$output_dir"

(
  cd "$build_source"
  dpkg-buildpackage -us -uc -b
)

find "$build_root" -maxdepth 1 -type f \( -name '*.deb' -o -name '*.buildinfo' -o -name '*.changes' \) \
  -exec mv -f {} "$output_dir/" \;

ls -1 "$output_dir"
