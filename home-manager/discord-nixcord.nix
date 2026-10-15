# /.dotfiles/home-manager/discord-nixcord.nix

{ inputs, ... }:
{
  flake.modules.homeManager.discord = { config, options, lib, pkgs, ... }:
    # IN CASE IT BREAKS AGAIN (nixcord#247-style): uncomment this `let` block,
    # the `package` line below, and the nixpkgs-discord input in flake.nix.
    # let
    #   oldPkgs = import inputs.nixpkgs-discord {
    #     system = pkgs.stdenv.hostPlatform.system;
    #     config.allowUnfree = true;
    #   };
    # in

    # Discord's video background filter opens its segmentation models O_RDWR,
    # which fails on the read-only Nix store and turns the camera black. Point
    # the store files at writable copies in ~/.local/share/discord-ml.
    let
      mlDir = "${config.xdg.dataHome}/discord-ml";
      mlModels = [ "selfie_segmentation.tflite" "selfie_segmentation_landscape.tflite" ];
    in

  {
    imports = [ inputs.nixcord.homeModules.nixcord ];

    home.activation.discordMlModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArg mlDir}
      for f in ${lib.escapeShellArgs mlModels}; do
        run install -m 644 "${config.programs.nixcord.finalPackage.discord}/share/discord-ml/$f" ${lib.escapeShellArg mlDir}/"$f"
      done
    '';

    programs.nixcord = {
      enable = true;
      vesktop.enable = true;
      discord = {
#         IN CASE IT BREAKS AGAIN:
#         package = oldPkgs.callPackage "${inputs.nixcord}/pkgs/discord" { };
        package = options.programs.nixcord.discord.package.default.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            voice="$out/opt/Discord/modules/discord_voice"
            mkdir -p "$out/share/discord-ml"
            for f in ${lib.escapeShellArgs mlModels}; do
              mv "$voice/$f" "$out/share/discord-ml/$f"
              ln -s ${lib.escapeShellArg mlDir}/"$f" "$voice/$f"
            done
          '';
        });
        vencord.enable = true;
        krisp.enable = true;
      };

      quickCss = ''
        @import url("https://ridge.codeberg.page/Discord-Adblock/discord-adblock.css");
      '';

      config = {
        useQuickCss = true;

        plugins = {
        # Media / quality
        fixImagesQuality.enable = true;      # loads images at original resolution
        fixYoutubeEmbeds.enable = true;      # bypasses YouTube embed blocks

        # Voice
        disableCallIdle.enable = true;       # don't get kicked from DM VCs after 3 min
        callTimer.enable = true;             # timer in voice channels

        # Chat
        shikiCodeblocks.enable = true;       # VSCode-style code blocks
        #clearURLs.enable = true;             # strips tracking params from links
        fullSearchContext.enable = true;           # search within reply threads
        voiceMessages.enable = true;         # send voice messages
        gifPaste.enable = true;              # paste GIFs from clipboard
        betterUploadButton.enable = true;    # single-click upload

        # Misc
        noTrack.enable = true;               # disables Discord analytics/Sentry
        alwaysTrust.enable = true;           # removes "untrusted domain" popups
        platformIndicators.enable = true;    # shows Desktop/Mobile/Web badges
        showHiddenChannels.enable = true;    # see channels you can't view
        showConnections.enable = true;       # linked accounts in profiles
        consoleJanitor.enable = true;        # silences console spam
        translate.enable = true;             # translate messages
        #newGuildSettings = { enable = true; autoMute = true; };  # auto-mute new servers
        #usrBg.enable = true;                 #Shows USRBG banner on their profile even without Nitro

          fakeNitro = {
            enable = true;

            # Emoji Bypass
            enableEmojiBypass = true;        # Allow sending fake emojis (default: true)
            emojiSize = 48;                  # Size of emojis (16-1024, default: 48)
            transformEmojis = true;          # Transform fake emojis back to real ones locally (default: true)

            # Sticker Bypass
            enableStickerBypass = true;      # Allow sending fake stickers (default: true)
            stickerSize = 160;               # Size of stickers (16-1024, default: 160)
            transformStickers = true;        # Transform fake stickers back to real ones locally (default: true)
            transformCompoundSentence = false; # Only transform standalone emojis/stickers (default: false)

            # Stream Quality
            enableStreamQualityBypass = true; # Allow streaming in Nitro quality (default: true)

            # Hyperlink Formatting
            useHyperLinks = true;            # Send emojis as hyperlinks (default: true)
            hyperLinkText = "{{NAME}}";      # Link text format ({{NAME}} replaced with emoji name)

            # Advanced
            disableEmbedPermissionCheck = false; # Disable embed permission warnings (default: false)
          };

          hideMedia.enable = true;

          ignoreActivities = {
            enable = true;
            ignorePlaying = true;
            ignoreStreaming = true;
            ignoreWatching = true;
            ignoreListening = true;
            ignoreCompeting = true;
          };

          webScreenShareFixes.enable = true;
          biggerStreamPreview.enable = true;
          volumeBooster = {
            enable = true;
            multiplier = 2.0;
          };
          streamerModeOnStream.enable = true;
        };
      };
    };
  };
}
