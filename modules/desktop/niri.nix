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
# can be deleted by hand.
{ config, ... }:
let
  hmModule = config.flake.modules.homeManager.niri;
in
{
  flake.modules.nixos.niri = { lib, pkgs, username, ... }: {
    programs.niri.enable = true;

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

    environment.systemPackages = [
      pkgs.xwayland-satellite # X11 apps (Steam, older games); niri starts it on demand
    ];

    home-manager.users.${username}.imports = [ hmModule ];
  };

  flake.modules.homeManager.niri = { lib, pkgs, ... }: {
    # --- First window on a workspace opens wide ---
    # Niri can't pick a width by how many windows a workspace has, so this
    # watches niri's event stream: a window that opens alone on its workspace
    # is set to the wide preset (2/3); always-center-single-column below puts
    # it in the middle. When a second window opens there, the wide one goes
    # back to normal (1/2), unless its width was changed by hand meanwhile.
    systemd.user.services.niri-first-window-wide = {
      Unit = {
        Description = "Open the first window on a Niri workspace wide";
        After = [ "niri.service" ];
        PartOf = [ "niri.service" ];
      };
      Service = {
        ExecStart = lib.getExe (pkgs.writers.writePython3Bin "niri-first-window-wide" {
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


          def width(win):
              return win["layout"]["tile_size"][0]


          def tiled_on(ws, skip):
              return [w for w in windows.values()
                      if w["workspace_id"] == ws and not w["is_floating"] and w["id"] != skip]


          def set_width(win_id, change):
              subprocess.run([NIRI, "msg", "action", "set-window-width", "--id", str(win_id), change])


          def opened(win):
              if win["is_floating"] or win["workspace_id"] is None:
                  return
              others = tiled_on(win["workspace_id"], win["id"])
              if not others:
                  set_width(win["id"], WIDE)
                  widened[win["id"]] = {"at": time.monotonic(), "width": None}
              elif len(others) == 1 and others[0]["id"] in widened:
                  first = widened.pop(others[0]["id"])
                  if first["width"] is None or abs(width(others[0]) - first["width"]) < 1:
                      set_width(others[0]["id"], NORMAL)


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


          stream = subprocess.Popen([NIRI, "msg", "--json", "event-stream"],
                                    stdout=subprocess.PIPE, text=True)
          for line in stream.stdout:
              event = json.loads(line)
              if "WindowsChanged" in event:
                  windows = {w["id"]: w for w in event["WindowsChanged"]["windows"]}
              elif "WindowOpenedOrChanged" in event:
                  win = event["WindowOpenedOrChanged"]["window"]
                  old = windows.get(win["id"])
                  windows[win["id"]] = win
                  if old is None:
                      opened(win)
                  elif old["workspace_id"] != win["workspace_id"] or old["is_floating"] != win["is_floating"]:
                      widened.pop(win["id"], None)
              elif "WindowClosed" in event:
                  windows.pop(event["WindowClosed"]["id"], None)
                  widened.pop(event["WindowClosed"]["id"], None)
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
    # Noctalia's settings window go to ~/.local/state/noctalia and win.
    # The wallpaper picker draws the wallpaper, so Noctalia doesn't.
    xdg.configFile."noctalia/wallpaper.toml".text = ''
      [wallpaper]
      enabled = false
    '';

    # Bar, dock and desktop widgets. The audio visualizer replaces GLava
    # (which only runs in Plasma, see tauon/glava.nix): in the bar next to the
    # media widget, and as a desktop widget along the bottom of DP-1.
    xdg.configFile."noctalia/layout.toml".text = ''
      [bar.default]
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
    # `niri validate` checks this file; niri reloads it live on save, but
    # this one is a store link, so edit here and nh os switch.
    xdg.configFile."niri/config.kdl".text = ''
      input {
          keyboard {
              xkb {
                  layout "us"
              }
              numlock
          }
          mouse {
              accel-profile "flat"
          }
          focus-follows-mouse max-scroll-amount="0%"
      }

      // Same layout as Plasma: the 1080p screen on the left, the ultrawide
      // on the right, bottom edges lined up.
      output "DP-3" {
          mode "1920x1080@60.000"
          scale 1
          position x=0 y=0
      }
      output "DP-1" {
          mode "3440x1440@143.923"
          scale 1.35
          position x=1920 y=13
      }

      layout {
          gaps 12
          center-focused-column "never"
          // A lone window sits in the middle (see niri-first-window-wide above).
          always-center-single-column
          preset-column-widths {
              proportion 0.33333
              proportion 0.5
              proportion 0.66667
          }
          default-column-width { proportion 0.5; }
          focus-ring {
              width 3
              active-color "#00aaff"
              inactive-color "#44475a"
          }
          border {
              off
          }
          // Glow, like the blue Breeze shadow in Plasma (plasma.nix): a
          // centered shadow in the focus-ring blue, dimmer on unfocused windows.
          shadow {
              on
              softness 30
              spread 4
              offset x=0 y=0
              color "#00aaffcc"
              inactive-color "#00aaff40"
          }
      }

      prefer-no-csd
      screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

      environment {
          // Qt apps use the Plasma theme, colors and icons (kdeglobals).
          QT_QPA_PLATFORMTHEME "kde"
          XDG_MENU_PREFIX "plasma-"
      }

      // Autostart entries (~/.config/autostart, /etc/xdg/autostart) run here
      // too, through systemd: that covers the wallpaper picker and KWallet's
      // unlock. KDE's password prompt is marked KDE-only, so start it here.
      spawn-at-startup "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1"

      window-rule {
          geometry-corner-radius 10
          clip-to-geometry true
      }
      window-rule {
          match app-id="org.kde.konsole"
          opacity 0.95
      }

      binds {
          Mod+Shift+Slash { show-hotkey-overlay; }

          // Apps (Konsole keys match Plasma's)
          Mod+Return hotkey-overlay-title="Konsole" { spawn "konsole"; }
          Ctrl+Alt+T { spawn "konsole"; }
          Mod+E hotkey-overlay-title="Dolphin" { spawn "dolphin"; }
          Mod+K hotkey-overlay-title="Kate" { spawn "kate"; }
          Mod+Space hotkey-overlay-title="Wallpaper picker" { spawn "wallpaperpicker" "toggle"; }

          // Noctalia
          Mod+D hotkey-overlay-title="Launcher" { spawn "noctalia" "msg" "panel-toggle" "launcher"; }
          Mod+S hotkey-overlay-title="Control center" { spawn "noctalia" "msg" "panel-toggle" "control-center"; }
          Mod+Comma hotkey-overlay-title="Noctalia settings" { spawn "noctalia" "msg" "settings-toggle"; }

          XF86AudioRaiseVolume allow-when-locked=true { spawn "noctalia" "msg" "volume-up"; }
          XF86AudioLowerVolume allow-when-locked=true { spawn "noctalia" "msg" "volume-down"; }
          XF86AudioMute        allow-when-locked=true { spawn "noctalia" "msg" "volume-mute"; }
          XF86AudioMicMute     allow-when-locked=true { spawn "noctalia" "msg" "mic-mute"; }

          // Windows
          Mod+Q repeat=false { close-window; }
          Alt+F4 repeat=false { close-window; }
          Mod+O repeat=false { toggle-overview; }
          Mod+MouseMiddle { toggle-overview; }

          Mod+Left  { focus-column-left; }
          Mod+Right { focus-column-right; }
          Mod+Up    { focus-window-or-workspace-up; }
          Mod+Down  { focus-window-or-workspace-down; }
          Mod+H     { focus-column-left; }
          Mod+L     { focus-column-right; }
          Mod+J     { focus-window-or-workspace-down; }
          Mod+I     { focus-window-or-workspace-up; }

          Mod+Shift+Left  { move-column-left; }
          Mod+Shift+Right { move-column-right; }
          Mod+Shift+Up    { move-window-up-or-to-workspace-up; }
          Mod+Shift+Down  { move-window-down-or-to-workspace-down; }

          // Mouse wheel: Mod+wheel scrolls through columns, with Ctrl it
          // carries the column along. Workspaces are on Mod+Shift+wheel below.
          // The Left/Right ones are for tilt wheels.
          Mod+WheelScrollDown      { focus-column-right; }
          Mod+WheelScrollUp        { focus-column-left; }
          Mod+Ctrl+WheelScrollDown { move-column-right; }
          Mod+Ctrl+WheelScrollUp   { move-column-left; }
          Mod+WheelScrollRight     { focus-column-right; }
          Mod+WheelScrollLeft      { focus-column-left; }

          Mod+Home { focus-column-first; }
          Mod+End  { focus-column-last; }

          // Monitors
          Mod+Ctrl+Left        { focus-monitor-left; }
          Mod+Ctrl+Right       { focus-monitor-right; }
          Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
          Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }

          // Workspaces
          Mod+Page_Down       { focus-workspace-down; }
          Mod+Page_Up         { focus-workspace-up; }
          Mod+Shift+Page_Down { move-column-to-workspace-down; }
          Mod+Shift+Page_Up   { move-column-to-workspace-up; }
          Mod+Shift+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
          Mod+Shift+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
          Mod+Ctrl+Shift+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
          Mod+Ctrl+Shift+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }
          Mod+1 { focus-workspace 1; }
          Mod+2 { focus-workspace 2; }
          Mod+3 { focus-workspace 3; }
          Mod+4 { focus-workspace 4; }
          Mod+5 { focus-workspace 5; }
          Mod+Shift+1 { move-column-to-workspace 1; }
          Mod+Shift+2 { move-column-to-workspace 2; }
          Mod+Shift+3 { move-column-to-workspace 3; }
          Mod+Shift+4 { move-column-to-workspace 4; }
          Mod+Shift+5 { move-column-to-workspace 5; }

          // Column sizing
          Mod+BracketLeft  { consume-or-expel-window-left; }
          Mod+BracketRight { consume-or-expel-window-right; }
          Mod+R       { switch-preset-column-width; }
          Mod+F       { maximize-column; }
          Mod+Shift+F { fullscreen-window; }
          Mod+C       { center-column; }
          Mod+V       { toggle-window-floating; }
          Mod+Minus   { set-column-width "-10%"; }
          Mod+Equal   { set-column-width "+10%"; }
          Mod+W       { toggle-column-tabbed-display; }

          // Screenshots
          Print      { screenshot; }
          Ctrl+Print { screenshot-screen; }
          Alt+Print  { screenshot-window; }

          // Session
          Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
          Mod+Shift+E { quit; }
      }
    '';
  };
}
