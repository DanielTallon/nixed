# /.dotfiles/modules/shell/fetch/default.nix

# areofyl's animated fetch. Upstream's home-manager module hard-wires its own
# unpatched package, so this installs the package and writes the config itself.
{
  flake.modules.homeManager.fetch = { inputs, pkgs, ... }: {
    home.packages = [
      # title.patch adds a `title=` setting that replaces the user@host line,
      # so screen recordings don't show my name
      (inputs.areofyl-fetch.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./title.patch ];
      }))
    ];

    # Info fields in display order (add "battery" to show it), then settings
    xdg.configFile."fetch/config".text = ''
      os
      host
      kernel
      uptime
      packages
      shell
      wm
      theme
      font
      terminal
      cpu
      gpu
      display
      memory
      swap
      disk
      title=nixos
      label_color=magenta
      separator=-
      size=1.5
      speed=0.9
      spin=y
    '';
  };
}
