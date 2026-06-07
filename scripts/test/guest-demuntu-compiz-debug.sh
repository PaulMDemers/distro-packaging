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

echo "== profile files =="
find "/home/$live_user/.config/compiz-1" -maxdepth 4 -type f -print -exec sed -n '1,100p' {} \; || true

echo "== gsettings schemas =="
run_as_live_user sh -lc 'gsettings list-schemas | grep -i compiz | sort' || true

echo "== gsettings active plugins =="
run_as_live_user sh -lc '
for schema in $(gsettings list-schemas | grep -i compiz | sort); do
  if gsettings list-keys "$schema" 2>/dev/null | grep -q "^active-plugins$"; then
    echo "$schema"
    gsettings get "$schema" active-plugins
  fi
done
' || true
