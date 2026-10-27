# /.dotfiles/modules/gaming/gaming.nix
# Everything game-related that isn't Steam: Gamescope, GameMode, launchers,
# Wine tools, overlays and controller fixes.
{
  flake.modules.nixos.gaming = { pkgs, pkgs-stable, username, ... }: {
    # --- Gaming: Gamescope ---
    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };

    # --- Gaming: Gamemode ---
    programs.gamemode = {
      enable = true;
      settings = {
        general.renice = 10;
        cpu.park_cores = "no";
      };
    };
    users.users.${username}.extraGroups = [ "gamemode" ];

    # --- XBox Gaming Controller Support ---
#     hardware.xone.enable = true;
#     hardware.xpadneo.enable = true;

    # Stop the PS4/PS5 controller touchpad from moving the mouse cursor
    services.udev.extraRules = ''
      ATTRS{name}=="Sony Interactive Entertainment Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ATTRS{name}=="Sony Interactive Entertainment DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ATTRS{name}=="Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ATTRS{name}=="DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    '';

    environment.systemPackages = with pkgs; [
      heroic-unwrapped
      mangohud # Track FPS of games
      mangojuice # GUI configure MangoHud
      protonplus
      wine
      pkgs-stable.bottles
      pkgs-stable.tetris
    ];
  };
}
