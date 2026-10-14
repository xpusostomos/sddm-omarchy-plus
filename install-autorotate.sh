#!/usr/bin/env bash
#
# Make the SDDM Wayland greeter start upright on a 2-in-1, and optionally follow
# the accelerometer.
#
# The stock greeter compositor config (/usr/share/sddm/hyprland.lua) belongs to
# the omarchy-settings package and has no hook that runs when the compositor
# starts, so a rotated login screen can only be corrected from the compositor's
# own Lua config. This installs our own config next to it and points SDDM's
# [Wayland] CompositorCommand at it. The package file is never modified, and our
# config loads it, so omarchy-settings upgrades keep taking effect.
#
# Independent of 'make install' -- this does not install or need the theme.
#
# Usage:
#   sudo ./install-autorotate.sh [--orient normal|left-up|bottom-up|right-up]
#                                [--output NAME|auto] [--dry-run]
#
set -euo pipefail

THEME=omarchy-plus
ROTATE_DIR=/usr/share/sddm/$THEME
ROTATE_LUA=$ROTATE_DIR/hyprland.lua
ROTATE_BIN=$ROTATE_DIR/autorotate
ROTATE_DROPIN=/etc/sddm.conf.d/zz-$THEME-wayland.conf
STOCK_LUA=/usr/share/sddm/hyprland.lua
SRC_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

orient=normal
output=eDP-1
dry_run=0

say() { printf '  %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat >&2 <<'EOF'
usage: install-autorotate.sh [--orient normal|left-up|bottom-up|right-up]
                             [--output NAME|auto] [--dry-run]

  --orient   which way up the login screen should be (default: normal)
  --output   the panel to rotate (default: eDP-1, or "auto")
  --dry-run  render and validate the config, print it, install nothing
EOF
  exit "${1:-1}"
}

# Captured before the parse loop: that loop shifts, and the sudo re-exec below
# needs the original argv.
args=("$@")

while (( $# > 0 )); do
  case $1 in
    --orient)
      (( $# >= 2 )) || die "--orient needs a value"
      orient=$2; shift 2 ;;
    --output)
      (( $# >= 2 )) || die "--output needs a value"
      output=$2; shift 2 ;;
    --dry-run)
      dry_run=1; shift ;;
    -h|--help)
      usage 0 ;;
    *)
      die "unknown argument: $1" ;;
  esac
done

case $orient in
  normal|0)    transform=0 ;;
  left-up|1)   transform=1 ;;
  bottom-up|2) transform=2 ;;
  right-up|3)  transform=3 ;;
  *) die "unknown orientation '$orient' (expected normal, left-up, bottom-up, right-up)" ;;
esac

