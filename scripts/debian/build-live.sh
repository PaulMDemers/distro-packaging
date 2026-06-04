#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: build-live.sh CONFIG_DIR" >&2
  exit 2
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "build-live.sh must run as root because live-build uses chroot and mounts" >&2
  exit 1
fi

config_dir="$(realpath "$1")"
profile_env="$config_dir/profile.env"

if [ ! -f "$profile_env" ]; then
  echo "missing profile: $profile_env" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$profile_env"

: "${DEBIAN_RELEASE:=trixie}"
: "${ARCHITECTURE:=amd64}"
: "${ARCHIVE_AREAS:=main contrib non-free-firmware}"
: "${MIRROR_BOOTSTRAP:=http://deb.debian.org/debian/}"
: "${MIRROR_CHROOT_SECURITY:=http://security.debian.org/debian-security/}"
: "${IMAGE_NAME:=demian-live}"
: "${BOOTAPPEND_LIVE:=components quiet}"
: "${BOOT_TIMEOUT_TENTHS:=0}"
: "${SERIAL_CONSOLE:=false}"
: "${CUSTOM_METAPACKAGES:=}"
: "${LOCAL_PACKAGE_DIR:=$(pwd)/dist/packages}"
: "${LIVE_APT_OPTIONS:=--yes -o Acquire::AllowInsecureRepositories=true -o APT::Get::AllowUnauthenticated=true}"

case "$IMAGE_NAME" in
  demian-desktop-live)
    boot_family="demian"
    boot_title="Demian Desktop"
    boot_live_label="^Try Demian Desktop"
    boot_failsafe_label="Demian Desktop (^safe graphics)"
    ;;
  demian-rescue-live)
    boot_family="demian"
    boot_title="Demian Rescue"
    boot_live_label="^Start Demian Rescue"
    boot_failsafe_label="Demian Rescue (^safe graphics)"
    ;;
  demian-server-live)
    boot_family="demian"
    boot_title="Demian Server"
    boot_live_label="^Start Demian Server"
    boot_failsafe_label="Demian Server (^safe graphics)"
    ;;
  *)
    boot_family="demian"
    boot_title="$IMAGE_NAME"
    boot_live_label="^Start live system"
    boot_failsafe_label="Live system (^safe graphics)"
    ;;
esac

build_root="${BUILD_ROOT:-$(pwd)/build}"
work_dir="$build_root/debian/$IMAGE_NAME"
out_dir="$(pwd)/dist/images"
repo_root="$(pwd)"

rm -rf "$work_dir"
mkdir -p "$work_dir" "$out_dir"

cd "$work_dir"

lb config \
  --mode debian \
  --distribution "$DEBIAN_RELEASE" \
  --architectures "$ARCHITECTURE" \
  --archive-areas "$ARCHIVE_AREAS" \
  --linux-flavours amd64 \
  --linux-packages linux-image \
  --firmware-chroot false \
  --firmware-binary false \
  --initsystem systemd \
  --apt-secure false \
  --apt-options "$LIVE_APT_OPTIONS" \
  --mirror-bootstrap "$MIRROR_BOOTSTRAP" \
  --mirror-chroot-security "$MIRROR_CHROOT_SECURITY" \
  --security false \
  --binary-images iso-hybrid \
  --bootloader syslinux \
  --bootappend-live "$BOOTAPPEND_LIVE" \
  --debian-installer false

mkdir -p config/package-lists config/packages.chroot config/hooks config/bootloaders/isolinux

cp -a /usr/share/live/build/bootloaders/isolinux/. config/bootloaders/isolinux/
rm -f config/bootloaders/isolinux/splash.svg.in
if [ -f config/bootloaders/isolinux/stdmenu.cfg ]; then
  sed -i '/^menu background /d' config/bootloaders/isolinux/stdmenu.cfg
  cat >> config/bootloaders/isolinux/stdmenu.cfg <<'EOF'
menu background splash.png
menu color title	* #FFFFFFFF *
menu color border	* #00000000 #00000000 none
menu color sel		* #ffffffff #b51a20ff *
menu color hotsel	1;7;37;40 #ffffffff #b51a20ff *
menu color help		37;40 #ffd8d8d8 #00000000 none
EOF
fi
if [ -f "$repo_root/assets/boot/$boot_family-isolinux.png" ]; then
  cp "$repo_root/assets/boot/$boot_family-isolinux.png" config/bootloaders/isolinux/splash.png
