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

      # FIX: usbmuxd deadlocks when the phone drops off USB while it's still
      # being set up (it does that a lot when it isn't trusted yet).
      # client_device_add() takes client_list_mutex then device_list_mutex,
      # device_remove() takes them the other way round, so both threads hang
      # forever: no device list for clients, and a 90s SIGKILL at every
      # shutdown. Still in upstream master as of 2026-10-29.
      # TODO: drop once upstream usbmuxd fixes the lock order.
      usbmuxd = pkgs.usbmuxd.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ lockOrderPatch ];
      });

      # Blank context lines are left empty (not a lone space) so formatters
      # can't break them; GNU patch reads an empty hunk line as blank context.
      lockOrderPatch = pkgs.writeText "usbmuxd-client-device-add-lock-order.patch" ''
        --- a/src/client.c
        +++ b/src/client.c
        @@ -986,9 +986,13 @@

         void client_device_add(struct device_info *dev)
         {
        +	// Mark the device visible before taking client_list_mutex: device_remove()
        +	// holds device_list_mutex while it calls client_device_remove(), so taking
        +	// the locks in the other order here deadlocks if the device drops out
        +	// during preflight.
        +	device_set_visible(dev->id);
         	mutex_lock(&client_list_mutex);
         	usbmuxd_log(LL_DEBUG, "client_device_add: id %d, location 0x%x, serial %s", dev->id, dev->location, dev->serial);
        -	device_set_visible(dev->id);
         	FOREACH(struct mux_client *client, &client_list) {
         		if(client->state == CLIENT_LISTEN)
         			send_device_add(client, dev);
      '';
    in
    {
      # usbmuxd talks to the phone; fusermount comes from NixOS's setuid wrappers
      services.usbmuxd = {
        enable = true;
        package = usbmuxd;
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
