# Corporate network and keyboard settings of the work laptop (Zscaler TLS
# inspection, the company's Artifactory is in the home layer). Enabled by the
# machine: `my.corporate.enable = true;` in systems/<machine>.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  ca = "/etc/ssl/certs/ca-certificates.crt";
in
{
  options.my.corporate.enable = lib.mkEnableOption "the corporate settings: root CA for Nix and Chrome, Alt+hjkl arrow keys";

  config = lib.mkIf config.my.corporate.enable {
    # Corporate root CA (Zscaler) via Ubuntu's trust store: for the Nix
    # daemon's downloads and for source fetches in the build sandbox.
    nix.settings = {
      ssl-cert-file = ca;
      extra-sandbox-paths = [ ca ];
    };
    # (scripts/bootstrap-nix.sh creates it first, so the initial build works)
    environment.etc."systemd/system/nix-daemon.service.d/corporate-ca.conf" = {
      text = ''
        [Service]
        Environment=NIX_SSL_CERT_FILE=${ca}
        Environment=NIX_GIT_SSL_CAINFO=${ca}
      '';
      replaceExisting = true;
    };

    # Chrome from Nix does not pick up the corporate roots from NSS the way the
    # distribution's Chrome did (ERR_CERT_AUTHORITY_INVALID behind Zscaler).
    # Its enterprise policy CACertificates does: built from the CAs IT deploys
    # to /usr/local/share/ca-certificates (nothing corporate in this repo), at
    # boot and on every switch.
    systemd.services.chrome-corporate-cas = {
      description = "Chrome policy: trust the locally installed CA certificates";
      wantedBy = [ "system-manager.target" ];
      after = [ "local-fs.target" ];
      path = [
        pkgs.openssl
        pkgs.coreutils
        pkgs.jq
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        dir=/etc/opt/chrome/policies/managed
        out="$dir/system-manager-local-cas.json"
        mkdir -p "$dir"
        certs=()
        for crt in /usr/local/share/ca-certificates/*.crt /usr/local/share/ca-certificates/*/*.crt; do
          [ -f "$crt" ] || continue
          certs+=("$(openssl x509 -in "$crt" -outform DER | base64 -w0)")
        done
        if [ ''${#certs[@]} -eq 0 ]; then
          rm -f "$out"
          exit 0
        fi
        printf '%s\n' "''${certs[@]}" | jq -R . | jq -s '{ CACertificates: . }' > "$out.tmp"
        chmod 644 "$out.tmp"
        mv "$out.tmp" "$out"
      '';
    };

    # Alt+hjkl as arrow keys, system-wide (keyd.nix merges the sections)
    my.keyd.settings = (import ../shared/keyd.nix).altArrows;
  };
}
