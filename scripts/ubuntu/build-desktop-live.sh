#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: build-desktop-live.sh BASE_ISO CONFIG_DIR" >&2
  exit 2
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "build-desktop-live.sh must run as root to unpack and repack the live filesystem" >&2
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

for cmd in 7z unsquashfs mksquashfs xorriso unmkinitramfs zstd curl gpg python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 1
  fi
done

# shellcheck disable=SC1090
. "$profile_env"

: "${IMAGE_NAME:=demuntu-desktop-live}"
: "${VOLUME_ID:=DEMUNTU_DESKTOP}"
: "${LIVE_SQUASHFS_PATH:=}"
: "${BOOT_MARKER:=DEMUNTU_DESKTOP_READY}"
: "${ARCHITECTURE:=amd64}"
: "${CUSTOM_METAPACKAGES:=}"
: "${LOCAL_PACKAGE_DIR:=dist/packages}"
: "${DESKTOP_SESSION:=xfce}"
: "${DESKTOP_PANEL_PROCESS:=xfce4-panel}"
: "${DESKTOP_DESKTOP_PROCESS:=xfdesktop}"
: "${DESKTOP_THEME_APPLY=/usr/lib/demuntu/apply-xfce-theme}"

repo_root="$(pwd)"
build_root="${BUILD_ROOT:-$repo_root/build}"
work_dir="$build_root/ubuntu/$IMAGE_NAME"
out_dir="$repo_root/dist/images"

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

rm -rf "$work_dir"
mkdir -p "$work_dir/extract" "$out_dir"

7z x -y "-o$work_dir/extract" "$base_iso" >/dev/null

if [ -z "$LIVE_SQUASHFS_PATH" ]; then
  LIVE_SQUASHFS_PATH="$(
    find "$work_dir/extract/casper" -maxdepth 1 -type f -name '*.squashfs' -printf '%s %P\n' \
      | sort -nr \
      | awk 'NR == 1 { print "casper/" $2 }'
  )"
fi

rebrand_iso_metadata() {
  local extract_dir="$1"

  if [ -f "$extract_dir/.disk/info" ]; then
    printf 'Demuntu 26.04 "Resolute" - Release %s\n' "$ARCHITECTURE" > "$extract_dir/.disk/info"
  fi
}

if [ -z "$LIVE_SQUASHFS_PATH" ] || [ ! -f "$work_dir/extract/$LIVE_SQUASHFS_PATH" ]; then
  echo "could not find live squashfs in extracted ISO" >&2
  exit 1
fi

rootfs="$work_dir/rootfs"
unsquashfs -d "$rootfs" "$work_dir/extract/$LIVE_SQUASHFS_PATH" >/dev/null

mounted=()
cleanup() {
  local mountpoint
  for mountpoint in "${mounted[@]}"; do
    if mountpoint -q "$mountpoint"; then
      umount "$mountpoint" || true
    fi
  done
}
trap cleanup EXIT

mount_bind() {
  local source="$1"
  local target="$2"
  mkdir -p "$target"
  mount --bind "$source" "$target"
  mounted=("$target" "${mounted[@]}")
}

disable_chroot_media_sources() {
  local target_root="$1"

  if [ -f "$target_root/etc/apt/sources.list" ]; then
    local tmp_sources
    tmp_sources="$(mktemp)"
    awk '
      /^[[:space:]]*deb[[:space:]]+(cdrom:|file:\/)/ {
        print "# disabled by Demuntu image build: " $0
        next
      }
      { print }
    ' "$target_root/etc/apt/sources.list" > "$tmp_sources"
    cp "$tmp_sources" "$target_root/etc/apt/sources.list"
    rm -f "$tmp_sources"
  fi

  if [ -d "$target_root/etc/apt/sources.list.d" ]; then
    while IFS= read -r -d '' source_file; do
      if grep -Eq '^[[:space:]]*URIs:[[:space:]]*(cdrom:|file:/)' "$source_file" || \
        grep -Eq '^[[:space:]]*deb[[:space:]]+(cdrom:|file:/)' "$source_file"; then
        mv "$source_file" "$source_file.disabled"
      fi
    done < <(find "$target_root/etc/apt/sources.list.d" -type f \( -name '*.sources' -o -name '*.list' \) -print0)
  fi
}

