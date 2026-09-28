#!/usr/bin/env bash
# Written by nixed-install. Stage 2 of the nixed install.
#
# Runs automatically on the first boot (tty1 autologin, see
# configuration.nix next to this file) while /var/lib/nixed/stage2 exists:
#   1. waits for the network
#   2. runs the nixed bootstrap app (modules/bootstrap.nix): clone the repo
#      to ~/.dotfiles, carry over hardware/locale/GPU/Windows detection,
#      build the real host, `nixos-rebuild boot`
#   3. removes the marker and reboots into the real config
#
# To retry by hand after a failure:  bash /etc/nixos/nixed-stage2.sh
set -uo pipefail

host="@HOST@"
repo="@REPO@"
ref="@REF@"
marker=/var/lib/nixed/stage2

flake="git+$repo"
if [ -n "$ref" ]; then flake="$flake?ref=$ref"; fi

clear
echo "============================================================"
echo " nixed install, stage 2 of 2: building '$host'"
echo " from $flake"
echo " This takes a while. It reboots on its own when it's done."
echo "============================================================"
echo

echo "==> Waiting for the network"
online=false
for _ in $(seq 1 60); do
  if curl -fsS -o /dev/null --max-time 5 https://github.com; then
    online=true
    break
  fi
  sleep 2
done
if [ "$online" != true ]; then
  echo "No network after 2 minutes. Connect with 'nmtui', then run:"
  echo "  bash /etc/nixos/nixed-stage2.sh"
  exit 1
fi

# A previous failed attempt leaves ~/.dotfiles behind, and the bootstrap
# refuses to clone over it. Keep it, just out of the way.
if [ -e "$HOME/.dotfiles" ]; then
  old="$HOME/.dotfiles.failed-$(date +%Y%m%d-%H%M%S)"
  echo "==> Moving the previous attempt's ~/.dotfiles to $old"
  mv "$HOME/.dotfiles" "$old"
fi

if NIXED_REPO="$repo" NIXED_REF="$ref" \
  nix --extra-experimental-features 'nix-command flakes' run "$flake" -- "$host"; then
  sudo rm -f "$marker"
  echo
  echo "Stage 2 finished. Rebooting into the real config in 15 seconds."
  echo "(Ctrl+C to stay here; reboot later with 'sudo reboot'.)"
  sleep 15 && sudo systemctl reboot
else
  echo
  echo "Stage 2 failed (see the output above). Fix the problem, then retry with:"
  echo "  bash /etc/nixos/nixed-stage2.sh"
  echo "It also runs again on its own the next time you log in on tty1."
  exit 1
fi
