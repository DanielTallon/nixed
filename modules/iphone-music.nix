# /.dotfiles/modules/iphone-music.nix
{ ... }:
{
  flake.modules.nixos.iphoneMusic = { pkgs, ... }:
    let
      iphone-music-sync = pkgs.writeShellApplication {
        name = "iphone-music-sync";
        runtimeInputs = with pkgs; [ ifuse libimobiledevice rsync xdg-user-dirs ];
        text = builtins.readFile ../scripts/iphone-music-sync.sh;
      };
    in
    {
      # usbmuxd talks to the phone; fusermount comes from NixOS's setuid wrappers
      services.usbmuxd.enable = true;
      environment.systemPackages = [
        iphone-music-sync
        pkgs.ifuse
        pkgs.libimobiledevice # also gives you idevicebackup2 permanently
      ];
    };
}
