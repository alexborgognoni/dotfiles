# GNOME on a standalone (Ubuntu) machine: settings, Shell extensions, GTK and
# Shell theme, cursors, wallpaper. Port of the Ansible gnome role; GNOME
# itself is the distribution's. All extensions are pinned to builds for its
# GNOME Shell in extensions.json (scripts/update-gnome-extensions.sh).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.hm.gvariant) mkTuple mkDouble mkEmptyArray type;
  none = mkEmptyArray type.string;

  pinned = lib.importJSON ./extensions.json;
  extension =
    e:
    pkgs.runCommand "gnome-shell-extension-${lib.replaceStrings [ "@" ] [ "-" ] e.uuid}-${toString e.version}"
      {
        src = pkgs.fetchurl {
          name = "${e.uuid}.v${toString e.version}.zip";
          inherit (e) url hash;
        };
        nativeBuildInputs = [
          pkgs.unzip
          pkgs.glib
        ];
      }
      ''
        mkdir -p $out
        unzip -q $src -d $out
        if [ -d $out/schemas ]; then glib-compile-schemas $out/schemas; fi
      '';

  themeName = "catppuccin-macchiato-lavender-standard";
  gtkTheme = pkgs.catppuccin-gtk.override {
    variant = "macchiato";
    accents = [ "lavender" ];
  };
  themeDir = "${gtkTheme}/share/themes/${themeName}";
  cursor = "volantes_light_cursors";
  wallpaper = "file://${../../../assets/wallpapers/catppuccin-spiderman.png}";
  # With my.desktop.themeToolkits Stylix themes GTK, the cursor and fonts
  # (and GNOME with them); otherwise GNOME keeps this fixed Catppuccin look.
  ownLook = !config.my.desktop.themeToolkits;
