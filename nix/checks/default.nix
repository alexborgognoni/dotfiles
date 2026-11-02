# `nix flake check` runs all of these.
#
#   toplevel-<host>   every NixOS host builds (evaluates all modules, every
#                     theme specialisation, validates the Noctalia config)
#   home-<user-host>  every standalone Home Manager configuration builds
#   system-<host>     every system-manager configuration (Ubuntu) builds
#   native-addons     bun loads a prebuilt library that needs libstdc++ and has
#                     no RPATH to it (what sharp and other npm addons are)
#   hyprland-config   the generated hyprland.lua and every theme pack's
#                     hyprland.lua pass `Hyprland --verify-config`
#   theme-packs       every theme x accent pack is complete and well-formed
#   theme-look        every theme's values are valid; the default keeps its baseline
#   theme-assets      every font, cursor and icon theme a theme names exists
#   theme-tmux        every theme's tmux config loads, with its shape; live reload
#   theme-noctalia    every theme's Noctalia config passes `noctalia config validate`
#   app-coverage      every installed application says how it follows the theme
#   vm                boots the desktop configuration in a VM and exercises
#                     login, theme switching, accents, the shell and Neovim
{
  self,
  inputs,
  pkgs,
}:
let
  inherit (pkgs) lib;
  vm = self.nixosConfigurations.vm.config;
  hm = vm.home-manager.users.${vm.my.user.name};
  catalogue = vm.my.themes;
  hyprland = vm.programs.hyprland.package;

  # Prints "<colorscheme>|<messages>" after Neovim has started (dashboard included).
  nvimProbe = pkgs.writeShellScript "nvim-probe" ''
    cd /tmp
    nvim --headless "+lua vim.defer_fn(function() io.stdout:write(vim.g.colors_name .. '|' .. vim.fn.execute('messages')) vim.cmd('qa!') end, 3000)" 2>&1
  '';

  allPacks = lib.concatLists (
    lib.mapAttrsToList (
      theme: t:
      lib.mapAttrsToList (accent: pack: {
        name = "${theme}/${accent}";
        inherit pack;
      }) t.packs
    ) catalogue.themes
  );
