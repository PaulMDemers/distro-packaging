#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

gitkraken_install="${GITKRAKEN_INSTALL:-best-effort}"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "git-gui-tools package set must run as root" >&2
    exit 1
  fi
}

install_packages() {
  apt-get update
  apt-get install -y \
    ca-certificates \
    curl \
    wget \
    git \
    git-cola \
    git-gui \
    gitk \
    meld \
    xdg-utils
}

install_gitkraken() {
  local arch temp_dir archive extracted target_dir icon_path

  case "$gitkraken_install" in
    skip|none|false|0)
      echo "Skipping GitKraken install because GITKRAKEN_INSTALL=$gitkraken_install"
      return 0
      ;;
  esac

  arch="$(dpkg --print-architecture)"
  if [ "$arch" != "amd64" ]; then
    echo "Skipping GitKraken install on unsupported architecture: $arch" >&2
    return 0
  fi

  temp_dir="$(mktemp -d /tmp/gitkraken.XXXXXX)"
  archive="$temp_dir/gitkraken.tar.gz"
  target_dir="/opt/gitkraken"
  if ! curl -fL --retry 3 --connect-timeout 30 \
    -o "$archive" \
    https://api.gitkraken.dev/releases/production/linux/x64/active/gitkraken-amd64.tar.gz; then
    rm -rf "$temp_dir"
    echo "GitKraken download failed; continuing with open-source Git GUI tools" >&2
    return 0
  fi

  tar -xzf "$archive" -C "$temp_dir"
  extracted="$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)"
  if [ -z "$extracted" ]; then
    rm -rf "$temp_dir"
    echo "GitKraken archive did not contain an install directory; continuing with open-source Git GUI tools" >&2
    return 0
  fi

  rm -rf "$target_dir"
  mkdir -p /opt
  mv "$extracted" "$target_dir"
  rm -rf "$temp_dir"

  if [ ! -x "$target_dir/gitkraken" ]; then
    echo "GitKraken archive did not contain an executable launcher; continuing with open-source Git GUI tools" >&2
    rm -rf "$target_dir"
    return 0
  fi

  ln -sf "$target_dir/gitkraken" /usr/local/bin/gitkraken
  icon_path="$target_dir/gitkraken.png"
  if [ ! -f "$icon_path" ]; then
    icon_path="git"
  fi

  cat > /usr/share/applications/gitkraken.desktop <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=GitKraken Desktop
Comment=Git client
Exec=/usr/local/bin/gitkraken %U
Icon=${icon_path}
Terminal=false
Categories=Development;RevisionControl;
StartupWMClass=gitkraken
EOF

  mkdir -p /usr/share/doc/demuntu-git-gui-tools
  cat > /usr/share/doc/demuntu-git-gui-tools/GITKRAKEN-NOTES.txt <<'EOF'
GitKraken Desktop is installed as a convenience from GitKraken's active Linux
tarball release channel into /opt/gitkraken. It is proprietary software and may
require a GitKraken account or license depending on repository type and use
case.
EOF
}

write_validation_service() {
  cat > /usr/local/sbin/demuntu-git-gui-tools-ready <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

serial=/dev/ttyS0

cloud-init status --wait >/dev/null 2>&1 || true

first_line() {
  sed -n '1p'
}

emit_check() {
  local label="$1"
  shift
  local output

  output="$("$@" 2>&1)"
  if [ -z "$output" ]; then
    printf '%s: <empty>\n' "$label" >&2
    return 1
  fi
  printf '%s: %s\n' "$label" "$(printf '%s\n' "$output" | first_line)"
}

{
  printf '\nDEMUNTU_GIT_GUI_TOOLS_CHECKS\n'
  emit_check git git --version
  if command -v git-cola >/dev/null 2>&1; then
    printf 'git-cola-launcher: %s\n' "$(command -v git-cola)"
  else
    printf 'git-cola-launcher: not installed\n'
  fi
  if [ -x "$(git --exec-path)/git-gui" ]; then
    printf 'git-gui-launcher: %s\n' "$(git --exec-path)/git-gui"
  else
    printf 'git-gui-launcher: not installed\n'
  fi
  if command -v gitk >/dev/null 2>&1; then
    printf 'gitk-launcher: %s\n' "$(command -v gitk)"
  else
    printf 'gitk-launcher: not installed\n'
  fi
  if command -v meld >/dev/null 2>&1; then
    printf 'meld-launcher: %s\n' "$(command -v meld)"
  else
    printf 'meld-launcher: not installed\n'
  fi
  if command -v gitkraken >/dev/null 2>&1; then
    printf 'gitkraken-launcher: %s\n' "$(command -v gitkraken)"
  else
    printf 'gitkraken-launcher: not installed\n'
  fi
  printf 'DEMUNTU_GIT_GUI_TOOLS_READY\n'
} > "$serial" 2>&1
EOF
  chmod 0755 /usr/local/sbin/demuntu-git-gui-tools-ready

  cat > /etc/systemd/system/demuntu-git-gui-tools-ready.service <<'EOF'
[Unit]
Description=Demuntu Git GUI tools package-set boot marker
After=multi-user.target cloud-final.service serial-getty@ttyS0.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/demuntu-git-gui-tools-ready

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable demuntu-git-gui-tools-ready.service >/dev/null 2>&1 || true
}

require_root
install_packages
install_gitkraken
write_validation_service
