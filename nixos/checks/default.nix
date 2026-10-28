# `nix flake check` runs all of these.
#
#   toplevel-<host>   every host builds (evaluates all modules, every theme
#                     specialisation, validates the Noctalia config)
#   hyprland-config   the generated hyprland.lua and every theme pack's
#                     hyprland.lua pass `Hyprland --verify-config`
#   theme-packs       every theme x accent pack is complete and well-formed
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
lib.mapAttrs' (
  name: host: lib.nameValuePair "toplevel-${name}" host.config.system.build.toplevel
) self.nixosConfigurations
// {
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
      for f in kitty.conf tmux.conf nvim.lua hyprland.lua noctalia.json wallpaper wallpapers polarity accent; do
        [ -e "$pack/$f" ] || fail "$name" "missing $f"
      done
      jq -e '.dark.mPrimary and .light.mSurface' "$pack/noctalia.json" >/dev/null || fail "$name" "bad noctalia.json"
      grep -q '^background #[0-9a-f]\{6\}$' "$pack/kitty.conf" || fail "$name" "kitty background"
      grep -q '@thm_bg "#' "$pack/tmux.conf" || fail "$name" "tmux palette"
      grep -q 'base0F = "#' "$pack/nvim.lua" || fail "$name" "nvim palette"
      grep -qE '^(dark|light)$' "$pack/polarity" || fail "$name" "polarity"
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
      virtualisation = {
        memorySize = 4096;
        cores = 4;
      };
      system.stateVersion = "26.05";
    };

    testScript = ''
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
          out = user("${nvimProbe}")
          assert out.startswith("theme-dracula"), out
          assert "Error" not in out, out

      with subtest("applications and tools are installed"):
          commands = [
              "google-chrome-stable", "chromium", "microsoft-edge", "teams-for-linux", "code",
              "neovide", "obsidian", "vlc", "obs", "audacity", "ghb", "inkscape", "foliate",
              "readest", "librepods", "openwhispr", "claude", "claude-vertex", "claude-copilot",
              "codex", "copilot", "opencode", "herdr", "forge", "github-mcp-server",
              "mcp-language-server", "node", "pnpm", "bun", "tsc", "typescript-language-server",
              "rustup", "go", "uv", "poetry", "aws", "az", "func", "azcopy", "cf", "terraform",
              "tflint", "kubectl", "kubecolor", "k9s", "ansible", "mkcert", "psql", "squawk",
              "bw", "fnox", "semgrep", "zizmor", "7zz", "sponge", "tree", "tokei", "lynx",
              "git-filter-repo", "process-compose", "llama-cli", "onedrive", "wine",
              "latexmk", "pdflatex", "python3", "ffmpeg", "magick", "docker", "virt-manager",
              "sops", "age", "ssh-to-age",
          ]
          missing = user("for c in " + " ".join(commands) + "; do command -v $c >/dev/null || echo $c; done").split()
          assert not missing, f"missing commands: {missing}"
          user("forge --version && kubectl version --client && terraform version && node --version")
          user("python3 -c 'import pandas, boto3, openpyxl, docx, pptx, pypdf, pikepdf'")

      with subtest("system services for the tools are running"):
          machine.wait_for_unit("docker.service")
          machine.wait_for_unit("keyd.service")
          machine.succeed("id -nG alex | grep -qw docker")

      with subtest("tmux loads the config and the theme reload file"):
          user("tmux new-session -d -s t && tmux source-file ~/.config/tmux/theme-reload.conf")
          assert user("tmux show -gv @thm_bg").strip() == "#282a36"
          user("tmux kill-server")
    '';
  };
}
