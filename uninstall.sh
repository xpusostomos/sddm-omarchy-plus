#!/usr/bin/env bash
#
# Remove the omarchy-plus theme and point SDDM back at the stock theme.
#
set -euo pipefail

THEME=omarchy-plus
STOCK=omarchy
THEME_DIR=/usr/share/sddm/themes/$THEME
DROPIN=/etc/sddm.conf.d/zz-$THEME.conf

say() { printf '  %s\n' "$*"; }

if (( EUID != 0 )); then
  echo "Root is needed to write to /usr/share/sddm/themes and /etc/sddm.conf.d"
  echo "-- re-running under sudo."
  echo
  exec sudo -- "$0" "$@"
fi

echo "Removing $THEME"
echo

if [[ -f $DROPIN ]]; then
  say "removing theme selection: $DROPIN"
  rm -f -- "$DROPIN"
else
  say "no $DROPIN found (already removed)"
fi

if [[ -d $THEME_DIR ]]; then
  say "removing theme directory: $THEME_DIR"
  rm -rf -- "$THEME_DIR"
else
  say "no $THEME_DIR found (already removed)"
fi

echo
echo "Done. SDDM falls back to the omarchy-settings configuration, which"
echo "selects '$STOCK'. That theme was never modified, so nothing to restore."
