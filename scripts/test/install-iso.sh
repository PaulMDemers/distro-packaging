#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: install-iso.sh [options] ISO_PATH

Options:
  --disk PATH            qcow2 disk path. Default: build/test/install-disk.qcow2.
  --disk-size SIZE       qemu-img disk size. Default: 20G.
  --timeout SECONDS      Install timeout. Default: 3600.
  --install-complete-serial TEXT
                         Stop installer VM once TEXT appears in installer serial log.
  --boot-timeout SECONDS Installed disk boot timeout. Default: 300.
  --serial-log PATH      Installer serial log path.
  --boot-serial-log PATH Installed boot serial log path.
  --expect-serial TEXT   Marker expected when booting installed disk.
  --headless             Use display=none.
  --memory MB            Guest memory. Default: 4096.
  --cpus N               Guest vCPUs. Default: 2.
  --accel MODE           QEMU acceleration: auto, kvm, tcg, none. Default: auto.
  --machine MACHINE      QEMU machine type for install and boot VMs.
  --abort-on-serial TEXT Abort installer wait if TEXT appears in installer serial log.
  --ssh-forward PORT     Forward host TCP port to guest SSH. Default: 2222.
  --boot-sendkeys KEYS   Comma-separated QEMU sendkey sequence for installer boot.
  --boot-sendkey-delay SECONDS
                         Seconds to wait before sending boot keys. Default: 5.
  --skip-install         Do not run installer; only boot the existing disk.
  --skip-boot            Do not boot-test the installed disk after install.
  --boot-check-on-timeout
                         If installer times out, stop it and try disk boot check.
  --keep-disk            Reuse existing disk instead of recreating it.
EOF
}

disk="build/test/install-disk.qcow2"
disk_size="20G"
timeout_seconds="3600"
install_complete_serial=""
boot_timeout_seconds="300"
serial_log="build/test/install-serial.log"
boot_serial_log="build/test/installed-boot-serial.log"
expect_serial=""
display="default"
memory="4096"
cpus="2"
accel="${QEMU_ACCEL:-auto}"
machine="${QEMU_MACHINE:-}"
abort_on_serial=""
ssh_forward="2222"
boot_sendkeys=""
boot_sendkey_delay="5"
skip_install=false
skip_boot=false
boot_check_on_timeout=false
keep_disk=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --disk)
      disk="$2"
      shift 2
      ;;
    --disk-size)
      disk_size="$2"
      shift 2
      ;;
    --timeout)
      timeout_seconds="$2"
      shift 2
      ;;
    --install-complete-serial)
      install_complete_serial="$2"
      shift 2
      ;;
    --boot-timeout)
      boot_timeout_seconds="$2"
      shift 2
      ;;
    --serial-log)
      serial_log="$2"
      shift 2
      ;;
    --boot-serial-log)
      boot_serial_log="$2"
      shift 2
      ;;
    --expect-serial)
      expect_serial="$2"
      shift 2
      ;;
    --headless)
      display="none"
      shift
      ;;
    --memory)
      memory="$2"
      shift 2
      ;;
    --cpus)
      cpus="$2"
      shift 2
      ;;
    --accel)
      accel="$2"
      shift 2
      ;;
    --machine)
      machine="$2"
      shift 2
      ;;
    --abort-on-serial)
      abort_on_serial="$2"
      shift 2
      ;;
    --ssh-forward)
      ssh_forward="$2"
      shift 2
      ;;
    --boot-sendkeys)
      boot_sendkeys="$2"
      shift 2
      ;;
    --boot-sendkey-delay)
      boot_sendkey_delay="$2"
      shift 2
      ;;
    --skip-install)
      skip_install=true
      shift
      ;;
    --skip-boot)
      skip_boot=true
      shift
      ;;
    --boot-check-on-timeout)
      boot_check_on_timeout=true
      shift
      ;;
    --keep-disk)
      keep_disk=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

iso="$(realpath "$1")"
disk="$(realpath -m "$disk")"
serial_log="$(realpath -m "$serial_log")"
boot_serial_log="$(realpath -m "$boot_serial_log")"

if [ ! -f "$iso" ]; then
  echo "missing ISO: $iso" >&2
  exit 1
fi

mkdir -p "$(dirname "$disk")" "$(dirname "$serial_log")" "$(dirname "$boot_serial_log")"

qemu_accel_args=()
case "$accel" in
  auto)
    if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
      qemu_accel_args=(-enable-kvm)
    fi
    ;;
  kvm)
    qemu_accel_args=(-enable-kvm)
    ;;
  tcg)
    qemu_accel_args=(-accel tcg)
    ;;
  none)
    ;;
  *)
    echo "unknown accelerator: $accel" >&2
    exit 2
    ;;
esac

qemu_machine_args=()
if [ -n "$machine" ]; then
  qemu_machine_args=(-machine "$machine")
fi

run_qemu_wait() {
  local pidfile="$1"
  local timeout_s="$2"
  local complete_log="$3"
  local complete_marker="$4"
  local abort_marker="$5"
  local deadline
  deadline=$((SECONDS + timeout_s))

  while [ "$SECONDS" -lt "$deadline" ]; do
    if [ -n "$abort_marker" ] && grep -F -- "$abort_marker" "$complete_log" >/dev/null 2>&1; then
      echo "installer abort marker observed: $abort_marker" >&2
      return 2
    fi

    if [ -n "$complete_marker" ] && grep -F -- "$complete_marker" "$complete_log" >/dev/null 2>&1; then
      echo "installer completion marker observed: $complete_marker"
      return 0
    fi

    if [ -f "$pidfile" ]; then
      pid="$(cat "$pidfile")"
      if ! kill -0 "$pid" 2>/dev/null; then
        return 0
      fi
    fi
    sleep 2
  done

  return 1
}