configure_external_apt_sources() {
  local target_root="$1"
  local package_file="$config_dir/packages.list"
  local keyring="$target_root/usr/share/keyrings/vivaldi-browser.gpg"
  local arch

  [ -f "$package_file" ] || return 0

  if grep -Eq '^[[:space:]]*vivaldi-stable([[:space:]]|$)' "$package_file"; then
    install -d -m 0755 \
      "$target_root/usr/share/keyrings" \
      "$target_root/etc/apt/sources.list.d"
    curl -fsSL https://repo.vivaldi.com/archive/linux_signing_key.pub |
      gpg --dearmor --batch --yes -o "$keyring"
    chmod 0644 "$keyring"
    arch="$(chroot "$target_root" dpkg --print-architecture)"
    printf 'deb [signed-by=/usr/share/keyrings/vivaldi-browser.gpg arch=%s] https://repo.vivaldi.com/archive/deb/ stable main\n' "$arch" \
      > "$target_root/etc/apt/sources.list.d/vivaldi-archive.list"
  fi
}

read_config_list() {
  local list_file="$1"

  [ -s "$list_file" ] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$list_file"
}

package_removal_requested() {
  local package_name="$1"
  local remove_file="$config_dir/remove-packages.list"
  local spec

  [ -s "$remove_file" ] || return 1

  while IFS= read -r spec; do
    [ -n "$spec" ] || continue
    if [[ "$spec" == "$package_name" ]]; then
      return 0
    fi
  done < <(read_config_list "$remove_file")

  return 1
}

remove_seeded_snaps() {
  local target_root="$1"
  local snap_file="$config_dir/remove-snaps.list"
  local names=()
  local snap_name
  local seed_yaml="$target_root/var/lib/snapd/seed/seed.yaml"
  local tmp_yaml

  [ -s "$snap_file" ] || return 0
  mapfile -t names < <(read_config_list "$snap_file")
  [ "${#names[@]}" -gt 0 ] || return 0

  if [ -f "$seed_yaml" ]; then
    tmp_yaml="$(mktemp)"
    awk -v remove_names="${names[*]}" '
      BEGIN {
        split(remove_names, remove, /[[:space:]]+/)
      }
      function should_remove(name, i) {
        for (i in remove) {
          if (name == remove[i]) {
            return 1
          }
        }
        return 0
      }
      function flush_block() {
        if (block != "" && keep) {
          printf "%s", block
        }
        block = ""
        keep = 1
      }
      /^  -$/ {
        flush_block()
        block = $0 ORS
        next
      }
      {
        if (block != "") {
          block = block $0 ORS
          if ($1 == "name:") {
            keep = !should_remove($2)
          }
          next
        }
        print
      }
      END {
        flush_block()
      }
    ' "$seed_yaml" > "$tmp_yaml"
    cp "$tmp_yaml" "$seed_yaml"
    rm -f "$tmp_yaml"
  fi

  for snap_name in "${names[@]}"; do
    rm -f "$target_root/var/lib/snapd/seed/snaps/${snap_name}_"*.snap 2>/dev/null || true
    rm -f "$target_root/var/lib/snapd/snaps/${snap_name}_"*.snap 2>/dev/null || true
    rm -f "$target_root/var/lib/snapd/sequence/${snap_name}.json" 2>/dev/null || true
    rm -rf "$target_root/snap/$snap_name" 2>/dev/null || true
    rm -f "$target_root/etc/systemd/system/snap-${snap_name}-"*.mount 2>/dev/null || true
    rm -f "$target_root/usr/lib/systemd/system/snap-${snap_name}-"*.mount 2>/dev/null || true
    rm -f "$target_root/lib/systemd/system/snap-${snap_name}-"*.mount 2>/dev/null || true
    if [ -d "$target_root/var/lib/snapd" ]; then
      while IFS= read -r -d '' snap_artifact; do
        rm -rf "$snap_artifact"
      done < <(find "$target_root/var/lib/snapd" -ignore_readdir_race -iname "*${snap_name}*" -print0 2>/dev/null)
    fi
    if [ -d "$target_root/var/cache/snapd" ]; then
      while IFS= read -r -d '' snap_artifact; do
        rm -rf "$snap_artifact"
      done < <(find "$target_root/var/cache/snapd" -ignore_readdir_race -iname "*${snap_name}*" -print0 2>/dev/null)
    fi
  done

  if [ -f "$target_root/var/lib/snapd/state.json" ]; then
    python3 - "$target_root/var/lib/snapd/state.json" "${names[@]}" <<'PY'
import json
import sys

path = sys.argv[1]
remove = tuple(sys.argv[2:])

with open(path, "r", encoding="utf-8") as fh:
    state = json.load(fh)

def keep_key(key):
    return not any(name in str(key) for name in remove)

def prune(value):
    if isinstance(value, dict):
        cleaned = {}
        for k, v in value.items():
            if not keep_key(k):
                continue
            pruned = prune(v)
            if isinstance(pruned, str) and any(name in pruned for name in remove):
                continue
            cleaned[k] = pruned
        return cleaned
    if isinstance(value, list):
        cleaned = []
        for item in value:
            if isinstance(item, str) and any(name in item for name in remove):
                continue
            if isinstance(item, (dict, list)) and any(name in json.dumps(item) for name in remove):
                pruned = prune(item)
                if pruned:
                    cleaned.append(pruned)
                continue
            cleaned.append(prune(item))
        return cleaned
    return value

with open(path, "w", encoding="utf-8") as fh:
    json.dump(prune(state), fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
  fi
}

remove_desktop_packages() {
  local target_root="$1"
  local remove_file="$config_dir/remove-packages.list"
  local spec
  local pkg
  local installed=()

  [ -s "$remove_file" ] || return 0

  while IFS= read -r spec; do
    [ -n "$spec" ] || continue
    if [[ "$spec" == *"*"* || "$spec" == *"?"* || "$spec" == *"["* ]]; then
      while IFS= read -r pkg; do
        case "$pkg" in
          $spec) installed+=("$pkg") ;;
        esac
      done < <(chroot "$target_root" dpkg-query -W -f='${Package}\n')
    elif chroot "$target_root" dpkg-query -W -f='${Package}\n' "$spec" >/dev/null 2>&1; then
      installed+=("$spec")
    fi
  done < <(read_config_list "$remove_file")

  [ "${#installed[@]}" -gt 0 ] || return 0

  chroot "$target_root" env DEBIAN_FRONTEND=noninteractive apt-get purge -y "${installed[@]}"
  chroot "$target_root" env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge
}

