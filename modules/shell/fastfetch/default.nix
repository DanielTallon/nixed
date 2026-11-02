# /.dotfiles/modules/shell/fastfetch/default.nix

# fastfetch, configured from a literal JSONC file
{
  flake.modules.homeManager.fastfetch = { pkgs, lib, ... }:
    let
      logoImage = pkgs.fetchurl {
        url = "https://camo.githubusercontent.com/4d0f616767bd4f25aa0da8f52498ffc690562c8166ea48811387c24a519802c0/68747470733a2f2f692e696d6775722e636f6d2f367146436c41312e706e67";
        hash = "sha256-XgWT+5hZiRRLpc44fYLNPucdT/oA9abgyboDWoSuKB8=";
      };
    in
    {
      programs.fastfetch.enable = true;
      xdg.configFile."fastfetch/config.jsonc".source = ./config.jsonc;
      xdg.configFile."fastfetch/logo.png".source = logoImage;
      # "nunny" from the Noctalia Discord, white background made transparent
      xdg.configFile."fastfetch/logo-niri.png".source = ./logo-niri.png;

      # Swap in the owl logo under Niri; KDE and everything else keep logo.png
      programs.fish.functions.fastfetch = ''
        if test "$XDG_CURRENT_DESKTOP" = niri
          command fastfetch --logo ~/.config/fastfetch/logo-niri.png $argv
        else
          command fastfetch $argv
        end
      '';
    };
}
