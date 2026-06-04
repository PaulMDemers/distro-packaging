#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

portainer_image="${PORTAINER_IMAGE:-portainer/portainer-ce:lts}"
lazydocker_install="${LAZYDOCKER_INSTALL:-latest}"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "docker-gui-tools package set must run as root" >&2
    exit 1
  fi
}

install_prerequisites() {
  apt-get update
  apt-get install -y ca-certificates curl gpg python3 xdg-utils
}

add_docker_repo() {
  local arch codename os_id repo_os repo_url

  arch="$(dpkg --print-architecture)"
  # shellcheck disable=SC1091
  . /etc/os-release
  os_id="${ID:-}"
  codename="${DOCKER_REPO_CODENAME:-${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}}"

  case "${DOCKER_REPO_OS:-$os_id}" in
    ubuntu)
      repo_os="ubuntu"
      ;;
    debian)
      repo_os="debian"
      ;;
    *)
      if printf '%s\n' "${ID_LIKE:-}" | grep -qw ubuntu; then
        repo_os="ubuntu"
      elif printf '%s\n' "${ID_LIKE:-}" | grep -qw debian; then
        repo_os="debian"
      else
        echo "unsupported Docker repository OS: ${os_id:-unknown}" >&2
        exit 1
      fi
      ;;
  esac

  if [ -z "$codename" ]; then
    echo "could not determine codename for Docker repository" >&2
    exit 1
  fi

  repo_url="https://download.docker.com/linux/${repo_os}"
  install -m 0755 -d /etc/apt/keyrings /etc/apt/sources.list.d
  rm -f /etc/apt/keyrings/docker.asc
  curl -fsSL "${repo_url}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod 0644 /etc/apt/keyrings/docker.asc

  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: ${repo_url}
Suites: ${codename}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
}

install_docker_engine() {
  if command -v docker >/dev/null 2>&1; then
    systemctl enable docker >/dev/null 2>&1 || true
    return 0
  fi

  add_docker_repo
  apt-get update
  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  systemctl enable docker >/dev/null 2>&1 || true
  if id ubuntu >/dev/null 2>&1; then
    usermod -aG docker ubuntu
  fi
  if id demuntu >/dev/null 2>&1; then
    usermod -aG docker demuntu
  fi
  if id demian >/dev/null 2>&1; then
    usermod -aG docker demian
  fi
}

github_latest_asset_url() {
  local repo pattern
  repo="$1"
  pattern="$2"

  python3 - "$repo" "$pattern" <<'PY'
import json
import re
import sys
import urllib.request

repo, pattern = sys.argv[1], re.compile(sys.argv[2])
url = f"https://api.github.com/repos/{repo}/releases/latest"
with urllib.request.urlopen(url, timeout=30) as response:
    release = json.load(response)
for asset in release.get("assets", []):
    name = asset.get("name", "")
    if pattern.search(name):
        print(asset["browser_download_url"])
        sys.exit(0)
sys.exit(1)
PY
}

install_lazydocker() {
  local arch pattern temp_dir archive asset_url extracted

  case "$lazydocker_install" in
    skip|none|false|0)
      echo "Skipping lazydocker install because LAZYDOCKER_INSTALL=$lazydocker_install"
      return 0
      ;;
  esac

  case "$(dpkg --print-architecture)" in
    amd64)
      arch="x86_64"
      ;;
    arm64)
      arch="arm64"
      ;;
    armhf)
      arch="armv7"
      ;;
    *)
      echo "Skipping lazydocker install on unsupported architecture: $(dpkg --print-architecture)" >&2
      return 0
      ;;
  esac

  pattern="Linux_${arch}\\.tar\\.gz$"
  if ! asset_url="$(github_latest_asset_url jesseduffield/lazydocker "$pattern")"; then
    echo "Could not find lazydocker release asset for ${arch}; continuing without lazydocker" >&2
    return 0
  fi

  temp_dir="$(mktemp -d /tmp/lazydocker.XXXXXX)"
  archive="$temp_dir/lazydocker.tar.gz"
  if ! curl -fL --retry 3 --connect-timeout 30 -o "$archive" "$asset_url"; then
    rm -rf "$temp_dir"
    echo "lazydocker download failed; continuing without lazydocker" >&2
    return 0
  fi

  tar -xzf "$archive" -C "$temp_dir"
  extracted="$(find "$temp_dir" -type f -name lazydocker | head -n 1)"
  if [ -z "$extracted" ]; then
    rm -rf "$temp_dir"
    echo "lazydocker archive did not contain a lazydocker binary" >&2
    return 0
  fi
  install -m 0755 "$extracted" /usr/local/bin/lazydocker
  rm -rf "$temp_dir"
}

install_portainer_service() {
  cat > /etc/systemd/system/demuntu-portainer.service <<EOF
[Unit]
Description=Portainer CE local Docker management UI
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStartPre=-/usr/bin/docker volume create portainer_data
ExecStartPre=-/usr/bin/docker rm -f portainer
ExecStart=/usr/bin/docker run --name portainer --pull=missing -p 8000:8000 -p 9443:9443 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data ${portainer_image}
ExecStop=/usr/bin/docker stop portainer
ExecStopPost=-/usr/bin/docker rm portainer
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable demuntu-portainer.service >/dev/null 2>&1 || true

  cat > /usr/share/applications/portainer.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Portainer CE
Comment=Manage local Docker containers
Exec=xdg-open https://localhost:9443
Icon=utilities-system-monitor
Terminal=false
Categories=Development;System;
EOF

  mkdir -p /usr/share/doc/demuntu-docker-gui-tools
  cat > /usr/share/doc/demuntu-docker-gui-tools/PORTAINER.txt <<EOF
Portainer CE is managed by demuntu-portainer.service and listens at:

https://localhost:9443

The service starts a local Docker container from:

${portainer_image}

On first launch, Portainer will ask you to create its local administrator
account.
EOF

  if command -v ufw >/dev/null 2>&1; then
    ufw allow 9443/tcp >/dev/null 2>&1 || true
  fi
}

write_validation_service() {
  cat > /usr/local/sbin/demuntu-docker-gui-tools-ready <<'EOF'
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
  printf '\nDEMUNTU_DOCKER_GUI_TOOLS_CHECKS\n'
  emit_check docker docker --version
  emit_check docker-enabled systemctl is-enabled docker
  if command -v lazydocker >/dev/null 2>&1; then
    emit_check lazydocker lazydocker --version
  else
    printf 'lazydocker: not installed\n'
  fi
  emit_check portainer-service systemctl is-enabled demuntu-portainer.service
  printf 'DEMUNTU_DOCKER_GUI_TOOLS_READY\n'
} > "$serial" 2>&1
EOF
  chmod 0755 /usr/local/sbin/demuntu-docker-gui-tools-ready

  cat > /etc/systemd/system/demuntu-docker-gui-tools-ready.service <<'EOF'
[Unit]
Description=Demuntu Docker GUI tools package-set boot marker
After=multi-user.target cloud-final.service serial-getty@ttyS0.service docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/demuntu-docker-gui-tools-ready

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable demuntu-docker-gui-tools-ready.service >/dev/null 2>&1 || true
}

require_root
install_prerequisites
install_docker_engine
install_lazydocker
install_portainer_service
write_validation_service
