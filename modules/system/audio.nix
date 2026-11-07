# /.dotfiles/modules/system/audio.nix
# PipeWire (with PulseAudio/ALSA shims) and the audio tools. JACK apps run
# through PipeWire with `pw-jack <app>` (e.g. `pw-jack ardour`). The global
# `jack.enable` shim is deprecated: it puts PipeWire's libjack on everyone's
# LD_LIBRARY_PATH.
{
  flake.modules.nixos.audio = { pkgs, ... }: {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Stop WirePlumber polling for cameras through libcamera
    services.pipewire.wireplumber.extraConfig."10-disable-libcamera" = {
      "wireplumber.profiles".main."monitor.libcamera" = "disabled";
    };

    environment.systemPackages = with pkgs; [
      easyeffects
      headsetcontrol
      pipewire.jack # pw-jack, for the occasional JACK-only app
    ];
  };
}
