#!/usr/bin/env bash
# iphone-music-sync: mirror a local music folder into VLC for iOS over USB.
# Usage: iphone-music-sync [-n] [MUSIC_DIR]
#        iphone-music-sync -i
#   -n         dry run: show what would be copied/deleted, change nothing
#   -i         show the connected phone's name and UDID, then exit
#   MUSIC_DIR  overrides the folder; otherwise it comes from the phones file
#              (see below), or your XDG music dir if there is no phones file
# Per-phone folders: ~/.config/iphone-music-sync/phones, one phone per line:
#   UDID  FOLDER  [APP]
# Once that file exists, a phone that isn't listed in it is refused, so one
# phone's music can't land on another phone by accident.
# Env overrides: IPHONE_MUSIC_APP (default: APP from the phones file, or
#                                  org.videolan.vlc-ios)
#                IPHONE_MUSIC_SUBDIR (default Music)
set -euo pipefail

phones_file="${XDG_CONFIG_HOME:-$HOME/.config}/iphone-music-sync/phones"
subdir="${IPHONE_MUSIC_SUBDIR:-Music}"
dry_run=()
identify=0

case "${1:-}" in
  -n) dry_run=(--dry-run); shift ;;
  -i) identify=1; shift ;;
esac

# One phone at a time, so it's always clear which phone gets which music
mapfile -t udids < <(idevice_id -l | grep .)
if (( ${#udids[@]} == 0 )); then
  echo "No iPhone detected. Plug it in, unlock it, and tap Trust if asked." >&2
  exit 1
fi
if (( ${#udids[@]} > 1 )); then
  echo "More than one iPhone is plugged in. Unplug all but the one to sync." >&2
  exit 1
fi
udid="${udids[0]}"
name="$(idevice_id "$udid" 2>/dev/null || echo "unknown name")"

if (( identify )); then
  echo "$name: $udid"
  exit 0
fi

# Look this phone up in the phones file
conf_dir=""
conf_app=""
if [[ -f "$phones_file" ]]; then
  while read -r line_udid line_dir line_app _; do
    [[ -z "$line_udid" || "$line_udid" == \#* ]] && continue
    if [[ "$line_udid" == "$udid" ]]; then
      conf_dir="$line_dir"
      conf_app="$line_app"
      break
    fi
  done <"$phones_file"
  if [[ -z "$conf_dir" ]]; then
    echo "\"$name\" ($udid) isn't listed in $phones_file." >&2
    echo "Add a line for it:  $udid  ~/SomeMusicFolder" >&2
    exit 1
  fi
fi
# A trailing comment on the line isn't an app ID
[[ "$conf_app" == \#* ]] && conf_app=""

app="${IPHONE_MUSIC_APP:-${conf_app:-org.videolan.vlc-ios}}"

if [[ -n "${1:-}" ]]; then
  src="$1"
elif [[ -n "$conf_dir" ]]; then
  src="${conf_dir/#\~/$HOME}"
else
  src="$(xdg-user-dir MUSIC 2>/dev/null || echo "$HOME/Music")"
fi
src="${src%/}/"

[[ -d "$src" ]] || { echo "Music folder not found: $src" >&2; exit 1; }
if [[ -z "$(find "$src" -type f -print -quit)" ]]; then
  echo "Music folder is empty: $src (refusing to wipe the phone)." >&2
  exit 1
fi
# xdg-user-dir falls back to $HOME when MUSIC isn't configured; never sync all of $HOME
if [[ "$src" == "${HOME%/}/" ]]; then
  echo "Refusing to sync your whole home folder. Pass a music folder explicitly." >&2
  exit 1
fi

apps="$(ifuse -u "$udid" --list-apps)"
if ! grep -qF "$app" <<<"$apps"; then
  echo "App $app not found on \"$name\" (is it installed, and the phone unlocked?)." >&2
  exit 1
fi

mnt="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/iphone-music.XXXXXX")"
cleanup() {
  fusermount -u "$mnt" 2>/dev/null || true
  rmdir "$mnt" 2>/dev/null || true
}
trap cleanup EXIT

ifuse -u "$udid" --documents "$app" "$mnt"
mkdir -p "$mnt/$subdir"

echo "Syncing $src -> \"$name\":$app/$subdir/"
# encode-output/ is Tauon's transcode folder: re-encoded copies of tracks already in the library
rsync -rt --modify-window=1 --delete --delete-excluded --exclude=/encode-output/ \
  --info=progress2 "${dry_run[@]}" "$src" "$mnt/$subdir/"
echo "Done. Open the music app on the phone to pick up the changes."
