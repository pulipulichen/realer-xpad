#!/usr/bin/env bash
# Run a command inside a throwaway headless sway (pure Wayland, no Xwayland).
#   tools/headless.sh pytest -q
#   tools/headless.sh python tools/screenshot.py screenshots
set -euo pipefail

# A private session bus too, so tray tests don't reach the real tray.
if [ -z "${REALER_XPAD_HEADLESS:-}" ] && command -v dbus-run-session >/dev/null; then
  export REALER_XPAD_HEADLESS=1
  exec dbus-run-session -- "$0" "$@"
fi
export REALER_XPAD_HEADLESS=1

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if ! command -v wtype >/dev/null; then
  echo "headless tests require wtype for a virtual Wayland keyboard" >&2
  exit 1
fi
tmp=$(mktemp -d)
sway_pid=
keyboard_pid=
cleanup() {
  if [ -n "$keyboard_pid" ]; then
    kill "$keyboard_pid" 2>/dev/null || true
    wait "$keyboard_pid" 2>/dev/null || true
  fi
  if [ -n "$sway_pid" ]; then
    kill "$sway_pid" 2>/dev/null || true
    wait "$sway_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

# sway reports its socket name through an exec'd child, so there's no guessing.
cat > "$tmp/config" <<EOF
output HEADLESS-1 resolution 1600x1000 bg #303030 solid_color
for_window [app_id="ch.giosuel.RealerXpad"] floating enable
default_border none
exec printenv WAYLAND_DISPLAY > "$tmp/display"
exec printenv SWAYSOCK > "$tmp/socket"
EOF

WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman WAYLAND_DISPLAY='' \
  sway -c "$tmp/config" >"$tmp/sway.log" 2>&1 &
sway_pid=$!

for _ in $(seq 50); do
  [ -s "$tmp/display" ] && [ -s "$tmp/socket" ] && break
  sleep 0.1
done
if [ ! -s "$tmp/display" ] || [ ! -s "$tmp/socket" ]; then
  echo "sway failed to start" >&2
  cat "$tmp/sway.log" >&2
  exit 1
fi

# No desktop portal in a bare session; don't let GTK/libadwaita wait on it.
WAYLAND_DISPLAY=$(cat "$tmp/display")
export WAYLAND_DISPLAY GDK_BACKEND=wayland ADW_DISABLE_PORTAL=1 GDK_DEBUG=no-portals GTK_A11Y=none
# Not the real Hyprland, even when run from inside it.
unset DISPLAY HYPRLAND_INSTANCE_SIGNATURE

# GTK's is-active tracks keyboard focus, not just the xdg-toplevel activated
# state. A device-free headless Sway seat needs a keyboard for focus events.
# Keep a virtual keyboard connected for the test session. F24 supplies a
# valid keymap; the key itself is scheduled after the test session.
wtype -s 1000000 -k F24 >"$tmp/keyboard.log" 2>&1 &
keyboard_pid=$!
sway_socket=$(cat "$tmp/socket")
keyboard_ready=false
for _ in $(seq 50); do
  if ! kill -0 "$keyboard_pid" 2>/dev/null; then
    break
  fi
  if swaymsg -s "$sway_socket" -r -t get_inputs 2>/dev/null |
    grep -E '"type"[[:space:]]*:[[:space:]]*"keyboard"' >/dev/null; then
    keyboard_ready=true
    break
  fi
  sleep 0.1
done
if [ "$keyboard_ready" != true ]; then
  echo "headless virtual keyboard failed to start" >&2
  cat "$tmp/keyboard.log" "$tmp/sway.log" >&2
  exit 1
fi
"$@"
