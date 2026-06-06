set -eu

live_user=""
for candidate in demuntu ubuntu; do
  if id "$candidate" >/dev/null 2>&1; then
    live_user="$candidate"
    break
  fi
done
if [ -z "$live_user" ]; then
  live_user=$(loginctl list-users --no-legend 2>/dev/null | awk 'NR == 1 {print $2}' || true)
fi
if [ -z "$live_user" ]; then
  echo "No live desktop user found" >&2
  exit 1
fi

live_uid=$(id -u "$live_user")

run_as_ubuntu() {
  sudo -u "$live_user" env \
    DISPLAY=:0 \
    XDG_RUNTIME_DIR="/run/user/$live_uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$live_uid/bus" \
    "$@"
}

wm_name() {
  run_as_ubuntu timeout 8 sh -lc '
    wid=$(xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | awk "{print \$5}")
    if [ -n "$wid" ]; then
      xprop -id "$wid" _NET_WM_NAME WM_NAME 2>/dev/null || true
    fi
  ' || true
}

echo "== baseline users/session =="
id "$live_user" || true
echo "live_user=$live_user live_uid=$live_uid"
run_as_ubuntu timeout 8 sh -lc 'echo XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unset}' || true

echo "== baseline processes =="
pgrep -a 'mate-session|marco|compiz|fusion' || true

echo "== baseline window manager =="
run_as_ubuntu timeout 8 xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null || true
wm_name

echo "== glxinfo =="
run_as_ubuntu timeout 12 sh -lc 'glxinfo -B 2>&1 | sed -n "1,60p"' || true

echo "== compiz binaries/plugins =="
compiz --version || true
ls \
  /usr/lib/x86_64-linux-gnu/compiz/libccp.so \
  /usr/lib/x86_64-linux-gnu/compiz/libcube.so \
  /usr/lib/x86_64-linux-gnu/compiz/libexpo.so \
  /usr/lib/x86_64-linux-gnu/compiz/librotate.so \
  2>&1 || true

echo "== attempting compiz --replace ccp =="
run_as_ubuntu timeout 8 sh -lc '
  rm -f /tmp/demuntu-compiz-manual.log
  nohup compiz --replace ccp >/tmp/demuntu-compiz-manual.log 2>&1 &
' || true
sleep 8

echo "== post-start processes =="
pgrep -a 'mate-session|marco|compiz|fusion' || true

echo "== post-start window manager =="
wm_name

echo "== compiz log =="
sed -n '1,160p' /tmp/demuntu-compiz-manual.log 2>/dev/null || true
