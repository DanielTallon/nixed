# /.dotfiles/home-manager/discord.nix

{ inputs, ... }:
{
  flake.modules.homeManager.discord = { ... }: {
    imports = [ inputs.nixcord.homeModules.nixcord ];

    programs.nixcord = {
      enable = true;
      vesktop.enable = true;
      discord.vencord.enable = true;

      quickCss = ''
        /* Add your custom CSS here */
      '';

      config = {
        useQuickCss = true;

        plugins = {
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
