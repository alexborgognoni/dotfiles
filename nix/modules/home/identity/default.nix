# Who you are: git, SSH and GPG, with the personal identity here and an
# optional work identity (my.identity.work, set by corporate/identity.nix). The
# private keys come from sops secrets (secrets/personal.yaml, work.yaml),
# decrypted by NixOS (modules/nixos/core/secrets.nix) or, standalone, by Home
# Manager (standalone.nix); either way they arrive as my.identity.files.
#   without a work identity: ~/.ssh/id_ed25519 = personal key
#   with one:                ~/.ssh/id_ed25519 = work key,
#                            ~/.ssh/id_ed25519_personal = personal key
#
#   git.nix   git (aliases: git-aliases.nix), GitHub CLI
#   ssh.nix   ssh config and the key files
#   gpg.nix   gpg agent, import of the secret keys
{ lib, ... }:
let
  identityOptions = {
    email = lib.mkOption { type = lib.types.str; };
    gpgKey = lib.mkOption {
      type = lib.types.str;
      description = "Fingerprint of the GPG key that signs commits and tags.";
    };
    sshPublicKey = lib.mkOption {
      type = lib.types.str;
      description = "Public SSH key (the private one comes from sops).";
    };
  };
in
{
  imports = [
    ./git.nix
    ./gpg.nix
    ./ssh.nix
  ];

  options.my.identity = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "Alex Borgognoni";
      description = "Name on commits, for every identity.";
    };

    personal = lib.mkOption {
      type = lib.types.submodule { options = identityOptions; };
      default = {
        email = "alex.bor0419@gmail.com";
        gpgKey = "A7B3752F07393182FB899C11D5A5A7F2739FC452";
        sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAoxgUAc1803bi1jrE64lTyEZYHR4ADVvUONz0S0UJg alex.bor0419@gmail.com";
      };
    };

    work = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = identityOptions // {
            githubHost = lib.mkOption {
              type = lib.types.str;
              description = "The company's GitHub Enterprise host (SSH instead of HTTPS).";
            };
          };
        }
      );
      default = null;
      description = ''
        A work identity: the primary one (default git identity, ~/.ssh/id_ed25519),
        with the personal one kept for ~/personal and ~/dotfiles.
      '';
    };

    files = lib.genAttrs [ "sshPersonal" "sshWork" "gpgPersonal" "gpgWork" ] (
      name:
      lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path of the decrypted ${name} secret (set by the secrets backend).";
      }
    );
  };
}
