# /.dotfiles/modules/system/audio.nix
# PipeWire (with PulseAudio/JACK/ALSA shims) and the audio tools.
{
  flake.modules.nixos.audio = { pkgs, ... }: {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    # Stop WirePlumber polling for cameras through libcamera
    services.pipewire.wireplumber.extraConfig."10-disable-libcamera" = {
      "wireplumber.profiles".main."monitor.libcamera" = "disabled";
    };

    environment.systemPackages = with pkgs; [
      easyeffects
      headsetcontrol
    ];
  };
}
