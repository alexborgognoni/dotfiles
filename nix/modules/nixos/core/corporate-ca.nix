# Trust extra root CAs (e.g. Zscaler's TLS-inspection CA) everywhere,
# including inside the Nix build sandbox, where source fetchers (fetchgit)
# otherwise only see nixpkgs' own certificate bundle.
{ config, lib, ... }:
let
  certs = config.my.corporateCA;
  # A real file outside /nix/store: store paths can't be bind-mounted into
  # the sandbox individually.
  bundle = "/etc/nix/ca-bundle.crt";
in
{
  options.my.corporateCA = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [ ];
    description = "Additional root certificates to trust system-wide and in the Nix sandbox.";
  };

  config = lib.mkIf (certs != [ ]) {
    security.pki.certificateFiles = certs;

    environment.etc."nix/ca-bundle.crt" = {
      source = config.security.pki.caBundle;
      mode = "0444";
    };

    nix.settings.extra-sandbox-paths = [ bundle ];
    systemd.services.nix-daemon.environment = {
      NIX_SSL_CERT_FILE = bundle;
      NIX_GIT_SSL_CAINFO = bundle;
    };
  };
}
