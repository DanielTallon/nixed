#!/usr/bin/env bash
# iphone-music-sync: mirror a local music folder into VLC for iOS over USB.
# Usage: iphone-music-sync [-n] [MUSIC_DIR]
#   -n         dry run: show what would be copied/deleted, change nothing
#   MUSIC_DIR  defaults to your XDG music dir (usually ~/Music)
# Env overrides: IPHONE_MUSIC_APP (default org.videolan.vlc-ios)
#                IPHONE_MUSIC_SUBDIR (default Music)
set -euo pipefail

app="${IPHONE_MUSIC_APP:-org.videolan.vlc-ios}"
subdir="${IPHONE_MUSIC_SUBDIR:-Music}"
dry_run=()

if [[ "${1:-}" == "-n" ]]; then
  dry_run=(--dry-run)
  shift
fi

src="${1:-$(xdg-user-dir MUSIC 2>/dev/null || echo "$HOME/Music")}"
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

if [[ -z "$(idevice_id -l)" ]]; then
  echo "No iPhone detected. Plug it in, unlock it, and tap Trust if asked." >&2
  exit 1
fi

apps="$(ifuse --list-apps)"
if ! grep -qF "$app" <<<"$apps"; then
  echo "App $app not found on the phone (is it installed, and the phone unlocked?)." >&2
  exit 1
fi

mnt="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/iphone-music.XXXXXX")"
cleanup() {
  fusermount -u "$mnt" 2>/dev/null || true
  rmdir "$mnt" 2>/dev/null || true
}
trap cleanup EXIT

ifuse --documents "$app" "$mnt"
mkdir -p "$mnt/$subdir"

echo "Syncing $src -> iPhone:$app/$subdir/"
rsync -rt --modify-window=1 --delete --info=progress2 "${dry_run[@]}" "$src" "$mnt/$subdir/"
echo "Done. Open VLC on the phone to pick up the changes."
