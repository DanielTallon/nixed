#!/usr/bin/env bash
# display-mode: step through projector modes, like Win+P on Windows.
# Usage: display-mode [computer|clone|extend|projector]
#   With no argument, moves to the next mode in this order:
#   computer only -> clone -> extend -> projector only -> computer only ...
# Bound to XF86Display (the ThinkPad's projector key) and Mod+P in
# niri/config.kdl.
#
# The built-in screen is the eDP/LVDS/DSI output; the projector is the
# first other connected output. niri can't mirror outputs itself, so clone
# shows the built-in screen on the projector in a fullscreen wl-mirror
# window. Changes go through `niri msg output`, so they're temporary and
# reset on re-login, like niri's own output commands.
#
# DISPLAY_MODE_INTERNAL=<output> picks the "built-in" screen by hand, for
# trying this on a machine with no laptop panel (the desktop's two monitors).
set -euo pipefail

title="display-mode-mirror"

notify() {
  notify-send -a "Display mode" -i video-display -h string:x-canonical-private-synchronous:display-mode "$@"
}

outputs="$(niri msg --json outputs)"

internal="${DISPLAY_MODE_INTERNAL:-$(jq -r '
  [keys[] | select(test("^(eDP|LVDS|DSI)"))] | sort | first // empty' <<<"$outputs")}"
if [[ -z "$internal" ]]; then
  notify "No built-in screen found"
  exit 1
fi
external="$(jq -r --arg i "$internal" '
  [keys[] | select(. != $i)] | sort | first // empty' <<<"$outputs")"

is_on() { jq -e --arg o "$1" '.[$o].logical != null' <<<"$outputs" >/dev/null; }

# The clone window's PID is kept in a file rather than found with
# `pgrep -f`, which would also match any shell whose command line mentions
# the window title.
pidfile="${XDG_RUNTIME_DIR:-/tmp}/display-mode-mirror.pid"
mirror_pid() {
  local pid
  pid="$(cat "$pidfile" 2>/dev/null)" || return 1
  [[ "$pid" =~ ^[0-9]+$ ]] && [[ "$(cat "/proc/$pid/comm" 2>/dev/null)" == *wl-mirror* ]] || return 1
  echo "$pid"
}
mirroring() { mirror_pid >/dev/null; }
stop_mirror() {
  local pid
  if pid="$(mirror_pid)"; then kill "$pid" || true; fi
  rm -f "$pidfile"
}

# Only the built-in screen: make sure it's on and there's nothing to switch.
if [[ -z "$external" ]]; then
  stop_mirror
  is_on "$internal" || niri msg output "$internal" on
  notify "No projector connected" "Plug in a second screen to switch modes."
  exit 0
fi

# Work out the current mode from what's on.
if is_on "$internal" && is_on "$external"; then
  if mirroring; then current=clone; else current=extend; fi
elif is_on "$external"; then
  current=projector
else
  current=computer
fi

case "${1:-}" in
  computer|clone|extend|projector) mode="$1" ;;
  "")
    case "$current" in
      computer) mode=clone ;;
      clone) mode=extend ;;
      extend) mode=projector ;;
      projector) mode=computer ;;
    esac
    ;;
  *)
    echo "Usage: display-mode [computer|clone|extend|projector]" >&2
    exit 1
    ;;
esac

# Turn outputs on before turning any off, so there's never a moment with
# every screen dark.
case "$mode" in
  computer)
    stop_mirror
    niri msg output "$internal" on
    niri msg output "$external" off
    notify "Computer screen only" "$internal"
    ;;
  clone)
    niri msg output "$internal" on
    niri msg output "$external" on
    if ! mirroring; then
      # A background job isn't a process group leader, so setsid execs
      # wl-mirror in place and $! is wl-mirror's own PID.
      setsid wl-mirror --title "$title" --fullscreen-output "$external" "$internal" \
        </dev/null >/dev/null 2>&1 &
      echo "$!" >"$pidfile"
      disown
    fi
    notify "Clone" "$internal shown on $external"
    ;;
  extend)
    stop_mirror
    niri msg output "$internal" on
    niri msg output "$external" on
    notify "Extend" "$internal and $external"
    ;;
  projector)
    stop_mirror
    niri msg output "$external" on
    niri msg output "$internal" off
    notify "Projector only" "$external"
    ;;
esac