purge_snapd_if_requested() {
  local target_root="$1"

  package_removal_requested snapd || return 0

  if chroot "$target_root" dpkg-query -W -f='${Package}\n' snapd >/dev/null 2>&1; then
    chroot "$target_root" env DEBIAN_FRONTEND=noninteractive apt-get purge -y snapd
    chroot "$target_root" env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge
  fi
}

remove_snapd_state_if_requested() {
  local target_root="$1"

  package_removal_requested snapd || return 0

  rm -rf \
    "$target_root/snap" \
    "$target_root/var/snap" \
    "$target_root/var/cache/snapd" \
    "$target_root/var/lib/snapd" 2>/dev/null || true
}

sanitize_desktop_surface() {
  local target_root="$1"
  local app_dir="$target_root/usr/share/applications"
  local local_app_dir="$target_root/usr/local/share/applications"
  local menu_file="$target_root/etc/xdg/menus/xfce-applications.menu"
  local launcher
  local stale_pattern

  mkdir -p "$app_dir"
  mkdir -p "$local_app_dir"

  for launcher in \
    xfce4-file-manager.desktop \
    xfce4-mail-reader.desktop \
    xfce4-terminal-emulator.desktop \
    xfce4-web-browser.desktop \
    exo-file-manager.desktop \
    exo-mail-reader.desktop \
    exo-terminal-emulator.desktop \
    exo-web-browser.desktop; do
    cat > "$local_app_dir/$launcher" <<EOF
[Desktop Entry]
Type=Application
Name=Hidden Demuntu launcher
Exec=true
NoDisplay=true
OnlyShowIn=XFCE;
EOF
  done

  if [ -f "$menu_file" ]; then
    sed -i \
      -e '/<Filename>xfce4-terminal-emulator\.desktop<\/Filename>/d' \
      -e '/<Filename>xfce4-file-manager\.desktop<\/Filename>/d' \
      -e '/<Filename>xfce4-mail-reader\.desktop<\/Filename>/d' \
      -e '/<Filename>xfce4-web-browser\.desktop<\/Filename>/d' \
      "$menu_file"
  fi

  if [ -d "$app_dir" ]; then
    for stale_pattern in \
      '*firefox*.desktop' \
      '*thunderbird*.desktop' \
      '*libreoffice*.desktop' \
      '*rhythmbox*.desktop' \
      '*totem*.desktop' \
      '*transmission*.desktop' \
      '*shotwell*.desktop'; do
      find "$app_dir" -maxdepth 1 -type f -iname "$stale_pattern" -delete 2>/dev/null || true
    done
  fi

  rm -f "$target_root/usr/share/applications/mimeinfo.cache" 2>/dev/null || true
  rm -rf "$target_root/var/lib/swcatalog" 2>/dev/null || true
}

