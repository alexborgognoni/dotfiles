# The work identity: the company's email and keys, and its GitHub Enterprise.
# It becomes the primary one (see identity/default.nix); the personal one stays
# for ~/personal and ~/dotfiles. The private keys are the sops secrets
# `work.yaml`.
{ config, lib, ... }:
{
  config = lib.mkIf config.my.corporate.enable {
    # The work keys, decrypted like the personal ones (standalone: sops-nix of
    # Home Manager; on NixOS the secrets module hands them over)
    sops.secrets = lib.mkIf config.my.standalone {
      ssh-work.sopsFile = ../../../secrets/work.yaml;
      gpg-work.sopsFile = ../../../secrets/work.yaml;
    };
    my.identity.files = lib.mkIf config.my.standalone {
      sshWork = config.sops.secrets.ssh-work.path;
      gpgWork = config.sops.secrets.gpg-work.path;
    };

    my.identity.work = {
      email = "alex.borgognoni@deutsche-boerse.com";
      gpgKey = "E69B33C4684313461110E75783E2B86EB1BD39F2";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICx+cqOXmeVOKmE6pOjeoiDOIY6DpS9QMulJDFgLJC7w alex.borgognoni@deutsche-boerse.com";
      githubHost = "github.deutsche-boerse.de";
    };
  };
}
