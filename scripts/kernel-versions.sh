#!/usr/bin/env bash
#Run this to install: chmod +x ~/.dotfiles/scripts/kernel-versions.sh
#Run: ~/.dotfiles/scripts/kernel-versions.sh

set -euo pipefail

FLAKE_DIR="$HOME/.dotfiles"
HOST="nixos"
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

# xddxdd needs the cachyos overlay applied manually, since it's conditional
xddxdd_ver=$(nix eval --raw --impure --expr "
  let
    flake = builtins.getFlake \"$FLAKE_DIR\";
    pkgs = import flake.inputs.nixpkgs {
      system = \"x86_64-linux\";
      overlays = [ flake.inputs.\"nix-cachyos-kernel\".overlays.pinned ];
    };
  in pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v3.kernel.version
" 2>/dev/null || echo "N/A")
printf "%-10s %s\n" "xddxdd" "$xddxdd_ver"