disable_snap_seed_wait() {
  local target_root="$1"
  local unit
  local unit_dir
  local snap_path

  mkdir -p "$target_root/etc/systemd/system"

  if [ -d "$target_root/etc/systemd/system" ]; then
    while IFS= read -r -d '' snap_path; do
      rm -rf "$snap_path"
    done < <(
      find "$target_root/etc/systemd/system" -ignore_readdir_race \
        \( -name 'snap-*' -o -name 'snapd*' -o -name '*snapd*' \) \
        -depth \
        -print0 2>/dev/null
    )

    while IFS= read -r -d '' snap_path; do
      case "$(readlink "$snap_path" 2>/dev/null || true)" in
        *snap*) rm -f "$snap_path" ;;
      esac
    done < <(find "$target_root/etc/systemd/system" -ignore_readdir_race -type l -print0 2>/dev/null)
  fi

  for unit_dir in "$target_root/usr/lib/systemd/system" "$target_root/lib/systemd/system"; do
    [ -d "$unit_dir" ] || continue
    while IFS= read -r -d '' snap_path; do
      rm -f "$snap_path"
    done < <(
      find "$unit_dir" -maxdepth 1 -ignore_readdir_race \
        \( -name 'snap-*' -o -name 'snapd*' -o -name '*snapd*' \) \
        -print0 2>/dev/null
    )
  done

  for unit in \
    snapd.apparmor.service \
    snapd.autoimport.service \
    snapd.core-fixup.service \
    snapd.failure.service \
    snapd.mounts-pre.target \
    snapd.mounts.target \
    snapd.recovery-chooser-trigger.service \
    snapd.seeded.service \
    snapd.service \
    snapd.socket \
    snapd.system-shutdown.service; do
    ln -sfn /dev/null "$target_root/etc/systemd/system/$unit"
  done
}

write_marker_service() {
  local target_root="$1"

  mkdir -p \
    "$target_root/etc/systemd/system" \
    "$target_root/etc/systemd/system/graphical.target.wants" \
    "$target_root/etc/systemd/system/multi-user.target.wants" \
    "$target_root/etc/systemd/system/getty.target.wants" \
    "$target_root/usr/local/sbin"

cat > "$target_root/usr/local/sbin/demuntu-desktop-ready" <<EOF
#!/bin/sh
marker="${BOOT_MARKER}"
panel_process="${DESKTOP_PANEL_PROCESS}"
desktop_process="${DESKTOP_DESKTOP_PROCESS}"
theme_apply="${DESKTOP_THEME_APPLY}"
i=0

mate_panel_layout_ready() {
  [ "\$panel_process" = "mate-panel" ] || return 0
  command -v gsettings >/dev/null 2>&1 || return 0

  live_user="\$1"
  uid="\$2"
  home="\$3"

  ids="\$(runuser -u "\$live_user" -- env \
    DISPLAY=:0 \
    XAUTHORITY="\$home/.Xauthority" \
    XDG_RUNTIME_DIR="/run/user/\$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/\$uid/bus" \
    gsettings get org.mate.panel toplevel-id-list 2>/dev/null || printf '[]')"
  objects="\$(runuser -u "\$live_user" -- env \
    DISPLAY=:0 \
    XAUTHORITY="\$home/.Xauthority" \
    XDG_RUNTIME_DIR="/run/user/\$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/\$uid/bus" \
    gsettings get org.mate.panel object-id-list 2>/dev/null || printf '[]')"

  printf "\\nDEMUNTU_MATE_PANEL_TOPLEVELS %s\\n" "\$ids" > /dev/ttyS0
  printf "\\nDEMUNTU_MATE_PANEL_OBJECTS %s\\n" "\$objects" > /dev/ttyS0

  case "\$ids" in
    *"'top'"*"'bottom'"*|*"'bottom'"*"'top'"*) ;;
    *) return 1 ;;
  esac

  case "\$objects" in *"'menu-bar'"*) ;; *) return 1 ;; esac
  case "\$objects" in *"'window-list'"*) ;; *) return 1 ;; esac
  case "\$objects" in *"'volume-control'"*) ;; *) return 1 ;; esac
}

