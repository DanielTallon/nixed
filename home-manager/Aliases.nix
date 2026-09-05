# /.dotfiles/home-manager/Aliases.nix
{
  flake.modules.homeManager.aliases = { config, pkgs, lib, ... }: {
    # --- Fonts ---
    home.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.meslo-lg

      # --- Aliases ---
      # `nhs` / `nhs switch`: stages new files (git add -A) before rebuilding,
      # since flakes only see tracked/staged files. Run from the flake root.
      (writeShellScriptBin "nhs" ''
        set -euo pipefail
        git add -A
        exec nh os "''${1:-test}" .
      '')

      # `kernel version`: prints the resolved kernel version for each
      # provider in kernel.nix, via ~/.dotfiles/scripts/kernel-versions.sh
      (writeShellScriptBin "kernel" ''
        set -euo pipefail
        case "''${1:-}" in
          version)
            exec "$HOME/.dotfiles/scripts/kernel-versions.sh"
            ;;
          *)
            echo "Usage: kernel version" >&2
            exit 1
            ;;
        esac
      '')
    ];
    fonts.fontconfig.enable = true;
  };
}
