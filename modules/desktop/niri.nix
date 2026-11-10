# /.dotfiles/modules/desktop/niri.nix
# Niri (scrollable-tiling Wayland compositor) with the Noctalia shell, the
# default session: autologin lands in Niri. Plasma is still installed; log
# out and choose "Plasma" at the SDDM login screen to use it.
# Desktop host only (modules/hosts.nix): nixos-26.05 has no Noctalia module.
#
# KDE apps (Kate, Konsole, Dolphin, ...) run as-is and keep their settings;
# they're pointed at the Plasma theme so they look the same in both sessions.
# The wallpaper is drawn by the wallpaper picker, not Noctalia.
#
# To drop it: remove this file and its line in modules/hosts.nix, then
# nh os switch. Leftovers in ~/.config/noctalia and ~/.local/state/noctalia
# can be deleted by hand, and so can the noctalia/ and niri/ folders next to
# this file.
{ config, ... }:
let
  hmModule = config.flake.modules.homeManager.niri;
in
{
  flake.modules.nixos.niri = { config, lib, pkgs, username, ... }: {
    programs.niri.enable = true;

    # Backport of niri-wm/niri#3004 (merged 2026-10-19, after 26.04), which
    # adds layout { fullscreen-backdrop-color }, with its default changed from
    # black to transparent so fullscreen windows stay see-through (Ghostty).
    # The default is patched instead of setting the key in niri/config.kdl:
    # an unpatched niri (an older generation, or a `test` build after a
    # reboot) rejects the key and falls back to niri's default config, which
    # drops every keybind in config.kdl.
    # TODO: once nixpkgs ships a niri release newer than 26.04, drop this and
    # put `fullscreen-backdrop-color "transparent"` in config.kdl's layout.
    programs.niri.package = pkgs.niri.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (pkgs.fetchpatch {
          name = "niri-fullscreen-backdrop-color.patch";
          url = "https://github.com/niri-wm/niri/commit/58d213e6e910a825ecf374d3903ee5a3d71abaa2.patch";
          excludes = [ "docs/*" ];
          hash = "sha256-ostQeHGUwrustnccwC6xvIVyTpMK85yHNmvkMOA9ago=";
        })
      ];
      postPatch = (old.postPatch or "") + ''
        substituteInPlace niri-config/src/layout.rs --replace-fail \
          'fullscreen_backdrop_color: Color::from_array_unpremul([0., 0., 0., 1.])' \
          'fullscreen_backdrop_color: Color::from_array_unpremul([0., 0., 0., 0.])'
        # parse()'s snapshot test checks that default too
        sed -i '/fullscreen_backdrop_color: Color {/,/}/ s/a: 1\.0,/a: 0.0,/' niri-config/src/lib.rs
        grep -A4 'fullscreen_backdrop_color: Color {' niri-config/src/lib.rs | grep -q 'a: 0.0,'
      '';
    });

    # --- Niri is the default session ---
    # SDDM's autologin and preselected session. Set back to "plasma" to make
    # Plasma the default again.
    services.displayManager.defaultSession = "niri";

    # --- Secrets: KWallet in both sessions ---
    # The niri module turns on GNOME Keyring, whose PAM hook would start it
    # in Plasma too, where it competes with KWallet for the secrets service.
    services.gnome.gnome-keyring.enable = false;

    # --- Portals for the Niri session ---
    # GNOME's portal does screen sharing (KDE's only works inside Plasma);
    # file dialogs stay KDE's and secrets KWallet's, as in Plasma. Plasma's
    # own portal settings in plasma.nix are separate and unchanged.
    programs.niri.useNautilus = false;
    xdg.portal.config.niri = {
      "org.freedesktop.impl.portal.FileChooser" = lib.mkForce "kde";
      "org.freedesktop.impl.portal.Secret" = lib.mkForce "kwallet";
    };

    # --- Noctalia: bar, launcher, notifications, control center ---
    # Started only with Niri. Its default target, graphical-session.target,
    # is reached by Plasma too and would put a second panel over Plasma's.
    programs.noctalia = {
      enable = true;
      systemd.enable = true;
      systemd.target = "niri.service";
    };
    # Apps started from Noctalia's launcher run inside noctalia.service and get
    # its environment, not the environment block in niri/config.kdl. Without
    # these, Qt apps (KCalc etc.) fall back to light Breeze, not kdeglobals.
    systemd.user.services.noctalia.environment = {
      QT_QPA_PLATFORMTHEME = "kde";
      XDG_MENU_PREFIX = "plasma-";
    };
    # KDE's portal draws the Open/Save dialogs for every app. It's started by
    # D-Bus/systemd, not by niri, so it misses the variable above too and
    # draws them in light Breeze instead of the kdeglobals color scheme.
    # A drop-in: the unit itself comes from the package via the system profile.
    systemd.user.services.plasma-xdg-desktop-portal-kde = {
      overrideStrategy = "asDropin";
      environment.QT_QPA_PLATFORMTHEME = "kde";
    };

    environment.systemPackages = [
      pkgs.xwayland-satellite # X11 apps (Steam, older games); niri starts it on demand
      pkgs.nirimod # GUI config editor; saves to niri/config.kdl in this repo
      # Volume of the focused app (keybinds in niri/config.kdl, with Mod+Alt)
      (pkgs.writeShellApplication {
        name = "app-volume";
        runtimeInputs = with pkgs; [ config.programs.niri.package jq procps pipewire wireplumber gawk libnotify ];
        text = builtins.readFile ../../scripts/app-volume.sh;
      })
      # Silent screen recording toggle (Shift+Print in niri/config.kdl)
      (pkgs.writeShellApplication {
        name = "screen-record";
        runtimeInputs = with pkgs; [ config.programs.niri.package jq procps libnotify coreutils ];
        text = builtins.readFile ../../scripts/screen-record.sh;
      })
    ];

    # Installs gpu-screen-recorder with the setcap wrapper it needs to capture
    # a monitor without a portal prompt. Used by screen-record above.
    programs.gpu-screen-recorder.enable = true;

    home-manager.users.${username}.imports = [ hmModule ];
  };

  flake.modules.homeManager.niri = { config, lib, pkgs, ... }: {
    # --- A window alone on its workspace goes wide ---
    # Niri can't pick a width by how many windows a workspace has, so this
    # watches niri's event stream. Whenever a workspace is down to one tiled
    # window (it opened alone, or the others closed or moved away), that
    # window is set to the wide preset (2/3); always-center-single-column in
    # config.kdl puts it in the middle. When another window joins it, the wide
    # one goes back to normal (1/2). A window whose width was changed by hand
    # while it was wide is left alone from then on.
    systemd.user.services.niri-lone-window-wide = {
      Unit = {
        Description = "Widen a window that is alone on its Niri workspace";
        After = [ "niri.service" ];
        PartOf = [ "niri.service" ];
      };
      Service = {
        ExecStart = lib.getExe (pkgs.writers.writePython3Bin "niri-lone-window-wide" {
          flakeIgnore = [ "E501" ];
        } ''
          import json
          import subprocess
          import time

          NIRI = "${pkgs.niri}/bin/niri"
          WIDE = "66.667%"
          NORMAL = "50%"

          windows = {}  # id -> window from the event stream
          widened = {}  # id -> {"at": time we widened it, "width": its width after}
          by_hand = set()  # ids resized by hand while wide; never widened again


          def width(win):
              return win["layout"]["tile_size"][0]


          def set_width(win_id, change):
              subprocess.run([NIRI, "msg", "action", "set-window-width", "--id", str(win_id), change])


          def reconcile(ws):
              """Widen a lone tiled window on ws, or narrow wide ones that have company."""
              if ws is None:
                  return
              tiled = [w for w in windows.values()
                       if w["workspace_id"] == ws and not w["is_floating"]]
              if len(tiled) == 1:
                  win = tiled[0]
                  if win["id"] not in widened and win["id"] not in by_hand:
                      set_width(win["id"], WIDE)
                      widened[win["id"]] = {"at": time.monotonic(), "width": None}
                  return
              for win in tiled:
                  state = widened.pop(win["id"], None)
                  if state is not None and (state["width"] is None or abs(width(win) - state["width"]) < 1):
                      set_width(win["id"], NORMAL)


          def layout_changed(win_id, layout):
              windows[win_id]["layout"] = layout
              state = widened.get(win_id)
              if state is None:
                  return
              # Resizes just after ours are ours (and its animation); later ones
              # mean the width was changed by hand, so leave it alone from then on.
              if time.monotonic() - state["at"] < 1:
                  state["width"] = layout["tile_size"][0]
              elif state["width"] is not None and abs(layout["tile_size"][0] - state["width"]) >= 1:
                  del widened[win_id]
                  by_hand.add(win_id)


          stream = subprocess.Popen([NIRI, "msg", "--json", "event-stream"],
                                    stdout=subprocess.PIPE, text=True)
          for line in stream.stdout:
              event = json.loads(line)
              if "WindowsChanged" in event:
                  windows = {w["id"]: w for w in event["WindowsChanged"]["windows"]}
                  for ws in {w["workspace_id"] for w in windows.values()}:
                      reconcile(ws)
              elif "WindowOpenedOrChanged" in event:
                  win = event["WindowOpenedOrChanged"]["window"]
                  old = windows.get(win["id"])
                  windows[win["id"]] = win
                  if win["is_floating"]:
                      widened.pop(win["id"], None)
                  if old is None:
                      reconcile(win["workspace_id"])
                  elif old["workspace_id"] != win["workspace_id"] or old["is_floating"] != win["is_floating"]:
                      # Its pixel width changes on a monitor with another
                      # size or scale; measure it again rather than calling
                      # that a resize by hand.
                      if win["id"] in widened:
                          widened[win["id"]] = {"at": time.monotonic(), "width": None}
                      reconcile(old["workspace_id"])
                      reconcile(win["workspace_id"])
              elif "WindowClosed" in event:
                  win_id = event["WindowClosed"]["id"]
                  gone = windows.pop(win_id, None)
                  widened.pop(win_id, None)
                  by_hand.discard(win_id)
                  if gone is not None:
                      reconcile(gone["workspace_id"])
              elif "WindowLayoutsChanged" in event:
                  for win_id, layout in event["WindowLayoutsChanged"]["changes"]:
                      if win_id in windows:
                          layout_changed(win_id, layout)
          raise SystemExit(stream.wait() or 1)
        '');
        Restart = "on-failure";
      };
      Install.WantedBy = [ "niri.service" ];
    };

    # --- Noctalia ---
    # Files in ~/.config/noctalia are the base config; changes made in
    # Noctalia's settings window go to its settings.toml and win.
    # The wallpaper picker draws the wallpaper, so Noctalia doesn't.

    # settings.toml is linked to noctalia/settings.toml in this repo (not
    # copied into the Nix store), so changes made in the settings window
    # land in ~/.dotfiles right away, ready to commit. Noctalia saves
    # through the link and reloads when the repo file is edited by hand.
    xdg.stateFile."noctalia/settings.toml".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/.dotfiles/modules/desktop/noctalia/settings.toml";

    xdg.configFile."noctalia/wallpaper.toml".text = ''
      [wallpaper]
      enabled = false
    '';

    # Bar, dock and desktop widgets. The audio visualizer replaces GLava
    # (which only runs in Plasma, see tauon/glava.nix): in the bar next to the
    # media widget, and as a desktop widget along the bottom of DP-1.
    xdg.configFile."noctalia/layout.toml".text = ''
      [bar.default]
#       position = "bottom"
      position = "top"
      thickness = 40        # bar height in pixels
      font_scale = 1.5      # text size on this bar
      scale = 1.1           # icons and widgets on this bar
      start = [ "launcher", "wallpaper", "workspaces" ]
      center = [ "clock" ]
      end = [
          "audio_visualizer",
          "media",
          "tray",
          "notifications",
          "clipboard",
          "network",
          "bluetooth",
          "volume",
          "brightness",
          "battery",
          "control-center",
          "session"
      ]
      [widget.clock]
        format = "{:%a, %b %-d  %-I:%M %p}"  # Mon, Nov 2  9:15 PM
      [widget.network]
        show_label = false  # icon only, no Wi-Fi network name

      [dock]
      enabled = true
      background_opacity = 0.5

      [desktop_widgets]
      enabled = true
      schema_version = 2
      widget_order = [ "desktop-widget-0000000000000002" ]

      [desktop_widgets.grid]
      cell_size = 32
      major_interval = 4
      visible = false

      [desktop_widgets.widget.desktop-widget-0000000000000002]
      type = "audio_visualizer"
      output = "DP-1"
      cx = 1274.0
      cy = 1035.0
      box_width = 2496.0
      box_height = 64.0
      placement_width = 2548.0
      placement_height = 1067.0
      rotation = 0.0

      [desktop_widgets.widget.desktop-widget-0000000000000002.settings]
      background = false
      bands = 128
      centered = true
      color_1 = "secondary"
      color_2 = "on_secondary"
      mirrored = true
      reversed = false
      show_wave = false
      show_when_idle = true
    '';

    # --- Niri ---
    # config.kdl is linked to niri/config.kdl in this repo (not copied into
    # the Nix store), so changes saved in NiriMod land in ~/.dotfiles right
    # away, ready to commit. NiriMod saves through the link (it writes to
    # the file the link points at), and niri reloads it live on save.
    xdg.configFile."niri/config.kdl".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/.dotfiles/modules/desktop/niri/config.kdl";

    # KDE's password prompt, for apps that ask for admin rights. Its autostart
    # entry is marked KDE-only, so it's started here for niri instead of from
    # config.kdl, which has to stay free of Nix store paths.
    systemd.user.services.niri-polkit-agent = {
      Unit = {
        Description = "KDE polkit authentication agent for Niri";
        After = [ "niri.service" ];
        PartOf = [ "niri.service" ];
      };
      Service = {
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "niri.service" ];
    };
  };
}