fi
if [ -f config/bootloaders/isolinux/menu.cfg ]; then
  sed -i "s/^menu title .*/menu title $boot_title/" config/bootloaders/isolinux/menu.cfg
fi
if [ -f config/bootloaders/isolinux/live.cfg.in ]; then
  sed -i \
    -e "s/menu label \^Live (@FLAVOUR@ failsafe)/menu label $boot_failsafe_label/" \
    -e "s/menu label \^Live (@FLAVOUR@)/menu label $boot_live_label/" \
    config/bootloaders/isolinux/live.cfg.in
fi
if [ -f config/bootloaders/isolinux/isolinux.cfg ]; then
  sed -i "s/^timeout .*/timeout $BOOT_TIMEOUT_TENTHS/" config/bootloaders/isolinux/isolinux.cfg
  if [ "$SERIAL_CONSOLE" = "true" ]; then
    sed -i '/^serial /d;/^SERIAL /d' config/bootloaders/isolinux/isolinux.cfg
    sed -i '1iserial 0 115200' config/bootloaders/isolinux/isolinux.cfg
  fi
fi
tmp_bootlogo="$(mktemp -d)"
(cd "$tmp_bootlogo" && find . -mindepth 1 -print | cpio --quiet -o) > config/bootloaders/isolinux/bootlogo
rm -rf "$tmp_bootlogo"
if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
  rm -f config/bootloaders/isolinux/isolinux.bin
  cp /usr/lib/ISOLINUX/isolinux.bin config/bootloaders/isolinux/isolinux.bin
fi
if [ -d /usr/lib/syslinux/modules/bios ]; then
  rm -f config/bootloaders/isolinux/vesamenu.c32
  cp /usr/lib/syslinux/modules/bios/vesamenu.c32 config/bootloaders/isolinux/vesamenu.c32
  cp /usr/lib/syslinux/modules/bios/ldlinux.c32 config/bootloaders/isolinux/ldlinux.c32
  cp /usr/lib/syslinux/modules/bios/libcom32.c32 config/bootloaders/isolinux/libcom32.c32
  cp /usr/lib/syslinux/modules/bios/libutil.c32 config/bootloaders/isolinux/libutil.c32
fi

if [ -d "$config_dir/package-lists" ]; then
  cp -a "$config_dir/package-lists/." config/package-lists/
fi

if [ -n "$CUSTOM_METAPACKAGES" ]; then
  if [ ! -d "$LOCAL_PACKAGE_DIR" ]; then
    echo "missing local package directory: $LOCAL_PACKAGE_DIR" >&2
    echo "build packages first: make packages" >&2
    exit 1
  fi

  for package_name in $CUSTOM_METAPACKAGES; do
    mapfile -t package_matches < <(
      find "$LOCAL_PACKAGE_DIR" -maxdepth 1 -type f \
        \( -name "${package_name}_*_${ARCHITECTURE}.deb" -o -name "${package_name}_*_all.deb" \) \
        | sort -V
    )

    if [ "${#package_matches[@]}" -eq 0 ]; then
      echo "missing metapackage for $package_name in $LOCAL_PACKAGE_DIR" >&2
      echo "build packages first: make packages" >&2
      exit 1
    fi

    last_match_index=$((${#package_matches[@]} - 1))
    package_deb="${package_matches[$last_match_index]}"
    cp "$package_deb" config/packages.chroot/
    echo "added local package: $(basename "$package_deb")"
  done
fi

if [ -d "$config_dir/hooks" ]; then
  for hook in "$config_dir"/hooks/*; do
    [ -f "$hook" ] || continue
    hook_name="$(basename "$hook")"
    case "$hook_name" in
      *.hook.chroot)
        hook_name="${hook_name%.hook.chroot}.chroot"
        ;;
    esac
    cp "$hook" "config/hooks/$hook_name"
    chmod +x "config/hooks/$hook_name"
  done
fi

lb build

iso="$(find . -maxdepth 1 -type f -name '*.iso' | head -n 1)"
if [ -z "$iso" ]; then
  echo "live-build completed but no ISO was found" >&2
  exit 1
fi

target="$out_dir/$IMAGE_NAME-$DEBIAN_RELEASE-$ARCHITECTURE.iso"
cp "$iso" "$target"
(cd "$out_dir" && sha256sum "$(basename "$target")") | tee "$target.sha256"

echo "$target"
