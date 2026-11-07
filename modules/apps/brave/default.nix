# /.dotfiles/modules/apps/brave/default.nix
# Brave Origin (Brave without Rewards, Wallet, VPN, AI or telemetry), with the
# leftover extras switched off by policy, and a cyberpunk look: an animated new
# tab page (./newtab) plus matching colors (./theme).
#
# nixpkgs dropped Brave in November 2026, so Brave Origin comes from
# github:DanielTallon/nix-packages, where a scheduled GitHub Action keeps it
# current. Its profile is ~/.config/BraveSoftware/Brave-Origin, separate from
# the old Brave-Browser one.
{
  flake.modules.nixos.brave = { pkgs, inputs, ... }:
  let
    brave-origin = inputs.nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.brave-origin;
  in
  {
    environment.systemPackages = [
      (brave-origin.override {
        commandLineArgs = builtins.concatStringsSep " " [
          # Keep the key that encrypts cookies and logins in KWallet in every
          # session. Left alone, Brave picks the keyring from the desktop name:
          # KWallet in Plasma, but libsecret under Niri, where it can't find the
          # key and every site signs you out.
          "--password-store=kwallet6"

          # Load both extensions straight from the Nix store on every launch.
          # The "key" in each manifest pins its ID, so Brave sees the same
          # extension after a rebuild even though the store path changes.
          # To try a different animation, replace newtab/cyberpunk-rain.gif
          # (any GIF works; it's cropped to fill the tab).
          "--load-extension=${./newtab},${./theme}"
        ];
      })
    ];

    # --- Brave Settings ---
    # Brave reads managed policies from /etc/brave/policies. The programs.chromium
    # module stopped writing there when nixpkgs dropped Brave, so write it directly.
    # Brave Origin already lacks most of the Brave* features; their policies are
    # kept as a backstop and are ignored where the feature doesn't exist.
    environment.etc."brave/policies/managed/extra.json".text = builtins.toJSON {
      BraveWalletDisabled       = true;
      BraveNewsDisabled         = true;
      BraveTalkDisabled         = true;
      BraveAIChatEnabled        = false;
      BraveRewardsDisabled      = true;
      BraveVPNDisabled          = true;
      MetricsReportingEnabled   = false;
      BraveStatsPingEnabled     = false;
      BraveWebDiscoveryEnabled  = false;
      BraveP3AEnabled           = false;
      BraveLocalAIEnabled       = false;
      IPFSEnabled               = false;
      BraveDeAmpEnabled         = true;
      BraveDebouncingEnabled    = true;
      BraveTrackingQueryParametersFilteringEnabled  = true;
      BraveGlobalPrivacyControlEnabled              = true;
      BraveReduceLanguageEnabled                    = true;
      UrlKeyedAnonymizedDataCollectionEnabled       = false;
      SafeBrowsingExtendedReportingEnabled          = false;
      DomainReliabilityAllowed                      = false;
      SpellCheckServiceEnabled                      = false;
      AlternateErrorPagesEnabled                    = false;
      FeedbackSurveysEnabled                        = false;
      UserFeedbackAllowed                           = false;
      NetworkPredictionOptions                      = 2;
      PrivacySandboxAdTopicsEnabled                 = false;
      PrivacySandboxSiteEnabledAdsEnabled           = false;
      PrivacySandboxAdMeasurementEnabled            = false;
      PrivacySandboxPromptEnabled                   = false;
      ShoppingListEnabled                           = false;
      MediaRecommendationsEnabled                   = false;
      PromotionalTabsEnabled                        = false;
      WebRtcIPHandling                              = "default_public_interface_only";
      BlockThirdPartyCookies                        = true;
      BackgroundModeEnabled                         = false;
      EnableMediaRouter                             = false;
      DefaultGeolocationSetting                     = 2;
      DefaultNotificationsSetting                   = 2;
      DefaultSensorsSetting                         = 2;
    };
  };
}
