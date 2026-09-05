#!/usr/bin/env bash
#
# check-updates.sh — for the nix-packages repo (DanielTallon/nix-packages)
#
# Checks lgl-papercutter and kenku-fm against their upstream GitHub releases.
# If either is behind, applies whatever bump can be automated, prints any
# steps that need YOUR hands, and — only if you pass --push — commits and
# pushes the change as a normal commit (no history rewriting).
#
# USAGE:
    #Check + apply automatable bumps, no git ops
#
#   bash ~/.dotfiles/scripts/check-updates.sh --dry-run --dry-run    # check only, print what WOULD change, touch nothing
#   bash ~/.dotfiles/scripts/check-updates.sh
#   bash ~/.dotfiles/scripts/check-updates.sh --push       # also commit + push
#
#
#
#
#
#
# REQUIRES: gh (authenticated), nix, nix-update, jq
#
# Paths below match the actual DanielTallon/nix-packages structure
# (lgl-papercutter/package.nix, kenku-fm/package.nix). Still worth a
# --dry-run pass before your first real run, in case the version/hash
# line format in those files doesn't match the patterns assumed here.

set -euo pipefail

REPO_DIR="${NIX_PACKAGES_DIR:-$HOME/Develop/nix-packages}"
SCRIPT_REL_PATH="scripts/check-updates.sh"   # this script's path INSIDE the repo, so it can unstage itself

LGL_PKG_FILE="lgl-papercutter/package.nix"
LGL_REPO="linuxgamerlife/lgl-papercutter"

KENKU_PKG_FILE="kenku-fm/package.nix"
KENKU_REPO="owlbear-rodeo/kenku-fm"

DRY_RUN=false
DO_PUSH=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --push) DO_PUSH=true ;;
    *) echo "unknown flag: $arg" >&2; exit 1 ;;
  esac
done

cd "$REPO_DIR"

manual_steps=()
changed=false

log() { echo "-> $*"; }

# ---- helpers -----------------------------------------------------------

get_pinned_version() {
  # assumes a line like:  version = "0.3.0";
  grep -oP '(?<=version = ")[^"]+' "$1" | head -n1
}

get_latest_tag() {
  gh api "repos/$1/releases/latest" --jq .tag_name
}

strip_v() { echo "${1#v}"; }

# ---- lgl-papercutter (fetchFromGitHub, tag-pinned) ----------------------

log "Checking lgl-papercutter..."
lgl_current="$(get_pinned_version "$LGL_PKG_FILE")"
lgl_latest_tag="$(get_latest_tag "$LGL_REPO")"
lgl_latest="$(strip_v "$lgl_latest_tag")"

if [[ "$lgl_current" != "$lgl_latest" ]]; then
  log "lgl-papercutter: $lgl_current -> $lgl_latest"
  if $DRY_RUN; then
    manual_steps+=("[DRY RUN] would run: nix-update lgl-papercutter --version=$lgl_latest --commit=false")
  else
    if nix-update lgl-papercutter --version="$lgl_latest" --commit=false; then
      changed=true
      log "lgl-papercutter bumped automatically via nix-update"
    else
      manual_steps+=("lgl-papercutter: nix-update failed — bump $LGL_PKG_FILE to $lgl_latest by hand (check CHANGELOG.md for breaking changes: https://github.com/$LGL_REPO/blob/main/CHANGELOG.md)")
    fi
  fi
else
  log "lgl-papercutter up to date ($lgl_current)"
fi

# ---- kenku-fm (fetchurl .deb, pinned to a specific release asset) -------

log "Checking kenku-fm..."
kenku_current="$(get_pinned_version "$KENKU_PKG_FILE")"
kenku_latest_tag="$(get_latest_tag "$KENKU_REPO")"
kenku_latest="$(strip_v "$kenku_latest_tag")"

if [[ "$kenku_current" != "$kenku_latest" ]]; then
  log "kenku-fm: $kenku_current -> $kenku_latest"

  deb_url="$(gh api "repos/$KENKU_REPO/releases/tags/$kenku_latest_tag" \
    --jq '.assets[] | select(.name | test("amd64\\.deb$")) | .browser_download_url' | head -n1)"

  if [[ -z "$deb_url" ]]; then
    manual_steps+=("kenku-fm: couldn't find an amd64 .deb asset on release $kenku_latest_tag — check https://github.com/$KENKU_REPO/releases/tag/$kenku_latest_tag by hand")
  elif $DRY_RUN; then
    manual_steps+=("[DRY RUN] would prefetch $deb_url and update $KENKU_PKG_FILE (version, url, hash)")
  else
    new_hash="$(nix store prefetch-file --json "$deb_url" | jq -r .hash)"
    # TODO: confirm these sed patterns match your actual package.nix syntax
    sed -i \
      -e "s|version = \"[^\"]*\"|version = \"$kenku_latest\"|" \
      -e "s|url = \"[^\"]*\"|url = \"$deb_url\"|" \
      -e "s|hash = \"[^\"]*\"|hash = \"$new_hash\"|" \
      "$KENKU_PKG_FILE"
    changed=true
    log "kenku-fm bumped: $kenku_latest, url + hash updated"
    manual_steps+=("kenku-fm: sed-based edit applied automatically — DOUBLE CHECK $KENKU_PKG_FILE diff before trusting it, sed is naive about which lines it hits")
  fi
else
  log "kenku-fm up to date ($kenku_current)"
fi

# ---- verify before touching git -----------------------------------------

if $changed && ! $DRY_RUN; then
  log "Verifying builds..."
  if ! nix build .#lgl-papercutter .#kenku-fm --no-link; then
    echo "BUILD FAILED — not committing or pushing. Fix the package files and re-run." >&2
    exit 1
  fi
  log "Builds succeeded."
fi

# ---- report manual steps --------------------------------------------------

if [[ ${#manual_steps[@]} -gt 0 ]]; then
  echo ""
  echo "=== Steps you need to take ==="
  for s in "${manual_steps[@]}"; do
    echo "  - $s"
  done
fi

if $changed; then
  echo ""
  echo "=== Don't forget ==="
  echo "  - After this lands on GitHub: in ~/.dotfiles run"
  echo "      nix flake lock --update-input nix-packages"
  echo "    then rebuild (nhs), since the dotfiles pin nix-packages separately."
fi

if $DRY_RUN; then
  echo ""
  echo "Dry run — nothing was staged, committed, or pushed."
  exit 0
fi

if ! $changed; then
  log "Nothing to commit."
  exit 0
fi

if ! $DO_PUSH; then
  echo ""
  echo "Changes applied locally but --push not passed — not touching git."
  echo "Re-run with --push once you've reviewed the diff above."
  exit 0
fi

# ---- stage, unstage self, commit, push (normal linear history) -----------

log "Staging changes..."
git add -A
git reset -- "$SCRIPT_REL_PATH" 2>/dev/null || true   # never let this script's own state ride along

if git diff --cached --quiet; then
  log "Nothing staged after excluding the script itself — done."
  exit 0
fi

commit_msg="Update packages ($(date +%Y-%m-%d))"
[[ "$lgl_current" != "$lgl_latest" ]] && commit_msg+="

lgl-papercutter: $lgl_current -> $lgl_latest"
[[ "$kenku_current" != "$kenku_latest" ]] && commit_msg+="
kenku-fm: $kenku_current -> $kenku_latest"

log "Committing..."
git commit -m "$commit_msg"

log "Pushing..."
git push origin main

log "Done."
