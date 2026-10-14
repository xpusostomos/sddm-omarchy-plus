#!/usr/bin/env bash
#
# Preview the theme in SDDM's greeter test mode.
#
# Stages a throwaway copy of the theme -- stock artwork plus this project's
# Main.qml -- and runs the greeter against it. Nothing on the system is
# touched, so this is safe to run as often as you like while iterating.
#
set -euo pipefail

SRC_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STOCK=/usr/share/sddm/themes/omarchy
STAGE=${TMPDIR:-/tmp}/omarchy-plus-preview

GREETER=sddm-greeter-qt6
command -v "$GREETER" >/dev/null || GREETER=sddm-greeter

[[ -d $STOCK ]] || { echo "error: no stock theme at $STOCK" >&2; exit 1; }

rm -rf -- "$STAGE"
mkdir -p -- "$STAGE"
cp -a -- "$STOCK"/. "$STAGE"/
cp -- "$SRC_DIR"/Main.qml "$SRC_DIR"/theme.conf "$SRC_DIR"/metadata.desktop "$STAGE"/

echo "Staged preview:  $STAGE"
echo "Artwork from:    $STOCK"
echo "Greeter:         $GREETER --test-mode"
echo
echo "Close the greeter window to exit. QML errors print below."
echo

exec "$GREETER" --test-mode --theme "$STAGE"
