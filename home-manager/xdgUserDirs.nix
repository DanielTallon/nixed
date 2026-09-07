# /.dotfiles/home-manager/xdg.nix
#---XDG User Directories---
{
  flake.modules.homeManager.xdgUserDirs = {
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
