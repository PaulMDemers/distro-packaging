#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: rebrand-initrd.sh INITRD_PATH desktop|server ASSET_DIR" >&2
  exit 2
fi

initrd="$(realpath "$1")"
mode="$2"
asset_dir="$(realpath "$3")"

if [ ! -f "$initrd" ]; then
  echo "missing initrd: $initrd" >&2
  exit 1
fi

case "$mode" in
  desktop|server) ;;
  *)
    echo "mode must be desktop or server" >&2
    exit 2
    ;;
esac

for cmd in unmkinitramfs cpio zstd; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 1
  fi
done

work_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

unmkinitramfs "$initrd" "$work_dir"
main="$work_dir/main"

if [ ! -d "$main" ]; then
  echo "initrd did not unpack into a main initramfs tree" >&2
  exit 1
fi

mkdir -p "$main/etc" "$main/etc/plymouth" "$main/usr/share/plymouth/themes/demuntu-text"

cat > "$main/etc/os-release" <<'EOF'
PRETTY_NAME="Demuntu 0.1 (Resolute)"
NAME="Demuntu"
VERSION_ID="0.1"
VERSION="0.1"
VERSION_CODENAME=resolute
ID=demuntu
ID_LIKE="ubuntu debian"
HOME_URL="https://demuntu.local/"
SUPPORT_URL="https://demuntu.local/support"
BUG_REPORT_URL="https://demuntu.local/bugs"
LOGO=distributor-logo-demuntu
EOF

cat > "$main/etc/plymouth/plymouthd.conf" <<EOF
[Daemon]
Theme=$([ "$mode" = desktop ] && printf '%s' bgrt || printf '%s' demuntu-text)
ShowDelay=0
EOF

cat > "$main/usr/share/plymouth/themes/demuntu-text/demuntu-text.plymouth" <<'EOF'
[Plymouth Theme]
Name=Demuntu Text
Description=Text mode theme for Demuntu
ModuleName=ubuntu-text

[ubuntu-text]
title=Demuntu 26.04
black=0x111113
white=0xf1f3f4
brown=0xd71920
blue=0xb9c0c5
EOF

mkdir -p "$main/usr/share/plymouth/themes/ubuntu-text"
cp "$main/usr/share/plymouth/themes/demuntu-text/demuntu-text.plymouth" \
  "$main/usr/share/plymouth/themes/ubuntu-text/ubuntu-text.plymouth"
ln -sfn /usr/share/plymouth/themes/demuntu-text/demuntu-text.plymouth \
  "$main/usr/share/plymouth/themes/text.plymouth"

if [ "$mode" = desktop ]; then
  watermark="$asset_dir/demuntu-plymouth-watermark.png"
  if [ ! -f "$watermark" ]; then
    echo "missing Plymouth watermark: $watermark" >&2
    exit 1
  fi

  mkdir -p "$main/usr/share/pixmaps" "$main/usr/share/plymouth/themes/spinner"
  install -m 0644 "$watermark" "$main/usr/share/pixmaps/demuntu-plymouth-watermark.png"
  rm -f "$main/usr/share/pixmaps/ubuntu-logo-text-dark.png"
  ln -sfn ../../../pixmaps/demuntu-plymouth-watermark.png \
    "$main/usr/share/plymouth/themes/spinner/watermark.png"

  if [ -f "$main/usr/share/plymouth/themes/bgrt/bgrt.plymouth" ]; then
    sed -i \
      -e 's/^Name=.*/Name=Demuntu BGRT/' \
      -e "s/^Description=.*/Description=Demuntu spinner theme using the firmware background/" \
      -e 's/^Font=.*/Font=DejaVu Sans 12/' \
      -e 's/^TitleFont=.*/TitleFont=DejaVu Sans 30/' \
      "$main/usr/share/plymouth/themes/bgrt/bgrt.plymouth"
  fi

  if [ -f "$main/usr/share/plymouth/themes/spinner/spinner.plymouth" ]; then
    sed -i \
      -e 's/^Name=.*/Name=Demuntu Spinner/' \
      -e "s/^Description=.*/Description=Demuntu spinner theme/" \
      -e 's/^Font=.*/Font=DejaVu Sans 12/' \
      -e 's/^TitleFont=.*/TitleFont=DejaVu Sans 30/' \
      "$main/usr/share/plymouth/themes/spinner/spinner.plymouth"
  fi
else
  ln -sfn /usr/share/plymouth/themes/demuntu-text/demuntu-text.plymouth \
    "$main/usr/share/plymouth/themes/default.plymouth"
fi

tmp_initrd="$work_dir/initrd"
: > "$tmp_initrd"

for part in early early2; do
  if [ -d "$work_dir/$part" ]; then
    (
      cd "$work_dir/$part"
      find . -print0 | sort -z | cpio --null --quiet --reproducible -o -H newc
    ) >> "$tmp_initrd"
  fi
done

(
  cd "$main"
  find . -print0 | sort -z | cpio --null --quiet --reproducible -o -H newc | zstd -19 -q -T0
) >> "$tmp_initrd"

install -m 0644 "$tmp_initrd" "$initrd"
