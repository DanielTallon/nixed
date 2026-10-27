# /.dotfiles/modules/system/locale.nix
# Defaults only (mkDefault): hosts/<host>/locale.nix overrides them. The
# nixed installer writes that file from its timezone/language/keyboard
# review screen; otherwise it's { } and these apply. The keyboard layout
# default lives with the display server in modules/desktop/plasma.nix.
{
  flake.modules.nixos.locale = { config, lib, ... }: {
    time.timeZone = lib.mkDefault "America/New_York";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    # Every LC_* follows the default locale.
    i18n.extraLocaleSettings = lib.genAttrs [
      "LC_ADDRESS"
      "LC_IDENTIFICATION"
      "LC_MEASUREMENT"
      "LC_MONETARY"
      "LC_NAME"
      "LC_NUMERIC"
      "LC_PAPER"
      "LC_TELEPHONE"
      "LC_TIME"
    ] (_: lib.mkDefault config.i18n.defaultLocale);
  };
}
