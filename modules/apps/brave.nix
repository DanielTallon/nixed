# /.dotfiles/modules/apps/brave.nix
# Brave, with its crypto/AI/telemetry extras switched off by policy.
{
  flake.modules.nixos.brave = { pkgs, ... }: {
    # Keep the key that encrypts cookies and logins in KWallet in every
    # session. Left alone, Brave picks the keyring from the desktop name:
    # KWallet in Plasma, but libsecret under Niri, where it can't find the
    # key and every site signs you out.
    environment.systemPackages = [
      (pkgs.brave.override { commandLineArgs = "--password-store=kwallet6"; })
    ];

    # --- Brave Settings ---
    programs.chromium = {
      enable = true;
        extraOpts = {
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
  };
}
