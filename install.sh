#!/usr/bin/env bash
#
# Install the Omarchy SDDM theme with session selector as "omarchy-plus".
#
# The stock "omarchy" theme is left completely untouched. This installs a
# separate theme alongside it and points SDDM's Current= at the new one, so
# reverting is just removing one config file.
#
set -euo pipefail

THEME=omarchy-plus
STOCK=omarchy
THEME_DIR=/usr/share/sddm/themes/$THEME
STOCK_DIR=/usr/share/sddm/themes/$STOCK
DROPIN=/etc/sddm.conf.d/zz-$THEME.conf
SRC_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Artwork is symlinked to the stock theme rather than copied, so a desktop
# theme change (which regenerates these via omarchy-plymouth-set) is reflected
# here automatically instead of leaving stale colours behind.
ASSETS=(bullet.png entry-failed.png entry.png lock-failed.png lock.png logo.png)

say() { printf '  %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if (( EUID != 0 )); then
  echo "Root is needed to write to /usr/share/sddm/themes and /etc/sddm.conf.d"
  echo "-- re-running under sudo."
  echo
  exec sudo -- "$0" "$@"
fi

echo "Installing $THEME (stock $STOCK theme is not modified)"
echo

[[ -d $STOCK_DIR ]] || die "$STOCK_DIR not found -- is the omarchy theme installed?"
[[ -f $SRC_DIR/Main.qml ]] || die "$SRC_DIR/Main.qml not found -- run this from the project directory."

say "theme directory: $THEME_DIR"
install -d -m 0755 -- "$THEME_DIR"

say "artwork symlinked from $STOCK_DIR:"
for asset in "${ASSETS[@]}"; do
  [[ -f $STOCK_DIR/$asset ]] || die "$STOCK_DIR/$asset missing"
  ln -sfn -- "$STOCK_DIR/$asset" "$THEME_DIR/$asset"
  say "  $asset -> $STOCK_DIR/$asset"
done

echo
say "installing modified files:"
for f in Main.qml theme.conf metadata.desktop; do
  install -m 0644 -- "$SRC_DIR/$f" "$THEME_DIR/$f"
  say "  $f"
done

echo
say "pointing SDDM at the new theme:"
say "  $DROPIN"
cat >"$DROPIN" <<EOF
# Written by omarchy-sddm (make install).
# Remove this file, or run 'make uninstall', to go back to the stock theme.
[Theme]
Current=$THEME
EOF

echo
echo "Done. SDDM will use '$THEME' at the next greeter."
echo
echo "Notes:"
echo "  * The stock '$STOCK' theme is untouched and still selectable -- change"
echo "    Current= to '$STOCK' to go back, or run 'make uninstall'."
echo "  * This drop-in sorts after the omarchy-settings ones, so it wins."
echo "  * Autologin is still enabled, so you will not see the greeter at all."
echo "    Run 'make install-no-auto-login' to disable it."
echo "  * 'omarchy-refresh-sddm' rewrites themes/$STOCK, not themes/$THEME, so"
echo "    this install survives it."
