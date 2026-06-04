#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: build-server-autoinstall.sh BASE_ISO CONFIG_DIR" >&2
  exit 2
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "build-server-autoinstall.sh must run as root to preserve ISO file modes" >&2
  exit 1
fi

base_iso="$(realpath "$1")"
config_dir="$(realpath "$2")"
profile_env="$config_dir/profile.env"

if [ ! -f "$base_iso" ]; then
  echo "missing base ISO: $base_iso" >&2
  exit 1
fi

if [ ! -f "$profile_env" ]; then
  echo "missing profile: $profile_env" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$profile_env"

: "${IMAGE_NAME:=demuntu-server-autoinstall}"
: "${VOLUME_ID:=DEMUNTU_SERVER}"
: "${ARCHITECTURE:=amd64}"
: "${CUSTOM_METAPACKAGES:=}"
: "${LOCAL_PACKAGE_DIR:=dist/packages}"

repo_root="$(pwd)"
build_root="${BUILD_ROOT:-$repo_root/build}"
work_dir="$build_root/ubuntu/$IMAGE_NAME"
out_dir="$repo_root/dist/images"

for cmd in unmkinitramfs zstd; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 1
  fi
done

copy_custom_metapackages() {
  local target_dir="$1"
  local package_dir="$LOCAL_PACKAGE_DIR"
  local package
  local match

  [ -n "$CUSTOM_METAPACKAGES" ] || return 0

  if [[ "$package_dir" != /* ]]; then
    package_dir="$repo_root/$package_dir"
  fi

  if [ ! -d "$package_dir" ]; then
    echo "missing local package directory: $package_dir" >&2
    exit 1
  fi

  mkdir -p "$target_dir"
  for package in $CUSTOM_METAPACKAGES; do
    match="$(
      find "$package_dir" -maxdepth 1 -type f \
        \( -name "${package}_*_all.deb" -o -name "${package}_*_${ARCHITECTURE}.deb" \) \
        | sort -V \
        | tail -n 1
    )"
    if [ -z "$match" ]; then
      echo "missing local package for $package in $package_dir" >&2
      exit 1
    fi
    install -m 0644 "$match" "$target_dir/"
  done
}

copy_package_sets() {
  local target_dir="$1"
  local scripts_dir="$repo_root/scripts/package-sets"
  local config_sets_dir="$repo_root/configs/package-sets"

  [ -d "$scripts_dir" ] || return 0

  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  cp -a "$scripts_dir/." "$target_dir/"

  if [ -d "$config_sets_dir" ]; then
    mkdir -p "$target_dir/configs"
    cp -a "$config_sets_dir/." "$target_dir/configs/"
  fi

  find "$target_dir" -type f -name '*.sh' -exec chmod 0755 {} +
  find "$target_dir" -type f ! -name '*.sh' -exec chmod 0644 {} +
}

rm -rf "$work_dir"
mkdir -p "$work_dir/extract" "$out_dir"

if command -v 7z >/dev/null 2>&1; then
  7z x -y "-o$work_dir/extract" "$base_iso" >/dev/null
else
  echo "missing 7z; install p7zip-full" >&2
  exit 1
fi

mkdir -p "$work_dir/extract/nocloud"
cp -a "$config_dir/nocloud/." "$work_dir/extract/nocloud/"
copy_custom_metapackages "$work_dir/extract/demuntu/packages"
copy_package_sets "$work_dir/extract/demuntu/package-sets"

grub_cfg="$work_dir/extract/boot/grub/grub.cfg"
if [ ! -f "$grub_cfg" ]; then
  echo "could not find GRUB config in extracted ISO" >&2
  exit 1
fi

tmp_grub="$(mktemp)"
if [ -f "$repo_root/assets/boot/demuntu-isolinux.png" ]; then
  cp "$repo_root/assets/boot/demuntu-isolinux.png" "$work_dir/extract/boot/grub/demuntu-grub.png"
fi
cat > "$tmp_grub" <<'EOF'
set timeout=20
loadfont unicode
insmod all_video
insmod gfxterm
insmod png
set gfxmode=auto
terminal_output gfxterm
if background_image /boot/grub/demuntu-grub.png; then
    set color_normal=light-gray/black
    set color_highlight=white/red
else
    set menu_color_normal=white/black
    set menu_color_highlight=black/light-gray
fi

menuentry "Autoinstall Demuntu Server" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ console=tty0 console=ttyS0,115200n8 ---
    initrd  /casper/initrd
}

menuentry "Autoinstall Demuntu Server (choose package sets)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ demuntu.package_sets=ask console=tty0 console=ttyS0,115200n8 ---
    initrd  /casper/initrd
}

menuentry "Autoinstall Demuntu Server (Node Developer automation)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ demuntu.package_sets=node-developer console=tty0 console=ttyS0,115200n8 ---
    initrd  /casper/initrd
}

menuentry "Autoinstall Demuntu Server (Python Developer automation)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ demuntu.package_sets=python-developer console=tty0 console=ttyS0,115200n8 ---
    initrd  /casper/initrd
}

menuentry "Autoinstall Demuntu Server (.NET Developer automation)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ demuntu.package_sets=dotnet-developer console=tty0 console=ttyS0,115200n8 ---
    initrd  /casper/initrd
}

menuentry "Autoinstall Demuntu Server (Git GUI Tools automation)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ demuntu.package_sets=git-gui-tools console=tty0 console=ttyS0,115200n8 ---
    initrd  /casper/initrd
}

menuentry "Autoinstall Demuntu Server (Docker GUI Tools automation)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ demuntu.package_sets=docker-gui-tools console=tty0 console=ttyS0,115200n8 ---
    initrd  /casper/initrd
}

EOF
cat "$grub_cfg" >> "$tmp_grub"
cp "$tmp_grub" "$grub_cfg"
rm -f "$tmp_grub"
sed -i \
  -e 's/Try or Install Ubuntu Server/Try or Install Demuntu Server/g' \
  "$grub_cfg"

if [ -f "$work_dir/extract/boot/grub/loopback.cfg" ]; then
  sed -i \
    -e 's/Try or Install Ubuntu Server/Try or Install Demuntu Server/g' \
    "$work_dir/extract/boot/grub/loopback.cfg"
fi

if [ -f "$work_dir/extract/.disk/info" ]; then
  printf 'Demuntu Server 26.04 "Resolute" - Release %s\n' "$ARCHITECTURE" > "$work_dir/extract/.disk/info"
fi

if [ -f "$work_dir/extract/casper/initrd" ]; then
  "$repo_root/scripts/ubuntu/rebrand-initrd.sh" \
    "$work_dir/extract/casper/initrd" \
    server \
    "$repo_root/assets/boot"
fi

(cd "$work_dir/extract" && find . -type f ! -name md5sum.txt -print0 | sort -z | xargs -0 md5sum) \
  > "$work_dir/extract/md5sum.txt"

target="$out_dir/$IMAGE_NAME.iso"
efi_img="$work_dir/efi.img"
mbr_img="$work_dir/mbr.img"

if [ -f "$work_dir/extract/boot/grub/efi.img" ]; then
  cp "$work_dir/extract/boot/grub/efi.img" "$efi_img"
elif [ -f "$work_dir/extract/[BOOT]/2-Boot-NoEmul.img" ]; then
  cp "$work_dir/extract/[BOOT]/2-Boot-NoEmul.img" "$efi_img"
else
  echo "could not find EFI boot image in extracted ISO" >&2
  exit 1
fi

dd if="$base_iso" of="$mbr_img" bs=1 count=32768 status=none
rm -rf "$work_dir/extract/[BOOT]"
efi_boot_load_size="$(( ($(stat -c '%s' "$efi_img") + 511) / 512 ))"

xorriso -as mkisofs \
  -r -V "$VOLUME_ID" \
  -o "$target" \
  -J -joliet-long -l \
  -iso-level 3 \
  --grub2-mbr "$mbr_img" \
  --protective-msdos-label \
  --mbr-force-bootable \
  -partition_offset 16 \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$efi_img" \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c boot.catalog \
  -b boot/grub/i386-pc/eltorito.img \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2:all::' \
  -no-emul-boot -boot-load-size "$efi_boot_load_size" \
  "$work_dir/extract"

(cd "$out_dir" && sha256sum "$(basename "$target")") | tee "$target.sha256"
echo "$target"
