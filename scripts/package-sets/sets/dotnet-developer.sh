#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

dotnet_major="${DOTNET_MAJOR:-10}"
dotnet_sdk_package="${DOTNET_SDK_PACKAGE:-dotnet-sdk-${dotnet_major}.0}"
aspnet_package="${ASPNET_RUNTIME_PACKAGE:-aspnetcore-runtime-${dotnet_major}.0}"
rider_install="${RIDER_INSTALL:-best-effort}"

apt_updated=0

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "dotnet-developer package set must run as root" >&2
    exit 1
  fi
}

apt_update_once() {
  if [ "$apt_updated" -eq 0 ]; then
    apt-get update
    apt_updated=1
  fi
}

package_available() {
  apt-cache show "$1" >/dev/null 2>&1
}

install_prerequisites() {
  apt_update_once
  apt-get install -y \
    ca-certificates \
    curl \
    wget \
    gpg \
    apt-transport-https \
    python3 \
    tar \
    gzip \
    desktop-file-utils
}

add_microsoft_product_repo_if_available() {
  local os_id version_id repo_id repo_version repo_url temp_deb

  # shellcheck disable=SC1091
  . /etc/os-release
  os_id="${ID:-}"
  version_id="${VERSION_ID:-}"
  repo_id="${DOTNET_REPO_ID:-$os_id}"
  repo_version="${DOTNET_REPO_VERSION:-$version_id}"

  if [ -z "$repo_id" ] || [ -z "$repo_version" ]; then
    return 1
  fi

  repo_url="https://packages.microsoft.com/config/${repo_id}/${repo_version}/packages-microsoft-prod.deb"
  if ! curl -fsI "$repo_url" >/dev/null 2>&1; then
    return 1
  fi

  temp_deb="$(mktemp /tmp/packages-microsoft-prod.XXXXXX.deb)"
  curl -fsSL "$repo_url" -o "$temp_deb"
  dpkg -i "$temp_deb"
  rm -f "$temp_deb"
  apt_updated=0
  apt_update_once
}

install_dotnet_from_script() {
  local install_script

  install_script="$(mktemp /tmp/dotnet-install.XXXXXX.sh)"
  curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$install_script"
  chmod 0755 "$install_script"
  mkdir -p /usr/share/dotnet
  "$install_script" --channel "${dotnet_major}.0" --install-dir /usr/share/dotnet
  rm -f "$install_script"

  ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
  cat > /etc/profile.d/dotnet.sh <<'EOF'
export DOTNET_ROOT=/usr/share/dotnet
case ":$PATH:" in
  *:/usr/share/dotnet:*) ;;
  *) export PATH="$PATH:/usr/share/dotnet" ;;
esac
EOF
}

install_dotnet() {
  apt_update_once

  if ! package_available "$dotnet_sdk_package"; then
    add_microsoft_product_repo_if_available || true
  fi

  if package_available "$dotnet_sdk_package"; then
    apt-get install -y "$dotnet_sdk_package"
    if package_available "$aspnet_package"; then
      apt-get install -y "$aspnet_package"
    fi
  else
    echo "APT package $dotnet_sdk_package is unavailable; falling back to dotnet-install.sh" >&2
    install_dotnet_from_script
  fi
}

install_common_dev_packages() {
  apt_update_once
  apt-get install -y git build-essential
}

install_rider_dependencies() {
  apt_update_once
  apt-get install -y \
    libxi6 \
    libxrender1 \
    libxtst6 \
    libfontconfig1 \
    libgtk-3-bin \
    libxss1 \
    libnss3 || return 1

  if ! apt-get install -y libasound2t64; then
    apt-get install -y libasound2 || true
  fi
}

install_rider() {
  local arch platform temp_dir archive extracted target_dir download_url

  case "$rider_install" in
    skip|none|false|0)
      echo "Skipping Rider install because RIDER_INSTALL=$rider_install"
      return 0
      ;;
  esac

  arch="$(dpkg --print-architecture)"
  case "$arch" in
    amd64)
      platform="linux"
      ;;
    arm64)
      platform="linuxARM64"
      ;;
    *)
      echo "Skipping Rider install on unsupported architecture: $arch" >&2
      return 0
      ;;
  esac

  if ! install_rider_dependencies; then
    echo "Skipping Rider install because desktop dependencies could not be installed" >&2
    return 0
  fi

  temp_dir="$(mktemp -d /tmp/rider-install.XXXXXX)"
  archive="$temp_dir/rider.tar.gz"
  target_dir="/opt/jetbrains/rider"
  download_url="https://data.services.jetbrains.com/products/download?code=RD&platform=${platform}"

  if ! curl -fL --retry 3 --connect-timeout 30 -o "$archive" "$download_url"; then
    rm -rf "$temp_dir"
    echo "Rider download failed; continuing without Rider" >&2
    return 0
  fi

  tar -xzf "$archive" -C "$temp_dir"
  extracted="$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)"
  if [ -z "$extracted" ]; then
    rm -rf "$temp_dir"
    echo "Rider archive did not contain an install directory; continuing without Rider" >&2
    return 0
  fi

  mkdir -p /opt/jetbrains
  rm -rf "$target_dir"
  mv "$extracted" "$target_dir"
  rm -rf "$temp_dir"

  ln -sf "$target_dir/bin/rider.sh" /usr/local/bin/rider
  cat > /usr/share/applications/jetbrains-rider.desktop <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=JetBrains Rider
Comment=.NET IDE
Exec=/usr/local/bin/rider %f
Icon=${target_dir}/bin/rider.svg
Terminal=false
Categories=Development;IDE;
StartupWMClass=jetbrains-rider
EOF
  chmod 0644 /usr/share/applications/jetbrains-rider.desktop
  update-desktop-database /usr/share/applications >/dev/null 2>&1 || true

  mkdir -p /usr/share/doc/demuntu-dotnet-developer
  cat > /usr/share/doc/demuntu-dotnet-developer/RIDER-NONCOMMERCIAL.txt <<'EOF'
JetBrains Rider is installed for convenience, but it is not pre-licensed.
JetBrains offers Rider free for non-commercial use. On first launch, sign in
with a JetBrains account and choose the appropriate license for your use case.
Commercial work requires an appropriate paid JetBrains license.
EOF
}

write_validation_service() {
  cat > /usr/local/sbin/demuntu-dotnet-developer-ready <<'EOF'
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
  printf '\nDEMUNTU_DOTNET_DEVELOPER_CHECKS\n'
  emit_check dotnet dotnet --version
  emit_check dotnet-sdks dotnet --list-sdks
  emit_check git git --version
  emit_check gcc gcc --version
  if [ -x /usr/local/bin/rider ]; then
    printf 'rider-launcher: %s\n' "$(readlink -f /usr/local/bin/rider)"
  else
    printf 'rider-launcher: not installed\n'
  fi
  printf 'DEMUNTU_DOTNET_DEVELOPER_READY\n'
} > "$serial" 2>&1
EOF
  chmod 0755 /usr/local/sbin/demuntu-dotnet-developer-ready

  cat > /etc/systemd/system/demuntu-dotnet-developer-ready.service <<'EOF'
[Unit]
Description=Demuntu .NET Developer package-set boot marker
After=multi-user.target cloud-final.service serial-getty@ttyS0.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/demuntu-dotnet-developer-ready

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable demuntu-dotnet-developer-ready.service >/dev/null 2>&1 || true
}

require_root
install_prerequisites
install_dotnet
install_common_dev_packages
install_rider
write_validation_service
