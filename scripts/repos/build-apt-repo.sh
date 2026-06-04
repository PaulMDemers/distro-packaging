#!/usr/bin/env bash
set -euo pipefail

packages_dir="${1:-dist/packages}"
repo_dir="${2:-dist/repo}"
suite="${REPO_SUITE:-custom}"
component="${REPO_COMPONENT:-main}"
origin="${REPO_ORIGIN:-Local Spins}"
label="${REPO_LABEL:-Local Spins}"
description="${REPO_DESCRIPTION:-Local distro package repository}"

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
  echo "missing dpkg-scanpackages; run: sudo ./scripts/common/install-deps.sh all" >&2
  exit 1
fi

if ! command -v apt-ftparchive >/dev/null 2>&1; then
  echo "missing apt-ftparchive; run: sudo apt-get install -y apt-utils" >&2
  exit 1
fi

if [ ! -d "$packages_dir" ]; then
  echo "missing package output directory: $packages_dir" >&2
  echo "build packages first: make packages" >&2
  exit 1
fi

mapfile -t debs < <(find "$packages_dir" -maxdepth 1 -type f -name '*.deb' | sort)
if [ "${#debs[@]}" -eq 0 ]; then
  echo "no .deb files found in $packages_dir" >&2
  echo "build packages first: make packages" >&2
  exit 1
fi

rm -rf "$repo_dir"
mkdir -p \
  "$repo_dir/pool/$component" \
  "$repo_dir/dists/$suite/$component/binary-amd64"

cp -f "${debs[@]}" "$repo_dir/pool/$component/"

(
  cd "$repo_dir"
  dpkg-scanpackages --multiversion "pool/$component" /dev/null \
    > "dists/$suite/$component/binary-amd64/Packages"
  gzip -9 -kf "dists/$suite/$component/binary-amd64/Packages"

  apt-ftparchive \
    -o "APT::FTPArchive::Release::Origin=$origin" \
    -o "APT::FTPArchive::Release::Label=$label" \
    -o "APT::FTPArchive::Release::Suite=$suite" \
    -o "APT::FTPArchive::Release::Codename=$suite" \
    -o "APT::FTPArchive::Release::Architectures=amd64 all" \
    -o "APT::FTPArchive::Release::Components=$component" \
    -o "APT::FTPArchive::Release::Description=$description" \
    release "dists/$suite" > "dists/$suite/Release"
)

cat > "$repo_dir/README.txt" <<EOF
Local APT repository
====================

Unsigned development repository for local distro packages.

Add from this workspace with:

  deb [trusted=yes] file:$(cd "$repo_dir" && pwd) $suite $component

For ISO builds, prefer adding this repository through the profile build scripts
instead of leaving it configured in a developer machine.
EOF

echo "wrote $repo_dir"
