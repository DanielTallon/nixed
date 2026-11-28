# /.dotfiles/modules/desktop/icons.nix
#---Icon Theme---
# BeautyLine: the neon gradient icons from Garuda's Dr460nized edition.
# Applies to both sessions (niri and Plasma), since both read the same two
# settings below. To switch back, drop "icons" from the features list in
# modules/hosts.nix: everything falls back to Breeze.
let
  iconTheme = "BeautyLine";
in
{
  flake.modules.nixos.icons = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.beauty-line-icon-theme ];
  };

  flake.modules.homeManager.icons = {
    # GTK apps read this (through dconf) on Wayland.
    dconf.settings."org/gnome/desktop/interface".icon-theme = iconTheme;

    # Qt/KDE apps read kdeglobals: Plasma itself, and under niri too, since
    # QT_QPA_PLATFORMTHEME=kde there (modules/desktop/niri.nix). Written
    # directly rather than with programs.plasma.workspace.iconTheme, which
    # only applies at Plasma login and so would never reach niri.
    programs.plasma.configFile.kdeglobals.Icons.Theme = iconTheme;
  };
}
