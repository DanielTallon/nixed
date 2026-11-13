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
      #
      # FIX: a second hang on the same kind of drop-out, one step earlier: if
      # the phone is gone before the RX loops start, get_serial_callback()
      # calls usb_disconnect() from inside a libusb transfer callback, which
      # re-enters libusb event handling and blocks in libusb_lock_event_waiters
      # forever. Mark the device dead and let reap_dead_devices() clean up
      # instead, as rx_callback/tx_callback already do. Still in upstream
      # master as of 2026-10-31.
      # TODO: drop once upstream usbmuxd stops disconnecting from the callback.
      #
      # FIX: a third hang, on unplugging a phone that was fully connected: if a
      # read finishes just as the phone goes away, rx_callback() resubmits it,
      # ignores the failure, and leaves it in rx_xfers. That transfer never
      # calls back, so usb_disconnect()'s busy-wait spins forever, and the main
      # loop never gets back to answering clients. Drop the transfer and mark
      # the device dead when the resubmit fails. Still in upstream master as
      # of 2026-11-01.
      # TODO: drop once upstream usbmuxd checks the RX resubmit.
      usbmuxd = pkgs.usbmuxd.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          lockOrderPatch
          serialCallbackPatch
          rxResubmitPatch
        ];
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

      serialCallbackPatch = pkgs.writeText "usbmuxd-get-serial-callback-no-reentry.patch" ''
        --- a/src/usb.c
        +++ b/src/usb.c
        @@ -302,9 +302,13 @@
         		usbdev->serial[di+1] = '\0';
         	}

        +	// We are inside a libusb transfer callback here, so usb_disconnect() would
        +	// re-enter libusb event handling and hang. Mark the device dead instead and
        +	// let reap_dead_devices() clean it up, as rx_callback/tx_callback do.
        +
         	/* Finish setup now */
         	if(device_add(usbdev) < 0) {
        -		usb_disconnect(usbdev);
        +		usbdev->alive = 0;
         		return;
         	}

        @@ -323,8 +327,7 @@
         	if (rx_loops == NUM_RX_LOOPS) {
         		usbmuxd_log(LL_FATAL, "Failed to start any RX loop for device %d-%d",
         					usbdev->bus, usbdev->address);
        -		device_remove(usbdev);
        -		usb_disconnect(usbdev);
        +		usbdev->alive = 0;
         		return;
         	} else if (rx_loops > 0) {
         		usbmuxd_log(LL_WARNING, "Failed to start all %d RX loops. Going on with %d loops. "
      '';

      rxResubmitPatch = pkgs.writeText "usbmuxd-rx-resubmit-failure.patch" ''
        --- a/src/usb.c
        +++ b/src/usb.c
        @@ -209,7 +209,17 @@
         	usbmuxd_log(LL_SPEW, "RX callback dev %d-%d len %d status %d", dev->bus, dev->address, xfer->actual_length, xfer->status);
         	if(xfer->status == LIBUSB_TRANSFER_COMPLETED) {
         		device_data_input(dev, xfer->buffer, xfer->actual_length);
        -		libusb_submit_transfer(xfer);
        +		// If the resubmit fails (the device just went away), this transfer will
        +		// never call back, and usb_disconnect() would wait for it forever.
        +		// Drop it and mark the device dead like any other RX failure.
        +		int res = libusb_submit_transfer(xfer);
        +		if(res != 0) {
        +			usbmuxd_log(LL_INFO, "Failed to resubmit RX transfer to device %d-%d: %s", dev->bus, dev->address, libusb_error_name(res));
        +			free(xfer->buffer);
        +			collection_remove(&dev->rx_xfers, xfer);
        +			libusb_free_transfer(xfer);
        +			dev->alive = 0;
        +		}
         	} else {
         		switch(xfer->status) {
         			case LIBUSB_TRANSFER_COMPLETED: //shut up compiler
      '';
    in
    {
      # usbmuxd talks to the phone; fusermount comes from NixOS's setuid wrappers
      services.usbmuxd = {
        enable = true;
        package = usbmuxd;
      };
      users.users.${username}.extraGroups = [ "usbmux" ];

      # FIX: the first plug-in after each boot never connected. Plugging in an
      # iPhone makes udev load apple_mfi_fastcharge, a whole-device driver, and
      # once it registers the kernel unbinds the phone from the generic USB
      # driver and rebinds it. That happens right after usbmuxd has switched
      # the phone to its usbmux configuration, so usbmuxd loses the device
      # mid-setup (and can even throw away the pair record). On the second
      # plug-in the module is already loaded, so nothing rebinds. Load it at
      # boot so the first plug-in looks like the second. (ipheth, the USB
      # tethering driver, only binds one interface, so it loads late safely.)
      boot.kernelModules = [ "apple_mfi_fastcharge" ];

      # With Personal Hotspot on, a plugged-in iPhone shows up as a wired
      # network (ipheth). NetworkManager would auto-connect it, and as "wired"
      # it outranks Wi-Fi, so all traffic goes out over the phone's cellular
      # data. Don't auto-create a connection for it; tethering on purpose
      # still works by adding a profile for the device by hand.
      networking.networkmanager.settings.main.no-auto-default = "driver:ipheth";

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
