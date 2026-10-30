# Formatting and linting of the whole repository (not only nix/).
#
#   nix fmt                 format everything (treefmt: nixfmt, shfmt, stylua)
#   nix run path:nix#lint   format check + statix + deadnix + shellcheck + selene
#   nix flake check         includes `lint-nix`: format, statix and deadnix on nix/
#
# Both commands find the repository through git, so they work from any
# directory inside it. Generated files are left alone (see `generated`).
{ pkgs }:
let
  luaConfig = "nix/modules/home/editor/astronvim/config";

  # Written by tools, not by us
  generated = [ "nix/hosts/vm/hardware-configuration.nix" ];

  # Shell scripts without a .sh suffix
  shellScripts = [
    "install"
    "nix/modules/home/corporate/scripts/*"
  ];

  formatter = pkgs.treefmt.withConfig {
    runtimeInputs = [
      pkgs.nixfmt
      pkgs.shfmt
      pkgs.stylua
    ];
    settings = {
      on-unmatched = "info";
      excludes = generated;
      formatter = {
        nixfmt = {
          command = "nixfmt";
          includes = [ "*.nix" ];
        };
        shfmt = {
          command = "shfmt";
          options = [
            "-i"
            "2"
            "-ci"
            "-w"
          ];
          includes = [ "*.sh" ] ++ shellScripts;
        };
        stylua = {
          command = "stylua";
          options = [
            "--config-path"
            "${luaConfig}/.stylua.toml"
          ];
          includes = [ "*.lua" ];
        };
      };
    };
  };

  lint = pkgs.writeShellApplication {
    name = "lint";
    runtimeInputs = [
      formatter
      pkgs.git
      pkgs.gnutar
      pkgs.diffutils
      pkgs.statix
      pkgs.deadnix
      pkgs.shellcheck
      pkgs.selene
    ];
    text = ''
      cd "$(git rev-parse --show-toplevel)"
      status=0
      step() {
        local name="$1"
        shift
        printf '\n\033[1;34m==> %s\033[0m\n' "$name"
        "$@" || status=1
      }

      # Formats a copy of the tracked files and shows what would change, so
      # the check itself never touches the working tree
      # shellcheck disable=SC2329 # called through step
      format_check() {
        local tmp out
        tmp="$(mktemp -d)"
        git ls-files -z | tar --null -T - --ignore-failed-read -cf - 2>/dev/null | tar -xf - -C "$tmp"
        treefmt --tree-root "$tmp" --no-cache >/dev/null 2>&1 || true
        out="$(git ls-files -z | while IFS= read -r -d "" f; do
          if [ -f "$f" ]; then diff -u "$f" "$tmp/$f" || true; fi
        done)"
        rm -rf "$tmp"
        if [ -n "$out" ]; then
          printf '%s\n' "$out"
          echo "not formatted: run nix fmt"
          return 1
        fi
      }

      step "format" format_check
      step "statix" bash -c "cd nix && statix check ."
      step "deadnix" deadnix --fail --exclude ${toString generated} nix
      # Every .sh and the extension-less scripts, all bash
      files=()
      while IFS= read -r f; do files+=("$f"); done < <(git ls-files '*.sh' ${toString shellScripts})
      step "shellcheck" shellcheck --shell=bash --external-sources --severity=warning "''${files[@]}"
      step "selene" bash -c 'cd ${luaConfig} && selene .'

      if [ "$status" -eq 0 ]; then printf '\nlint: all clean\n'; else printf '\nlint: problems found\n'; fi
      exit "$status"
    '';
  };

  # The same for the flake's own files, in the sandbox (`nix flake check`)
  lintNix =
    src:
    pkgs.runCommand "lint-nix"
      {
        nativeBuildInputs = [
          pkgs.nixfmt
          pkgs.statix
          pkgs.deadnix
        ];
      }
      ''
        cd ${src}
        nixfmt --check $(find . -name '*.nix' ${
          pkgs.lib.concatMapStringsSep " " (f: "-not -path ./${pkgs.lib.removePrefix "nix/" f}") generated
        })
        statix check .
        deadnix --fail --exclude ${
          pkgs.lib.concatMapStringsSep " " (f: pkgs.lib.removePrefix "nix/" f) generated
        } .
        touch $out
      '';
in
{
  inherit formatter lint lintNix;
}