stop_qemu() {
  local pidfile="$1"
  if [ -f "$pidfile" ]; then
    pid="$(cat "$pidfile")"
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid" 2>/dev/null || true
      sleep 2
      if kill -0 "$pid" 2>/dev/null; then
        kill -KILL "$pid" 2>/dev/null || true
      fi
    fi
  fi
}

send_boot_keys() {
  local monitor="$1"
  local keys_csv="$2"
  local delay="$3"

  [ -n "$keys_csv" ] || return 0
  sleep "$delay"

  python3 - "$monitor" "$keys_csv" <<'PY'
import socket
import sys
import time

monitor_path, keys_csv = sys.argv[1], sys.argv[2]
commands = [key.strip() for key in keys_csv.split(",") if key.strip()]

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
deadline = time.monotonic() + 15
while True:
    try:
        sock.connect(monitor_path)
        break
    except OSError:
        if time.monotonic() > deadline:
            raise
        time.sleep(0.2)

time.sleep(0.2)
try:
    sock.recv(4096)
except OSError:
    pass

for key in commands:
    sock.sendall(f"sendkey {key}\n".encode())
    time.sleep(0.35)
    try:
        sock.recv(4096)
    except OSError:
        pass

sock.close()
PY
}

if [ "$skip_install" = false ]; then
  if [ "$keep_disk" = false ]; then
    rm -f "$disk"
    qemu-img create -f qcow2 "$disk" "$disk_size"
  elif [ ! -f "$disk" ]; then
    qemu-img create -f qcow2 "$disk" "$disk_size"
  fi

  rm -f "$serial_log"
  install_tmp="$(mktemp -d)"
  install_pidfile="$install_tmp/qemu-install.pid"
  install_monitor="$install_tmp/qemu-install-monitor.sock"
  install_monitor_args=()
  if [ -n "$boot_sendkeys" ]; then
    install_monitor_args=(-monitor "unix:$install_monitor,server,nowait")
  fi

  qemu-system-x86_64 \
    "${qemu_accel_args[@]}" \
    "${qemu_machine_args[@]}" \
    -m "$memory" \
    -smp "$cpus" \
    -drive "file=$disk,format=qcow2,if=virtio" \
    -cdrom "$iso" \
    -boot d \
    -netdev "user,id=n1,hostfwd=tcp::$ssh_forward-:22" \
    -device virtio-net-pci,netdev=n1 \
    -device virtio-rng-pci \
    -serial "file:$serial_log" \
    "${install_monitor_args[@]}" \
    -display "$display" \
    -pidfile "$install_pidfile" \
    -no-reboot \
    -daemonize

  send_boot_keys "$install_monitor" "$boot_sendkeys" "$boot_sendkey_delay"

  set +e
  run_qemu_wait "$install_pidfile" "$timeout_seconds" "$serial_log" "$install_complete_serial" "$abort_on_serial"
  wait_rc="$?"
  set -e

  if [ "$wait_rc" -ne 0 ]; then
    stop_qemu "$install_pidfile"
    if [ "$wait_rc" -eq 2 ]; then
      echo "installer aborted because serial log matched: $abort_on_serial" >&2
    else
      echo "installer did not exit within ${timeout_seconds}s" >&2
    fi
    echo "installer serial log: $serial_log" >&2
    rm -rf "$install_tmp"

    if [ "$wait_rc" -eq 2 ] || [ "$boot_check_on_timeout" = false ] || [ "$skip_boot" = true ] || [ -z "$expect_serial" ]; then
      exit 1
    fi

    echo "continuing with installed disk boot check after installer timeout"
  else
    stop_qemu "$install_pidfile"
    rm -rf "$install_tmp"
    echo "installer finished: $disk"
    echo "installer serial log: $serial_log"
  fi
fi

if [ "$skip_boot" = true ]; then
  exit 0
fi

if [ -z "$expect_serial" ]; then
  echo "installed disk boot skipped: --expect-serial was not provided"
  exit 0
fi

rm -f "$boot_serial_log"
boot_tmp="$(mktemp -d)"
boot_pidfile="$boot_tmp/qemu-boot.pid"

qemu-system-x86_64 \
  "${qemu_accel_args[@]}" \
  "${qemu_machine_args[@]}" \
  -m "$memory" \
  -smp "$cpus" \
  -drive "file=$disk,format=qcow2,if=virtio" \
  -boot c \
  -netdev "user,id=n1,hostfwd=tcp::$ssh_forward-:22" \
  -device virtio-net-pci,netdev=n1 \
  -device virtio-rng-pci \
  -serial "file:$boot_serial_log" \
  -display "$display" \
  -pidfile "$boot_pidfile" \
  -daemonize

deadline=$((SECONDS + boot_timeout_seconds))
while [ "$SECONDS" -lt "$deadline" ]; do
  if grep -F -- "$expect_serial" "$boot_serial_log" >/dev/null 2>&1; then
    stop_qemu "$boot_pidfile"
    rm -rf "$boot_tmp"
    echo "installed disk boot assertion passed: $expect_serial"
    echo "installed boot serial log: $boot_serial_log"
    exit 0
  fi

  if [ -f "$boot_pidfile" ]; then
    pid="$(cat "$boot_pidfile")"
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "installed disk VM exited before assertion passed" >&2
      break
    fi
  fi

  sleep 1
done

stop_qemu "$boot_pidfile"
rm -rf "$boot_tmp"
echo "installed disk boot assertion failed: $expect_serial" >&2
echo "installed boot serial log: $boot_serial_log" >&2
exit 1
