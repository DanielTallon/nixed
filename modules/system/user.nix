# /.dotfiles/modules/system/user.nix
# The user account (NixOS half) and the home-manager basics for it.
# Groups a feature needs (networkmanager, gamemode, ...) are added by that
# feature's own file.
{
  flake.modules.nixos.user = { lib, username, ... }: {
    users.users.${username} = {
      isNormalUser = true;
      group = username;
      description =
        lib.toUpper (builtins.substring 0 1 username)
        + builtins.substring 1 (-1) username;
      extraGroups = [ "wheel" ];
    };

    users.groups.${username} = { };

    # Only wheel members can even execute the sudo binary.
    security.sudo.execWheelOnly = true;
  };

  flake.modules.homeManager.user = { lib, username, ... }: {
    home.username = username;
    home.homeDirectory = lib.mkForce "/home/${username}";
    home.stateVersion = "26.11";
    home.enableNixpkgsReleaseCheck = false;

    programs.home-manager.enable = true;

    manual.manpages.enable = false;
  };
}
