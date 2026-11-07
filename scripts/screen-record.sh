#!/usr/bin/env bash
# screen-record: start or stop a silent recording of the focused monitor,
# like the record option in Plasma's Print Screen tool.
# Usage: screen-record
#   First press starts recording, the next press stops and saves it.
# Recordings go to ~/Videos/Screencasts. No audio is captured.
# Notifications are paused (Noctalia Do Not Disturb) while recording.
set -euo pipefail

dir="${XDG_VIDEOS_DIR:-$HOME/Videos}/Screencasts"

# Already recording: SIGINT makes gpu-screen-recorder finish the file.
# Match on the command line, not the name: Linux cuts process names to 15
# characters ("gpu-screen-reco"), so `pkill -x gpu-screen-recorder` never
# matches. Matching our output folder also leaves alone recordings started
# from the GTK app.
if pkill -INT -f -- "gpu-screen-recorder .*-o $dir/"; then
  exit 0
fi

output="$(niri msg --json focused-output | jq -r '.name')"
file="$dir/Recording from $(date '+%Y-%m-%d %H-%M-%S').mp4"
mkdir -p "$dir"

notify-send -a "Screen recorder" -i media-record "Recording $output" \
  "Press Shift+Print again to stop."

# Keep notifications out of the recording. gpu-screen-recorder grabs the
# monitor straight from KMS, bypassing niri, so niri's block-out-from rules
# can't hide them. Turn on Noctalia's Do Not Disturb instead, and put it back
# the way it was afterwards. If Noctalia isn't running, record anyway.
dnd_before=""
if command -v noctalia >/dev/null; then
  dnd_before="$(noctalia msg notification-dnd-status)" || dnd_before=""
fi

restore_dnd() {
  if [[ -n "$dnd_before" ]]; then
    noctalia msg notification-dnd-set "$dnd_before"
    dnd_before=""
  fi
}

if [[ -n "$dnd_before" ]]; then
  # Restore on any exit too, so a crash can't leave DND stuck on.
  trap restore_dnd EXIT
  noctalia msg notification-dnd-set on

  # Let the "Recording" popup be read, then clear it (and any other popups)
  # and give the fade-out a moment to finish before capture starts.
  sleep 1.5
  noctalia msg notification-clear-active
  sleep 0.5
fi

# gpu-screen-recorder comes from the system profile, where
# programs.gpu-screen-recorder gives it the capture rights it needs.
status=0
gpu-screen-recorder -w "$output" -f 60 -cursor yes -o "$file" || status=$?

# Restore DND before the result notification so it isn't held back.
restore_dnd

if [[ $status -eq 0 ]]; then
  notify-send -a "Screen recorder" -i media-record "Recording saved" "$file"
else
  notify-send -a "Screen recorder" -i dialog-error -u critical \
    "Recording failed" "gpu-screen-recorder exited with an error."
fi
