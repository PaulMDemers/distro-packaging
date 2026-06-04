#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: boot-iso.sh [options] ISO_PATH

Options:
  --timeout SECONDS      Run QEMU for a bounded smoke test.
  --headless             Use a non-interactive display for smoke testing.
  --screendump PATH      Capture a QEMU screen dump after boot wait seconds.
  --expect-serial TEXT   Pass only if TEXT appears on the serial console.
  --serial-log PATH      Serial console log path for --expect-serial.
  --boot-wait SECONDS    Seconds to wait before screendump. Default: 12.
  --memory MB            Guest memory. Default: 2048.
  --cpus N               Guest vCPUs. Default: 2.
  --accel MODE           QEMU acceleration: auto, kvm, tcg, none. Default: auto.
  --no-rng               Do not attach QEMU's virtio RNG device.
  --display DISPLAY      QEMU display backend. Default: default.

Environment overrides:
  QEMU_TIMEOUT, QEMU_BOOT_WAIT, QEMU_MEMORY, QEMU_CPUS, QEMU_ACCEL,
  QEMU_DISPLAY
EOF
}

timeout_seconds="${QEMU_TIMEOUT:-0}"
boot_wait="${QEMU_BOOT_WAIT:-12}"
memory="${QEMU_MEMORY:-2048}"
cpus="${QEMU_CPUS:-2}"
accel="${QEMU_ACCEL:-auto}"
display="${QEMU_DISPLAY:-default}"
screendump=""
expect_serial=""
serial_log=""
headless=false
use_rng=true

while [ "$#" -gt 0 ]; do
  case "$1" in
    --timeout)
      timeout_seconds="$2"
      shift 2
      ;;
    --headless)
      headless=true
      shift
      ;;
    --screendump)
      screendump="$2"
      shift 2
      ;;
    --expect-serial)
      expect_serial="$2"
      shift 2
      ;;
    --serial-log)
      serial_log="$2"
      shift 2
      ;;
    --boot-wait)
      boot_wait="$2"
      shift 2
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
    --no-rng)
      use_rng=false
      shift
      ;;
    --display)
      display="$2"
      shift 2
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

if [ ! -f "$iso" ]; then
  echo "missing ISO: $iso" >&2
  exit 1
fi

base_args=(
  -m "$memory"
  -smp "$cpus"
  -cdrom "$iso"
  -boot d
  -no-reboot
  -net none
)

case "$accel" in
  auto)
    if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
      base_args+=(-enable-kvm)
    fi
    ;;
  kvm)
    base_args+=(-enable-kvm)
    ;;
  tcg)
    base_args+=(-accel tcg)
    ;;
  none)
    ;;
  *)
    echo "unknown accelerator: $accel" >&2
    exit 2
    ;;
esac

if [ "$use_rng" = true ]; then
  base_args+=(-device virtio-rng-pci)
fi

if [ -n "$expect_serial" ]; then
  if [ "$timeout_seconds" = "0" ]; then
    timeout_seconds="300"
  fi
  if [ -z "$serial_log" ]; then
    serial_log="$(pwd)/qemu-serial.log"
  fi
  serial_log="$(realpath -m "$serial_log")"
  mkdir -p "$(dirname "$serial_log")"
  rm -f "$serial_log"

  if [ "$headless" = true ] && [ "$display" = "default" ]; then
    display="none"
  fi

  tmpdir="$(mktemp -d)"
  pidfile="$tmpdir/qemu.pid"

  cleanup_expect() {
    if [ -f "$pidfile" ]; then
      pid="$(cat "$pidfile")"
      if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
        sleep 1
        if kill -0 "$pid" 2>/dev/null; then
          kill -KILL "$pid" 2>/dev/null || true
        fi
      fi
    fi
    rm -rf "$tmpdir"
  }
  trap cleanup_expect EXIT

  qemu-system-x86_64 \
    "${base_args[@]}" \
    -display "$display" \
    -serial "file:$serial_log" \
    -pidfile "$pidfile" \
    -daemonize

  deadline=$((SECONDS + timeout_seconds))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if tr -d '\r' < "$serial_log" | grep -Fx -- "$expect_serial" >/dev/null 2>&1; then
      echo "serial assertion passed: $expect_serial"
      echo "serial log: $serial_log"
      exit 0
    fi

    if [ -f "$pidfile" ]; then
      pid="$(cat "$pidfile")"
      if ! kill -0 "$pid" 2>/dev/null; then
        echo "QEMU exited before serial assertion passed." >&2
        break
      fi
    fi

    sleep 1
  done

  echo "serial assertion failed: $expect_serial" >&2
  echo "serial log: $serial_log" >&2
  exit 1
fi

if [ -n "$screendump" ]; then
  screendump="$(realpath -m "$screendump")"
  mkdir -p "$(dirname "$screendump")"

  tmpdir="$(mktemp -d)"
  monitor="$tmpdir/qemu-monitor.sock"
  pidfile="$tmpdir/qemu.pid"

  cleanup() {
    if [ -f "$pidfile" ]; then
      pid="$(cat "$pidfile")"
      if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
        sleep 1
        if kill -0 "$pid" 2>/dev/null; then
          kill -KILL "$pid" 2>/dev/null || true
        fi
      fi
    fi
    rm -rf "$tmpdir"
  }
  trap cleanup EXIT

  if [ "$headless" = true ] && [ "$display" = "default" ]; then
    display="vnc=127.0.0.1:0,to=99"
  fi

  qemu-system-x86_64 \
    "${base_args[@]}" \
    -display "$display" \
    -monitor "unix:$monitor,server,nowait" \
    -pidfile "$pidfile" \
    -daemonize

  sleep "$boot_wait"

  python3 - "$monitor" "$screendump" <<'PY'
import socket
import sys
import time

monitor_path, screendump_path = sys.argv[1], sys.argv[2]
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(monitor_path)
time.sleep(0.2)
try:
    sock.recv(4096)
except OSError:
    pass
sock.sendall(f"screendump {screendump_path}\n".encode())
time.sleep(0.5)
try:
    sock.recv(4096)
except OSError:
    pass
sock.close()
PY

  echo "captured QEMU screendump: $screendump"
  exit 0
fi

if [ "$headless" = true ] && [ "$display" = "default" ]; then
  display="none"
fi

if [ "$timeout_seconds" != "0" ]; then
  set +e
  timeout "${timeout_seconds}s" qemu-system-x86_64 \
    "${base_args[@]}" \
    -display "$display" \
    -serial mon:stdio
  rc="$?"
  set -e

  if [ "$rc" -eq 124 ]; then
    echo "QEMU stayed up for ${timeout_seconds}s smoke test."
    exit 0
  fi

  exit "$rc"
fi

exec qemu-system-x86_64 \
  "${base_args[@]}" \
  -display "$display" \
  -serial stdio
