#!/usr/bin/env bash
#
# Comment out SDDM autologin so the greeter is actually shown.
#
# The Omarchy installer writes /etc/sddm.conf.d/autologin.conf on encrypted
# installs (you already typed a passphrase at the disk, so it skips the
# greeter). Without this, a custom greeter theme is never displayed.
#
set -euo pipefail

CONF=/etc/sddm.conf.d/autologin.conf
BACKUP=$CONF.orig

say() { printf '  %s\n' "$*"; }

if (( EUID != 0 )); then
  echo "Root is needed to edit $CONF -- re-running under sudo."
  echo
  exec sudo -- "$0" "$@"
fi

echo "Disabling SDDM autologin"
echo

if [[ ! -f $CONF ]]; then
  say "$CONF does not exist -- autologin is already off."
  exit 0
fi

tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT

changed=0
while IFS= read -r line || [[ -n $line ]]; do
  if [[ $line =~ ^[[:space:]]*(User|Session)[[:space:]]*= ]]; then
    printf '# %s\n' "$line" >>"$tmp"
    say "commented out: $line"
    changed=1
  else
    printf '%s\n' "$line" >>"$tmp"
  fi
done <"$CONF"

if (( changed == 0 )); then
  say "no active User= or Session= lines found -- autologin is already disabled."
  exit 0
fi

if [[ ! -f $BACKUP ]]; then
  cp -a -- "$CONF" "$BACKUP"
  say "backed up original to $BACKUP"
fi

install -m 0644 -- "$tmp" "$CONF"

echo
echo "Done. Autologin is disabled; SDDM will show the greeter at next login."
echo "To re-enable, restore the backup: sudo mv $BACKUP $CONF"