# Substituted into a Lua string literal and into the drop-in, so allow only
# characters that cannot break either.
[[ $output =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid output name '$output'"

[[ -r $SRC_DIR/autorotate.lua.in ]] || die "$SRC_DIR/autorotate.lua.in not found -- run this from the project directory."
[[ -r $SRC_DIR/autorotate-watch.sh ]] || die "$SRC_DIR/autorotate-watch.sh not found -- run this from the project directory."
command -v start-hyprland >/dev/null || die "start-hyprland not found -- SDDM is not using the Hyprland Wayland compositor here."
[[ -d /etc/sddm.conf.d ]] || die "/etc/sddm.conf.d not found -- is SDDM installed?"

render_lua() {
  local content
  content=$(<"$SRC_DIR/autorotate.lua.in")
  content=${content//@OUTPUT@/$output}
  content=${content//@TRANSFORM@/$transform}
  content=${content//@WATCHER@/$ROTATE_BIN}
  printf '%s\n' "$content"
}

echo "SDDM greeter autorotate"
echo

# Validate before anything is installed. This pass is unprivileged on purpose:
# Hyprland refuses to run as root, and the rendered config is what the greeter
# compositor will actually be started with, so a broken one means no login
# screen at all.
#
# The .lua suffix matters: without it Hyprland parses the file as hyprlang
# rather than Lua, and reports a config error on every line.
check_tmp=$(mktemp --suffix=.lua)
trap 'rm -f -- "$check_tmp"' EXIT
render_lua >"$check_tmp"

if command -v luac >/dev/null 2>&1; then
  luac -p "$check_tmp" || die "generated Lua does not compile -- please report this."
  say "syntax:  ok (luac -p)"
fi

if (( EUID != 0 )); then
  hyprland_bin=$(command -v Hyprland || command -v hyprland || :)
  if [[ -n $hyprland_bin ]]; then
    # Hyprland refuses to run as root, so this check is only possible before the
    # re-exec below. Only an explicitly reported config error is fatal -- this
    # subcommand is also known to crash, and to bail out for environmental
    # reasons, neither of which says anything about the file.
    verify_out=$("$hyprland_bin" --verify-config -c "$check_tmp" 2>&1 || :)
    if grep -q 'config ok' <<<"$verify_out"; then
      say "config:  ok ($hyprland_bin --verify-config)"
    elif grep -q 'Config error' <<<"$verify_out"; then
      die "hyprland rejected the generated config:
$verify_out"
    else
      say "config:  $hyprland_bin --verify-config could not check it;"
      say "         luac passed, so continuing"
    fi
  fi
fi

if (( dry_run == 1 )); then
  echo
  say "rendered config (dry run -- nothing installed):"
  echo
  render_lua | sed 's/^/  /'
  echo
  exit 0
fi

# exec() below replaces this process, so the EXIT trap would never run.
rm -f -- "$check_tmp"
trap - EXIT

if (( EUID != 0 )); then
  echo "Root is needed to write to /usr/share/sddm and /etc/sddm.conf.d"
  echo "-- re-running under sudo."
  echo
  exec sudo -- "$0" "${args[@]}"
fi

# Rendered again as root into a root-owned temporary, so no user-writable file
# crosses the sudo boundary.
work=$(mktemp --suffix=.lua)
trap 'rm -f -- "$work"' EXIT
render_lua >"$work"
if command -v luac >/dev/null 2>&1; then
  luac -p "$work" || die "generated Lua does not compile"
fi

say "greeter config:  $ROTATE_LUA"
install -d -m 0755 -- "$ROTATE_DIR"
install -m 0644 -- "$work" "$ROTATE_LUA"

say "watcher:         $ROTATE_BIN"
install -m 0755 -- "$SRC_DIR/autorotate-watch.sh" "$ROTATE_BIN"

# Written last: the config above has to exist before anything points at it.
say "override:        $ROTATE_DROPIN"
cat >"$ROTATE_DROPIN" <<EOF
# Written by omarchy-plus (make install-autorotate).
# Points the SDDM Wayland greeter compositor at this project's config, which
# applies the startup rotation and starts the accelerometer watcher.
# Remove this file, or run 'make uninstall-autorotate', to go back to the
# stock greeter config.
[Wayland]
CompositorCommand=start-hyprland -- --config $ROTATE_LUA
EOF

echo
echo "Done."
say "orientation:     $orient (transform $transform)"
say "output:          $output"
echo
echo "Notes:"
echo "  * Takes effect at the next greeter. Do NOT restart sddm from your"
echo "    session -- that logs you out. Log out or reboot to see it."
echo "  * The stock $STOCK_LUA is untouched and is still"
echo "    loaded from the new config, so omarchy-settings upgrades keep working."
echo "  * Only the internal panel is rotated. If yours is not called '$output'"
echo "    and not eDP*/DSI*/LVDS*, nothing will move -- use OUTPUT=auto or the"
echo "    right name."
if ! command -v monitor-sensor >/dev/null 2>&1; then
  echo "  * monitor-sensor is not installed, so only the fixed orientation above"
  echo "    applies. For automatic rotation:  sudo pacman -S iio-sensor-proxy"
fi
[[ -f $STOCK_LUA ]] || echo "  * $STOCK_LUA is missing; the built-in defaults are used instead."
echo "  * If the greeter ever fails to start, undo this from a TTY:"
echo "      sudo rm $ROTATE_DROPIN && sudo systemctl restart sddm"
