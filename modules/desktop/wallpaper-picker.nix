# /.dotfiles/modules/desktop/wallpaper-picker.nix
#---Wallpaper picker, and desktop colors from the wallpaper---
# nix-packages' wallpaperpicker, set up through its Home Manager module
# (homeModules.wallpaperpicker, wallpaperpicker/home-module.nix there): the
# package, an autostart entry (it runs in both Niri and Plasma), the Plasma
# shortcut, and the colors below. Niri's Mod+Space is in niri/config.kdl.
#
# useMatugen (below)
#   false - Plasma's own "accent color from wallpaper": highlights, selection
#           and focus follow the wallpaper, everything else stays Breeze Dark.
#           The picker keeps its built-in colors.
#   true  - matugen (run by the picker on every wallpaper it sets) makes a
#           whole dark color scheme from the wallpaper: window, view, button,
#           header, selection and title-bar colors, plus the picker's own UI.
#           Always dark; it never switches you to a light scheme.
#
# How bold matugen's colors are is set in nix-packages, as matugenScheme in
# wallpaperpicker/wallpaperpicker.nix; the module reads it from there, so the
# picker's swatch cards and the login re-apply always agree. From most muted
# to boldest, with average saturation on a few of my own wallpapers
# (0 = gray, 1 = fully saturated):
#   scheme-monochrome  0.00  No color at all: grays only, whatever the wallpaper.
#   scheme-neutral     0.16  Barely tinted grays.
#   scheme-tonal-spot  0.53  matugen's default. Soft, pastel and a bit dusty.
#   scheme-smart       0.53  Picks a style for each wallpaper; on mine it came
#                            out the same as tonal spot.
#   scheme-rainbow     0.60  Like tonal spot, with a stronger deep accent.
#   scheme-fidelity    0.63  Sticks closest to the wallpaper's actual colors,
#                            third color included (often a warm gold or orange).
#   scheme-content     0.64  Like fidelity, but the third color is a pink
#                            rather than taken from the wallpaper.
#   scheme-expressive  0.68  Bold, but moves the hues around: blue wallpapers
#                            get green accents. Least like the wallpaper.
#   scheme-vibrant     0.79  Bold and keeps the wallpaper's hues. Picked.
#   scheme-fruit-salad 0.89  Boldest, but leans everything toward blue/cyan,
#                            so a purple wallpaper gives a blue scheme.
#
# After changing either: rebuild, then log out and back in. Plasma only
# picks the change up at login (the module's startup script runs once).
{ inputs, ... }:
{
  flake.modules.homeManager.wallpaperPicker = { ... }:
  let
    useMatugen = true;
  in
  {
    imports = [ inputs.nix-packages.homeModules.wallpaperpicker ];

    programs.wallpaperpicker = {
      enable = true;
      autostart = true;
      hotkey = "Meta+Space";  # Plasma; Niri's is in niri/config.kdl
      matugen.enable = useMatugen;
      plasmaColors = if useMatugen then "matugen" else "accent";
    };
  };
}
