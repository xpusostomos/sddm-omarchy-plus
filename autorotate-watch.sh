#!/usr/bin/env bash
#
# Match the SDDM greeter compositor's rotation to the accelerometer.
#
# Started from hyprland.lua (same directory) at 'hyprland.start', so it runs as
# the sddm user inside the greeter compositor's environment. Hyprland's instance
# signature and XDG_RUNTIME_DIR are inherited, which is what hyprctl needs in
# order to find the IPC socket.
#
# Needs monitor-sensor, from extra/iio-sensor-proxy. Without it this exits at
# once and only the fixed orientation in hyprland.lua applies.
#
# The rotation itself is done by evaluating the global rotate() defined in
# hyprland.lua, so the output-name policy and the monitor rule itself stay in
# one place rather than being duplicated here.
#
# 'set -e' is deliberately omitted: a hyprctl that fails, while the greeter is
# shutting down say, must not kill this loop.
#
set -uo pipefail

hyprctl_bin=$(command -v hyprctl || :)
[[ -n $hyprctl_bin ]] || hyprctl_bin=/usr/bin/hyprctl
[[ -x $hyprctl_bin ]] || exit 0

monitor_sensor=$(command -v monitor-sensor || :)
[[ -n $monitor_sensor ]] || exit 0

# The orientation words and their transforms are the same mapping used by
# ~/bin/autorotate in a logged-in session.
"$monitor_sensor" 2>/dev/null | while IFS= read -r line; do
  case $line in
    *"right-up"*)  direction=3 ;;
    *"bottom-up"*) direction=2 ;;
    *"left-up"*)   direction=1 ;;
    *"normal"*)    direction=0 ;;
    *)             continue ;;
  esac

  "$hyprctl_bin" eval "rotate($direction)" >/dev/null 2>&1 || true
done