while [ "\$i" -lt 180 ]; do
  live_user="\$(getent passwd 1000 | cut -d: -f1)"
  [ -n "\$live_user" ] || live_user="ubuntu"

  if pgrep -u "\$live_user" -x "\$panel_process" >/dev/null 2>&1 && \
    { [ -z "\$desktop_process" ] || pgrep -u "\$live_user" -x "\$desktop_process" >/dev/null 2>&1; }; then
    if [ -n "\$theme_apply" ] && [ -x "\$theme_apply" ]; then
      uid="\$(id -u "\$live_user" 2>/dev/null || printf 1000)"
      home="\$(getent passwd "\$live_user" | cut -d: -f6)"
      [ -n "\$home" ] || home="/home/\$live_user"
      if [ -S "/run/user/\$uid/bus" ]; then
        printf "\\nDEMUNTU_DESKTOP_APPLY_THEME_START\\n" > /dev/ttyS0
        runuser -u "\$live_user" -- env \
          DISPLAY=:0 \
          XAUTHORITY="\$home/.Xauthority" \
          XDG_RUNTIME_DIR="/run/user/\$uid" \
          DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/\$uid/bus" \
          timeout 45s "\$theme_apply" || printf "\\nDEMUNTU_DESKTOP_APPLY_THEME_FAILED\\n" > /dev/ttyS0
        if command -v xfconf-query >/dev/null 2>&1; then
          runuser -u "\$live_user" -- env \
            DISPLAY=:0 \
            XAUTHORITY="\$home/.Xauthority" \
            XDG_RUNTIME_DIR="/run/user/\$uid" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/\$uid/bus" \
            xfconf-query -c xsettings -p /Net/ThemeName 2>/dev/null \
            | sed 's/^/DEMUNTU_XFCE_THEME /' > /dev/ttyS0 || true
          runuser -u "\$live_user" -- env \
            DISPLAY=:0 \
            XAUTHORITY="\$home/.Xauthority" \
            XDG_RUNTIME_DIR="/run/user/\$uid" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/\$uid/bus" \
            xfconf-query -c xfce4-panel -p /plugins/plugin-1/show-button-title 2>/dev/null \
            | sed 's/^/DEMUNTU_PANEL_TITLE /' > /dev/ttyS0 || true
        fi
        printf "\\nDEMUNTU_DESKTOP_APPLY_THEME_DONE\\n" > /dev/ttyS0
      fi
    fi
    uid="\$(id -u "\$live_user" 2>/dev/null || printf 1000)"
    home="\$(getent passwd "\$live_user" | cut -d: -f6)"
    [ -n "\$home" ] || home="/home/\$live_user"
    if [ -S "/run/user/\$uid/bus" ] && ! mate_panel_layout_ready "\$live_user" "\$uid" "\$home"; then
      i=\$((i + 1))
      sleep 2
      continue
    fi
    printf "\\nDEMUNTU_DESKTOP_SESSION %s\\n" "${DESKTOP_SESSION}" > /dev/ttyS0
    printf "\\n%s\\n" "\$marker" > /dev/ttyS0
    exit 0
  fi

  i=\$((i + 1))
  sleep 2
done

{
  printf "\\nDEMUNTU_DESKTOP_SESSION_TIMEOUT\\n"
  systemctl --no-pager --full status display-manager lightdm || true
  ps -ef || true
} > /dev/ttyS0
exit 1
EOF
  chmod 0755 "$target_root/usr/local/sbin/demuntu-desktop-ready"

  cat > "$target_root/etc/systemd/system/demuntu-desktop-marker.service" <<EOF
