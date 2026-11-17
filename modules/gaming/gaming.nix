# /.dotfiles/modules/gaming/gaming.nix
# Everything game-related that isn't Steam: Gamescope, GameMode, launchers,
# Wine tools, overlays and controller fixes.
{
  flake.modules.nixos.gaming = { pkgs, pkgs-stable, username, ... }:
  let
    # Plasma makes Qt Quick apps use the Breeze style, which needs Kirigami.
    # lsfg-vk-ui's launcher only lists its own Qt modules, so it fails with
    # 'module "org.kde.kirigami" is not installed'. Wrap it with Kirigami added.
    lsfg-vk-ui = pkgs.symlinkJoin {
      name = "lsfg-vk-ui-with-kirigami";
      paths = [ pkgs.lsfg-vk-ui ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/lsfg-vk-ui \
          --prefix NIXPKGS_QT6_QML_IMPORT_PATH : ${pkgs.kdePackages.kirigami.unwrapped}/lib/qt-6/qml
      '';
    };
  in {
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

    # --- Gaming: Ananicy ---
    # Auto-renices known games, Proton and Wine (plus background tasks) without
    # needing a launch option. GameMode still handles the CPU governor.
    services.ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-rules-cachyos;
    };

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
      lsfg-vk    # Lossless Scaling frame generation as a Vulkan layer (reads Lossless.dll from the Steam install)
      lsfg-vk-ui # GUI for per-game lsfg-vk profiles (Kirigami-wrapped, see let above)
      protonplus
      wine
      pkgs-stable.bottles
      pkgs-stable.tetris
    ];
  };
}
