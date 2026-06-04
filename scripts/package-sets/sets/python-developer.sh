#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "python-developer package set must run as root" >&2
    exit 1
  fi
}

install_packages() {
  apt-get update
  apt-get install -y \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    pipx \
    git \
    build-essential \
    sqlite3 \
    jq \
    direnv

  if id ubuntu >/dev/null 2>&1; then
    runuser -u ubuntu -- pipx ensurepath >/dev/null 2>&1 || true
  fi
}

write_validation_service() {
  cat > /usr/local/sbin/demuntu-python-developer-ready <<'EOF'
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
  printf '\nDEMUNTU_PYTHON_DEVELOPER_CHECKS\n'
  emit_check python python3 --version
  emit_check pip pip3 --version
  emit_check venv python3 -m venv --help
  emit_check pipx pipx --version
  emit_check git git --version
  emit_check gcc gcc --version
  emit_check sqlite sqlite3 --version
  emit_check jq jq --version
  emit_check direnv direnv version
  printf 'DEMUNTU_PYTHON_DEVELOPER_READY\n'
} > "$serial" 2>&1
EOF
  chmod 0755 /usr/local/sbin/demuntu-python-developer-ready

  cat > /etc/systemd/system/demuntu-python-developer-ready.service <<'EOF'
[Unit]
Description=Demuntu Python Developer package-set boot marker
After=multi-user.target cloud-final.service serial-getty@ttyS0.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/demuntu-python-developer-ready

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable demuntu-python-developer-ready.service >/dev/null 2>&1 || true
}

require_root
install_packages
write_validation_service
