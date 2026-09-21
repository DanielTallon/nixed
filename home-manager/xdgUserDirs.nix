# /.dotfiles/home-manager/xdg.nix
#---XDG User Directories---
{
  flake.modules.homeManager.xdgUserDirs = {
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };

    # xdg-user-dirs-update (or booting an older generation) can recreate
    # this as a plain file outside Nix's control, which makes activation
    # refuse to proceed once a stale .backup exists. Since this file is
    # fully declarative here anyway, just always overwrite it.
    xdg.configFile."user-dirs.dirs".force = true;
  };
}
