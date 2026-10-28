# Personal scripts (previously in ~/.local/bin on Ubuntu).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Switch Claude Code's env to a provider profile, then start it.
  # Profiles: ~/.claude/settings.<name>.json (only their `env` is copied).
  claudeProfile = name: extra: ''
    profile="$HOME/.claude/settings.${name}.json"
    active="$HOME/.claude/settings.json"
    [[ -f "$profile" ]] || { echo "missing $profile" >&2; exit 1; }
    if [[ -f "$active" ]]; then
      jq --slurpfile p "$profile" '.env = $p[0].env' "$active" > "$active.tmp"
      mv "$active.tmp" "$active"
    else
      cp "$profile" "$active"
    fi
    ${extra}
    exec claude "$@"
  '';
in
{
  home.packages = [
    # Claude Code against DBG Vertex AI
    (pkgs.writeShellApplication {
      name = "claude-vertex";
      runtimeInputs = [
        pkgs.jq
        pkgs.unstable.claude-code
      ];
      text = claudeProfile "vertex" "";
    })

    # Claude Code against GitHub Copilot Business, via a local copilot-api proxy
    (pkgs.writeShellApplication {
      name = "claude-copilot";
      runtimeInputs = with pkgs; [
        jq
        curl
        coreutils
        unstable.bun
        unstable.claude-code
      ];
      text = claudeProfile "copilot" ''
        port=4141
        log="$HOME/.claude/copilot-api.log"
        if ! curl -sf -o /dev/null "http://localhost:$port/v1/models"; then
          echo "starting copilot-api proxy on :$port (log: $log)..."
          nohup bunx copilot-api@latest start --port "$port" --account-type business >"$log" 2>&1 &
          disown
          for _ in $(seq 1 20); do
            sleep 1
            curl -sf -o /dev/null "http://localhost:$port/v1/models" && { echo "proxy up"; break; }
          done
          curl -sf -o /dev/null "http://localhost:$port/v1/models" || {
            echo "proxy failed to start, see $log" >&2
            exit 1
          }
        fi
      '';
    })
  ]
  # Corporate network rescue (Zscaler, Ubuntu's NetworkManager and systemd);
  # run as is, with the system's tools
  ++ lib.optionals (config.my.profile == "work") (
    map (name: pkgs.writeScriptBin name (builtins.readFile ./${name})) [
      "fix-zscaler"
      "net-diag"
      "net-rescue"
    ]
  );
}