in
(import ./theme.nix { inherit self pkgs; })
// lib.mapAttrs' (
  name: host: lib.nameValuePair "toplevel-${name}" host.config.system.build.toplevel
) self.nixosConfigurations
// lib.mapAttrs' (
  name: home:
  lib.nameValuePair "home-${lib.replaceStrings [ "@" ] [ "-" ] name}" home.activationPackage
) self.homeConfigurations
// lib.mapAttrs' (name: system: lib.nameValuePair "system-${name}" system) self.systemConfigs
// {
  native-addons =
    pkgs.runCommand "check-native-addons"
      {
        nativeBuildInputs = [
          pkgs.gcc
          pkgs.patchelf
          self.packages.${pkgs.stdenv.hostPlatform.system}.bun-libstdcxx
        ];
      }
      ''
        export HOME=$TMPDIR
        cat > probe.cc <<'EOF'
        #include <string>
        extern "C" int probe_answer() { return (int)std::string("ok").size(); }
        EOF
        g++ -shared -fPIC -o libprobe.so probe.cc
        patchelf --remove-rpath libprobe.so
        readelf -d libprobe.so | grep -q 'libstdc++.so.6'
        result="$(bun -e "
          import { dlopen } from 'bun:ffi'
          console.log('answer', dlopen('$PWD/libprobe.so', { probe_answer: { args: [], returns: 'i32' } }).symbols.probe_answer())
        " 2>&1)"
        echo "$result"
        grep -q 'answer 2' <<<"$result"
        touch $out
      '';

  hyprland-config = pkgs.runCommand "check-hyprland-config" { } ''
    export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR
    verify() {
      result="$(${hyprland}/bin/Hyprland --verify-config -c "$1" 2>&1)"
      if ! grep -q "config ok" <<<"$result"; then
        echo "FAIL $2:"
        echo "$result"
        exit 1
      fi
    }
    verify ${hm.xdg.configFile."hypr/hyprland.lua".source} hyprland.lua
    ${lib.concatMapStrings (p: ''
      verify ${p.pack}/hyprland.lua ${lib.escapeShellArg p.name}
    '') allPacks}
    echo "${toString (lib.length allPacks + 1)} configs ok" > $out
  '';

  theme-packs = pkgs.runCommand "check-theme-packs" { nativeBuildInputs = [ pkgs.jq ]; } ''
    fail() { echo "FAIL $1: $2"; exit 1; }
    check() {
      name="$1" pack="$2"
      for f in kitty.conf tmux.conf nvim.lua hyprland.lua noctalia.json wallpaper wallpapers polarity accent cursor terminal-opacity look.json; do
        [ -e "$pack/$f" ] || fail "$name" "missing $f"
      done
      jq -e '.dark.mPrimary and .light.mSurface' "$pack/noctalia.json" >/dev/null || fail "$name" "bad noctalia.json"
      grep -q '^background #[0-9a-f]\{6\}$' "$pack/kitty.conf" || fail "$name" "kitty background"
      grep -q '@thm_bg "#' "$pack/tmux.conf" || fail "$name" "tmux palette"
      grep -q 'base0F = "#' "$pack/nvim.lua" || fail "$name" "nvim palette"
      grep -qE '^(dark|light)$' "$pack/polarity" || fail "$name" "polarity"
      grep -qE '^[^ ]+ [0-9]+$' "$pack/cursor" || fail "$name" "cursor"
      grep -qE '^(0|1)(\.[0-9]+)?$' "$pack/terminal-opacity" || fail "$name" "terminal-opacity"
      jq -e '.decoration.rounding >= 0 and .animation.preset and .tmux.shape and .fonts.monospace' "$pack/look.json" >/dev/null || fail "$name" "look.json"
      jq -e --arg p "$(cat "$pack/polarity")" '.polarity == $p' "$pack/look.json" >/dev/null || fail "$name" "look.json polarity"
      grep -q 'hl.animation' "$pack/hyprland.lua" || [ "$(jq -r .animation.enabled "$pack/look.json")" = false ] || fail "$name" "no animations in hyprland.lua"
      grep -q 'active_opacity' "$pack/hyprland.lua" || fail "$name" "no window opacity in hyprland.lua"
      [ -n "$(ls "$pack/wallpapers")" ] || fail "$name" "no wallpapers"
      accent="$(cut -d' ' -f2 "$pack/accent")"
      jq -e --arg a "$accent" '.dark.mPrimary == $a' "$pack/noctalia.json" >/dev/null || fail "$name" "accent mismatch"
    }
    ${lib.concatMapStrings (p: ''
      check ${lib.escapeShellArg p.name} ${p.pack}
    '') allPacks}
    echo "${toString (lib.length allPacks)} packs ok" > $out
  '';

  vm = pkgs.testers.runNixOSTest {
    name = "desktop";
    node.specialArgs = { inherit inputs self; };
    # The modules configure nixpkgs (allowUnfree), like on a real host.
    node.pkgsReadOnly = false;
    nodes.machine = {
      imports = [ ../modules/nixos ];
      nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
      networking.hostName = "test";
      users.users.alex.password = "test";
      # Only the themes the test uses: keeps evaluation memory down.
      home-manager.users.alex.my.themes.prebuilt = [
        "nord"
        "dracula"
        # a light theme
        "catppuccin-latte"
      ];
      virtualisation = {
        memorySize = 4096;
        cores = 4;
      };
      system.stateVersion = "26.05";
    };

    testScript = ''
      import re

      def user(cmd):
          status, out = machine.execute(f"su - alex -c {repr(cmd)} 2>/tmp/stderr")
          if status != 0:
              err = machine.execute("cat /tmp/stderr")[1]
              raise AssertionError(f"{cmd!r} failed ({status}):\n{out}\n{err}")
          return out

      def current_pack():
          return user("readlink ~/.local/state/theme/current").strip()

      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("greetd.service")
      machine.wait_for_unit("home-manager-alex.service")

      with subtest("theme state is initialised by activation"):
          assert "catppuccin-macchiato" in current_pack(), current_pack()
          assert "nord" in user("theme list")

      with subtest("applying a theme switches the live pack and the GTK theme"):
          user("theme apply nord")
          assert "theme-pack-nord-" in current_pack(), current_pack()
          user("grep -qi 2e3440 ~/.config/gtk-3.0/gtk.css")
          assert user("theme current").strip() == "nord"

      with subtest("switching back to the default theme restores it"):
          user("theme apply catppuccin-macchiato")
          assert "catppuccin-macchiato" in current_pack(), current_pack()
          user("grep -qi 24273a ~/.config/gtk-3.0/gtk.css")

      with subtest("accents are validated and remembered per theme"):
          user("theme accent peach")
          assert "-peach" in current_pack(), current_pack()
          machine.fail("su - alex -c 'theme accent no-such-accent'")
          machine.fail("su - alex -c 'theme apply no-such-theme'")
          user("theme apply dracula")
          user("theme accent pink")
          user("theme apply catppuccin-macchiato")
          assert "-peach" in current_pack(), current_pack()
          user("theme apply dracula")
          assert "-pink" in current_pack(), current_pack()

      with subtest("the chosen theme survives re-activation (rebuilds)"):
          machine.succeed("systemctl restart home-manager-alex.service")
          assert "theme-pack-dracula-pink" in current_pack(), current_pack()

      with subtest("preview changes the live pack without applying"):
          user("theme preview nord")
          assert "nord" in current_pack()
          assert user("theme current").strip() == "dracula"
          user("theme preview dracula")

      with subtest("zsh starts cleanly with plugins"):
          out = machine.succeed("su - alex -c 'zsh -i -c exit' 2>&1")
          assert out.strip() == "", out
          user("zsh -i -c 'whence fzf-tab-complete >/dev/null && alias ls | grep -q eza'")

      with subtest("neovim starts without errors, including the dashboard"):
          # (Neovim sets terminal palette entries at startup: strip the escapes)
          out = re.sub(r"\x1b\][^\x07]*\x07", "", user("${nvimProbe}"))
          assert out.startswith("theme-dracula"), out
          assert "Error" not in out, out

      with subtest("applications and tools are installed"):
          commands = [
              "google-chrome-stable", "chromium", "microsoft-edge", "code",
              "neovide", "obsidian", "vlc", "obs", "audacity", "ghb", "inkscape", "foliate",
              "readest", "claude",
              "codex", "copilot", "opencode", "herdr", "forge", "github-mcp-server",
              "mcp-language-server", "node", "pnpm", "bun", "tsc", "typescript-language-server",
              "rustup", "go", "uv", "poetry", "aws", "az", "func", "azcopy", "cf", "terraform",
              "tflint", "kubectl", "kubecolor", "k9s", "ansible", "mkcert", "psql", "squawk",
              "bw", "fnox", "semgrep", "zizmor", "7zz", "sponge", "tree", "tokei", "lynx",
              "git-filter-repo", "process-compose", "llama-cli", "onedrive", "wine",
              "latexmk", "pdflatex", "python3", "ffmpeg", "magick", "docker", "virt-manager",
              "sops", "age", "ssh-to-age", "mise",
          ]
          missing = user("for c in " + " ".join(commands) + "; do command -v $c >/dev/null || echo $c; done").split()
          assert not missing, f"missing commands: {missing}"
          user("forge --version && kubectl version --client && terraform version && node --version")
          user("python3 -c 'import pandas, boto3, openpyxl, docx, pptx, pypdf, pikepdf'")

      with subtest("system services for the tools are running"):
          machine.wait_for_unit("docker.service")
          machine.wait_for_unit("keyd.service")
          machine.succeed("id -nG alex | grep -qw docker")
          # nix-ld: the standard dynamic linker exists for prebuilt binaries
          machine.succeed("test -e /lib64/ld-linux-x86-64.so.2")

      with subtest("tmux loads the config and the theme reload file"):
          user("tmux new-session -d -s t && tmux source-file ~/.config/tmux/theme-reload.conf")
          assert user("tmux show -gv @thm_bg").strip() == "#282a36"
          user("tmux kill-server")

      def look():
          import json
          return json.loads(user("cat ~/.local/state/theme/current/look.json"))

      def tmux_cap():
          return user("LC_ALL=C.UTF-8 tmux -u show -gv @catppuccin_window_current_right_separator").strip()

      with subtest("each theme brings its own look: animation, shape, borders"):
          user("theme apply dracula")
          d = look()
          assert d["animation"]["preset"] == "bouncy", d["animation"]
          assert d["tmux"]["shape"] == "flame", d["tmux"]
          assert d["decoration"]["shadowGlow"] is True, d["decoration"]
          hypr = user("cat ~/.local/state/theme/current/hyprland.lua")
          assert 'leaf = "windows"' in hypr, "no window animation"
          assert "rgba(bd93f9b3)" in hypr or "rgba(ff79c6b3)" in hypr, "no accent glow shadow"
          assert "overshoot" in hypr, "the bouncy curve is missing"
          user("tmux new-session -d -s look")
          dracula_cap = tmux_cap()
          user("theme apply nord")
          n = look()
          assert n["animation"]["preset"] == "smooth" and n["tmux"]["shape"] == "arrow", n
          # the running tmux took the new shape without a restart
          nord_cap = tmux_cap()
          assert nord_cap != dracula_cap, (nord_cap, dracula_cap)
          assert nord_cap.endswith("\ue0b0"), repr(nord_cap)
          user("tmux kill-server")

      with subtest("the Noctalia config follows the theme's look"):
          user("theme apply dracula")
          cfg = user("cat ~/.config/noctalia/config.toml")
          assert 'transition = ["disc"]' in cfg, "wallpaper transition"
          assert "transition_duration = 700" in cfg, "wallpaper duration"
          user("theme apply nord")
          cfg = user("cat ~/.config/noctalia/config.toml")
          assert 'transition = ["fade"]' in cfg and "transition_duration = 500" in cfg

      with subtest("light and dark follow the theme system-wide"):
          user("theme apply catppuccin-macchiato")
          assert "prefer-dark" in user("dconf read /org/gnome/desktop/interface/color-scheme")
          user("theme apply nord")
          assert "prefer-dark" in user("dconf read /org/gnome/desktop/interface/color-scheme")
          assert "Nordzy-dark" in user("dconf read /org/gnome/desktop/interface/icon-theme")
          assert "Nordzy-cursors" in user("dconf read /org/gnome/desktop/interface/cursor-theme")
          user("theme apply catppuccin-latte")
          assert "prefer-light" in user("dconf read /org/gnome/desktop/interface/color-scheme")
          assert "Papirus-Light" in user("dconf read /org/gnome/desktop/interface/icon-theme")
          assert look()["polarity"] == "light"
          assert user("cat ~/.local/state/theme/current/polarity").strip() == "light"

      with subtest("theme apps lists how every application is themed"):
          out = user("theme apps")
          for app in ["kitty", "nautilus-and-gnome", "firefox", "tmux", "hyprland"]:
              assert app in out, f"{app} missing from theme apps"

      with subtest("the default theme's look is unchanged after switching back"):
          user("theme apply catppuccin-macchiato")
          m = look()
          assert m["decoration"]["rounding"] == 10 and m["animation"]["preset"] == "smooth", m
          assert m["tmux"]["shape"] == "round", m
    '';
  };
}