in
{
  options.my.gnome.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.my.standalone && config.my.features.gui.enable;
    defaultText = lib.literalExpression "config.my.standalone && config.my.features.gui.enable";
    description = "Configure the distribution's GNOME desktop (settings, extensions, theme).";
  };

  config = lib.mkIf config.my.gnome.enable {
    xdg.dataFile =
      lib.listToAttrs (
        map (e: lib.nameValuePair "gnome-shell/extensions/${e.uuid}" { source = extension e; }) pinned.extensions
      )
      // lib.optionalAttrs ownLook {
        "themes/${themeName}".source = themeDir;
        "icons/${cursor}".source = "${pkgs.volantes-cursors}/share/icons/${cursor}";
      };

    # Login apps of the GNOME session (auto-move-windows puts them on
    # workspaces 1 and 2); Hyprland starts its own (my.desktop.autostart)
    xdg.autostart = {
      enable = true;
      entries = [
        "${
          pkgs.makeDesktopItem {
            name = "kitty-autostart";
            desktopName = "kitty";
            exec = "kitty";
            onlyShowIn = [ "GNOME" ];
          }
        }/share/applications/kitty-autostart.desktop"
        "${
          pkgs.makeDesktopItem {
            name = "google-chrome-autostart";
            desktopName = "Google Chrome";
            exec = "google-chrome-stable";
            onlyShowIn = [ "GNOME" ];
          }
        }/share/applications/google-chrome-autostart.desktop"
      ];
    };

    # libadwaita (GTK 4) apps ignore gtk-theme; in dark mode they load
    # ~/.config/gtk-4.0/gtk-dark.css. gtk.css stays unmanaged: the Unite
    # extension rewrites it (GTK 3 and 4) with its window button styles.
    xdg.configFile = lib.mkIf ownLook {
      "gtk-4.0/assets".source = "${themeDir}/gtk-4.0/assets";
      "gtk-4.0/gtk-dark.css".source = "${themeDir}/gtk-4.0/gtk-dark.css";
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        clock-format = "24h";
        clock-show-date = true;
        clock-show-seconds = false;
        clock-show-weekday = false;
        enable-animations = false;
        font-hinting = "slight";
        show-battery-percentage = true;
        text-scaling-factor = mkDouble 1.0;
      }
      // lib.optionalAttrs ownLook {
        color-scheme = "prefer-dark";
        cursor-size = 32;
        cursor-theme = cursor;
        font-name = "JetBrainsMono Nerd Font 11";
        document-font-name = "JetBrainsMono Nerd Font 11";
        monospace-font-name = "JetBrainsMono Nerd Font Mono 13";
        gtk-theme = themeName;
        icon-theme = "Yaru-blue-dark";
      };
      "org/gnome/desktop/input-sources" = {
        per-window = false;
        sources = [
          (mkTuple [
            "xkb"
            "us"
          ])
          (mkTuple [
            "xkb"
            "gb"
          ])
        ];
        xkb-options = none;
      };
      "org/gnome/desktop/calendar".show-weekdate = true;
      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
        focus-mode = "click";
        num-workspaces = 10;
      };
      "org/gnome/desktop/peripherals/mouse".speed = mkDouble (-0.17518248175182483);
      "org/gnome/desktop/peripherals/touchpad" = {
        click-method = "none";
        natural-scroll = true;
        send-events = "enabled";
        speed = mkDouble 0.29197080291970812;
        tap-to-click = false;
        two-finger-scrolling-enabled = true;
      };
      "org/gnome/desktop/privacy" = {
        remember-recent-files = true;
        recent-files-max-age = 30;
      };
      "org/gnome/desktop/background" = lib.mkIf ownLook {
        picture-uri = wallpaper;
        picture-uri-dark = wallpaper;
        picture-options = "zoom";
        color-shading-type = "solid";
        primary-color = "#000000000000";
        secondary-color = "#000000000000";
      };
      "org/gnome/mutter" = {
        dynamic-workspaces = false;
        edge-tiling = true;
        workspaces-only-on-primary = true;
      };

      # --- Keybindings ------------------------------------------------------
      "org/gnome/settings-daemon/plugins/media-keys" = {
        terminal = [ "<Super>Return" ];
        www = [ "<Shift><Super>Return" ];
        home = [ "<Super>e" ];
        control-center = [ "<Super>c" ];
        screensaver = [ "<Super>Escape" ];
        rotate-video-lock-static = none;
        custom-keybindings = none;
      };
      "org/gnome/desktop/wm/keybindings" = {
        close = [ "<Shift><Super>q" ];
        maximize = [ "<Shift><Super>k" ];
        unmaximize = [ "<Super>Down" ];
        toggle-fullscreen = [ "<Super>f" ];
        toggle-maximized = [ "<Shift><Super>f" ];
        switch-to-workspace-up = [
          "<Primary><Super>Up"
          "<Primary><Super>k"
        ];
        switch-to-workspace-down = [
          "<Primary><Super>Down"
          "<Primary><Super>j"
        ];
        move-to-workspace-up = none;
        move-to-workspace-down = none;
        move-to-workspace-1 = [ "<Shift><Super>exclam" ];
        move-to-workspace-2 = [ "<Shift><Super>at" ];
        move-to-workspace-3 = [ "<Shift><Super>numbersign" ];
        move-to-workspace-4 = [ "<Shift><Super>dollar" ];
        move-to-workspace-5 = [ "<Super><Shift>5" ];
        move-to-workspace-6 = [ "<Super><Shift>6" ];
        move-to-workspace-7 = [ "<Super><Shift>7" ];
        move-to-workspace-8 = [ "<Super><Shift>8" ];
        move-to-workspace-9 = [ "<Super><Shift>9" ];
        move-to-workspace-10 = [ "<Super><Shift>0" ];
      };
      "org/gnome/mutter/keybindings" = {
        toggle-tiled-left = [ "<Shift><Super>h" ];
        toggle-tiled-right = [ "<Shift><Super>l" ];
      };
      "org/gnome/mutter/wayland/keybindings".restore-shortcuts = none;
      "org/gnome/shell/keybindings" = {
        toggle-application-view = [ "<Super>a" ];
        toggle-overview = [ "<Super>s" ];
        show-screenshot-ui = [ "<Shift><Super>s" ];
      }
      // lib.genAttrs (map (n: "switch-to-application-${toString n}") (lib.range 1 9)) (_: none);

      # --- Shell, extensions ------------------------------------------------
      "org/gnome/shell" = {
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "google-chrome.desktop"
          "kitty.desktop"
        ];
        enabled-extensions = map (e: e.uuid) pinned.extensions;
        disabled-extensions = [
          "ubuntu-appindicators@ubuntu.com"
          "ubuntu-dock@ubuntu.com"
          "ding@rastersoft.com"
          "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
          "window-list@gnome-shell-extensions.gcampax.github.com"
          "screenshot-window-sizer@gnome-shell-extensions.gcampax.github.com"
          "places-menu@gnome-shell-extensions.gcampax.github.com"
          "native-window-placement@gnome-shell-extensions.gcampax.github.com"
          "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
          "apps-menu@gnome-shell-extensions.gcampax.github.com"
        ];
      };
      "org/gnome/shell/extensions/user-theme" = lib.mkIf ownLook { name = themeName; };
      "org/gnome/shell/extensions/auto-move-windows".application-list = [
        "kitty.desktop:1"
        "google-chrome.desktop:2"
      ];
      "org/gnome/shell/extensions/appindicator" = {
        legacy-tray-enabled = true;
        tray-pos = "right";
      };
      "org/gnome/shell/extensions/blur-my-shell" = {
        color-and-noise = false;
        sigma = 65;
      };
      "org/gnome/shell/extensions/blur-my-shell/applications".blur = false;
      "org/gnome/shell/extensions/blur-my-shell/dash-to-panel".blur-original-panel = true;
      "org/gnome/shell/extensions/blur-my-shell/hidetopbar".compatibility = false;
      "org/gnome/shell/extensions/blur-my-shell/overview".blur = true;
      "org/gnome/shell/extensions/blur-my-shell/panel" = {
        blur = false;
        customize = true;
        sigma = 0;
        static-blur = true;
        unblur-in-overview = true;
      };
      "org/gnome/shell/extensions/clipboard-history" = {
        display-mode = 3;
        private-mode = false;
        strip-text = true;
      };
      "org/gnome/shell/extensions/emoji-copy" = {
        always-show = false;
        position = "top";
      };
      "org/gnome/shell/extensions/mpris-label" = {
        album-size = 28;
        auto-switch-to-most-recent = true;
        extension-place = "right";
        left-padding = 10;
        remove-text-when-paused = false;
        right-padding = 4;
        show-icon = "left";
        symbolic-source-icon = false;
        use-album = true;
      };
      "org/gnome/shell/extensions/notification-banner-reloaded" = {
        always-minimized = 1;
        anchor-horizontal = 1;
        anchor-vertical = 1;
        animation-direction = 1;
        animation-time = 500;
        padding-horizontal = 0;
        padding-vertical = 0;
      };
      "org/gnome/shell/extensions/space-bar/appearance" = {
        active-workspace-border-color = "rgba(0,0,0,0)";
        active-workspace-border-radius = 4;
        active-workspace-padding-h = 8;
        active-workspace-padding-v = 2;
        empty-workspace-border-radius = 4;
        empty-workspace-padding-h = 8;
        empty-workspace-padding-v = 2;
        inactive-workspace-border-color = "rgba(0,0,0,0)";
        inactive-workspace-border-radius = 4;
        inactive-workspace-border-radius-active = false;
        inactive-workspace-padding-h = 8;
        inactive-workspace-padding-v = 2;
        workspace-margin = 4;
        workspaces-bar-padding = 12;
      };
      "org/gnome/shell/extensions/space-bar/behavior" = {
        always-show-numbers = false;
        indicator-style = "workspaces-bar";
        position = "left";
        show-empty-workspaces = false;
        smart-workspace-names = false;
        toggle-overview = false;
      };
      "org/gnome/shell/extensions/space-bar/shortcuts" = {
        activate-empty-key = none;
        activate-previous-key = none;
        enable-activate-workspace-shortcuts = true;
        enable-move-to-workspace-shortcuts = true;
        move-workspace-left = none;
        move-workspace-right = none;
        open-menu = none;
      };
      "org/gnome/shell/extensions/top-bar-organizer" = {
        center-box-order = none;
        left-box-order = [
          "Space Bar"
          "activities"
          "appMenu"
        ];
        right-box-order = [
          "Mpris Label"
          "EmojisMenu"
          "vitalsMenu"
          "screenRecording"
          "Clipboard History Indicator"
          "dwellClick"
          "a11y"
          "keyboard"
          "dateMenu"
          "aggregateMenu"
        ];
      };
      "org/gnome/shell/extensions/unite" = {
        app-menu-ellipsize-mode = "end";
        autofocus-windows = false;
        desktop-name-text = "GNOME Desktop";
        enable-titlebar-actions = false;
        extend-left-box = true;
        greyscale-tray-icons = false;
        hide-activities-button = "never";
        hide-app-menu-icon = false;
        hide-dropdown-arrows = true;
        # Unite does this by rewriting gtk.css, which Stylix manages with
        # themeToolkits
        hide-window-titlebars = if ownLook then "maximized" else "never";
        notifications-position = "right";
        reduce-panel-spacing = true;
        restrict-to-primary-screen = false;
        show-desktop-name = false;
        show-legacy-tray = true;
        show-window-buttons = "never";
        show-window-title = "always";
        window-buttons-placement = "auto";
        window-buttons-theme = "auto";
      };
      "org/gnome/shell/extensions/vitals" = {
        fixed-widths = true;
        hide-icons = false;
        hide-zeros = false;
        position-in-panel = 2;
        show-battery = true;
        show-processor = true;
        show-storage = true;
        show-system = true;
        show-temperature = true;
        use-higher-precision = false;
      };
    };
  };
}
