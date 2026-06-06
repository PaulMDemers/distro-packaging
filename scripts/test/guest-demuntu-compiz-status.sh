set -eu

live_user=""
for candidate in demuntu ubuntu; do
  if id "$candidate" >/dev/null 2>&1; then
    live_user="$candidate"
    break
  fi
done
live_uid=$(id -u "$live_user" 2>/dev/null || echo 1000)

run_as_live_user() {
  sudo -u "$live_user" env \
    DISPLAY=:0 \
    XDG_RUNTIME_DIR="/run/user/$live_uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$live_uid/bus" \
    "$@"
}

echo "== process status =="
pgrep -a 'mate-session|marco|compiz|fusion|xprop|glxinfo' || true
ps -ef | grep -E 'compiz|marco|xprop|glxinfo|demuntu-compiz' | grep -v grep || true

echo "== active window manager =="
if [ -n "$live_user" ]; then
  run_as_live_user timeout 8 xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null || true
  run_as_live_user timeout 8 sh -lc '
    wid=$(xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | awk "{print \$5}")
    if [ -n "$wid" ]; then
      xprop -id "$wid" _NET_WM_NAME WM_NAME 2>/dev/null || true
    fi
  ' || true
fi

echo "== glxinfo =="
if [ -n "$live_user" ]; then
  run_as_live_user timeout 12 sh -lc 'glxinfo -B 2>&1 | sed -n "1,60p"' || true
fi

echo "== compiz log =="
sed -n '1,200p' /tmp/demuntu-compiz-manual.log 2>/dev/null || true

echo "== users =="
id demuntu || true
id ubuntu || true