[Unit]
Description=Demuntu desktop live boot marker
After=graphical.target display-manager.service serial-getty@ttyS0.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/demuntu-desktop-ready

[Install]
WantedBy=graphical.target
EOF

  ln -sfn /etc/systemd/system/demuntu-desktop-marker.service \
    "$target_root/etc/systemd/system/graphical.target.wants/demuntu-desktop-marker.service"
  ln -sfn /usr/lib/systemd/system/serial-getty@.service \
    "$target_root/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service"
}

if [ -d "$config_dir/files" ]; then
  cp -a "$config_dir/files/." "$rootfs/"
fi

if [ -s "$config_dir/packages.list" ] || [ -n "$CUSTOM_METAPACKAGES" ]; then
  cp /etc/resolv.conf "$rootfs/etc/resolv.conf"
  disable_chroot_media_sources "$rootfs"
  mount_bind /dev "$rootfs/dev"
  mount -t devpts devpts "$rootfs/dev/pts"
  mounted=("$rootfs/dev/pts" "${mounted[@]}")
  mount_bind /run "$rootfs/run"
  mount -t proc proc "$rootfs/proc"
  mounted=("$rootfs/proc" "${mounted[@]}")
  mount -t sysfs sysfs "$rootfs/sys"
  mounted=("$rootfs/sys" "${mounted[@]}")

  cat > "$rootfs/usr/sbin/policy-rc.d" <<'EOF'
#!/bin/sh
exit 101
EOF
  chmod +x "$rootfs/usr/sbin/policy-rc.d"

  chroot "$rootfs" apt-get update
  remove_seeded_snaps "$rootfs"
  remove_desktop_packages "$rootfs"
  remove_snapd_state_if_requested "$rootfs"
  disable_snap_seed_wait "$rootfs"
  configure_external_apt_sources "$rootfs"
  chroot "$rootfs" apt-get update
  packages=()
  if [ -s "$config_dir/packages.list" ]; then
    mapfile -t packages < <(grep -vE '^[[:space:]]*(#|$)' "$config_dir/packages.list")
  fi
  if [ "${#packages[@]}" -gt 0 ]; then
    chroot "$rootfs" env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
  fi
  if [ -n "$CUSTOM_METAPACKAGES" ]; then
    copy_custom_metapackages "$rootfs/tmp/demuntu-packages"
    chroot "$rootfs" env DEBIAN_FRONTEND=noninteractive /bin/sh -c 'apt-get install -y /tmp/demuntu-packages/*.deb'
    rm -rf "$rootfs/tmp/demuntu-packages"
  fi
  purge_snapd_if_requested "$rootfs"
  remove_snapd_state_if_requested "$rootfs"
  sanitize_desktop_surface "$rootfs"
  disable_snap_seed_wait "$rootfs"
  chroot "$rootfs" apt-get clean
  rm -rf "$rootfs/var/lib/apt/lists/"*
  rm -f "$rootfs/usr/sbin/policy-rc.d"
fi

