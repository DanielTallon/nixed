# /.dotfiles/modules/bootstrap.nix
#
# One-command setup for a freshly installed NixOS machine:
#
#   nix --extra-experimental-features 'nix-command flakes' \
#     run github:DanielTallon/nixed -- <host>
#
# <host> is "nixos" (desktop) or "laptop"; defaults to the current hostname.
# Run it as your normal user (not root) AFTER Calamares has installed a
# minimal system and you've rebooted into it. It will:
#   1. clone the repo to ~/.dotfiles (refuses if that path already exists)
#   2. copy this machine's /etc/nixos/hardware-configuration.nix into it
#   3. swap the placeholder username for yours (public copy only)
#   4. build the system with nom (live dependency tree), then
#      `nixos-rebuild boot` — then you reboot into the real config
#
# Overrides: NIXED_REPO=<git url>  NIXED_DEST=<path>
# See INSTALL.md for the full install walkthrough.
{
  perSystem = { pkgs, ... }: {
    apps.default = {
      type = "app";
      meta.description = "Clone these dotfiles onto a fresh NixOS install and rebuild";
      program = pkgs.lib.getExe (pkgs.writeShellApplication {
        name = "nixed-bootstrap";
        runtimeInputs = [ pkgs.git pkgs.nix-output-monitor ];
        text = ''
          repo="''${NIXED_REPO:-https://github.com/DanielTallon/nixed.git}"
          dest="''${NIXED_DEST:-$HOME/.dotfiles}"
          host="''${1:-$(hostname)}"

          case "$host" in
            nixos | desktop) host="nixos";  hwdir="desktop" ;;
            laptop)          host="laptop"; hwdir="laptop"  ;;
            *)
              echo "Unknown host '$host'. Usage: nix run github:DanielTallon/nixed -- <nixos|laptop>" >&2
              exit 1
              ;;
          esac

          if [ "$(id -u)" -eq 0 ]; then
            echo "Run this as your normal user, not root (it will sudo when needed)." >&2
            exit 1
          fi

          if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
            echo "/etc/nixos/hardware-configuration.nix not found. Generate it with: sudo nixos-generate-config" >&2
            exit 1
          fi

          if [ -e "$dest" ]; then
            echo "$dest already exists. Move it aside (or set NIXED_DEST) and re-run." >&2
            exit 1
          fi

          # Ask for sudo once up front and keep it alive for the whole install
          # (the build can outlast sudo's 5-minute timeout). The loop exits
          # on its own when this script does.
          sudo -v
          while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done &

          echo "==> Cloning $repo into $dest"
          git clone "$repo" "$dest"

          echo "==> Using this machine's hardware-configuration.nix for hosts/$hwdir"
          cp /etc/nixos/hardware-configuration.nix "$dest/hosts/$hwdir/hardware-configuration.nix"

          me="$(id -un)"
          if grep -q 'username = "youruser";' "$dest/flake.nix"; then
            echo "==> Setting username to '$me' in flake.nix"
            sed -i "s/username = \"youruser\";/username = \"$me\";/" "$dest/flake.nix"
          fi

          # Flakes only see git-tracked files.
          git -C "$dest" add -A

          # Fresh installs don't have flakes or the nix-community cache enabled
          # yet; pass both for this first build (root is a trusted user).
          # warn-dirty: the hardware config and username edits are
          # intentionally left uncommitted, so skip the "Git tree is dirty" noise.
          nixconf="experimental-features = nix-command flakes
          extra-substituters = https://nix-community.cachix.org
          extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
          warn-dirty = false"

          # `boot`, not `switch`: the real kernel/NVIDIA setup differs from
          # Calamares' defaults, so don't activate it in the live session.
          echo "==> Building $host. This can take a while."
          sudo env NIX_CONFIG="$nixconf" PATH="$PATH" \
            nom build "$dest#nixosConfigurations.$host.config.system.build.toplevel" --no-link

          echo "==> Installing boot entry"
          sudo env NIX_CONFIG="$nixconf" nixos-rebuild boot --flake "$dest#$host"

          echo
          echo "Done. Reboot to start the real config. Use 'nh os switch' from then on."
        '';
      });
    };
  };
}
