#!/usr/bin/env bash
#
# Remove the SDDM greeter autorotate hook installed by install-autorotate.sh,
# putting the greeter compositor back on the omarchy-settings config.
#
# The omarchy-plus theme itself is untouched -- 'make uninstall' removes that.
#
set -euo pipefail

THEME=omarchy-plus
ROTATE_DIR=/usr/share/sddm/$THEME
ROTATE_DROPIN=/etc/sddm.conf.d/zz-$THEME-wayland.conf

say() { printf '  %s\n' "$*"; }

if (( EUID != 0 )); then
  echo "Root is needed to write to /usr/share/sddm and /etc/sddm.conf.d"
  echo "-- re-running under sudo."
  echo
  exec sudo -- "$0" "$@"
fi

echo "Removing the SDDM greeter autorotate hook"
echo

# The override goes first: a CompositorCommand pointing at a config that is no
# longer there would stop the greeter starting at all.
if [[ -f $ROTATE_DROPIN ]]; then
  say "removing CompositorCommand override: $ROTATE_DROPIN"
  rm -f -- "$ROTATE_DROPIN"
else
  say "no $ROTATE_DROPIN found (already removed)"
fi

if [[ -d $ROTATE_DIR ]]; then
  say "removing greeter config and watcher: $ROTATE_DIR"
  rm -rf -- "$ROTATE_DIR"
else
  say "no $ROTATE_DIR found (already removed)"
fi

echo
echo "Done. The greeter compositor goes back to the omarchy-settings config and"
echo "the stock login screen. Nothing else was changed, so there is nothing to"
echo "restore."
