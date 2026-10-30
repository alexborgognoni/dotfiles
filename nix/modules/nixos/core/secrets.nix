# sops-nix: secrets are stored encrypted in secrets/<host>.yaml (see
# ../../../.sops.yaml for who can decrypt them). Machines decrypt at boot with
# their SSH host key; edit with `sops secrets/<host>.yaml` (needs the admin key
# in ~/.config/sops/age/keys.txt).
#
# With secrets enabled, users are fully declarative: the login password comes
# from the `<user>-password` secret (a yescrypt hash, `mkpasswd -m yescrypt`).
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.secrets;
  user = config.my.user.name;
  isWork = config.my.profile == "work";
  identitySecret = sopsFile: {
    inherit sopsFile;
    owner = user;
    mode = "0400";
  };
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.my.secrets = {
    enable = lib.mkEnableOption "sops-nix secrets for this host";
    file = lib.mkOption {
      type = lib.types.path;
      description = "Encrypted secrets file for this host.";
    };
  };

  config = lib.mkMerge [
    {
      # Tools to edit secrets and enroll new machines.
      environment.systemPackages = with pkgs; [
        sops
        age
        ssh-to-age
      ];
    }

    (lib.mkIf cfg.enable {
      sops = {
        defaultSopsFile = cfg.file;
        age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        secrets = {
          "${user}-password".neededForUsers = true;

          # Identity keys, readable only by the user (see modules/home/identity/)
          ssh-personal = identitySecret ../../../secrets/personal.yaml;
          gpg-personal = identitySecret ../../../secrets/personal.yaml;
        }
        // lib.optionalAttrs isWork {
          ssh-work = identitySecret ../../../secrets/work.yaml;
          gpg-work = identitySecret ../../../secrets/work.yaml;
        };
      };

      home-manager.users.${user}.my.identity.files = {
        sshPersonal = config.sops.secrets.ssh-personal.path;
        gpgPersonal = config.sops.secrets.gpg-personal.path;
      }
      // lib.optionalAttrs isWork {
        sshWork = config.sops.secrets.ssh-work.path;
        gpgWork = config.sops.secrets.gpg-work.path;
      };

      users.mutableUsers = false;
      users.users.${user}.hashedPasswordFile = config.sops.secrets."${user}-password".path;

      # The host key is the decryption key: make sure it exists.
      services.openssh.hostKeys = lib.mkDefault [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    })
  ];
}
