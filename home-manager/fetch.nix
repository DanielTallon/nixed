# /.dotfiles/home-manager/fetch.nix
{
  flake.modules.homeManager.fetch = { inputs, ... }: {
    imports = [ inputs.areofyl-fetch.homeManagerModules.default ];

    programs.fetch = {
      enable = true;
      speed = 0.9;
      spin = "y";
      size = 1.5;

info = [
      "os"
      "host"
      "kernel"
      "uptime"
      "packages"
      "shell"
      "wm"
      "theme"
      "font"
      "terminal"
      "cpu"
      "gpu"
      "display"
      "memory"
      "swap"
      "disk"
#      "battery"
      ];

    };
  };
}
