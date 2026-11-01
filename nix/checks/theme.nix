# Checks of the theme engine (themes/): every theme is valid, its assets exist,
# tmux and Noctalia accept what it generates, and every installed application
# says how it follows the theme. Imported by checks/default.nix.
#
#   theme-look        values in range, polarity matches the palette, animation
#                     presets are well-formed, the default theme keeps its baseline
#   theme-assets      every font family, cursor and icon theme a theme names
#                     exists in its package
#   theme-tmux        every theme's tmux config loads in a real tmux, with its
#                     shape, and a live reload switches the shape
#   theme-noctalia    every theme's generated Noctalia config passes
#                     `noctalia config validate`
#   app-coverage      every installed GUI app and watched terminal tool is in
#                     themes/apps.nix, and each entry's mechanism is really enabled
#   theme-rejects     the checks themselves: broken themes fail evaluation with
#                     the right message, a broken look is reported by theme-look,
#                     an unlisted app is reported by app-coverage
{ self, pkgs }:
let
  inherit (pkgs) lib;
  vm = self.nixosConfigurations.vm.config;
  vmHm = vm.home-manager.users.${vm.my.user.name};
  laptop = self.homeConfigurations."alex@work-laptop";
  laptopCfg = laptop.config;
  catalogue = vm.my.themes;
  inherit (catalogue) themes;
  appsFile = import ../themes/apps.nix;

  # Every theme, as the work laptop would apply it
  asTheme =
    t:
    (laptop.extendModules {
      modules = [
        {
          my.theme = lib.mkForce t;
          my.isThemeSpecialisation = true;
        }
      ];
    }).config;

  problemsToCheck =
    name: problems:
    pkgs.runCommand "check-${name}" { } ''
      ${
        if problems == [ ] then
          ""
        else
          ''
            cat <<'EOF'
            ${lib.concatStringsSep "\n" problems}
            EOF
            exit 1
          ''
      }
      echo ok > $out
    '';

  # ---------------------------------------------------------------- look
  effects = [
    "fade"
    "wipe"
    "disc"
    "stripes"
    "zoom"
    "honeycomb"
    "vortex"
    "pixel"
    "diamond"
    "golden"
    "melt"
  ];
  styleOk =
    s:
    builtins.match "(popin [0-9]+%|slide|slidevert|slidefade|slidefadevert|fade|gnomed|once|loop)" s
    != null;
  lum =
    c:
    let
      ch = i: lib.fromHexString (builtins.substring i 2 c);
    in
    0.299 * ch 0 + 0.587 * ch 2 + 0.114 * ch 4;

  # The default theme is Hyprland's own look; changing it must be deliberate
  baseline = {
    rounding = 10;
    roundingPower = 2;
    borderSize = 2;
    borderStyle = "gradient";
    gapsIn = 5;
    gapsOut = 10;
    shadow = true;
    shadowRange = 4;
    shadowPower = 3;
    shadowGlow = false;
    blur = true;
    blurSize = 3;
    blurPasses = 2;
    blurVibrancy = 0.1696;
  };

  themeProblems =
    name: t:
    let
      bad = cond: msg: lib.optional (!cond) "${name}: ${msg}";
      an = t.animation;
      curveNames = [ "default" ] ++ lib.attrNames an.curves;
    in
    bad (
      (t.polarity == "light") == (lum t.colors.base00 > lum t.colors.base05)
    ) "polarity ${t.polarity} does not match the palette (base00 vs base05 luminance)"
    ++ bad (lib.all (v: v >= 0 && v <= 1) (lib.attrValues t.opacity)) "an opacity is outside 0..1"
    ++ bad (
      t.opacity.desktop > 0 && t.opacity.popups > 0
    ) "the bar and popups must not be fully see-through"
    ++ bad (t.decoration.rounding >= 0 && t.decoration.borderSize >= 0) "negative rounding or border"
    ++ bad (t.decoration.borderSize <= 8) "border wider than 8"
    ++ bad (t.decoration.gapsIn >= 0 && t.decoration.gapsOut >= 0) "negative gaps"
    ++ bad (t.decoration.shellRadius >= 0 && t.decoration.shellRadius <= 2) "shellRadius outside 0..2"
    ++ bad (t.decoration.blurPasses >= 1 && t.decoration.blurPasses <= 6) "blurPasses outside 1..6"
    ++ bad (
      t.decoration.rounding == 0 -> t.decoration.shellRadius <= 0.5
    ) "a square window theme with a round shell"
    ++ bad (t.fonts.sizes.terminal > 0 && t.fonts.sizes.applications > 0) "font sizes must be positive"
    ++ bad (t.cursor.size >= 16 && t.cursor.size <= 64) "cursor size outside 16..64"
    ++ bad (an.speed > 0 && an.speed <= 4) "animation speed outside (0, 4]"
    ++ bad (an.enabled == (an.leaves != [ ])) "animation enabled state and leaves disagree"
    ++ lib.concatMap (
      l:
      bad (l.speed > 0) "animation ${l.leaf}: speed must be positive"
      ++ bad (lib.elem l.bezier curveNames) "animation ${l.leaf}: unknown curve ${l.bezier}"
      ++ bad (!(l ? style) || styleOk l.style) "animation ${l.leaf}: unknown style ${l.style or ""}"
    ) an.leaves
    ++ bad (
      an.wallpaper.transition != [ ] && lib.all (e: lib.elem e effects) an.wallpaper.transition
    ) "wallpaper transition effects must be a non-empty list of: ${lib.concatStringsSep " " effects}"
    ++ bad (
      an.wallpaper.duration >= 0 && an.wallpaper.duration <= 5000
    ) "wallpaper transition duration outside 0..5000 ms"
    ++ bad (
      if t.tmux.shape == "square" then
        t.tmux.glyphs.left == "" && t.tmux.glyphs.right == ""
      else
        # one private-use code point is three bytes in UTF-8
        lib.stringLength t.tmux.glyphs.left == 3 && lib.stringLength t.tmux.glyphs.right == 3
    ) "tmux shape ${t.tmux.shape}: wrong glyphs"
    ++ bad (t.wallpapers != [ ]) "no wallpapers"
    ++ bad (
      builtins.length (lib.unique (map (w: w.name) t.wallpapers)) == builtins.length t.wallpapers
    ) "two wallpapers with the same file name"
    ++ bad (lib.all (
      w: lib.hasSuffix ".jpg" w.name || lib.hasSuffix ".png" w.name
    ) t.wallpapers) "a wallpaper that is not a jpg or png";

  defaultProblems =
    let
      t = themes.${catalogue.default};
      bad = cond: msg: lib.optional (!cond) "default theme ${catalogue.default}: ${msg}";
    in
    lib.concatMap (
      k: bad (t.decoration.${k} == baseline.${k}) "${k} is not the baseline ${toString baseline.${k}}"
    ) (lib.attrNames baseline)
    ++ bad (
      t.animation.preset == "smooth" && t.animation.speed == 1.0
    ) "animation is not smooth at speed 1"
    ++ bad (t.opacity.applications == 1.0 && t.opacity.inactive == 1.0) "windows are not opaque"
    ++ bad (t.tmux.shape == "round") "tmux shape is not round";

  presetProblems = lib.concatLists (
    lib.mapAttrsToList (
      n: p:
      let
        r = (import ../themes/assets/animations.nix { inherit lib; }).resolve p 1.0;
      in
      lib.optional (!(p ? wallpaper)) "preset ${n}: no wallpaper transition"
      ++ lib.optional (
        !(lib.all (l: l.bezier == "default" || r.curves ? ${l.bezier}) r.leaves)
      ) "preset ${n}: a leaf uses a curve that is not defined"
    ) (import ../themes/assets/animations.nix { inherit lib; }).presets
  );

  # ---------------------------------------------------------------- rejects
  # A catalogue of one theme, evaluated on its own (like themes/default.nix does)
  buildOne =
    attrs:
    (import ../themes {
      inherit pkgs lib;
      base16 = self.inputs.stylix.inputs.base16.lib { inherit pkgs lib; };
      catalogue.probe = attrs;
    }).themes.probe;
  # Forces every value a theme resolves (names, numbers, the animation), not the
  # packages behind them: forcing a whole derivation throws for unrelated reasons.
  evaluates =
    attrs:
    let
      t = buildOne attrs;
    in
    (builtins.tryEval (
      builtins.deepSeq [
        t.fonts.monospace.name
        t.fonts.sansSerif.name
        t.cursor.name
        t.cursor.size
        t.icons.dark
        t.icons.light
        t.decoration
        t.opacity
        t.animation
        t.tmux
        t.polarity
        t.accent
        t.accent2
        (builtins.attrNames t.packs)
      ] true
    )).success;
  # (the default accent2, purple, is not in Nord's palette: a real case the
  # catalogue handles by naming one)
  base = {
    scheme = "nord";
    accent2 = "cyan";
  };
  rejected = {
    "unknown mono font" = base // {
      mono = "comic-sans";
    };
    "unknown UI font" = base // {
      ui = "papyrus";
    };
    "unknown cursor" = base // {
      cursor = "no-such-cursor";
    };
    "unknown icon set" = base // {
      icons = "no-such-icons";
    };
    "unknown animation preset" = base // {
      animation.preset = "wobbly";
    };
    "unknown tmux shape" = base // {
      tmuxShape = "hexagon";
    };
    "unknown accent" = base // {
      accent = "ultraviolet";
    };
    "unknown accent2" = base // {
      accent2 = "infrared";
    };
    "a default accent the palette lacks" = {
      scheme = "nord";
    };
    "opacity above 1" = base // {
      opacity.terminal = 1.5;
    };
    "negative opacity" = base // {
      opacity.inactive = -0.1;
    };
    "negative rounding" = base // {
      decoration.rounding = -2;
    };
    "negative gaps" = base // {
      decoration.gapsOut = -1;
    };
    "unknown border style" = base // {
      decoration.borderStyle = "dotted";
    };
    "animation speed 0" = base // {
      animation.speed = 0;
    };
    "negative animation speed" = base // {
      animation.speed = -1;
    };
    "wallpaper transition without duration" = base // {
      animation.wallpaper.transition = [ "wipe" ];
    };
  };
  rejectProblems =
    lib.optional (
      !(evaluates base)
    ) "a minimal valid theme (nord, accent2 cyan) does not evaluate: the harness is broken"
    ++ lib.concatLists (
      lib.mapAttrsToList (
        what: attrs: lib.optional (evaluates attrs) "accepted a theme with ${what}"
      ) rejected
    );

  # theme-look must report a broken look (each a valid theme with one value off)
  inherit (themes) nord;
  lookRejected = {
    "polarity not matching the palette" = nord // {
      polarity = "light";
    };
    "a fully see-through bar" = nord // {
      opacity = nord.opacity // {
        desktop = 0.0;
      };
    };
    "a border wider than 8" = nord // {
      decoration = nord.decoration // {
        borderSize = 12;
      };
    };
    "too many blur passes" = nord // {
      decoration = nord.decoration // {
        blurPasses = 9;
      };
    };
    "square windows with a round shell" = nord // {
      decoration = nord.decoration // {
        rounding = 0;
        shellRadius = 1.5;
      };
    };
    "a tiny cursor" = nord // {
      cursor = nord.cursor // {
        size = 4;
      };
    };
    "an unknown wallpaper effect" = nord // {
      animation = nord.animation // {
        wallpaper = {
          transition = [ "spin" ];
          duration = 500;
        };
      };
    };
    "an empty wallpaper transition list" = nord // {
      animation = nord.animation // {
        wallpaper = {
          transition = [ ];
          duration = 500;
        };
      };
    };
    "a wallpaper transition of 10 s" = nord // {
      animation = nord.animation // {
        wallpaper = {
          transition = [ "fade" ];
          duration = 10000;
        };
      };
    };
    "an animation with an undefined curve" = nord // {
      animation = nord.animation // {
        leaves = [
          {
            leaf = "windows";
            enabled = true;
            speed = 3;
            bezier = "nope";
          }
        ];
      };
    };
    "an animation with an unknown style" = nord // {
      animation = nord.animation // {
        leaves = map (l: l // { style = "spin"; }) nord.animation.leaves;
      };
    };
    "an animation with speed 0" = nord // {
      animation = nord.animation // {
        leaves = map (l: l // { speed = 0; }) nord.animation.leaves;
      };
    };
    "animations disabled but leaves set" = nord // {
      animation = nord.animation // {
        enabled = false;
      };
    };
    "no wallpapers" = nord // {
      wallpapers = [ ];
    };
    "two wallpapers with one name" = nord // {
      wallpapers = [
        (builtins.head nord.wallpapers)
        (builtins.head nord.wallpapers)
      ];
    };
    "a tmux shape with wrong glyphs" = nord // {
      tmux = {
        shape = "arrow";
        glyphs = {
          left = "<";
          right = ">";
        };
      };
    };
  };
  lookRejectProblems =
    lib.optional (
      themeProblems "nord" nord != [ ]
    ) "theme-look reports the unmodified nord theme: ${toString (themeProblems "nord" nord)}"
    ++ lib.concatLists (
      lib.mapAttrsToList (
        what: t: lib.optional (themeProblems "probe" t == [ ]) "theme-look accepted ${what}"
      ) lookRejected
    );

  # ---------------------------------------------------------------- assets
  allAssets =
    let
      per = t: [
        {
          kind = "font";
          inherit (t.fonts.monospace) package name;
        }
        {
          kind = "font";
          inherit (t.fonts.sansSerif) package name;
        }
        {
          kind = "font";
          inherit (t.fonts.serif) package name;
        }
        {
          kind = "cursor";
          inherit (t.cursor) package name;
        }
        {
          kind = "icons";
          inherit (t.icons) package;
          name = t.icons.dark;
        }
        {
          kind = "icons";
          inherit (t.icons) package;
          name = t.icons.light;
        }
      ];
      all = lib.concatMap per (lib.attrValues themes);
    in
    lib.attrValues (
      lib.listToAttrs (
        map (
          a: lib.nameValuePair (builtins.unsafeDiscardStringContext "${a.kind}|${a.package}|${a.name}") a
        ) all
      )
    );

  # Shell lines that call fail() when the asset is not in its package
  assetCheck =
    a:
    if a.kind == "font" then
      ''
        # (the whole list first: an early-exiting grep in the pipe trips pipefail)
        find -L ${a.package}/share/fonts -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.ttc' \) -print0 \
          | xargs -0 -r fc-scan --format '%{family}\n' 2>/dev/null | tr ',' '\n' > families.txt
        grep -Fx ${lib.escapeShellArg a.name} families.txt > /dev/null \
          || fail "font family '${a.name}' is not in ${a.package}"
      ''
    else if a.kind == "cursor" then
      ''
        d=${a.package}/share/icons/${lib.escapeShellArg a.name}
        [ -d "$d/cursors" ] && [ -n "$(ls "$d/cursors")" ] || fail "cursor theme '${a.name}' has no cursors in ${a.package}"
      ''
    else
      ''
        [ -f ${a.package}/share/icons/${lib.escapeShellArg a.name}/index.theme ] || fail "icon theme '${a.name}' is not in ${a.package}"
      '';

  # ---------------------------------------------------------------- tmux
  tmuxConf = laptopCfg.xdg.configFile."tmux/tmux.conf".source;
  tmuxReload = laptopCfg.xdg.configFile."tmux/theme-reload.conf".source;
  tmuxState = laptopCfg.my.themeState;

  # ---------------------------------------------------------------- apps
  packFiles = [
    "kitty.conf"
    "tmux.conf"
    "nvim.lua"
    "hyprland.lua"
    "noctalia.json"
    "readest.json"
  ];
  hows = [
    "pack"
    "stylix"
    "toolkit"
    "terminal"
    "portal"
    "own"
    "none"
  ];
  entryProblems =
    cfg: name: e:
    let
      bad = cond: msg: lib.optional (!cond) "apps.nix ${name}: ${msg}";
      enabled = path: lib.attrByPath path false cfg;
    in
    bad (e ? how && lib.elem e.how hows) "how must be one of ${lib.concatStringsSep ", " hows}"
    ++ bad (e ? match || e ? bins) "needs match (desktop ids) or bins (executables)"
    ++ lib.optionals (e.how or "" == "pack") (
      bad (
        e ? file && lib.elem e.file packFiles
      ) "pack entries need file: one of ${lib.concatStringsSep ", " packFiles}"
    )
    ++ lib.optionals (e.how or "" == "stylix") (
      bad (e ? target) "stylix entries need target"
      ++ bad (enabled [
        "stylix"
        "targets"
        (e.target or "?")
        "enable"
      ]) "Stylix target ${e.target or "?"} is not enabled"
      ++ bad (enabled [
        "programs"
        (e.program or e.target or "?")
        "enable"
      ]) "programs.${e.program or e.target or "?"} is not enabled, so Stylix writes nothing for it"
    )
    ++ lib.optionals (e.how or "" == "toolkit") (
      bad (lib.elem (e.toolkit or "") [
        "gtk"
        "qt"
      ]) "toolkit entries need toolkit = gtk or qt"
      ++ bad (enabled [
        "stylix"
        "targets"
        (e.toolkit or "gtk")
        "enable"
      ]) "the Stylix ${e.toolkit or "gtk"} target is not enabled"
    )
    ++ lib.optionals (lib.elem (e.how or "") [
      "own"
      "none"
      "portal"
    ]) (bad (e ? note && e.note != "") "${e.how} entries need a note saying why");
  appProblems = lib.concatLists (
    lib.mapAttrsToList (entryProblems laptopCfg) appsFile.apps
    ++ lib.mapAttrsToList (entryProblems vmHm) appsFile.apps
  );
  matchLines = lib.concatStrings (
    lib.mapAttrsToList (n: e: lib.optionalString (e ? match) "${n}\t${e.match}\n") appsFile.apps
  );
  binLines = lib.concatStrings (
    lib.mapAttrsToList (n: e: lib.concatMapStrings (b: "${n}\t${b}\n") (e.bins or [ ])) appsFile.apps
  );
  # Fails (exit 1) when an application in one of the environments is not in
  # themes/apps.nix, or an entry's theming mechanism is not enabled.
  coverageScript = envs: ''
    failed=0
    printf '%b' ${lib.escapeShellArg matchLines} > matches.tsv
    printf '%b' ${lib.escapeShellArg binLines} > bins.tsv

    # every pattern must be a valid regex
    while IFS=$'\t' read -r name re; do
      [ -n "$name" ] || continue
      rc=0; echo | grep -Eq -- "^($re)$" || rc=$?
      [ "$rc" -le 1 ] || { echo "FAIL apps.nix $name: invalid match regex: $re"; failed=1; }
    done < matches.tsv

    covered_id() {
      while IFS=$'\t' read -r name re; do
        [ -n "$name" ] || continue
        if grep -Eq -- "^($re)$" <<<"$1"; then return 0; fi
      done < matches.tsv
      return 1
    }
    covered_bin() { cut -f2 bins.tsv | grep -Fxq -- "$1"; }
    watch="${lib.concatStringsSep " " appsFile.watch}"

    check_env() {
      label="$1"; env="$2"
      if [ -d "$env/share/applications" ]; then
        for f in "$env"/share/applications/*.desktop; do
          [ -e "$f" ] || continue
          id="$(basename "$f" .desktop)"
          covered_id "$id" || { echo "FAIL $label: the application '$id' is not in themes/apps.nix"; failed=1; }
        done
      fi
      for b in $watch; do
        if [ -e "$env/bin/$b" ] && ! covered_bin "$b"; then
          echo "FAIL $label: the tool '$b' is installed but not in themes/apps.nix (bins)"; failed=1
        fi
      done
    }
    ${lib.concatStrings (lib.mapAttrsToList (l: e: "check_env ${lib.escapeShellArg l} ${e}\n") envs)}

    ${lib.optionalString (appProblems != [ ]) ''
      cat <<'EOF'
      ${lib.concatStringsSep "\n" appProblems}
      EOF
      failed=1
    ''}
    if [ "$failed" -ne 0 ]; then
      echo
      echo "Every installed application must say how it follows the theme."
      echo "Add it to themes/apps.nix (how = pack | stylix | toolkit | terminal | portal | own | none)."
      exit 1
    fi
  '';
in
{
  theme-look = problemsToCheck "theme-look" (
    lib.concatLists (lib.mapAttrsToList themeProblems themes) ++ defaultProblems ++ presetProblems
  );

  theme-assets = pkgs.runCommand "check-theme-assets" { nativeBuildInputs = [ pkgs.fontconfig ]; } ''
    export HOME=$TMPDIR XDG_CACHE_HOME=$TMPDIR/cache
    fail() { echo "FAIL $1"; failed=1; }
    failed=0
    ${lib.concatMapStrings assetCheck allAssets}
    [ "$failed" -eq 0 ] || exit 1
    echo "${toString (builtins.length allAssets)} assets ok" > $out
  '';

  theme-tmux =
    pkgs.runCommand "check-theme-tmux"
      {
        nativeBuildInputs = [
          laptopCfg.programs.tmux.package
          pkgs.bash
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gnused
        ];
      }
      ''
        # UTF-8, or tmux prints the shape glyphs as "_"
        export HOME=$TMPDIR TMUX_TMPDIR=$TMPDIR TERM=xterm-256color XDG_DATA_HOME=$TMPDIR/data LC_ALL=C.UTF-8
        mkdir -p $TMPDIR/data
        failed=0
        fail() { echo "FAIL $1"; failed=1; }

        # The live pack replaced by a given one, and the plugins run through bash:
        # their `#!/usr/bin/env bash` has no /usr/bin/env in the build sandbox
        # (a real system has one).
        localise() {
          sed -e "s|${tmuxState}/current/tmux.conf|$2/tmux.conf|" \
            -e 's|^run-shell \(/nix/store/[^ ]*\.tmux\)$|run-shell "bash \1"|' "$1"
        }
        # wait until the catppuccin plugin has defined its segments
        settled() {
          for _ in $(seq 50); do
            [ -n "$(tmux -L "$1" show -gv @catppuccin_status_session 2>/dev/null)" ] && return 0
            sleep 0.1
          done
          fail "$1: the catppuccin plugin did not run"
          return 1
        }
        start() {
          localise ${tmuxConf} "$2" > "$TMPDIR/$1.conf"
          grep -q 'run-shell "bash ' "$TMPDIR/$1.conf" || { fail "$1: no plugin found in tmux.conf"; return 1; }
          tmux -L "$1" -f "$TMPDIR/$1.conf" new-session -d -s main -x 200 -y 50 2> "$TMPDIR/$1.err" \
            || { cat "$TMPDIR/$1.err"; fail "$1: tmux did not start"; return 1; }
          [ ! -s "$TMPDIR/$1.err" ] || { cat "$TMPDIR/$1.err"; fail "$1: errors while loading"; }
          settled "$1"
        }
        shape() {
          # shape <server> <left> <right>: the segments carry the theme's glyphs
          cur="$(tmux -L "$1" show -gv @catppuccin_window_current_left_separator)"
          if [ -n "$2" ]; then
            grep -qF -- "$2" <<<"$cur" || fail "$1: current-window left cap is not the theme's"
          fi
          right="$(tmux -L "$1" show -gv @catppuccin_window_current_right_separator)"
          if [ -n "$3" ]; then
            grep -qF -- "$3" <<<"$right" || fail "$1: current-window right cap is not the theme's"
          fi
          fmt="$(tmux -L "$1" display-message -p -t main:1 '#{T:window-status-current-format}')"
          [ -n "$fmt" ] || fail "$1: empty window format"
          grep -q '#{' <<<"$fmt" && fail "$1: unexpanded format in the window segment"
          sl="$(tmux -L "$1" display-message -p -t main:1 '#{T:status-left}')"
          [ -n "$sl" ] || fail "$1: empty status-left"
          [ "$(tmux -L "$1" show -gv status-position)" = top ] || fail "$1: status not at the top"
        }

        ${lib.concatStrings (
          lib.mapAttrsToList (n: t: ''
            if start ${lib.escapeShellArg n} ${t.pack}; then
              shape ${lib.escapeShellArg n} ${lib.escapeShellArg t.tmux.glyphs.left} ${lib.escapeShellArg t.tmux.glyphs.right}
              tmux -L ${lib.escapeShellArg n} kill-server
            fi
          '') themes
        )}

        # the shape check notices a theme whose segments carry another shape
        if start wrong ${themes.nord.pack}; then
          saved=$failed
          shape wrong ${lib.escapeShellArg themes.dracula.tmux.glyphs.left} ${lib.escapeShellArg themes.dracula.tmux.glyphs.right}
          [ "$failed" = 1 ] || { echo "FAIL the tmux check accepted nord's segments as dracula's"; saved=1; }
          failed=$saved
          tmux -L wrong kill-server
        fi

        # a live reload (what `theme` does) switches the shape without a restart
        ${
          let
            from = themes.${catalogue.default};
            to = themes.gruvbox-dark-medium;
          in
          ''
            if start reload ${from.pack}; then
              before="$(tmux -L reload show -gv @catppuccin_window_current_left_separator)"
              localise ${tmuxReload} ${to.pack} > "$TMPDIR/reload-to.conf"
              tmux -L reload source-file "$TMPDIR/reload-to.conf" || fail "reload: source-file failed"
              for _ in $(seq 50); do
                after="$(tmux -L reload show -gv @catppuccin_window_current_left_separator)"
                [ "$after" != "$before" ] && break
                sleep 0.1
              done
              [ "$before" != "$after" ] || fail "reload: the shape did not change"
              grep -qF -- ${lib.escapeShellArg to.tmux.glyphs.left} <<<"$after" || [ -z ${lib.escapeShellArg to.tmux.glyphs.left} ] \
                || fail "reload: not the new theme's shape"
              grep -q "fill=" <<<"$(tmux -L reload show -gv message-style)" || fail "reload: message style lost its fill"
              tmux -L reload kill-server
            fi
          ''
        }

        [ "$failed" -eq 0 ] || exit 1
        echo "${toString (lib.length (lib.attrNames themes))} tmux configs ok" > $out
      '';

  theme-noctalia =
    let
      noctalia = laptopCfg.programs.noctalia.package;
      perTheme = lib.mapAttrsToList (
        n: t:
        let
          cfg = asTheme t;
        in
        {
          inherit n;
          config = cfg.xdg.configFile."noctalia/config.toml".source;
          # (Home Manager links the palette to the live state: take the pack's)
          palette = "${t.pack}/noctalia.json";
        }
      ) themes;
    in
    pkgs.runCommand "check-theme-noctalia" { nativeBuildInputs = [ noctalia ]; } ''
      export HOME=$TMPDIR
      failed=0
      ${lib.concatMapStrings (p: ''
        dir=$TMPDIR/${p.n}
        mkdir -p $dir/config/noctalia/palettes $dir/state
        cp ${p.config} $dir/config/noctalia/config.toml
        cp ${p.palette} $dir/config/noctalia/palettes/current.json
        if ! result="$(XDG_CONFIG_HOME=$dir/config XDG_STATE_HOME=$dir/state noctalia config validate 2>&1)"; then
          echo "FAIL ${p.n}:"; echo "$result"; failed=1
        fi
      '') perTheme}
      [ "$failed" -eq 0 ] || exit 1
      echo "${toString (builtins.length perTheme)} noctalia configs ok" > $out
    '';

  app-coverage = pkgs.runCommand "check-app-coverage" { } ''
    ${coverageScript {
      "home (work laptop)" = laptopCfg.home.path;
      "home (NixOS VM)" = vmHm.home.path;
      "system (NixOS VM)" = vm.system.path;
    }}
    echo ok > $out
  '';

  theme-rejects =
    let
      # an environment with an application and a tool nobody listed
      fakeEnv = pkgs.runCommand "fake-env" { } ''
        mkdir -p $out/share/applications $out/bin
        printf '[Desktop Entry]\nName=Mystery\n' > $out/share/applications/com.example.Mystery.desktop
        printf '#!/bin/sh\n' > $out/bin/micro
        chmod +x $out/bin/micro
      '';
      knownEnv = pkgs.runCommand "known-env" { } ''
        mkdir -p $out/share/applications $out/bin
        printf '[Desktop Entry]\nName=Kitty\n' > $out/share/applications/kitty.desktop
        printf '#!/bin/sh\n' > $out/bin/k9s
      '';
      problems = rejectProblems ++ lookRejectProblems;
    in
    pkgs.runCommand "check-theme-rejects" { nativeBuildInputs = [ pkgs.fontconfig ]; } ''
      export HOME=$TMPDIR XDG_CACHE_HOME=$TMPDIR/cache
      ${lib.optionalString (problems != [ ]) ''
        cat <<'EOF'
        ${lib.concatStringsSep "\n" problems}
        EOF
        exit 1
      ''}
      # app-coverage must catch an unlisted app and an unlisted tool...
      if result="$( (${coverageScript { fake = fakeEnv; }}) 2>&1 )"; then
        echo "FAIL app-coverage accepted an unlisted application"; exit 1
      fi
      grep -q "com.example.Mystery" <<<"$result" || { echo "FAIL app-coverage did not name the unlisted app:"; echo "$result"; exit 1; }
      grep -q "'micro'" <<<"$result" || { echo "FAIL app-coverage did not name the unlisted tool:"; echo "$result"; exit 1; }
      # ...and accept listed ones
      ( ${
        coverageScript { known = knownEnv; }
      } ) || { echo "FAIL app-coverage rejected listed apps"; exit 1; }

      # theme-assets must report a misnamed font, cursor and icon theme
      ${lib.concatMapStrings
        (a: ''
          failed=0
          fail() { failed=1; }
          ${assetCheck a}
          [ "$failed" = 1 ] || { echo "FAIL theme-assets accepted a missing ${a.kind} '${a.name}'"; exit 1; }
        '')
        [
          (
            nord.fonts.monospace
            // {
              kind = "font";
              name = "MesloLGL Nerd Fonts";
            }
          )
          (
            nord.cursor
            // {
              kind = "cursor";
              name = "Nordzy-cursor";
            }
          )
          (
            nord.icons
            // {
              kind = "icons";
              name = "Nordzy-darker";
            }
          )
        ]
      }
      # ...and accept the real ones
      failed=0
      fail() { echo "$1"; failed=1; }
      ${assetCheck (nord.cursor // { kind = "cursor"; })}
      ${assetCheck (
        nord.icons
        // {
          kind = "icons";
          name = nord.icons.dark;
        }
      )}
      ${assetCheck (nord.fonts.monospace // { kind = "font"; })}
      [ "$failed" = 0 ] || { echo "FAIL theme-assets rejected nord's real assets"; exit 1; }
      echo "${
        toString (lib.length (lib.attrNames rejected) + lib.length (lib.attrNames lookRejected) + 6)
      } rejections ok" > $out
    '';
}
