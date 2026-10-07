{
  flake.modules.homeManager.librewolf = {
    programs.librewolf = {
      enable = true;
      settings = {
        # DRM (Widevine) — LibreWolf disables all four by default
        "media.eme.enabled" = true;
        "media.gmp-provider.enabled" = true;
        "media.gmp-widevinecdm.enabled" = true;
        "media.gmp-widevinecdm.visible" = true;
        "media.gmp-manager.updateEnabled" = true;

        # Uncomment only if a streaming site still refuses to play
        # "privacy.resistFingerprinting" = false;
      };

      # Lock the DRM prefs so they can't be toggled off in the UI
      policies.Preferences = {
        "media.eme.enabled" = { Value = true; Status = "locked"; };
        "media.gmp-widevinecdm.enabled" = { Value = true; Status = "locked"; };
      };
    };
  };
}
