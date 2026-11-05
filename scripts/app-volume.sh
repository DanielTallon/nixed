#!/usr/bin/env bash
# app-volume: change the volume of the app whose window is focused in niri,
# like hovering a task in Plasma's taskbar and scrolling.
# Usage: app-volume up|down|mute [STEP]
#   STEP  how much up/down moves the volume (default 5%)
# Works on every audio stream the app plays, including ones from child
# processes (browsers and Electron apps play sound from a helper process).
set -euo pipefail

action="${1:?usage: app-volume up|down|mute [STEP]}"
step="${2:-5%}"

window="$(niri msg --json focused-window)"
pid="$(jq -r '.pid // empty' <<<"$window")"
title="$(jq -r '.title // .app_id // "This window"' <<<"$window")"
[[ -n "$pid" ]] || exit 0

# The window's process and everything under it.
pids=("$pid")
for ((i = 0; i < ${#pids[@]}; i++)); do
  mapfile -t children < <(pgrep -P "${pids[i]}" || true)
  pids+=("${children[@]}")
done

# Playback streams whose PipeWire client is one of those processes. The PID
# is on the client, not the stream node, so join the two.
mapfile -t streams < <(
  pw-dump | jq -r --args '
    ($ARGS.positional) as $pids
    | [.[] | select(.type == "PipeWire:Interface:Client")
           | select((.info.props["application.process.id"] | tostring) as $p
                    | $pids | index($p))
           | .id] as $clients
    | .[] | select(.type == "PipeWire:Interface:Node")
          | select(.info.props["media.class"] == "Stream/Output/Audio")
          | select(.info.props["client.id"] as $c | $clients | index($c))
          | .id' "${pids[@]}"
)

notify() {
  # One popup that updates in place instead of stacking: reuse the last
  # popup's ID (Noctalia ignores the x-canonical-private-synchronous hint).
  # Transient keeps it out of the notification history.
  local id_file="${XDG_RUNTIME_DIR:-/tmp}/app-volume.id" id=0
  [[ -r "$id_file" ]] && id="$(<"$id_file")"
  notify-send --transient --app-name "App volume" --expire-time 1500 \
    --replace-id "$id" --print-id "$@" >"$id_file"
}

if ((${#streams[@]} == 0)); then
  notify "$title" "Not playing any sound"
  exit 0
fi

case "$action" in
  up | down)
    sign="+"
    [[ "$action" == down ]] && sign="-"
    for id in "${streams[@]}"; do
      wpctl set-volume --limit 1.0 "$id" "${step}${sign}"
    done
    ;;
  mute)
    # Follow the first stream so all of them end up the same.
    if wpctl get-volume "${streams[0]}" | grep -q MUTED; then mute=0; else mute=1; fi
    for id in "${streams[@]}"; do
      wpctl set-mute "$id" "$mute"
    done
    ;;
  *)
    echo "app-volume: unknown action '$action' (use up, down or mute)" >&2
    exit 1
    ;;
esac

# "Volume: 0.40" or "Volume: 0.40 [MUTED]"
read -r _ level muted < <(wpctl get-volume "${streams[0]}")
percent="$(awk -v v="$level" 'BEGIN { printf "%d", v * 100 + 0.5 }')"
notify --hint "int:value:$percent" "$title" "${percent}%${muted:+ (muted)}"
