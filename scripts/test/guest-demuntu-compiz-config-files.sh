set -eu

live_user=""
for candidate in demuntu ubuntu; do
  if id "$candidate" >/dev/null 2>&1; then
    live_user="$candidate"
    break
  fi
done

for path in \
  "/home/$live_user/.config/compiz-1/compizconfig/config" \
  /etc/compizconfig/config.conf \
  /etc/compizconfig/mate.conf \
  /etc/compizconfig/mate.ini \
  /etc/compizconfig/config \
  /usr/share/compizconfig/config
do
  echo "== $path =="
  ls -l "$path" 2>/dev/null || true
  sed -n '1,160p' "$path" 2>/dev/null || true
done
