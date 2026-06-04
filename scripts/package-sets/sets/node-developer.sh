#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

node_major="${NODE_MAJOR:-24}"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "node-developer package set must run as root" >&2
    exit 1
  fi
}

install_prerequisites() {
  apt-get update
  apt-get install -y ca-certificates curl gnupg apt-transport-https
}

add_nodesource_repo() {
  local arch

  arch="$(dpkg --print-architecture)"
  install -m 0755 -d /usr/share/keyrings /etc/apt/preferences.d /etc/apt/sources.list.d

  rm -f /usr/share/keyrings/nodesource.gpg
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
  chmod 0644 /usr/share/keyrings/nodesource.gpg

  cat > /etc/apt/sources.list.d/nodesource.sources <<EOF
Types: deb
URIs: https://deb.nodesource.com/node_${node_major}.x
Suites: nodistro
Components: main
Architectures: ${arch}
Signed-By: /usr/share/keyrings/nodesource.gpg
EOF

  cat > /etc/apt/preferences.d/nodesource-nodejs <<'EOF'
Package: nodejs
Pin: origin deb.nodesource.com
Pin-Priority: 600
EOF

  cat > /etc/apt/preferences.d/nodesource-nsolid <<'EOF'
Package: nsolid
Pin: origin deb.nodesource.com
Pin-Priority: 600
EOF
}

add_vscode_repo() {
  install -m 0755 -d /usr/share/keyrings /etc/apt/sources.list.d

  rm -f /usr/share/keyrings/microsoft.gpg
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
  chmod 0644 /usr/share/keyrings/microsoft.gpg

  cat > /etc/apt/sources.list.d/vscode.sources <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
}

add_docker_repo() {
  local arch codename

  arch="$(dpkg --print-architecture)"
  # shellcheck disable=SC1091
  . /etc/os-release
  codename="${DOCKER_UBUNTU_CODENAME:-${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}}"

  if [ -z "$codename" ]; then
    echo "could not determine Ubuntu codename for Docker repository" >&2
    exit 1
  fi

  install -m 0755 -d /etc/apt/keyrings /etc/apt/sources.list.d
  rm -f /etc/apt/keyrings/docker.asc
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  chmod 0644 /etc/apt/keyrings/docker.asc

  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${codename}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
}

install_packages() {
  apt-get update
  apt-get install -y \
    nodejs \
    code \
    git \
    build-essential \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  if ! command -v npm >/dev/null 2>&1; then
    echo "npm was not installed with the NodeSource nodejs package" >&2
    exit 1
  fi

  systemctl enable docker >/dev/null 2>&1 || true
  if id ubuntu >/dev/null 2>&1; then
    usermod -aG docker ubuntu
  fi
}

write_validation_service() {
  cat > /usr/local/sbin/demuntu-node-developer-ready <<'EOF'
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
  printf '\nDEMUNTU_NODE_DEVELOPER_CHECKS\n'
  emit_check node node --version
  emit_check npm npm --version
  emit_check code code --version --user-data-dir /tmp/demuntu-code-check --no-sandbox
  emit_check git git --version
  emit_check gcc gcc --version
  emit_check docker docker --version
  emit_check docker-enabled systemctl is-enabled docker
  emit_check ubuntu-groups id ubuntu
  printf 'DEMUNTU_NODE_DEVELOPER_READY\n'
} > "$serial" 2>&1
EOF
  chmod 0755 /usr/local/sbin/demuntu-node-developer-ready

  cat > /etc/systemd/system/demuntu-node-developer-ready.service <<'EOF'
[Unit]
Description=Demuntu Node Developer package-set boot marker
After=multi-user.target cloud-final.service serial-getty@ttyS0.service docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/demuntu-node-developer-ready

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable demuntu-node-developer-ready.service >/dev/null 2>&1 || true
}

require_root
install_prerequisites
add_nodesource_repo
add_vscode_repo
add_docker_repo
install_packages
write_validation_service
