# User-level secrets (sops-nix), decrypted with the admin age key. The work
# keys' secrets are declared by corporate/identity.nix.
{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  config = lib.mkIf config.my.standalone {
    sops = {
      age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
      secrets = {
        ssh-personal.sopsFile = ../../../secrets/personal.yaml;
        gpg-personal.sopsFile = ../../../secrets/personal.yaml;
      };
    };

    # sops-nix decrypts through a systemd user service. Without a running
    # user manager (containers, activation at early boot) run its install
    # script directly, so the secrets exist before they are used.
    home.activation.sopsWithoutSystemd = lib.hm.dag.entryBetween [ "importGpgKeys" ] [ "sops-nix" ] ''
      if ! ${config.systemd.user.systemctlPath} --user is-system-running >/dev/null 2>&1 \
        && [ "$(${config.systemd.user.systemctlPath} --user is-system-running 2>&1)" != degraded ]; then
        verboseEcho "Decrypting secrets without systemd"
        run ${lib.head (lib.toList config.systemd.user.services.sops-nix.Service.ExecStart)}
      fi
    '';

    my.identity.files = {
      sshPersonal = config.sops.secrets.ssh-personal.path;
      gpgPersonal = config.sops.secrets.gpg-personal.path;
    };
  };
}
