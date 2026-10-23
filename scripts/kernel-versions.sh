#!/usr/bin/env bash
#Run this to install: chmod +x ~/.dotfiles/scripts/kernel-versions.sh
#Run: ~/.dotfiles/scripts/kernel-versions.sh

set -euo pipefail

FLAKE_DIR="$HOME/.dotfiles"
# This machine's config (/etc/nixed-host), since both hosts share the hostname "nixos"
HOST="$(cat /etc/nixed-host 2>/dev/null || hostname)"
cd "$FLAKE_DIR"

echo "Kernel versions for host: $HOST"
echo "--------------------------------"

declare -A providers=(
  [lts]="linuxPackages"
  [latest]="linuxPackages_latest"
  [zen]="linuxPackages_zen"
  [xanmod]="linuxPackages_xanmod_latest"
  [chaotic]="linuxPackages_cachyos"
)

for name in lts latest zen xanmod chaotic; do
  attr="${providers[$name]}"
  ver=$(nix eval --raw ".#nixosConfigurations.${HOST}.pkgs.${attr}.kernel.version" 2>/dev/null || echo "N/A")
  printf "%-10s %s\n" "$name" "$ver"
done
