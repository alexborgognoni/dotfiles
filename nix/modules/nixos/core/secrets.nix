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

  # SSH and GPG keys, readable only by the user. The work keys exist only on
  # the corporate laptop (standalone Home Manager), not here.
  identity = (import ../../shared/identity-secrets.nix { inherit lib; }).forGroup {
    inherit config;
    group = "personal";
    extra = {
      owner = user;
      mode = "0400";
    };
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
        }
        // identity.secrets;
      };

      # (modules/home/identity/ puts them in ~/.ssh and the GPG keyring)
      home-manager.users.${user}.my.identity.files = identity.files;

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
