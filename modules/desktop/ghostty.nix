# /.dotfiles/modules/desktop/ghostty.nix
# Ghostty set up to match konsole.nix (same font, colors, opacity/blur,
# padding, window size, no chrome). Fish, Oh My Posh, aliases and functions
# live in the shell, so they come along on their own.
{
  flake.modules.homeManager.ghostty = { ... }: {
    programs.ghostty = {
      enable = true; # also installs the package
      enableFishIntegration = true;

      # Same colors as Konsole's BreezeTransparent scheme (konsole.nix),
      # converted from R,G,B to hex. Konsole's Color0-7 -> palette 0-7,
      # Color0-7Intense -> palette 8-15. Ghostty has no "faint" variants.
      themes.BreezeTransparent = {
        background = "232627";
        foreground = "fcfcfc";
        palette = [
          "0=#232627"
          "1=#7f8c8d"
          "2=#11d116"
          "3=#f67400"
          "4=#1d99f3"
          "5=#9b59b6"
          "6=#1abc9c"
          "7=#fcfcfc"
          "8=#7f8c8d"
          "9=#c0392b"
          "10=#1cdc9a"
          "11=#fdbc4b"
          "12=#3daee9"
          "13=#8e44ad"
          "14=#16a085"
          "15=#ffffff"
        ];
      };

      settings = {
        theme = "BreezeTransparent";
        bold-color = "#3daee9"; # Konsole's ForegroundIntense

        font-family = "JetBrainsMono Nerd Font";
        font-size = 13;

        # Konsole: Opacity = 0.75, Blur = true. Blur strength still comes
        # from kwin.effects.blur.strength in plasma.nix.
        background-opacity = 0.75;
        background-blur = true;

        window-padding-x = 10; # Konsole TerminalMargin
        window-padding-y = 10;
        window-width = 151; # Konsole TerminalColumns
        window-height = 43; # Konsole TerminalRows

        scrollbar = "never"; # Konsole ScrollBarPosition = 2 (hidden)
        window-decoration = "none"; # like the "Konsole borderless" KWin rule in plasma.nix
        # (on niri, the matching window-rule in niri/config.kdl keeps it see-through)

        # Close right away, even with a command still running, like Konsole.
        confirm-close-surface = false;

        # F11 = fullscreen, like Konsole (Ctrl+Enter is Ghostty's default for
        # it too). Stays see-through on niri thanks to the backdrop patch in
        # niri.nix; under stock niri the fullscreen backdrop is solid black.
        keybind = [ "f11=toggle_fullscreen" ];
      };
    };

    # Meta+Return opens Ghostty (Niri's Mod+Return is set to match in
    # niri/config.kdl). Ctrl+Alt+T still opens Konsole (konsole.nix).
    programs.plasma.shortcuts."services/com.mitchellh.ghostty.desktop"."_launch" = [ "Meta+Return" ];
  };
}
