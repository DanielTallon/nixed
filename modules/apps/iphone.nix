# /.dotfiles/modules/apps/iphone.nix
# iPhone over USB: usbmuxd, mounting and backups, and iphone-music-sync
# (fills VLC for iOS from ~/Music, see the README).
{
  flake.modules.nixos.iphone = { pkgs, username, ... }:
    let
      iphone-music-sync = pkgs.writeShellApplication {
        name = "iphone-music-sync";
        runtimeInputs = with pkgs; [ ifuse libimobiledevice rsync xdg-user-dirs ];
        text = builtins.readFile ../../scripts/iphone-music-sync.sh;
      };
    in
    {
      # usbmuxd talks to the phone; fusermount comes from NixOS's setuid wrappers
      services.usbmuxd = {
        enable = true;
        package = pkgs.usbmuxd2;
      };
      users.users.${username}.extraGroups = [ "usbmux" ];

      environment.systemPackages = [
        iphone-music-sync
        pkgs.ifuse
        # NOTE: First Time Run: mkdir -p ~/mnt/vlc
        # ifuse --documents org.videolan.vlc-ios ~/mnt/vlc
        # cp -r ~/Music/SomeAlbum ~/mnt/vlc/
        # fusermount -u ~/mnt/vlc
        pkgs.libimobiledevice # also gives you idevicebackup2 permanently
        # NOTE: First Time Run: mkdir -p ~/iphone-backup
        # NOTE: Then Run: idevicebackup2 backup --full ~/iphone-backup
        # NOTE: To check on backup progress run: watch -n 5 du -sh ~/iphone-backup
        # Or: watch -n 5 du -sm ~/iphone-backup
        # NOTE: Restore later with: idevicebackup2 restore ~/iphone-backup
        # NOTE: idevicebackup2 -i encryption on ~/iphone-backup
        # NOTE: Unencrypted is still a good backup. It just leaves out saved passwords, Health data, and Wi-Fi settings, which iOS only includes when backups are encrypted. If you don't care about those, just skip.

        pkgs.idevicerestore
      ];
    };
}