if [ -d "$config_dir/hooks" ]; then
  for hook in "$config_dir"/hooks/*; do
    [ -f "$hook" ] || continue
    hook_name="$(basename "$hook")"
    install -m 0755 "$hook" "$rootfs/tmp/$hook_name"
    chroot "$rootfs" "/tmp/$hook_name"
    rm -f "$rootfs/tmp/$hook_name"
  done
fi

write_marker_service "$rootfs"
cleanup

if [ -f "$rootfs/etc/motd" ]; then
  printf '\n%s\n' "Demuntu desktop live ISO" >> "$rootfs/etc/motd"
fi

if [ -f "$work_dir/extract/casper/filesystem.size" ]; then
  du -sx --block-size=1 "$rootfs" | awk '{ print $1 }' > "$work_dir/extract/casper/filesystem.size"
fi

if [ -f "$work_dir/extract/casper/filesystem.manifest" ]; then
  # shellcheck disable=SC2016
  chroot "$rootfs" dpkg-query -W --showformat='${Package} ${Version}\n' \
    > "$work_dir/extract/casper/filesystem.manifest"
fi

rm -f "$work_dir/extract/$LIVE_SQUASHFS_PATH"
mksquashfs "$rootfs" "$work_dir/extract/$LIVE_SQUASHFS_PATH" -noappend -comp xz -b 1M >/dev/null

while IFS= read -r -d '' live_layer; do
  layer_name="$(basename "$live_layer")"
  layer_root="$work_dir/live-layers/${layer_name%.squashfs}"
  rm -rf "$layer_root"
  mkdir -p "$(dirname "$layer_root")"
  unsquashfs -d "$layer_root" "$live_layer" >/dev/null
  remove_seeded_snaps "$layer_root"
  remove_snapd_state_if_requested "$layer_root"
  sanitize_desktop_surface "$layer_root"
  disable_snap_seed_wait "$layer_root"
  case "$layer_name" in
    *.live.squashfs) write_marker_service "$layer_root" ;;
  esac
  rm -f "$live_layer"
  mksquashfs "$layer_root" "$live_layer" -noappend -comp xz -b 1M >/dev/null
  layer_size_file="${live_layer%.squashfs}.size"
  if [ -f "$layer_size_file" ]; then
    du -sx --block-size=1 "$layer_root" | awk '{ print $1 }' > "$layer_size_file"
  fi
done < <(
  find "$work_dir/extract/casper" -maxdepth 1 -type f -name '*.squashfs' \
    ! -path "$work_dir/extract/$LIVE_SQUASHFS_PATH" \
    -print0
)

grub_cfg="$work_dir/extract/boot/grub/grub.cfg"
if [ -f "$grub_cfg" ]; then
  linux_line="$(grep -m 1 -E '^[[:space:]]*linux[[:space:]]+/casper/' "$grub_cfg" | sed -E 's/^[[:space:]]*//')"
  initrd_line="$(grep -m 1 -E '^[[:space:]]*initrd[[:space:]]+/casper/' "$grub_cfg" | sed -E 's/^[[:space:]]*//')"
  if [ -n "$linux_line" ] && [ -n "$initrd_line" ]; then
    if [[ "$linux_line" == *" ---"* ]]; then
      linux_line="${linux_line/ ---/ console=tty0 console=ttyS0,115200n8 ---}"
    else
      linux_line="$linux_line console=tty0 console=ttyS0,115200n8"
    fi

    tmp_grub="$(mktemp)"
    if [ -f "$rootfs/usr/share/backgrounds/demuntu/demuntu-grub.png" ]; then
      cp "$rootfs/usr/share/backgrounds/demuntu/demuntu-grub.png" \
        "$work_dir/extract/boot/grub/demuntu-grub.png"
    fi
    {
      printf 'set timeout=20\n'
      printf 'loadfont unicode\n'
      printf 'insmod all_video\n'
      printf 'insmod gfxterm\n'
      printf 'insmod png\n'
      printf 'set gfxmode=auto\n'
      printf 'terminal_output gfxterm\n'
      printf 'if background_image /boot/grub/demuntu-grub.png; then\n'
      printf '    set color_normal=light-gray/black\n'
      printf '    set color_highlight=white/red\n'
      printf 'else\n'
      printf '    set menu_color_normal=white/black\n'
      printf '    set menu_color_highlight=black/light-gray\n'
      printf 'fi\n\n'
      printf 'menuentry "Try Demuntu Desktop" {\n'
      printf '    set gfxpayload=keep\n'
      printf '    %s\n' "$linux_line"
      printf '    %s\n' "$initrd_line"
      printf '}\n\n'
      sed \
        -e 's/Try or Install Ubuntu/Try or Install Demuntu/g' \
        -e 's/Ubuntu (safe graphics)/Demuntu (safe graphics)/g' \
        "$grub_cfg"
    } > "$tmp_grub"
    cp "$tmp_grub" "$grub_cfg"
    rm -f "$tmp_grub"
  fi
fi

if [ -f "$work_dir/extract/boot/grub/loopback.cfg" ]; then
  sed -i \
    -e 's/Try or Install Ubuntu/Try or Install Demuntu/g' \
    -e 's/Ubuntu (safe graphics)/Demuntu (safe graphics)/g' \
    "$work_dir/extract/boot/grub/loopback.cfg"
fi

rebrand_iso_metadata "$work_dir/extract"

if [ -f "$work_dir/extract/casper/initrd" ]; then
  "$repo_root/scripts/ubuntu/rebrand-initrd.sh" \
    "$work_dir/extract/casper/initrd" \
    desktop \
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
